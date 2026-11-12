
"""Offline query for the last published-state inventory; no Roblox API call."""
import argparse,json
from scene_sync import ROOT,read,state_path,require
from deploy import load_all,resolve
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game",default="mapa-principal");p.add_argument("--place",default="main")
    p.add_argument("--environment",choices=["staging","production"],default="staging")
    p.add_argument("--service");p.add_argument("--name");p.add_argument("--class",dest="cls");p.add_argument("--roots",action="store_true");p.add_argument("--limit",type=int,default=50)
    a=p.parse_args();games,targets=load_all();t=resolve(games,targets,a.game,a.place,a.environment)
    require(1<=a.limit<=500,"Query limit")
    d=read(state_path(t));results=[]
    for key,row in d["records"].items():
        if a.service and row.get("service")!=a.service:continue
        if a.name and a.name.casefold() not in row.get("name","").casefold():continue
        if a.cls and row.get("class")!=a.cls:continue
        if a.roots and len(row.get("path",[]))!=1:continue
        results.append({"key":key,**row})
    print(json.dumps({"loadedVersion":d["loadedVersion"],"stateDigest":d["stateDigest"],"count":len(results),"results":results[:a.limit],"truncated":len(results)>a.limit},ensure_ascii=False,indent=2))
if __name__=="__main__":main()
