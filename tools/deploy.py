#!/usr/bin/env python3
"""Validate deployment targets and publish a Place using Roblox Assets API.

No network requests are made unless 'publish --execute' is specified.
Keep Open Cloud keys in GitHub Environments, never in manifests.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from workspace import MAPS, ROOT, WorkspaceError, load_games

ENVIRONMENTS = ("staging", "production")
API_BASE = "https://apis.roblox.com/assets/v1"
OPERATION_PATH = re.compile(r"^operations/[a-zA-Z0-9_-]+$")


def normalized_id(value, location):
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (str, int)):
        raise WorkspaceError(f"{location}: expected a positive ID or null")
    text = str(value)
    if not re.fullmatch(r"[1-9][0-9]*", text):
        raise WorkspaceError(f"{location}: expected a positive numeric ID or null")
    return text


def load_targets(game_slug, game):
    path = MAPS / game_slug / "deploy.targets.json"
    if not path.is_file():
        raise WorkspaceError(f"Deployment targets missing: {path}")
    try:
        targets = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise WorkspaceError(f"Invalid deployment targets file {path}: {exc}") from exc
    if not isinstance(targets, dict) or targets.get("schemaVersion") != 1:
        raise WorkspaceError(f"Invalid deployment schema: {path}")
    environments = targets.get("environments")
    if not isinstance(environments, dict) or set(environments) != set(ENVIRONMENTS):
        raise WorkspaceError(f"Expected staging and production environments in {path}")
    slugs = {p["slug"] for p in game["places"]}
    occupied = {}
    for environment in ENVIRONMENTS:
        config = environments[environment]
        if not isinstance(config, dict):
            raise WorkspaceError(f"Invalid environment {environment} in {path}")
        universe = normalized_id(config.get("universeId"), f"{game_slug}/{environment}.universeId")
        place_ids = config.get("placeIds")
        if not isinstance(place_ids, dict) or set(place_ids) != slugs:
            raise WorkspaceError(f"{game_slug}/{environment}: placeIds must match declared places {sorted(slugs)}")
        seen = set()
        for place in sorted(slugs):
            id_value = normalized_id(place_ids[place], f"{game_slug}/{environment}/{place}.placeId")
            if id_value is not None:
                if id_value in seen:
                    raise WorkspaceError(f"{game_slug}/{environment}: duplicate Place ID {id_value}")
                seen.add(id_value)
                if universe is None:
                    raise WorkspaceError(f"{game_slug}/{environment}: configure Universe ID before Place IDs")
                if id_value in occupied:
                    raise WorkspaceError(
                        f"{game_slug}: Place ID {id_value} appears in both {occupied[id_value]} and {environment}"
                    )
                occupied[id_value] = environment
        if universe is None and any(place_ids[place] is not None for place in slugs):
            raise WorkspaceError(f"{game_slug}/{environment}: missing Universe ID")
    s = normalized_id(environments["staging"]["universeId"], f"{game_slug}/staging")
    p = normalized_id(environments["production"]["universeId"], f"{game_slug}/production")
    if s is not None and p is not None and s == p:
        raise WorkspaceError(f"{game_slug}: staging and production must use distinct Universe IDs")
    return targets


def load_all():
    games = load_games()
    targets = {slug: load_targets(slug, game) for slug, game in games.items()}
    validate_global_targets(targets)
    return games, targets


def validate_global_targets(targets):
    """Prevent any Place alias and staging/production Universe overlap repository-wide."""
    occupied = {}
    universe_env = {}
    for slug, config in targets.items():
        for env, dest in config["environments"].items():
            universe = normalized_id(dest["universeId"], "universeId")
            if universe:
                if universe in universe_env and universe_env[universe] != env:
                    raise WorkspaceError(f"Universe {universe} shared across staging and production")
                universe_env[universe] = env
            for place, raw in dest["placeIds"].items():
                pid = normalized_id(raw, "placeId")
                if pid:
                    label = f"{slug}/{place}/{env}"
                    if pid in occupied:
                        raise WorkspaceError(f"Place ID {pid} shared by {occupied[pid]} and {label}")
                    occupied[pid] = label


def resolve(games, targets, game_slug, place_slug, environment):
    if game_slug not in games:
        raise WorkspaceError(f"Unknown game: {game_slug}")
    if environment not in ENVIRONMENTS:
        raise WorkspaceError(f"Unknown environment: {environment}")
    game = games[game_slug]
    if place_slug not in {p["slug"] for p in game["places"]}:
        raise WorkspaceError(f"Unknown Place {place_slug} in {game_slug}")
    config = targets[game_slug]["environments"][environment]
    universe = normalized_id(config["universeId"], "universeId")
    place = normalized_id(config["placeIds"][place_slug], "placeId")
    if universe is None or place is None:
        raise WorkspaceError(
            f"Target is not configured: {game_slug}/{place_slug}/{environment}. "
            f"Edit games/maps/{game_slug}/deploy.targets.json (IDs are not secrets)."
        )
    return {"game": game_slug, "place": place_slug, "environment": environment,
            "universeId": universe, "placeId": place,
            "fullPlaceBuildAuthoritative": next(p for p in game["places"] if p["slug"] == place_slug).get("fullPlaceBuildAuthoritative") is True,
            "file": ROOT / "dist" / game_slug / (place_slug + ".rbxlx")}


def multipart_place_file(place_id, source):
    boundary = "----RobloxWorkspace" + uuid.uuid4().hex
    metadata = json.dumps({"assetId": int(place_id), "assetType": "Place", "published": True})
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n"
        f"Content-Type: application/json\r\n\r\n{metadata}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"place.rbxlx\"\r\n"
        f"Content-Type: application/xml\r\n\r\n"
    ).encode("utf-8") + source.read_bytes() + f"\r\n--{boundary}--\r\n".encode("utf-8")
    return f"multipart/form-data; boundary={boundary}", body


def request_json(url, key, *, method="GET", data=None, content_type=None):
    headers = {"x-api-key": key, "Accept": "application/json"}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        message = exc.read(1000).decode("utf-8", errors="replace")
        raise WorkspaceError(f"Roblox API rejected request (HTTP {exc.code}): {message}") from None
    except (urllib.error.URLError, TimeoutError) as exc:
        raise WorkspaceError(f"Roblox API network error: {exc}") from exc
    except (ValueError, UnicodeError) as exc:
        raise WorkspaceError(f"Roblox API sent invalid JSON: {exc}") from exc


def publish(target, key):
    if target.get("fullPlaceBuildAuthoritative") is not True:
        raise WorkspaceError("Full Place replacement blocked: repository is not declared authoritative for this Place")
    from scene_sync import require_current
    require_current(target,key)
    artifact = target["file"]
    if not artifact.is_file() or artifact.stat().st_size == 0:
        raise WorkspaceError(f"Missing/empty built Place: {artifact}. Run 'workspace.py build' first.")
    content_type, payload = multipart_place_file(target["placeId"], artifact)
    place_id = target["placeId"]
    print(f"Publishing {target['game']}/{target['place']} to {target['environment']} "
          f"(Universe {target['universeId']}, Place {place_id})", flush=True)
    initial = request_json(f"{API_BASE}/assets/{place_id}", key, method="PATCH",
                           data=payload, content_type=content_type)
    operation = initial.get("path") if isinstance(initial, dict) else None
    if not isinstance(operation, str) or not OPERATION_PATH.fullmatch(operation):
        raise WorkspaceError("Upload response did not contain a valid operation path")
    for attempt in range(30):
        status = request_json(f"{API_BASE}/{operation}", key)
        if not isinstance(status, dict):
            raise WorkspaceError("Invalid operation response")
        if status.get("done") is True:
            if "error" in status:
                raise WorkspaceError(f"Roblox processing failed: {status['error']}")
            result = status.get("response")
            if not isinstance(result, dict) or result.get("isPublished") is not True:
                raise WorkspaceError(f"Publish not confirmed as public version: {status}")
            if result.get("path") != f"assets/{place_id}":
                raise WorkspaceError("Published asset does not match requested Place ID")
            print(f"SUCCESS: Place {place_id}, revision {result.get('revisionId', 'unknown')}")
            return
        if attempt < 29:
            time.sleep(2)
    raise WorkspaceError("Roblox did not finish the publish operation within the polling limit")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("validate", help="Validate every game's targets (null IDs are allowed)")
    cmd = sub.add_parser("show", help="Show configured IDs for one target, no secrets")
    publish_cmd = sub.add_parser("publish", help="Dry-run unless --execute is supplied")
    for p in (cmd, publish_cmd):
        p.add_argument("--game", required=True)
        p.add_argument("--place", required=True)
        p.add_argument("--environment", choices=ENVIRONMENTS, required=True)
    publish_cmd.add_argument("--execute", action="store_true", help="Actually call Roblox API")
    args = parser.parse_args(argv)
    try:
        games, targets = load_all()
        if args.action == "validate":
            print(f"VALID: deployment targets for {len(games)} games")
            return 0
        target = resolve(games, targets, args.game, args.place, args.environment)
        if args.action == "show" or not args.execute:
            print(json.dumps({k: str(v) for k, v in target.items()}, indent=2))
            if args.action == "publish":
                print("DRY RUN ONLY: pass --execute to actually publish.")
            return 0
        # Mandatory even when executed directly, outside GitHub Actions.
        from script_quality import main as check_luau
        if check_luau([]) != 0:
            raise WorkspaceError("Luau pre-deploy quality gate failed; refusing remote write")
        key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
        if not key:
            raise WorkspaceError("ROBLOX_OPEN_CLOUD_API_KEY secret is not set")
        publish(target, key)
        return 0
    except WorkspaceError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
