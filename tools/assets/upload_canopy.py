"""One authorized original Model upload. No Place save, no public distribution.
Never automatically repeat POST; report denial or ambiguous result for reconciliation.
"""
import argparse,hashlib,json,os,time,urllib.request,urllib.error
from pathlib import Path
from pipeline import ROOT
from scene_sync import task,read,write,require,state_path
from deploy import load_all,resolve
EXPECTED="32b04f3e0c5bd57430741b400783021ec4bc471e3a16ff0979d68c414a38bb49"
def request(url,key,method="GET",data=None,headers=None):
    h={"x-api-key":key,**(headers or {})}
    try:
        with urllib.request.urlopen(urllib.request.Request(url,data=data,headers=h,method=method),timeout=45) as r:return r.status,json.loads(r.read())
    except urllib.error.HTTPError as e:
        try:body=json.loads(e.read())
        except ValueError:body={}
        return e.code,body
def main():
    p=argparse.ArgumentParser();p.add_argument("--rig",type=Path,required=True);p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target));key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    require(base["loadedVersion"]==16,"Pinned staging scope")
    data=a.rig.read_bytes();require(hashlib.sha256(data).hexdigest()==EXPECTED,"Reviewed original GLB hash")
    c=task(target,key,'return syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})',read_version=16,compile_source=True)
    require(c["noPlaceWrites"] and c["loadedVersion"]==16 and c["creatorType"] in ("User","Group") and c["creatorId"].isdigit() and int(c["creatorId"])>0,"Creator scope")
    report={"schemaVersion":1,"originalSha256":EXPECTED,"creatorType":c["creatorType"],"creatorId":c["creatorId"],"status":"post_started","noPlaceWrites":True,"retryAllowed":False}
    dest=a.output/"upload-receipt.json";a.output.mkdir(parents=True,exist_ok=True)
    # The workflow commits a one-shot intent before POST; local receipt also refuses retries.
    with dest.open("x") as out:json.dump(report,out);out.flush();os.fsync(out.fileno())
    desc={"assetType":"Model","displayName":"RS S06 Original Pine Canopy Prototype","description":"Original project-authored skinned canopy prototype, no external geometry. Not a published Place change.","creationContext":{"creator":{("userId" if c["creatorType"]=="User" else "groupId"):c["creatorId"]}}}
    boundary="RSCanopyS06-"+EXPECTED[:24]
    body=(f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n"+json.dumps(desc)+f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"pine-canopy.glb\"\r\nContent-Type: model/gltf-binary\r\n\r\n").encode()+data+f"\r\n--{boundary}--\r\n".encode()
    try:
        code,r=request("https://apis.roblox.com/assets/v1/assets",key,"POST",body,{"Content-Type":"multipart/form-data; boundary="+boundary})
        report.update(httpStatus=code,status="denied" if code in (401,403) else "rejected" if code>=400 else "operation_created")
        report["response"]=r;write(dest,report)
        if code>=400:print("S064_UPLOAD "+json.dumps(report),flush=True);return
        path=r.get("path","");require(path.startswith("operations/") and path[11:].replace("-","").isalnum(),"Unexpected operation path")
        for _ in range(12):
            code,o=request("https://apis.roblox.com/assets/v1/"+path,key)
            report["operation"]=o;write(dest,report)
            if code!=200 or o.get("done"):break
            time.sleep(3)
        if o.get("done") and o.get("response",{}).get("assetId"):
            aid=str(o["response"]["assetId"]);require(aid.isdigit(),"Asset ID")
            report.update(status="created",assetId=aid)
            write(dest,report)
            src='''local A=game:GetService("AssetService")
local m=A:LoadAssetAsync(tonumber(cfg.assetId));assert(m and m:IsA("Model") and m.Parent==nil,"Detached asset")
local meshes,bones,scripts=0,0,0;local names={}
for _,o in m:GetDescendants() do
    if o:IsA("MeshPart") then meshes+=1 end
    if o:IsA("Bone") then bones+=1;table.insert(names,o.Name) end
    if o:IsA("LuaSourceContainer") then scripts+=1 end
end
local _,size=m:GetBoundingBox()
local boughs=0
for _,n in names do if string.sub(n,1,6)=="Bough_" then boughs+=1 end end
local mesh=m:FindFirstChildWhichIsA("MeshPart",true)
local loaded=false
if mesh then
    local ok=pcall(function()game:GetService("ContentProvider"):PreloadAsync({mesh.MeshId},function(_,status)loaded=status==Enum.AssetFetchStatus.Success end)end)
    loaded=ok and loaded
end
m:Destroy()
return syncResult({assetId=cfg.assetId,meshes=meshes,bones=bones,boughs=boughs,scripts=scripts,meshLoaded=loaded,size={size.X,size.Y,size.Z},noPlaceWrites=true,clientRenderVerified=false})
'''
            try:
                proof=task(target,key,"do\n"+src+"\nend",read_version=16,compile_source=True,assetId=aid)
                report["nativeProof"]=proof
                report["status"]="import_structure_verified" if proof["meshes"]==1 and proof["bones"]>=20 and proof["boughs"]==18 and proof["scripts"]==0 and proof["meshLoaded"] else "import_requires_review"
            except Exception as e:report.update(status="created_native_load_pending",nativeError=str(e)[:350])
        else:report["status"]="operation_pending_or_failed"
    except Exception as e:report.update(status="requires_reconciliation",error=str(e)[:350])
    write(dest,report);print("S064_UPLOAD "+json.dumps(report),flush=True)
if __name__=="__main__":main()
