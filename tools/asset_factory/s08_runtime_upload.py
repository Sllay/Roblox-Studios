"""Submit and verify single-mesh prop variants without changing a Place."""
import json,os,sys
from s08_prop_intake import ROOT,APP,RECEIPTS,PROPS,sha,submit,commit,write
sys.path.insert(0,str(ROOT/"tools"))
from scene_sync import task,read,state_path
from deploy import load_all,resolve
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];version=read(state_path(target))["loadedVersion"]
    c=task(target,key,'do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend',read_version=version,compile_source=True)
    assert c["noPlaceWrites"] and c["creatorType"]=="User" and c["creatorId"]=="8136365379"
    ids={}
    for name,*_ in PROPS:
        src=APP/name/"v1";dst=src/"runtime";m=read(dst/"manifest.json")
        assert m["geometryUnchanged"] and sha((dst/"asset.glb").read_bytes())==m["sha256"] and sha((src/"atlas.png").read_bytes())==m["atlasSha256"]
        ids[name]={"model":submit(key,c["creatorId"],c["creatorType"],name+"-v1-runtime",dst/"asset.glb","Model")["assetId"],"atlas":submit(key,c["creatorId"],c["creatorType"],name+"-v1-atlas",src/"atlas.png","Image")["assetId"]}
    dispatch="""do
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local rows={}
for name,ids in pairs(cfg.assets) do
 local m=A:LoadAssetAsync(tonumber(ids.model));assert(m.Parent==nil and m:IsA("Model"))
 local parts={};local scripts=0
 for _,o in m:GetDescendants() do
  if o:IsA("MeshPart") then table.insert(parts,o) end
  if o:IsA("LuaSourceContainer") then scripts+=1 end
 end
 local _,size=m:GetBoundingBox()
 local r={name=name,assetId=ids.model,atlasId=ids.atlas,parts=#parts,scripts=scripts,bounds={size.X,size.Y,size.Z}}
 if #parts==1 then
  local p=parts[1];local uri="rbxassetid://"..ids.atlas
  r.meshId=p.MeshId;r.originalTextureId=p.TextureID
  local meshOK=false
  local ok,err=pcall(function() CP:PreloadAsync({p},function(id,s) if s==Enum.AssetFetchStatus.Success then meshOK=true end end) end)
  r.meshLoaded=ok and meshOK
  local txOK,txErr=pcall(function() p.TextureID=uri;p.Color=Color3.new(1,1,1);assert(p.TextureID==uri) end)
  r.textureBound=txOK;r.textureError=if txOK then "" else tostring(txErr):sub(1,200)
  local imageOK=false
  local preOK=pcall(function() CP:PreloadAsync({uri},function(_,s) if s==Enum.AssetFetchStatus.Success then imageOK=true end end) end)
  r.imageLoaded=preOK and imageOK
 end
 m:Destroy();rows[name]=r
end
return syncResult({props=rows,noPlaceWrites=true})
end"""
    r=task(target,key,dispatch,read_version=version,compile_source=True,assets=ids)
    r["clientRenderVerified"]=False
    p=ROOT/"asset-library/roblox-receipts/s08-runtime-proof.json";write(p,r);commit([p],"evidence(s08): one MeshPart per resource with native texture binding")
    print(json.dumps(r,indent=2))
    assert r["noPlaceWrites"] and all(x["parts"]==1 and x["scripts"]==0 and x["meshLoaded"] and x["textureBound"] and x["imageLoaded"] for x in r["props"].values())
if __name__=="__main__":main()
