"""Convert pinned GLB clips to Roblox KeyframeSequence XML, then upload pilot and prove Animator playback."""
import os,sys,json,struct,hashlib,math,xml.etree.ElementTree as ET
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation,Slerp
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/"tools"),str(ROOT/"tools/asset_factory")]
import s08_prop_intake as api
from scene_sync import task
from deploy import load_all,resolve
DIR=ROOT/"asset-library/roblox-receipts/s09";api.RECEIPTS=DIR
BASE=ROOT/"asset-library/candidates/chicken-rig-43578265487-1"
SHA="ea0ebd42c7ea7a6b7ec6bf7c976edb2a1e91e205f83a017b21c9e5bc48121466"
CLIPS={"Idle":(48,0,True),"Walk":(24,1,True),"Run":(18,1,True),"Peck":(30,2,False),"Flap":(30,2,False)}
def cf(x):
    m=np.eye(4);m[:3,3]=x[:3];m[:3,:3]=np.array(x[3:]).reshape(3,3);return m
def serial(m):return [float(x) for x in [*m[:3,3],*m[:3,:3].ravel()]]
def trs(t,r):
    m=np.eye(4);m[:3,3]=t;m[:3,:3]=Rotation.from_quat(r).as_matrix();return m
def decode(data):
    n=struct.unpack_from("<I",data,12)[0];j=json.loads(data[20:20+n]);b=data[28+n:]
    def acc(i):
        a=j["accessors"][i];v=j["bufferViews"][a["bufferView"]];assert a["componentType"]==5126
        k={"SCALAR":1,"VEC3":3,"VEC4":4}[a["type"]];return np.ndarray((a["count"],k),dtype="<f4",buffer=b,offset=v.get("byteOffset",0)+a.get("byteOffset",0),strides=(v.get("byteStride",4*k),4)).copy()
    return j,acc
def property(p,tag,name,value):
    e=ET.SubElement(p,tag,name=name);e.text=str(value);return e
def item(parent,cl,name):
    e=ET.SubElement(parent,"Item",{"class":cl});p=ET.SubElement(e,"Properties");property(p,"string","Name",name);return e,p
def pose(parent,name,m):
    e,p=item(parent,"Pose",name);c=ET.SubElement(p,"CoordinateFrame",name="CFrame")
    for k,v in zip(("X","Y","Z","R00","R01","R02","R10","R11","R12","R20","R21","R22"),serial(m)):ET.SubElement(c,k).text=format(v,".10g")
    property(p,"float","Weight",1);property(p,"token","EasingStyle",0);property(p,"token","EasingDirection",0);return e
def convert():
    data=(BASE/"chicken-v2-rig.glb").read_bytes();assert hashlib.sha256(data).hexdigest()==SHA
    j,acc=decode(data);bind=json.loads((DIR/"chicken-native-bind.json").read_text())
    rows={r["name"]:r for r in bind["bones"]};nodes=j["nodes"];ids=j["skins"][0]["joints"];names={i:nodes[i]["name"] for i in ids}
    parent={c:i for i in ids for c in nodes[i].get("children",[]) if c in ids}
    assert len(rows)==len(ids)==14
    rest={i:trs(nodes[i].get("translation",[0,0,0]),nodes[i].get("rotation",[0,0,0,1])) for i in ids}
    # Root orientation differs by 180 degrees; other local frames match.
    native={i:cf(rows[names[i]]["localFrame"]) for i in ids}
    assert all(rows[names[i]]["parent"]==(names[parent[i]] if i in parent else bind["meshName"]) for i in ids)
    assert max(np.max(np.abs(native[i]-rest[i])) for i in parent)<1e-5
    assert all(np.max(np.abs(cf(row["transform"])-np.eye(4)))<1e-5 for row in rows.values())
    out=BASE/"native-animations";out.mkdir(exist_ok=True);manifest={}
    for a in j["animations"]:
        name=a["name"];frames,priority,loop=CLIPS[name];times=np.arange(frames+1)/24
        chans={}
        for c in a["channels"]:
            s=a["samplers"][c["sampler"]];t=acc(s["input"]).ravel();v=acc(s["output"]);path=c["target"]["path"];i=c["target"]["node"]
            assert i in ids and abs(t[0])<1e-6 and abs(t[-1]-times[-1])<1e-5
            if path=="scale":assert np.max(np.abs(v-1))<1e-5;continue
            ts=np.clip(times,t[0],t[-1])
            if s["interpolation"]=="STEP":val=v[np.clip(np.searchsorted(t,ts,side="right")-1,0,len(t)-1)]
            elif path=="rotation":val=Slerp(t,Rotation.from_quat(v))(ts).as_quat()
            else:val=np.stack([np.interp(ts,t,v[:,k]) for k in range(3)],axis=1)
            chans[i,path]=val
        root=ET.Element("roblox",{"version":"4","xmlns:xmime":"http://www.w3.org/2005/05/xmlmime","xmlns:xsi":"http://www.w3.org/2001/XMLSchema-instance"});ET.SubElement(root,"External").text="null";ET.SubElement(root,"External").text="nil"
        seq,p=item(root,"KeyframeSequence",name);property(p,"bool","Loop",str(loop).lower());property(p,"token","Priority",priority)
        samples=[];maxerr=0
        for f,t in enumerate(times):
            k,p=item(seq,"Keyframe","Frame_%03d"%f);property(p,"float","Time",format(t,".10g"))
            wrapper=pose(k,bind["meshName"],np.eye(4));deltas={}
            for i in ids:
                m=trs(chans[i,"translation"][f],chans[i,"rotation"][f]);delta=np.linalg.inv(rest[i])@m
                # Native rest locals and source rest locals coincide except root; root is static.
                if i not in parent:assert np.max(np.abs(delta-np.eye(4)))<1e-5
                deltas[i]=delta
                maxerr=max(maxerr,float(np.max(np.abs(rest[i]@delta-m))))
            def add(i,p):
                child=pose(p,names[i],deltas[i])
                for c in nodes[i].get("children",[]):
                    if c in ids:add(c,child)
            add(next(i for i in ids if i not in parent),wrapper)
            samples.append({"time":float(t),"bones":{names[i]:serial(deltas[i]) for i in ids}})
        path=out/(name.lower()+".rbxmx");ET.ElementTree(root).write(path,encoding="utf-8",xml_declaration=True)
        # Independent XML decode validates hierarchy and serialized matrices.
        parsed=ET.parse(path).getroot().find("Item");ks=parsed.findall("Item");assert len(ks)==frames+1
        for frame,k in enumerate(ks):
            pp=k.findall(".//Item[@class='Pose']");assert len(pp)==15
            for e in pp:
                p=e.find("Properties");n=p.find("string[@name='Name']").text
                if n==bind["meshName"]:continue
                m=[float(x.text) for x in p.find("CoordinateFrame")]
                assert np.max(np.abs(np.array(m)-samples[frame]["bones"][n]))<1e-8
        assert maxerr<1e-8
        movement=max(float(np.max(np.abs(cf(v)-np.eye(4)))) for s in samples for v in s["bones"].values())
        assert movement>.01
        sample=max(samples,key=lambda s:max(np.max(np.abs(cf(v)-np.eye(4))) for v in s["bones"].values()))
        manifest[name]={"file":str(path.relative_to(ROOT)),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"keyframes":frames+1,"duration":float(times[-1]),"loop":loop,"priority":priority,"poseCount":15,"sourceMatrixMaxError":maxerr,"sample":sample,"start":samples[0],"end":samples[-1]}
    api.write(out/"manifest.json",manifest);api.commit([out],"assets(s09): native KeyframeSequences from verified source and imported bind")
    return manifest
