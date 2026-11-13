"""S08 detached native validation; import the already-textured V8 for runtime tinting."""
import json,os,sys
from pathlib import Path
from s08_prop_intake import ROOT,EGG,RECEIPTS,sha,glb,tris,submit,commit,write
sys.path.insert(0,str(ROOT/"tools"))
from scene_sync import task,read,state_path
from deploy import load_all,resolve
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    base=read(state_path(target));key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    version=base["loadedVersion"]
    c=task(target,key,'do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend',read_version=version,compile_source=True)
    assert c["noPlaceWrites"] and c["creatorType"]=="User" and c["creatorId"]=="8136365379"
    source=EGG/"eggydrasil-v8-tintable.glb";b=source.read_bytes();d=glb(b)
    assert sha(b)=="e8d0379acd6f9c0cf3ab22c478410d1e52806458121cf3b2ca94d51e926d8048" and tris(d)==21660
    assert len(d["images"])==2 and all(m["alphaMode"]=="MASK" for m in d["materials"] if m["name"].startswith("Leaves_"))
    names=["stone-v1","stick-v1","log-v1","eggydrasil-v8","eggydrasil-white","eggydrasil-gray"]
    receipts=[read(RECEIPTS/(name+".json")) for name in names]
    assert all(r["state"]=="created" and r["assetId"].isdigit() for r in receipts)
    receipts.append(submit(key,c["creatorId"],c["creatorType"],"eggydrasil-v8-tintable",source,"Model"))
    ids={r["id"]:r["assetId"] for r in receipts}
    out=ROOT/"asset-library/roblox-receipts/s08-native-proof.json"
    dispatch="""do
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local results={}
local function probe(id)
 local uri="rbxassetid://"..id
 local status="NotObserved"
 local ok,err=pcall(function() CP:PreloadAsync({uri},function(_,s) status=s.Name end) end)
 return {ok=ok,status=status,error=ok and "" or tostring(err):sub(1,200)}
end
for name,id in pairs(cfg.assetIds) do
 if name=="eggydrasil-white" or name=="eggydrasil-gray" then
  results[name]={id=id,image=probe(id)}
 else
  local ok,m=pcall(function() return A:LoadAssetAsync(tonumber(id)) end)
  if not ok then results[name]={id=id,error=tostring(m):sub(1,250)}
  else
   assert(m.Parent==nil,"Asset must remain detached")
   local row={id=id,meshes={},scripts=0,class=m.ClassName}
   local _,size=m:GetBoundingBox()
   row.bounds={size.X,size.Y,size.Z}
   for _,o in m:GetDescendants() do
    if o:IsA("LuaSourceContainer") then row.scripts+=1 end
    if o:IsA("MeshPart") then
     local r={name=o.Name,meshId=o.MeshId,size={o.Size.X,o.Size.Y,o.Size.Z},surfaces={},loaded=false}
     local loadOK,loadErr=pcall(function() CP:PreloadAsync({o},function(_,s) if s==Enum.AssetFetchStatus.Success then r.loaded=true end end) end)
     r.loadOK=loadOK
     for _,sa in o:GetChildren() do
      if sa:IsA("SurfaceAppearance") then
       local mapOK,map=pcall(function() return sa.ColorMapContent.Uri end)
       local original=sa.Color
       local tintOK=pcall(function()
        sa.Color=Color3.fromRGB(128,64,230)
        assert(sa.Color==Color3.fromRGB(128,64,230))
        sa.Color=original
       end)
       table.insert(r.surfaces,{name=sa.Name,alpha=sa.AlphaMode.Name,map=mapOK and map or "",tintRoundTrip=tintOK})
      end
     end
     table.insert(row.meshes,r)
    end
   end
   m:Destroy();results[name]=row
  end
 end
end
return syncResult({assetProof=results,noPlaceWrites=true})
end"""
    report=task(target,key,dispatch,read_version=version,compile_source=True,assetIds=ids)
    report["assetIds"]=ids
    report["clientRenderVerified"]=False
    write(out,report);commit([out],"evidence(s08): detached native asset and tint readback")
    print(json.dumps(report,indent=2))
    assert report["noPlaceWrites"]
    for name in ("stone-v1","stick-v1","log-v1","eggydrasil-v8","eggydrasil-v8-tintable"):
        r=report["assetProof"][name]
        assert r.get("scripts")==0 and r.get("meshes") and all(m["loaded"] for m in r["meshes"]),name
    for name in ("eggydrasil-white","eggydrasil-gray"):
        assert report["assetProof"][name]["image"]["status"]=="Success",name
    tint=report["assetProof"]["eggydrasil-v8-tintable"]
    canopies=[m for m in tint["meshes"] if "canopy" in m["name"].lower()]
    assert len(canopies)==2 and all(any(sa["map"] and sa["alpha"]=="Transparency" and sa["tintRoundTrip"] for sa in m["surfaces"]) for m in canopies),"Native importer tint/alpha needs review"
if __name__=="__main__":main()
