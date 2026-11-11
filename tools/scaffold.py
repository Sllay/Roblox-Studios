#!/usr/bin/env python3
"""Create games/Places deterministically from the versioned _template."""
from __future__ import annotations
import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "games" / "maps"
SLUG = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
ID = re.compile(r"^[1-9][0-9]*$")

class ScaffoldError(Exception):
    pass

def check_slug(value):
    if not isinstance(value, str) or not SLUG.fullmatch(value):
        raise ScaffoldError(f"Invalid slug: {value!r}")
    return value

def check_id(value):
    if not isinstance(value, str) or not ID.fullmatch(value):
        raise ScaffoldError("IDs must contain positive decimal digits without leading zeros")
    return value

def read_json(path):
    try:
        result = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ScaffoldError(f"Cannot parse {path}: {exc}") from exc
    if not isinstance(result, dict):
        raise ScaffoldError(f"Expected JSON object: {path}")
    return result

def save_json(path, content):
    path.write_text(json.dumps(content, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def rename_place(place_dir, label):
    project_file = place_dir / "default.project.json"
    project = read_json(project_file)
    project["name"] = label
    save_json(project_file, project)
    for script in place_dir.rglob("*.luau"):
        source = script.read_text(encoding="utf-8")
        script.write_text(source.replace("TemplateMain", label), encoding="utf-8")

def new_game(maps, game_slug, name):
    game_slug = check_slug(game_slug)
    if not isinstance(name, str) or not name.strip():
        raise ScaffoldError("Game name must be provided")
    source = maps / "_template"
    target = maps / game_slug
    if target.exists():
        raise ScaffoldError(f"Game already exists, refusing overwrite: {target}")
    if not (source / "game.manifest.json").is_file():
        raise ScaffoldError("Missing canonical _template")
    try:
        shutil.copytree(source, target)
        manifest_file = target / "game.manifest.json"
        manifest = read_json(manifest_file)
        manifest["slug"] = game_slug
        manifest["name"] = name.strip()
        save_json(manifest_file, manifest)
        rename_place(target / "game" / "places" / "main", game_slug.replace("-", "_") + "_main")
        (target / "README.md").write_text(
            f"# {name.strip()}\n\nCreated with the official Roblox-Studios game template.\n"
            "Read AGENTS.md, ARCHITECTURE.md, GDD.md and deploy.targets.json before editing.\n",
            encoding="utf-8"
        )
    except Exception:
        if target.is_dir():
            shutil.rmtree(target)
        raise
    return target

def add_place(maps, game_slug, place_slug):
    game_slug, place_slug = check_slug(game_slug), check_slug(place_slug)
    game = maps / game_slug
    manifest_path, targets_path = game / "game.manifest.json", game / "deploy.targets.json"
    manifest, targets = read_json(manifest_path), read_json(targets_path)
    if manifest.get("slug") != game_slug:
        raise ScaffoldError("Game manifest slug mismatch")
    if any(p.get("slug") == place_slug for p in manifest["places"]):
        raise ScaffoldError(f"Place already exists: {place_slug}")
    source = maps / "_template" / "game" / "places" / "main"
    target = game / "game" / "places" / place_slug
    if target.exists():
        raise ScaffoldError("Place directory already exists")
    old_manifest, old_targets = manifest_path.read_bytes(), targets_path.read_bytes()
    try:
        shutil.copytree(source, target)
        rename_place(target, game_slug.replace("-", "_") + "_" + place_slug.replace("-", "_"))
        manifest["places"].append({
            "slug": place_slug,
            "name": place_slug.replace("-", " ").title(),
            "project": f"game/places/{place_slug}/default.project.json"
        })
        for env in ("staging", "production"):
            targets["environments"][env]["placeIds"][place_slug] = None
        save_json(manifest_path, manifest)
        save_json(targets_path, targets)
    except Exception:
        manifest_path.write_bytes(old_manifest)
        targets_path.write_bytes(old_targets)
        if target.is_dir():
            shutil.rmtree(target)
        raise
    return target

def set_ids(maps, game_slug, place_slug, env, universe_id, place_id):
    game_slug, place_slug = check_slug(game_slug), check_slug(place_slug)
    universe_id, place_id = check_id(universe_id), check_id(place_id)
    if env not in ("staging", "production"):
        raise ScaffoldError("Invalid environment")
    game = maps / game_slug
    manifest = read_json(game / "game.manifest.json")
    if manifest.get("slug") != game_slug or place_slug not in {p["slug"] for p in manifest["places"]}:
        raise ScaffoldError("Unknown game/place")
    targets_path = game / "deploy.targets.json"
    targets = read_json(targets_path)
    target = targets["environments"][env]
    if target["universeId"] is not None and str(target["universeId"]) != universe_id:
        raise ScaffoldError("Universe ID already set differently; verify before editing")
    if target["placeIds"][place_slug] is not None and str(target["placeIds"][place_slug]) != place_id:
        raise ScaffoldError("Place ID already set differently; verify before editing")
    other = "production" if env == "staging" else "staging"
    other_universe = targets["environments"][other]["universeId"]
    if other_universe is not None and str(other_universe) == universe_id:
        raise ScaffoldError("Staging and production must use different Universe IDs")
    for dest_env, cfg in targets["environments"].items():
        for dest_place, value in cfg["placeIds"].items():
            if value is not None and str(value) == place_id and (dest_env, dest_place) != (env, place_slug):
                raise ScaffoldError(f"Duplicate Place ID in {dest_env}/{dest_place}")
    target["universeId"] = universe_id
    target["placeIds"][place_slug] = place_id
    save_json(targets_path, targets)
    return targets_path

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    new = sub.add_parser("new-game")
    new.add_argument("--slug", required=True)
    new.add_argument("--name", required=True)
    extra = sub.add_parser("add-place")
    extra.add_argument("--game", required=True)
    extra.add_argument("--place", required=True)
    ids = sub.add_parser("set-ids")
    ids.add_argument("--game", required=True)
    ids.add_argument("--place", required=True)
    ids.add_argument("--environment", choices=("staging", "production"), required=True)
    ids.add_argument("--universe-id", required=True)
    ids.add_argument("--place-id", required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "new-game":
            result = new_game(MAPS, args.slug, args.name)
        elif args.command == "add-place":
            result = add_place(MAPS, args.game, args.place)
        else:
            result = set_ids(MAPS, args.game, args.place, args.environment, args.universe_id, args.place_id)
        print(f"OK: {result}")
        return 0
    except (ScaffoldError, KeyError, TypeError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