def publish_and_verify(name,manifest,key,target,c):
    m=manifest[name];path=ROOT/m["file"]
    slug=name.lower()
    receipt=DIR/f"chicken-v2-{slug}-animation.json"
    # API helper treats .rbxmx as glb, so implement exact documented animation MIME.
    if receipt.exists():
        r=json.loads(receipt.read_text());assert r["sha256"]==m["sha256"]
        if r.get("operationPath") and r["state"]!="created":api.poll(key,r,receipt)
        assert r["state"]=="created"
    else:
        r={"id":f"chicken-v2-{slug}-animation","sha256":m["sha256"],"state":"post_intent","retryAllowed":False,"noPlaceWrites":True,"source":m["file"]}
        api.write(receipt,r);api.commit([receipt],f"intent(s09): one-shot native {name} animation")
        desc={"assetType":"Animation","displayName":f"Black Islands Chicken V2 {name}","description":f"Original Chicken V2 {name}, rig asset 76960331636475","creationContext":{"creator":{"userId":c["creatorId"]}}}
        boundary="S09Chicken"+name+m["sha256"][:20]
        body=(f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n"+json.dumps(desc)+f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{slug}.rbxmx\"\r\nContent-Type: model/x-rbxm\r\n\r\n").encode()+path.read_bytes()+f"\r\n--{boundary}--\r\n".encode()
        try:
            code,o=api.request("https://apis.roblox.com/assets/v1/assets",key,"POST",body,{"Content-Type":"multipart/form-data; boundary="+boundary})
            r.update(httpStatus=code,response=o,state="operation_created" if code<300 else "rejected_or_uncertain")
            if code<300:r["operationPath"]=o["path"]
        except Exception as e:r.update(state="requires_reconciliation",error=str(e)[:300])
        api.write(receipt,r);api.commit([receipt],f"evidence(s09): {name} animation upload response")
        if r.get("operationPath"):api.poll(key,r,receipt)
        assert r["state"]=="created",r
    code=(ROOT/"tools/sync/s09_chicken_animation_probe.luau").read_text()
    proof=task(target,key,code,read_version=25,compile_source=True,assetId=r["assetId"],expected=m["sample"],duration=m["duration"])
    p=DIR/f"chicken-v2-{slug}-playback.json";api.write(p,proof);api.commit([p],f"evidence(s09): native {name} animation playback")
    print(json.dumps(proof,indent=2));assert proof["playbackVerified"],proof
    return {"assetId":r["assetId"],"duration":m["duration"],"proof":str(p.relative_to(ROOT))}

def main():
    manifest=convert();key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    c=task(target,key,'do\nreturn syncResult({creatorId=tostring(game.CreatorId),noPlaceWrites=true})\nend',read_version=25,compile_source=True)
    assert c["creatorId"]=="8136365379" and c["loadedVersion"]==25
    idle=json.loads((DIR/"chicken-v2-idle-playback.json").read_text())
    assert idle["playbackVerified"] and idle["assetId"]=="123461134632415", "Idle pilot gate"
    result={"Idle":{"assetId":idle["assetId"],"duration":manifest["Idle"]["duration"],"proof":"asset-library/roblox-receipts/s09/chicken-v2-idle-playback.json"}}
    for name in ("Walk","Run","Peck","Flap"):
        result[name]=publish_and_verify(name,manifest,key,target,c)
    p=DIR/"chicken-v2-native-animation-set.json"
    api.write(p,{"clips":result,"allPlaybackVerified":True,"rigAssetId":"76960331636475","loadedVersion":25,"noPlaceWrites":True})
    api.commit([p],"evidence(s09): all five native chicken animations verified")
if __name__=="__main__":main()
