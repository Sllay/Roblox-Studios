"""Native PBR wood template, with TintMask and original V4 geometry parity."""
import base64,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
from s08_prop_intake import ROOT,EGG,submit,commit,write,sha
sys.path.insert(0,str(ROOT/"tools"))
from deploy import load_all,resolve
from scene_sync import task,read,require
from sharded_scene_sync import latest
COMMON="""local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local Serial=game:GetService("SerializationService")
local Enc=game:GetService("EncodingService")
local function serialized(m)
 local b=Serial:SerializeInstancesAsync({m})
 assert(buffer.len(b)<512000,"RBXM budget")
 return buffer.tostring(Enc:Base64Encode(b)),buffer.tostring(Enc:Base64Encode(Enc:ComputeBufferHash(b,Enum.HashAlgorithm.Sha256)))
end
local function meshes(m)
 local r={}
 for _,p in m:GetDescendants() do
  assert(not p:IsA("LuaSourceContainer"),"Unexpected script")
  if p:IsA("MeshPart") and string.sub(p.Name,1,7)=="Wood_V4" then assert(not r[p.Name]);r[p.Name]=p end
 end
 local n=0;for _ in r do n+=1 end;assert(n==3,"Three wood meshes")
 return r
end
local function near(a,b,t)return (a-b).Magnitude<t end
local function proof(m,hasSurface)
 local old=A:LoadAssetAsync(128938533912044)
 local a,b=meshes(m),meshes(old)
 local rows={};local n=0
 local oldBase=b.Wood_V4.Position;local newBase=a.Wood_V4.Position
 for _,name in {"Wood_V4","Wood_V42","Wood_V43"} do
  local p,q=a[name],b[name];assert(p and q,"Wood name")
  local ratio=p.Size.X/q.Size.X
  assert(near(p.Size,q.Size*ratio,.01) and near(p.Position-newBase,(q.Position-oldBase)*ratio,.01),"Wood geometry transform "..name)
  assert(near(p.MeshSize,q.MeshSize,.02),"Wood mesh bounds "..name)
  assert(p.CollisionFidelity==q.CollisionFidelity,"Collision fidelity "..name)
  if hasSurface then
   local sa=p:FindFirstChildWhichIsA("SurfaceAppearance")
   assert(sa and sa.ColorMapContent.Uri==cfg.barkUri and sa.AlphaMode==Enum.AlphaMode.TintMask and p.TextureID=="","Wood surface "..name)
   local c=sa.Color;sa.Color=Color3.fromRGB(96,150,200);assert(sa.Color==Color3.fromRGB(96,150,200));sa.Color=c
  end
  rows[name]={meshId=p.MeshId,oldMeshId=q.MeshId,size={p.Size.X,p.Size.Y,p.Size.Z},meshSize={p.MeshSize.X,p.MeshSize.Y,p.MeshSize.Z},collisionFidelity=p.CollisionFidelity.Name}
  n+=1
 end
 old:Destroy()
 if hasSurface then
  local loaded=false;CP:PreloadAsync({cfg.barkUri},function(_,s)if s==Enum.AssetFetchStatus.Success then loaded=true end end);assert(loaded,"Bark texture preload")
 end
 return rows
end
"""
def decode(r):
    b=base64.b64decode(r["serializedBase64"],validate=True)
    assert b.startswith(b"<roblox!") and len(b)<512000
    assert base64.b64encode(hashlib.sha256(b).digest()).decode()==r["digest"]
    return b
def main():
    dest=EGG/"wood-uv";ids=read(dest/"roblox-ids.json");manifest=read(dest/"manifest.json")
    assert manifest["geometryUnchanged"] and manifest["triangles"]==14460
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    version=latest(target,key);require(version==20,"Expected v20")
    opts=dict(modelId=ids["eggydrasil-wood-v4-uv"],barkUri="rbxassetid://"+ids["eggydrasil-bark-alpha-mask"])
    model=dest/"wood-v4-pbr.rbxm"
    if not model.exists():
        r=task(target,key,"do\n"+COMMON+"""local m=A:LoadAssetAsync(tonumber(cfg.modelId));assert(m.Parent==nil)
local rows=proof(m,false)
for _,p in meshes(m) do
 for _,s in p:GetChildren() do if s:IsA("SurfaceAppearance") then s:Destroy() end end
 p.TextureID="";p.Color=Color3.new(1,1,1);p.Anchored=true
end
local b,h=serialized(m);m:Destroy()
return syncResult({serializedBase64=b,digest=h,parts=rows,noPlaceWrites=true})
end""",read_version=20,compile_source=True,**opts)
        assert r["noPlaceWrites"]
        with tempfile.TemporaryDirectory() as td:
            raw=Path(td)/"raw.rbxm";patched=Path(td)/"patched.rbxm";raw.write_bytes(decode(r))
            subprocess.run(["cargo","run","--quiet","--manifest-path",str(ROOT/"tools/assets/rbx-wood-author/Cargo.toml"),"--",str(raw),str(patched),opts["barkUri"]],check=True,timeout=300)
            payload=base64.b64encode(patched.read_bytes()).decode()
        r=task(target,key,"do\n"+COMMON+"""local d=Serial:DeserializeInstancesAsync(Enc:Base64Decode(buffer.fromstring(cfg.blob)))
assert(#d==1 and d[1]:IsA("Model"))
local m=d[1];local rows=proof(m,true);local b,h=serialized(m);m:Destroy()
return syncResult({serializedBase64=b,digest=h,parts=rows,noPlaceWrites=true})
end""",read_version=20,compile_source=True,blob=payload,**opts)
        assert r["noPlaceWrites"];model.write_bytes(decode(r))
        write(dest/"native-manifest.json",{"sha256":sha(model.read_bytes()),"sourceGeometry":manifest["geometryStreamSha256"],"barkUri":opts["barkUri"],"parts":r["parts"],"alphaMode":"TintMask","noPlaceWrites":True})
        commit([model,dest/"native-manifest.json"],"assets(s082): native wood-only surface template with nontransparent tint mask")
    else:assert sha(model.read_bytes())==read(dest/"native-manifest.json")["sha256"]
    receipt=submit(key,"8136365379","User","eggydrasil-wood-v4-pbr",model,"Model")
    assert receipt["state"]=="created"
    r=task(target,key,"do\n"+COMMON+"""local m=A:LoadAssetAsync(tonumber(cfg.pbrId));assert(m.Parent==nil)
local rows=proof(m,true);m:Destroy()
return syncResult({parts=rows,alphaMode="TintMask",barkUri=cfg.barkUri,noPlaceWrites=true,clientRenderVerified=false})
end""",read_version=20,compile_source=True,pbrId=receipt["assetId"],**opts)
    assert r["noPlaceWrites"] and r["alphaMode"]=="TintMask"
    r["assetId"]=receipt["assetId"];write(dest/"native-proof.json",r);commit([dest/"native-proof.json"],"evidence(s082): native tint-mask wood mesh and geometry round trip")
    print("S082_NATIVE_WOOD",json.dumps(r),flush=True)
if __name__=="__main__":main()
