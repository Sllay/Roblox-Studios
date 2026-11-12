"""Inventory acquired model packs and prove detached individual-model extraction.
No binary export, no Place writes, no visual approval. Requires Open Cloud read access.
"""
from __future__ import annotations
import argparse
import json
import os
import sys
from pathlib import Path
from pipeline import ROOT,call,write,check_id,WorkspaceError
from deploy import load_all,resolve

def validate_selector(value):
    if not isinstance(value,list) or not 1<=len(value)<=32:
        raise WorkspaceError("Selector must have 1-32 path segments")
    for item in value:
        if (not isinstance(item,dict) or set(item)!={"index","name","class"}
            or type(item["index"]) is not int or item["index"]<1
            or not isinstance(item["name"],str) or not isinstance(item["class"],str)):
            raise WorkspaceError("Invalid pack selector segment")
    return value

def inspect(target,key,asset_id,selector=None,sample=False,components=False):
    options={"sample":bool(sample)}
    if components:
        options["components"]=True
    if selector is not None:
        options["selector"]=validate_selector(selector)
    report=call(target,key,"pack_inventory",check_id(asset_id),**options)
    pack=report.get("pack")
    if not isinstance(pack,dict) or pack.get("schemaVersion")!=1 or not isinstance(pack.get("candidates"),list):
        raise WorkspaceError("Malformed pack report")
    extraction=pack.get("extraction")
    if extraction and (extraction.get("detached") is not True or extraction.get("importAuthorized") is not False):
        raise WorkspaceError("Unexpected extraction state")
    return report

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game",default="mapa-principal")
    p.add_argument("--place",default="main")
    p.add_argument("--environment",choices=["staging","production"],default="staging")
    p.add_argument("--asset-id",required=True)
    p.add_argument("--selector",type=Path,help="JSON array copied from candidate.selector")
    p.add_argument("--sample",action="store_true",help="Extract one technical candidate, not visual approval")
    p.add_argument("--output",type=Path,default=ROOT/"dist"/"asset-pack")
    a=p.parse_args(argv)
    try:
        games,targets=load_all()
        target=resolve(games,targets,a.game,a.place,a.environment)
        key=os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY","")
        if not key: raise WorkspaceError("Missing Open Cloud key")
        selector=json.loads(a.selector.read_text()) if a.selector else None
        report=inspect(target,key,a.asset_id,selector,a.sample)
        pack=report["pack"]
        write(a.output/"pack.json",report)
        print(f"PACK: {pack['totalModels']} models; {pack['totalInstances']} descendants; {pack['scriptsInPack']} scripts; truncated={pack['inventoryTruncated']}",flush=True)
        for i,candidate in enumerate(pack["candidates"],1):
            print(f"MODEL {i}: {candidate['name']!r} parts={candidate['parts']} meshes={candidate['meshes']} pbr={candidate['pbr']} eligible={candidate['technicalCandidate']}",flush=True)
        sample=pack.get("extraction")
        if sample:
            write(a.output/"selector.json",sample["selector"])
            audit=sample["audit"]
            print("EXTRACTION:",json.dumps({"name":sample["name"],"instances":sample["instances"],"detached":sample["detached"],"parts":audit["parts"],"allowed":audit["allowed"],"issues":audit["issues"],"serialization":sample["serialization"]},ensure_ascii=False),flush=True)
        elif a.sample or selector is not None:
            raise WorkspaceError("No eligible individual model extracted")
        return 0
    except (WorkspaceError,OSError,ValueError,KeyError) as exc:
        print(f"ERROR: {exc}",file=sys.stderr)
        return 1
if __name__=="__main__":
    raise SystemExit(main())
