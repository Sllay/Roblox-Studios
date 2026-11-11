#!/usr/bin/env python3
"""Discover, validate and selectively build the Roblox projects (stdlib only)."""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "games" / "maps"
SLUG = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")


class WorkspaceError(Exception):
    pass


def load_games():
    games = {}
    if not MAPS.is_dir():
        raise WorkspaceError(f"Missing games directory: {MAPS}")
    for directory in sorted(MAPS.iterdir()):
        if not directory.is_dir() or directory.name.startswith("_"):
            continue
        if not SLUG.fullmatch(directory.name):
            raise WorkspaceError(f"Invalid game directory slug: {directory.name}")
        manifest_file = directory / "game.manifest.json"
        if not manifest_file.is_file():
            raise WorkspaceError(f"Missing manifest: {manifest_file}")
        try:
            game = json.loads(manifest_file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            raise WorkspaceError(f"Invalid JSON: {manifest_file}: {exc}") from exc
        if not isinstance(game, dict) or game.get("schemaVersion") != 1:
            raise WorkspaceError(f"Unsupported schemaVersion: {manifest_file}")
        if game.get("slug") != directory.name or game.get("platform") != "roblox":
            raise WorkspaceError(f"Wrong slug/platform in: {manifest_file}")
        places = game.get("places")
        if not isinstance(places, list) or not places:
            raise WorkspaceError(f"No places defined: {manifest_file}")
        seen = set()
        for place in places:
            if not isinstance(place, dict) or not isinstance(place.get("slug"), str):
                raise WorkspaceError(f"Malformed place: {manifest_file}")
            place_slug = place["slug"]
            if not SLUG.fullmatch(place_slug) or place_slug in seen:
                raise WorkspaceError(f"Invalid/duplicate place {place_slug}: {manifest_file}")
            seen.add(place_slug)
            expected = f"game/places/{place_slug}/default.project.json"
            if place.get("project") != expected:
                raise WorkspaceError(f"Expected project={expected} in {manifest_file}")
            project_file = directory / expected
            if not project_file.is_file():
                raise WorkspaceError(f"Missing Rojo project: {project_file}")
            try:
                project = json.loads(project_file.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError) as exc:
                raise WorkspaceError(f"Invalid project JSON: {project_file}: {exc}") from exc
            if not isinstance(project, dict) or not isinstance(project.get("tree"), dict) or project["tree"].get("$className") != "DataModel":
                raise WorkspaceError(f"Project must describe a DataModel: {project_file}")
            def check_paths(node):
                if isinstance(node, dict):
                    if "$path" in node:
                        rel_path = node["$path"]
                        if not isinstance(rel_path, str):
                            raise WorkspaceError(f"Invalid $path in {project_file}")
                        candidate = (project_file.parent / rel_path).resolve()
                        if not candidate.is_relative_to(ROOT.resolve()) or not candidate.exists():
                            raise WorkspaceError(f"Missing or out-of-repo $path {rel_path}: {project_file}")
                        # Docs are never accidentally compiled through Rojo.
                        if (directory / "docs").resolve() == candidate or (directory / "agents").resolve() == candidate:
                            raise WorkspaceError(f"Agent/docs path cannot be compiled: {project_file}")
                    for value in node.values():
                        check_paths(value)
                elif isinstance(node, list):
                    for value in node:
                        check_paths(value)
            check_paths(project["tree"])
            for key in ("placeId", "universeId"):
                value = place.get(key)
                if value is not None and (not isinstance(value, int) or isinstance(value, bool) or value <= 0):
                    raise WorkspaceError(f"{key} must be null or positive integer: {manifest_file}")
        for doc in ("AGENTS.md", "GDD.md", "ARCHITECTURE.md"):
            if not (directory / doc).is_file():
                raise WorkspaceError(f"Missing {doc} in {directory}")
        games[directory.name] = game
    if not games:
        raise WorkspaceError("No runnable games found (templates excluded)")
    return games


def build_place(game_slug, place, out_root):
    project_path = MAPS / game_slug / place["project"]
    output = out_root / game_slug / (place["slug"] + ".rbxlx")
    output.parent.mkdir(parents=True, exist_ok=True)
    print(f"BUILD {game_slug}/{place['slug']} -> {output}", flush=True)
    proc = subprocess.run(["rojo", "build", str(project_path), "-o", str(output)], check=False)
    if proc.returncode:
        raise WorkspaceError(f"Rojo build failed: {game_slug}/{place['slug']} (exit {proc.returncode})")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("validate")
    sub.add_parser("list")
    build = sub.add_parser("build")
    target = build.add_mutually_exclusive_group(required=True)
    target.add_argument("--all", action="store_true", help="Build every declared Place")
    target.add_argument("--game", help="Select one game")
    build.add_argument("--place", help="Select a Place within --game")
    args = parser.parse_args(argv)
    try:
        games = load_games()
        if args.command == "validate":
            print(f"VALID: {len(games)} games, {sum(len(g['places']) for g in games.values())} places")
        elif args.command == "list":
            for game_slug, game in games.items():
                print(f"{game_slug}: {', '.join(p['slug'] for p in game['places'])}")
        elif args.command == "build":
            if args.place and not args.game:
                raise WorkspaceError("--place requires --game")
            if not shutil.which("rojo"):
                raise WorkspaceError("Rojo CLI not found; install Rojo 7.7.1 (see rokit.toml)")
            if args.game and args.game not in games:
                raise WorkspaceError(f"Unknown game: {args.game}")
            for slug, game in games.items():
                if args.game and slug != args.game:
                    continue
                selected = [p for p in game["places"] if not args.place or p["slug"] == args.place]
                if not selected:
                    raise WorkspaceError(f"Unknown Place '{args.place}' in '{slug}'")
                for place in selected:
                    build_place(slug, place, ROOT / "dist")
        return 0
    except WorkspaceError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
