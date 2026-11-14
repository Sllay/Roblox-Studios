"""Read-only native comparison of existing canopy materials and Eggydrasil V8."""
import json
import os
from scene_sync import ROOT, task, write, require
from deploy import load_all, resolve
from sharded_scene_sync import latest

def main():
    games, targets = load_all()
    target = resolve(games, targets, "mapa-principal", "main", "staging")
    key = os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    require(latest(target, key) == 22, "Expected staging v22")
    source = "do\n" + (ROOT / "tools/sync/s084_foliage_preview.luau").read_text() + "\nend"
    result = task(target, key, source, read_version=22, compile_source=True)
    write(ROOT / "dist/s084/preview.json", result)
    require(result["noPlaceWrites"] and result["counts"] == {"tree":250,"pine":16,"bush":200}, "Preview scope")
    require(result["preloaded"] == {"white":True,"gray":True} and len(result["samples"]) >= 8, "Material preview")
    print("S084_FOLIAGE_PREVIEW", json.dumps(result), flush=True)

if __name__ == "__main__":
    main()
