"""S09 one-shot original rigged chicken upload and detached staging proof. No Place save."""
import json,os,sys,time,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/"tools"),str(ROOT/"tools/asset_factory")]
from s08_prop_intake import request,write,commit,glb,tris
from scene_sync import task
from deploy import load_all,resolve
BASE=ROOT/"asset-library/candidates/chicken-rig-43578265487-1"
EXPECTED="ea0ebd42c7ea7a6b7ec6bf7c976edb2a1e91e205f83a017b21c9e5bc48121466"
RECEIPT=ROOT/"asset-library/roblox-receipts/s09-chicken-v2-rig.json"
def persist(r,msg):
    write(RECEIPT,r);commit([RECEIPT],msg)
def main():
    model=BASE/"chicken-v2-rig.glb";data=model.read_bytes()
    assert hashlib.sha256(data).hexdigest()==EXPECTED
    g=glb(data);report=json.loads((BASE/"report.json").read_text())
    assert tris(g)==3120 and len(g["meshes"])==1 and len(g["skins"][0]["joints"])==14
    assert set(a["name"] for a in g["animations"])=={"Idle","Walk","Run","Peck","Flap"}
    assert report["glbSha256"]==EXPECTED and report["independentBlenderReimport"] and report["restTriangleParity"]
    games,targets=load_all();target=resolve(games,targets,"mapa-principal","main","staging")
    assert str(target["placeId"])=="93428341652658"
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    creator=task(target,key,'do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend',read_version=25,compile_source=True)
    assert creator["loadedVersion"]==25 and creator["creatorType"]=="User" and creator["creatorId"]=="8136365379"
    if RECEIPT.exists():
        r=json.loads(RECEIPT.read_text());assert r["sha256"]==EXPECTED
        if not r.get("assetId") and not r.get("operationPath"):raise RuntimeError("Existing POST intent: reconcile before any retry")
    else:
        r={"schema":1,"sha256":EXPECTED,"source":str(model.relative_to(ROOT)),"state":"post_intent","retryAllowed":False,"creatorId":creator["creatorId"],"creatorType":"User","noPlaceWrites":True,"stagingVersion":25}
        persist(r,"intent(s09): one-shot original chicken rig upload")
        desc={"assetType":"Model","displayName":"Black Islands Chicken V2 Rig","description":"Original project-authored stylized chicken, isolated S09 rig proof; no Place publication.","creationContext":{"creator":{"userId":creator["creatorId"]}}}
        boundary="RSChickenS09"+EXPECTED[:24]
        body=(f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n"+json.dumps(desc)+f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"chicken-v2-rig.glb\"\r\nContent-Type: model/gltf-binary\r\n\r\n").encode()+data+f"\r\n--{boundary}--\r\n".encode()
        try:
            code,o=request("https://apis.roblox.com/assets/v1/assets",key,"POST",body,{"Content-Type":"multipart/form-data; boundary="+boundary})
            r.update(httpStatus=code,response=o,state="operation_created" if code<300 else "rejected_or_uncertain")
            if code<300:r["operationPath"]=o["path"]
        except Exception as e:r.update(state="requires_reconciliation",error=str(e)[:300])
        persist(r,"evidence(s09): chicken asset upload response")
    if not r.get("assetId"):
        op=r.get("operationPath","");assert op.startswith("operations/") and op[11:].replace("-","").isalnum()
        for _ in range(15):
            code,o=request("https://apis.roblox.com/assets/v1/"+op,key);r["operation"]=o
            if code!=200 or o.get("done"):break
            time.sleep(3)
        if o.get("done") and o.get("response",{}).get("assetId"):
            r.update(assetId=str(o["response"]["assetId"]),state="created")
        else:r["state"]="operation_pending_or_failed"
        persist(r,"evidence(s09): reconcile chicken asset operation")
    assert r.get("assetId","").isdigit(),r["state"]
    dispatch="""do
local A=game:GetService("AssetService")
local CP=game:GetService("ContentProvider")
local m=A:LoadAssetAsync(tonumber(cfg.assetId))
assert(m and m:IsA("Model") and m.Parent==nil,"Expected detached model")
local expected={Root=true,Body=true,Neck=true,Head=true,Jaw=true,Wing_L=true,Wing_R=true,Tail=true,Hip_L=true,Shin_L=true,Foot_L=true,Hip_R=true,Shin_R=true,Foot_R=true}
local meshes,bones,scripts={}, {},0
local clips={}
local animations={}
local classes={}
for _,o in m:GetDescendants() do
 classes[o.ClassName]=(classes[o.ClassName] or 0)+1
 if o:IsA("MeshPart") then table.insert(meshes,o) end
 if o:IsA("Bone") then bones[o.Name]=o end
 if o:IsA("LuaSourceContainer") then scripts+=1 end
 if o:IsA("KeyframeSequence") then
  local ks=o:GetKeyframes()
  local duration=0
  for _,k in ks do duration=math.max(duration,k.Time) end
  table.insert(clips,{name=o.Name,keyframes=#ks,duration=duration})
 elseif o:IsA("Animation") then table.insert(animations,{name=o.Name,id=o.AnimationId}) end
end
local p=meshes[1]
local names={}
local missing={}
for name in pairs(expected) do if not bones[name] then table.insert(missing,name) end end
for name in pairs(bones) do table.insert(names,name) end
table.sort(names);table.sort(missing)
local statuses={}
local meshLoaded=false
local textureId=""
local surface=p and p:FindFirstChildWhichIsA("SurfaceAppearance")
if p then textureId=if surface then surface.ColorMap else p.TextureID end
local preloadOK,preloadError=pcall(function()
 if p then CP:PreloadAsync({p},function(id,st) statuses[tostring(id)]=st.Name;if st==Enum.AssetFetchStatus.Success and id==p.MeshId then meshLoaded=true end end) end
end)
local textureLoaded=false
if textureId~="" then
 pcall(function()CP:PreloadAsync({textureId},function(_,st)if st==Enum.AssetFetchStatus.Success then textureLoaded=true end end)end)
 if statuses[textureId]=="Success" then textureLoaded=true end
end
local moved,restored=0,0
for name,b in pairs(bones) do
 if expected[name] then
  local old=b.Transform
  local test=old*CFrame.Angles(.15,.08,0)
  b.Transform=test
  if (b.Transform:Inverse()*test).Position.Magnitude<1e-5 then
   local _,angle=(b.Transform:Inverse()*test):ToAxisAngle()
   if math.abs(angle)<1e-4 then moved+=1 end
  end
  b.Transform=old
  local _,a=(b.Transform:Inverse()*old):ToAxisAngle()
  if math.abs(a)<1e-4 and (b.Transform.Position-old.Position).Magnitude<1e-5 then restored+=1 end
 end
end
local _,size=m:GetBoundingBox()
local result={assetId=cfg.assetId,meshParts=#meshes,bones=#names,boneNames=names,missingBones=missing,scripts=scripts,classes=classes,meshId=if p then p.MeshId else "",textureId=textureId,meshLoaded=meshLoaded,textureLoaded=textureLoaded,preloadOK=preloadOK,preloadError=if preloadOK then "" else tostring(preloadError):sub(1,200),statuses=statuses,boneTransformRoundtrip=moved,boneRestore=restored,importedKeyframeSequences=clips,importedAnimations=animations,size={size.X,size.Y,size.Z},noPlaceWrites=true,clientRenderVerified=false}
m:Destroy()
return syncResult(result)
end"""
    try:
        proof=task(target,key,dispatch,read_version=25,compile_source=True,assetId=r["assetId"])
        r["nativeProof"]=proof
        good=proof["meshParts"]==1 and len(proof["missingBones"])==0 and proof["scripts"]==0 and proof["meshLoaded"] and proof["boneTransformRoundtrip"]==14 and proof["boneRestore"]==14
        r["state"]="native_structure_verified" if good else "native_requires_review"
        persist(r,"evidence(s09): detached chicken native proof")
        print(json.dumps(r,indent=2));assert good,"Native structure gate"
    except Exception as e:
        if "nativeProof" not in r:
            r.update(state="created_native_load_pending",nativeError=str(e)[:500]);persist(r,"evidence(s09): native chicken proof blocked")
        raise
if __name__=="__main__":main()
