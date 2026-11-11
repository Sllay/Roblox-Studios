#!/usr/bin/env python3
"""Read-only cloud Place spatial inspection and diagram generation."""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

from deploy import load_all, resolve, WorkspaceError

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://apis.roblox.com/cloud/v2"
LUAU = ROOT / "tools" / "scene_inspector.luau"


def request_api(path: str, key: str, *, payload: dict | None = None) -> dict:
    if not path.startswith("universes/") or not re.fullmatch(r"[A-Za-z0-9/_-]+", path) or ".." in path:
        raise WorkspaceError("Unexpected Luau task path")
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE}/{path}", data=data,
        headers={"Accept": "application/json", "x-api-key": key, **({"Content-Type": "application/json"} if data else {})},
        method="POST" if data is not None else "GET"
    )
    try:
        with urllib.request.urlopen(req, timeout=50) as resp:
            result = json.load(resp)
        if not isinstance(result, dict):
            raise WorkspaceError("Unexpected Roblox API response")
        return result
    except urllib.error.HTTPError as exc:
        raise WorkspaceError(f"Roblox API HTTP {exc.code}: {exc.read(350).decode('utf-8', errors='replace')}") from None
    except (urllib.error.URLError, ValueError, TimeoutError) as exc:
        raise WorkspaceError(f"Roblox API request failed: {exc}") from exc


def fetch_scene(universe: str, place: str, key: str) -> dict:
    script = LUAU.read_text(encoding="utf-8")
    assert "SavePlaceAsync(" not in script and "Instance.new(" not in script
    endpoint = f"universes/{universe}/places/{place}/luau-execution-session-tasks"
    task = request_api(endpoint, key, payload={"script": script})
    path = task.get("path")
    if not isinstance(path, str) or not path.startswith(f"universes/{universe}/places/{place}/"):
        raise WorkspaceError("Roblox did not return a valid task path")
    print(f"Read-only inspection task started: {path}", flush=True)
    for attempt in range(40):
        task = request_api(path, key)
        state = task.get("state")
        if state == "COMPLETE":
            if task.get("error"):
                raise WorkspaceError(f"Roblox execution error: {task['error']}")
            output = task.get("output")
            if not isinstance(output, dict) or not isinstance(output.get("results"), list) or not output["results"]:
                raise WorkspaceError("Roblox task completed without return values")
            first = output["results"][0]
            if not isinstance(first, str):
                raise WorkspaceError(f"Expected serialized JSON string in task output, got {type(first).__name__}")
            try:
                result = json.loads(first)
            except (ValueError, TypeError) as exc:
                raise WorkspaceError("Failed to decode scene JSON from Luau task output") from exc
            if not isinstance(result, dict) or result.get("universeId") != universe or result.get("placeId") != place:
                raise WorkspaceError("Reported scene identity does not match requested Place")
            return result
        if state not in ("QUEUED", "PENDING", "PROCESSING"):
            raise WorkspaceError(f"Roblox Luau task failed: {task.get('error', state)}")
        if attempt != 39:
            time.sleep(3)
    raise WorkspaceError("Read-only inspection timed out; no Place modifications were made")


def safe_objects(data: dict) -> list[dict]:
    if data.get("schemaVersion") != 1 or not isinstance(data.get("objects"), list):
        raise ValueError("Unsupported scene report schema")
    result = []
    for obj in data["objects"][:2500]:
        if not isinstance(obj, dict):
            continue
        p, s, color = obj.get("position"), obj.get("size"), obj.get("color")
        if not (isinstance(p, list) and isinstance(s, list) and isinstance(color, list)
                and len(p) == 3 and len(s) == 3 and len(color) == 3):
            continue
        if not all(isinstance(v, (int, float)) and math.isfinite(v) and abs(v) < 1_000_001 for v in p + s):
            continue
        result.append(obj)
    return result


