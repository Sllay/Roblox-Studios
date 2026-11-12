"""Offline lookup of reviewed visual memory; no Roblox calls or import authorization."""
from __future__ import annotations
import argparse
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def normalize(value):
    value = unicodedata.normalize("NFKD", value.casefold())
    return "".join(c for c in value if not unicodedata.combining(c))

def lookup(registry, query="", biome=None, name=None):
    if registry.get("schemaVersion") != 1:
        raise ValueError("Unsupported visual review schema")
    terms = re.findall(r"\w+", normalize(query))
    matches = []
    for review in registry["reviews"]:
        visual = review["visual"]
        if visual.get("status") not in ("geometry_reviewed", "visual_reviewed"):
            continue
        if name and normalize(review["name"]) != normalize(name):
            continue
        if biome and normalize(biome) not in [normalize(x) for x in visual["inferred"]["suitableBiomes"]]:
            continue
        haystack = normalize(json.dumps(visual, ensure_ascii=False) + " " + review["name"])
        if all(term in haystack for term in terms):
            matches.append({**review, "packAssetId": registry["packAssetId"],
                            "sourceRun": registry["sourceRun"], "requiresReauditBeforeImport": True})
    return matches

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game", default="mapa-principal")
    p.add_argument("--pack", default="79689531752352")
    p.add_argument("--query", default="")
    p.add_argument("--biome")
    p.add_argument("--name")
    a = p.parse_args()
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", a.game) or not re.fullmatch(r"[1-9][0-9]*", a.pack):
        p.error("Invalid game or pack ID")
    path = ROOT/"games"/"maps"/a.game/"game"/"assets"/"visual-reviews"/(a.pack+".json")
    try:
        registry = json.loads(path.read_text(encoding="utf-8"))
        print(json.dumps({"results": lookup(registry,a.query,a.biome,a.name),
                          "note":"Cached visual observations, not current security or import approval."}, ensure_ascii=False,indent=2))
    except (OSError,ValueError,KeyError) as exc:
        p.exit(1,f"ERROR: {exc}\n")
if __name__ == "__main__":
    main()
