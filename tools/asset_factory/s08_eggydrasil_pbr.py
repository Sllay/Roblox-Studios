"""Author and validate a persistent Eggydrasil SurfaceAppearance template.
Source is the owned imported model; native serialize -> isolated authoring ->
native deserialize/re-serialize -> one-shot asset upload -> native readback.
No Place save, no EditableImage replication workaround.
"""
import base64,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
from s08_prop_intake import ROOT,EGG,RECEIPTS,submit,commit,write,sha
sys.path.insert(0,str(ROOT/"tools"))
from deploy import load_all,resolve
from scene_sync import task,read,state_path
def decode(r):
    b=base64.b64decode(r["serializedBase64"],validate=True)
    assert b.startswith(b"<roblox!") and len(b)<512000
    assert base64.b64encode(hashlib.sha256(b).digest()).decode()==r["digest"]
    return b
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];version=read(state_path(target))["loadedVersion"]
    ids={n:read(RECEIPTS/(n+".json"))["assetId"] for n in ("eggydrasil-v8","eggydrasil-white","eggydrasil-gray")}
    opts=dict(assetId=ids["eggydrasil-v8"],whiteUri="rbxassetid://"+ids["eggydrasil-white"],grayUri="rbxassetid://"+ids["eggydrasil-gray"])
    dest=EGG/"native";dest.mkdir(exist_ok=True);model=dest/"eggydrasil-v8-pbr.rbxm";manifest=dest/"manifest.json"
    common="""local A=game:GetService("AssetService")
local Serial=game:GetService("SerializationService")
local Enc=game:GetService("EncodingService")
local CP=game:GetService("ContentProvider")
local function serialized(m)
 local b=Serial:SerializeInstancesAsync({m})
 assert(buffer.len(b)<512000,"RBXM budget")
 return buffer.tostring(Enc:Base64Encode(b)),buffer.tostring(Enc:Base64Encode(Enc:ComputeBufferHash(b,Enum.HashAlgorithm.Sha256)))
end
local function parts(m)
 local r={}
 for _,o in m:GetDescendants() do
  assert(not o:IsA("LuaSourceContainer"),"Script not allowed")
  if o:IsA("MeshPart") then assert(not r[o.Name],"Duplicate mesh name");r[o.Name]=o end
 end
 return r
end
local function verify(m,original)
 local a,b=parts(m),parts(original);local count=0;local surfaces={}
 for name,p in a do
  count+=1;local q=b[name];assert(q and p.MeshId==q.MeshId,"Mesh reference changed "..name)
  assert((p.Size-q.Size).Magnitude<.0001,"Size changed")
  local cf1,cf2={p.CFrame:GetComponents()},{q.CFrame:GetComponents()}
  for i=1,12 do assert(math.abs(cf1[i]-cf2[i])<.0001,"Transform changed") end
  if name=="Canopy_White" or name=="Canopy_Gray" then
   local sa=p:FindFirstChildWhichIsA("SurfaceAppearance")
   local uri=if name=="Canopy_White" then cfg.whiteUri else cfg.grayUri
   assert(sa and sa.ColorMapContent.Uri==uri,"ColorMap binding "..name)
   assert(sa.AlphaMode==Enum.AlphaMode.Transparency and p.DoubleSided and not p.CanCollide and p.TextureID=="","Alpha or collision")
   local loaded=false;CP:PreloadAsync({uri},function(_,s) if s==Enum.AssetFetchStatus.Success then loaded=true end end)
   assert(loaded,"ColorMap not loaded")
   surfaces[name]=sa
  end
 end
 assert(count==5 and surfaces.Canopy_White and surfaces.Canopy_Gray,"Geometry/surface count")
 local w,g=surfaces.Canopy_White,surfaces.Canopy_Gray
 w.Color=Color3.fromRGB(255,60,70);g.Color=Color3.fromRGB(90,30,200)
 assert(w.Color==Color3.fromRGB(255,60,70) and g.Color==Color3.fromRGB(90,30,200),"Independent tint")
 w.Color=Color3.new(1,1,1);g.Color=Color3.new(1,1,1)
 return {meshCount=count,whiteUri=w.ColorMapContent.Uri,grayUri=g.ColorMapContent.Uri,alphaMode="Transparency",independentTint=true}
end
"""
    if not model.exists():
        r=task(target,key,"do\n"+common+"""local m=A:LoadAssetAsync(tonumber(cfg.assetId));assert(m.Parent==nil)
local count=0
for name,p in parts(m) do
 count+=1;p.Anchored=true
 if name=="Canopy_White" or name=="Canopy_Gray" then
  p.TextureID="";p.DoubleSided=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Color=Color3.new(1,1,1)
 end
end
assert(count==5)
local b,h=serialized(m);m:Destroy()
return syncResult({serializedBase64=b,digest=h,creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})
end""",read_version=version,compile_source=True,**opts)
        assert r["creatorId"]=="8136365379" and r["creatorType"]=="User" and r["noPlaceWrites"]
        with tempfile.TemporaryDirectory() as td:
            src=Path(td)/"native.rbxm";patched=Path(td)/"patched.rbxm";src.write_bytes(decode(r))
            subprocess.run(["cargo","run","--quiet","--manifest-path",str(ROOT/"tools/assets/rbx-author/Cargo.toml"),"--",str(src),str(patched),opts["whiteUri"],opts["grayUri"]],check=True,timeout=300)
            payload=base64.b64encode(patched.read_bytes()).decode()
        q=task(target,key,"do\n"+common+"""local decoded=Serial:DeserializeInstancesAsync(Enc:Base64Decode(buffer.fromstring(cfg.blob)))
assert(#decoded==1 and decoded[1]:IsA("Model"),"One native Model")
local m=decoded[1];local original=A:LoadAssetAsync(tonumber(cfg.assetId))
local proof=verify(m,original)
local b,h=serialized(m);m:Destroy();original:Destroy()
return syncResult({serializedBase64=b,digest=h,proof=proof,noPlaceWrites=true})
end""",read_version=version,compile_source=True,blob=payload,**opts)
        assert q["noPlaceWrites"] and q["proof"]["independentTint"]
        model.write_bytes(decode(q))
        write(manifest,dict(sourceAssetId=ids["eggydrasil-v8"],sha256=sha(model.read_bytes()),proof=q["proof"],nativeRoundTrip=True,noPlaceWrites=True))
        commit([model,manifest],"assets(s08): engine-reserialized Eggydrasil with two persistent albedo surfaces")
    else:assert sha(model.read_bytes())==read(manifest)["sha256"]
    receipt=submit(key,"8136365379","User","eggydrasil-v8-pbr",model,"Model")
    r=task(target,key,"do\n"+common+"""local m=A:LoadAssetAsync(tonumber(cfg.pbrAssetId));assert(m.Parent==nil)
local original=A:LoadAssetAsync(tonumber(cfg.assetId))
local proof=verify(m,original)
m:Destroy();original:Destroy()
return syncResult({proof=proof,noPlaceWrites=true})
end""",read_version=version,compile_source=True,pbrAssetId=receipt["assetId"],**opts)
    r["assetId"]=receipt["assetId"];r["clientRenderVerified"]=False
    p=ROOT/"asset-library/roblox-receipts/s08-eggydrasil-pbr-proof.json";write(p,r);commit([p],"evidence(s08): persisted native albedo transparency and independent tint verified")
    print(json.dumps(r,indent=2));assert r["noPlaceWrites"] and r["proof"]["independentTint"]
if __name__=="__main__":main()
