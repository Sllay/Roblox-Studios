"""S08 approved natural prop intake and idempotent Open Cloud asset submission.
Does not write Places or activate any model. Durable per-item receipt before POST.
"""
import hashlib,json,os,struct,subprocess,sys,time,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
APP=ROOT/"asset-library/approved"
RECEIPTS=ROOT/"asset-library/roblox-receipts/s08-props"
PROPS=[
 ("stone","/tmp/s08-organic/stone/baked","e616861e0605ceec597e57b6b7bd63f96f77b1be12cc6a0019a5f97d101b6663",80,43427280002),
 ("stick","/tmp/s08-organic/stick/baked","8d07c0882f873f4b45d30cb559b8f8df1f8c08189bec7a80042e6ac0f492c249",120,43427280002),
 ("log","/tmp/s08-log/baked","478518b081103073bf1b5a44634c4e0c56f2aa544b7d0eadbec88db6fe1936a3",636,43501908191)]
EGG=APP/"eggydrasil/v8"
def sha(b):return hashlib.sha256(b).hexdigest()
def write(p,obj):
    p.parent.mkdir(parents=True,exist_ok=True);tmp=p.with_suffix(".tmp");tmp.write_text(json.dumps(obj,indent=2)+"\n");tmp.replace(p)
def glb(b):
    assert b[:4]==b"glTF" and len(b)<20_000_000
    n,k=struct.unpack_from("<II",b,12);assert k==0x4e4f534a
    return json.loads(b[20:20+n])