def render_report(data: dict, folder: Path) -> None:
    objects = safe_objects(data)
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "scene.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    canvas = Image.new("RGB", (1200, 950), "#f0f4f8")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    draw.rectangle((0, 0, 1199, 90), fill="#15283b")
    draw.text((20, 15), f"Roblox Scene Inspector | Universe {data.get('universeId')} | Place {data.get('placeId')}", fill="#ffffff", font=font)
    stats = data.get("stats") or {}
    draw.text((20, 41), f"Sampled: {len(objects)} parts | Seen: {stats.get('totalPartsScanned', '?')} | Structural only - NOT game screenshot", fill="#b4d8e8", font=font)

    if objects:
        minx = min(obj["position"][0] - obj["size"][0]/2 for obj in objects)
        maxx = max(obj["position"][0] + obj["size"][0]/2 for obj in objects)
        minz = min(obj["position"][2] - obj["size"][2]/2 for obj in objects)
        maxz = max(obj["position"][2] + obj["size"][2]/2 for obj in objects)
        span = max(maxx - minx, maxz - minz, 20)
        scale = min(1070 / span, 10)
        cx, cz = (minx + maxx) / 2, (minz + maxz) / 2
        count_by_biome: dict[str, int] = {}
        for obj in sorted(objects, key=lambda o: o["size"][0] * o["size"][2], reverse=True):
            name = str(obj.get("name", "?"))
            biome = str(obj.get("biome", "unclassified"))
            count_by_biome[biome] = count_by_biome.get(biome, 0) + 1
            x, _, z = obj["position"]
            sx, _, sz = obj["size"]
            px, pz = 600 + (x - cx) * scale, 518 + (z - cz) * scale
            halfx = max(2, min(500, sx * scale / 2))
            halfz = max(2, min(500, sz * scale / 2))
            raw = obj.get("color")
            rgb = tuple(max(0, min(255, int(v))) for v in raw)
            draw.rectangle((int(px - halfx), int(pz - halfz), int(px + halfx), int(pz + halfz)),
                           fill=rgb, outline="#273e52", width=1)
            if "Spawn" in name:
                draw.ellipse((px - 8, pz - 8, px + 8, pz + 8), fill="#f5cb42", outline="#263238")
        draw.text((20, 920), "Biome attributes: " + ", ".join(f"{k}={v}" for k, v in sorted(count_by_biome.items()))[:150], fill="#263b4b", font=font)
    else:
        draw.text((450, 485), "No visible BasePart samples", fill="#4b5c70", font=font)
    if stats.get("objectsTruncated") or stats.get("scanTruncated"):
        draw.text((20, 900), "WARNING: sample truncated, map is incomplete", fill="#a52a2a", font=font)
    canvas.save(folder / "scene-map.png", optimize=True)

    summary = [
        "# Read-only Place report",
        "",
        f"- Universe: {data.get('universeId')}",
        f"- Place: {data.get('placeId')}",
        f"- Sampled Parts: {len(objects)}",
        f"- Parts scanned: {stats.get('totalPartsScanned', '?')}",
        f"- Truncated: {bool(stats.get('objectsTruncated') or stats.get('scanTruncated'))}",
        "- No SavePlaceAsync used; no data was written.",
        "- The PNG is a top-down spatial diagram, NOT a Roblox screenshot.",
        "- Unclassified biome is not evidence of a specific biome.",
    ]
    (folder / "report.md").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(f"CREATED scene report: {folder} ({len(objects)} parts)")


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game", default="mapa-principal")
    p.add_argument("--place", default="main")
    p.add_argument("--environment", choices=("staging", "production"), default="production")
    p.add_argument("--execute", action="store_true", help="Run read-only Luau Open Cloud task")
    p.add_argument("--from-json", type=Path, help="Render an existing scene.json offline")
    p.add_argument("--output", type=Path, default=ROOT / "dist" / "scene-inspector")
    args = p.parse_args(argv)
    try:
        if args.from_json:
            data = json.loads(args.from_json.read_text(encoding="utf-8"))
        else:
            games, targets = load_all()
            target = resolve(games, targets, args.game, args.place, args.environment)
            if not args.execute:
                print(f"DRY RUN (no network): {target['universeId']}/{target['placeId']}; Lua script: {LUAU}")
                return 0
            key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY", "").strip()
            if not key:
                raise WorkspaceError("Missing GitHub Actions secret ROBLOX_OPEN_CLOUD_API_KEY")
            data = fetch_scene(target["universeId"], target["placeId"], key)
        render_report(data, args.output)
        return 0
    except (WorkspaceError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
