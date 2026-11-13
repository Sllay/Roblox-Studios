"""S08 inspect native texture bindings and test official asset-backed SurfaceAppearance."""
import os,json,sys
from pathlib import Path
from s08_prop_intake import ROOT,RECEIPTS,commit,write
sys.path.insert(0,str(ROOT/"tools"))
from deploy import load_all,resolve
from scene_sync import task,read,state_path
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    version=read(state_path(target))["loadedVersion"]
    ids={n:read(RECEIPTS/(n+".json"))["assetId"] for n in ("stone-v1","stick-v1","log-v1","eggydrasil-v8-tintable","eggydrasil-white","eggydrasil-gray")}
    dispatch="""do
local A=game:GetService("AssetService")
local results={}
for name,id in pairs(cfg.assetIds) do
 if name~="eggydrasil-white" and name~="eggydrasil-gray" then
  local m=A:LoadAssetAsync(tonumber(id))
  assert(m.Parent==nil,"Detached model")
  local row={meshParts={}}
  for _,p in m:GetDescendants() do
   if p:IsA("MeshPart") then
    local q={name=p.Name,textureId=p.TextureID,meshId=p.MeshId,surfaceCount=0}
    for _,c in p:GetChildren() do if c:IsA("SurfaceAppearance") then q.surfaceCount+=1 end end
    if name=="eggydrasil-v8-tintable" and (p.Name=="Canopy_White" or p.Name=="Canopy_Gray") then
     local imageId=cfg.assetIds[if p.Name=="Canopy_White" then "eggydrasil-white" else "eggydrasil-gray"]
     local uri="rbxassetid://"..imageId
     local ok,sa=pcall(function()
      return A:CreateSurfaceAppearanceAsync({ColorMap=Content.fromUri(uri)})
     end)
     q.surfaceAPI={ok=ok,error=if ok then "" else tostring(sa):sub(1,250)}
     if ok and sa then
      local setOK,err=pcall(function()
       sa.AlphaMode=Enum.AlphaMode.Transparency
       sa.Color=if p.Name=="Canopy_White" then Color3.fromRGB(120,220,65) else Color3.fromRGB(60,130,50)
       sa.Parent=p
       assert(sa.ColorMapContent.Uri==uri,"ColorMap URI mismatch")
      end)
      q.surfaceAPI.configured=setOK
      q.surfaceAPI.configError=if setOK then "" else tostring(err):sub(1,250)
      q.surfaceAPI.alpha=sa.AlphaMode.Name
      q.surfaceAPI.color={sa.Color.R,sa.Color.G,sa.Color.B}
      q.surfaceAPI.uri=sa.ColorMapContent.Uri
     end
     local txOK,txErr=pcall(function() p.TextureID=uri;p.DoubleSided=true;assert(p.TextureID==uri) end)
     q.textureAssignment={ok=txOK,error=if txOK then "" else tostring(txErr):sub(1,200)}
    end
    table.insert(row.meshParts,q)
   end
  end
  m:Destroy();results[name]=row
 end
end
return syncResult({textureProbe=results,noPlaceWrites=true})
end"""
    r=task(target,key,dispatch,read_version=version,compile_source=True,assetIds=ids)
    assert r["noPlaceWrites"]
    p=ROOT/"asset-library/roblox-receipts/s08-texture-probe.json";write(p,r);commit([p],"evidence(s08): inspect texture IDs and official surface creation")
    print(json.dumps(r,indent=2))
if __name__=="__main__":main()