def tris(d):
    return sum(d["accessors"][p["indices"]]["count"]//3 for m in d["meshes"] for p in m["primitives"])
def commit(paths,message):
    subprocess.run(["git","add",*[str(p.relative_to(ROOT)) for p in paths]],cwd=ROOT,check=True)
    if subprocess.run(["git","diff","--cached","--quiet"],cwd=ROOT).returncode==0:return
    subprocess.run(["git","commit","-m",message],cwd=ROOT,check=True)
    for _ in range(3):
        subprocess.run(["git","fetch","origin","main"],cwd=ROOT,check=True)
        subprocess.run(["git","rebase","origin/main"],cwd=ROOT,check=True)
        if subprocess.run(["git","push","origin","HEAD:main"],cwd=ROOT).returncode==0:return
    raise RuntimeError("Unable to persist durable receipt; stop before further POST")
def register():
    for name,folder,h,n,run in PROPS:
        src=Path(folder);b=(src/"asset.glb").read_bytes();d=glb(b)
        audit=json.loads((src/"audit.json").read_text())
        assert sha(b)==h and tris(d)==n and audit["triangles"]==n
        assert all(audit[k]==0 for k in ("degenerate","outsideUnitSquare","overlapPairs"))
        dest=APP/name/"v1";dest.mkdir(parents=True,exist_ok=True)
        files=[]
        for filename,data in [("asset.glb",b),("atlas.png",(src/"atlas.png").read_bytes()),("audit.json",(src/"audit.json").read_bytes())]:
            p=dest/filename
            if p.exists():assert p.read_bytes()==data
            else:p.write_bytes(data)
            files.append(dict(path=filename,sha256=sha(data),bytes=len(data)))
        write(dest/"release-manifest.json",dict(schema=1,status="approved",approval="User authorized S08 natural prop import after modelling review",sourceRun=run,technicalValidation="Pinned GLB and UV audit",files=files))
    b=(EGG/"eggydrasil-v8-planes-no-texture.glb").read_bytes();d=glb(b)
    assert sha(b)=="69808bb43888b3164dce014b3f84afaeb925189802154c0278c7473963793217" and tris(d)==21660
    assert {n["name"] for n in d["nodes"] if "mesh" in n}=={"Wood_V4","Canopy_White","Canopy_Gray"}
    assert not d.get("images") and not d.get("textures")
    for name,h in [("leaves-white.png","a7a0ac6bfa9b0cac091accd1e2f86aa48a6cbb9a17de9f8b0b4800f606a65e03"),("leaves-gray.png","2007e0cd1ac1712ab45687fa0afa1fb6f2a2e82a19e3b4f458b9c980c14e23ec")]:
        assert sha((EGG/name).read_bytes())==h
    commit([APP/name/"v1" for name,*_ in PROPS],"assets(s08): register exact natural prop GLBs and UV evidence")
def request(url,key,method="GET",data=None,headers=None):
    try:
        with urllib.request.urlopen(urllib.request.Request(url,data=data,method=method,headers={"x-api-key":key,**(headers or {})}),timeout=60) as r:return r.status,json.loads(r.read())
    except urllib.error.HTTPError as e:
        try:obj=json.loads(e.read())
        except ValueError:obj={}
        return e.code,obj
def poll(key,report,path):
    op=report["operationPath"]
    assert op.startswith("operations/") and op[11:].replace("-","").isalnum()
    for _ in range(15):
        code,o=request("https://apis.roblox.com/assets/v1/"+op,key)
        report["operation"]=o;report["operationHttpStatus"]=code
        if code!=200 or o.get("done"):break
        time.sleep(3)
    if o.get("done") and o.get("response",{}).get("assetId"):
        response=o["response"];report.update(state="created",assetId=str(response["assetId"]))
    else:report["state"]="operation_pending_or_failed"
    write(path,report);commit([path],"evidence(s08): reconcile "+report["id"])
def submit(key,owner,kind,id,path,typ):
    b=path.read_bytes();h=sha(b);receipt=RECEIPTS/(id+".json")
    if receipt.exists():
        r=json.loads(receipt.read_text());assert r["sha256"]==h
        if r["state"]=="created":return r
        if r.get("operationPath"):poll(key,r,receipt);return r
        raise RuntimeError("Prior POST intent without operation: reconcile before retry "+id)
    r=dict(id=id,sha256=h,bytes=len(b),source=str(path.relative_to(ROOT)),state="post_intent",retryAllowed=False,creatorId=owner,creatorType=kind,noPlaceWrites=True)
    write(receipt,r);commit([receipt],"intent(s08): one-shot upload "+id)
    desc={"assetType":typ,"displayName":"Black Islands "+id,"description":"S08 project asset; not a Place publication","creationContext":{"creator":{("userId" if kind=="User" else "groupId"):owner}}}
    boundary="RSPropS08"+h[:24];mime=("model/x-rbxm" if path.suffix==".rbxm" else "model/gltf-binary") if typ=="Model" else "image/png"
    body=(f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n"+json.dumps(desc)+f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\nContent-Type: {mime}\r\n\r\n").encode()+b+f"\r\n--{boundary}--\r\n".encode()
    try:
        code,o=request("https://apis.roblox.com/assets/v1/assets",key,"POST",body,{"Content-Type":"multipart/form-data; boundary="+boundary})
        r.update(httpStatus=code,response=o,state="operation_created" if code<300 else "rejected_or_uncertain")
        if code<300:r["operationPath"]=o["path"]
    except Exception as e:r.update(state="requires_reconciliation",error=str(e)[:300])
    write(receipt,r);commit([receipt],"evidence(s08): upload response "+id)
    if r.get("operationPath"):poll(key,r,receipt)
    if r["state"]!="created":raise RuntimeError("Upload not confirmed: "+id)
    return r
def main():
    register()
    if "--publish" not in sys.argv:return
    sys.path.insert(0,str(ROOT/"tools"))
    from deploy import load_all,resolve
    from scene_sync import task,read,state_path
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    base=read(state_path(target));key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    c=task(target,key,'do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend',read_version=base["loadedVersion"],compile_source=True)
    assert c["noPlaceWrites"] and c["creatorType"]=="User" and c["creatorId"]=="8136365379"
    entries=[(name+"-v1",APP/name/"v1/asset.glb","Model") for name,*_ in PROPS]+[("eggydrasil-v8",EGG/"eggydrasil-v8-planes-no-texture.glb","Model"),("eggydrasil-white",EGG/"leaves-white.png","Image"),("eggydrasil-gray",EGG/"leaves-gray.png","Image")]
    results=[]
    for id,path,typ in entries:
        results.append(submit(key,c["creatorId"],c["creatorType"],id,path,typ))
    print(json.dumps([{"id":r["id"],"assetId":r["assetId"],"state":r["state"]} for r in results],indent=2))
if __name__=="__main__":main()
