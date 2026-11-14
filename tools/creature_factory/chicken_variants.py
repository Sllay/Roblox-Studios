"""Derive static and single-clip GLBs; preserve source mesh, skin, texture and clip bytes."""
import copy,hashlib,json,struct,sys
from pathlib import Path
SOURCE_SHA="ea0ebd42c7ea7a6b7ec6bf7c976edb2a1e91e205f83a017b21c9e5bc48121466"
CLIPS=("Idle","Walk","Run","Peck","Flap")
def digest(b):return hashlib.sha256(b).hexdigest()
def read_glb(b):
    magic,version,total=struct.unpack_from("<4sII",b);assert magic==b"glTF" and version==2 and total==len(b)
    n,t=struct.unpack_from("<I4s",b,12);assert t==b"JSON";j=json.loads(b[20:20+n]);m,t=struct.unpack_from("<I4s",b,20+n);assert t==b"BIN\0";return j,b[28+n:28+n+m]
def pack(j,b):
    s=json.dumps(j,separators=(",",":"),ensure_ascii=True).encode();s+=b" "*((-len(s))%4);b+=b"\0"*((-len(b))%4)
    return struct.pack("<4sII",b"glTF",2,28+len(s)+len(b))+struct.pack("<I4s",len(s),b"JSON")+s+struct.pack("<I4s",len(b),b"BIN\0")+b
def view(j,b,i):
    v=j["bufferViews"][i];off=v.get("byteOffset",0);return b[off:off+v["byteLength"]]
def accessor(j,b,i):
    a=copy.deepcopy(j["accessors"][i]);v=a.pop("bufferView");return a,view(j,b,v)
def variant(source,clip):
    j,b=read_glb(source);j=copy.deepcopy(j);orig=j.pop("animations");assert tuple(a["name"] for a in orig)==CLIPS
    if clip:j["animations"]=[a for a in orig if a["name"]==clip];assert len(j["animations"])==1
    refs=[]
    for mesh in j["meshes"]:
        for p in mesh["primitives"]:
            refs.extend(p["attributes"].values());refs.append(p["indices"])
    refs.extend(s["inverseBindMatrices"] for s in j["skins"])
    for a in j.get("animations",[]):
        for s in a["samplers"]:refs.extend([s["input"],s["output"]])
    used=sorted(set(refs));amap={old:new for new,old in enumerate(used)};j["accessors"]=[j["accessors"][i] for i in used]
    for mesh in j["meshes"]:
        for p in mesh["primitives"]:
            p["attributes"]={k:amap[v] for k,v in p["attributes"].items()};p["indices"]=amap[p["indices"]]
    for s in j["skins"]:s["inverseBindMatrices"]=amap[s["inverseBindMatrices"]]
    for a in j.get("animations",[]):
        for s in a["samplers"]:s["input"]=amap[s["input"]];s["output"]=amap[s["output"]]
    bvrefs=[a["bufferView"] for a in j["accessors"]]+[im["bufferView"] for im in j["images"]];used=sorted(set(bvrefs));vmap={old:new for new,old in enumerate(used)};views=[];out=bytearray()
    for i in used:
        v=copy.deepcopy(j["bufferViews"][i]);assert v["buffer"]==0;data=view(j,b,i);assert len(data)==v["byteLength"]
        out.extend(b"\0"*((-len(out))%4));v["byteOffset"]=len(out);out.extend(data);views.append(v)
    for a in j["accessors"]:a["bufferView"]=vmap[a["bufferView"]]
    for im in j["images"]:im["bufferView"]=vmap[im["bufferView"]]
    j["bufferViews"]=views;j["buffers"]=[{"byteLength":len(out)}];return pack(j,bytes(out))
def verify(source,derived,clip):
    a,ab=read_glb(source);j,b=read_glb(derived)
    for k in ("nodes","materials","textures","samplers","scenes"):assert a[k]==j[k]
    p=a["meshes"][0]["primitives"][0];q=j["meshes"][0]["primitives"][0]
    assert len(j["meshes"])==1 and len(j["meshes"][0]["primitives"])==1
    assert a["accessors"][p["indices"]]["count"]==3120*3
    for k,i in p["attributes"].items():assert accessor(a,ab,i)==accessor(j,b,q["attributes"][k])
    assert accessor(a,ab,p["indices"])==accessor(j,b,q["indices"])
    assert a["skins"][0]["joints"]==j["skins"][0]["joints"] and len(j["skins"][0]["joints"])==14
    assert accessor(a,ab,a["skins"][0]["inverseBindMatrices"])==accessor(j,b,j["skins"][0]["inverseBindMatrices"])
    assert view(a,ab,a["images"][0]["bufferView"])==view(j,b,j["images"][0]["bufferView"])
    assert len(j.get("animations",[]))==int(clip is not None)
    if clip:
        old=next(x for x in a["animations"] if x["name"]==clip);new=j["animations"][0];assert old["name"]==new["name"] and old["channels"]==new["channels"]
        for s,t in zip(old["samplers"],new["samplers"],strict=True):
            assert s["interpolation"]==t["interpolation"]
            for k in ("input","output"):assert accessor(a,ab,s[k])==accessor(j,b,t[k])
def build(source,out):
    source=Path(source).read_bytes();assert digest(source)==SOURCE_SHA;out=Path(out);out.mkdir(parents=True,exist_ok=True);manifest={}
    for clip in (None,*CLIPS):
        name="chicken-v2-base.glb" if clip is None else "chicken-v2-"+clip.lower()+".glb";data=variant(source,clip);verify(source,data,clip);(out/name).write_bytes(data);manifest[name]={"sha256":digest(data),"bytes":len(data),"clips":[clip] if clip else [],"sourceParity":True}
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n");return manifest
if __name__=="__main__":print(json.dumps(build(sys.argv[1],sys.argv[2]),indent=2))
