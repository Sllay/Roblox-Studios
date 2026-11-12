"""Offline capability discovery for agents. Does not dispatch or publish."""
import argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MODES={"offline","read","staging_write"}
STATES={"implemented","live_verified","planned"}
def load():
    d=json.loads((ROOT/"tools/capabilities.json").read_text())
    if d["schemaVersion"]!=1:raise ValueError("Capability schema")
    rows=d["capabilities"];ids={r["id"] for r in rows}
    if len(ids)!=len(rows):raise ValueError("Duplicate capability")
    for r in rows:
        if r["mode"] not in MODES or r["status"] not in STATES:raise ValueError("Capability mode/state")
        if not set(r["requires"])<=ids or r["id"] in r["requires"]:raise ValueError("Unknown dependency")
        if r["status"]=="planned":
            if r["entry"] is not None:raise ValueError("Planned capability executable")
        else:
            if not r["entry"]:raise ValueError("Missing entry")
            p=(ROOT/r["entry"]).resolve()
            if not p.is_relative_to(ROOT/"tools") or not p.is_file():raise ValueError("Missing capability file: "+r["id"])
        if r["mode"]=="staging_write" and r["status"]!="planned" and not {"scene.sync","quality.gate"}<=set(r["requires"]):raise ValueError("Unsafe writer dependencies")
    def visit(id,stack):
        if id in stack:raise ValueError("Dependency cycle")
        for d in next(r["requires"] for r in rows if r["id"]==id):visit(d,stack|{id})
    for id in ids:visit(id,set())
    return rows
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--id");p.add_argument("--mode",choices=sorted(MODES));p.add_argument("--ready",action="store_true")
    a=p.parse_args()
    rows=[r for r in load() if (not a.id or r["id"]==a.id) and (not a.mode or r["mode"]==a.mode) and (not a.ready or r["status"]!="planned")]
    print(json.dumps({"schemaVersion":1,"capabilities":rows},ensure_ascii=False,indent=2))
if __name__=="__main__":main()
