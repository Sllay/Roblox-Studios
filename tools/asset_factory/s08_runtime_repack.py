"""Repack approved baked props into one primitive and one UV0 atlas.
Exact indexed POSITION/NORMAL/UV triangle data is preserved, not re-modeled.
"""
import hashlib,json,struct,sys
from pathlib import Path
from s08_prop_intake import ROOT,APP,PROPS,sha,glb,tris,write,commit
def parse(b):
    d=glb(b);n=struct.unpack_from("<I",b,12)[0];length,kind=struct.unpack_from("<II",b,20+n);assert kind==0x004e4942
    return d,b[28+n:28+n+length]
def raw(d,b,i):
    a=d["accessors"][i];v=d["bufferViews"][a["bufferView"]]
    fmt={5126:"f",5123:"H",5125:"I",5121:"B"}[a["componentType"]]
    width={"SCALAR":1,"VEC2":2,"VEC3":3}[a["type"]]
    size=struct.calcsize("<"+fmt)*width
    assert v.get("byteStride",size)==size and not a.get("sparse")
    offset=v.get("byteOffset",0)+a.get("byteOffset",0)
    return [b[offset+j*size:offset+(j+1)*size] for j in range(a["count"])]
def indices(d,b,i):
    a=d["accessors"][i];fmt={5123:"<H",5125:"<I",5121:"<B"}[a["componentType"]]
    return [struct.unpack(fmt,x)[0] for x in raw(d,b,i)]
def triangle_stream(d,b,uv):
    h=hashlib.sha256()
    for m in d["meshes"]:
        for p in m["primitives"]:
            assert p.get("mode",4)==4
            a=p["attributes"];fields=[raw(d,b,a[k]) for k in ("POSITION","NORMAL",uv)]
            for i in indices(d,b,p["indices"]):
                for f in fields:h.update(f[i])
    return h.hexdigest()
def encode(d,b):
    while len(b)%4:b.append(0)
    d["buffers"]=[{"byteLength":len(b)}]
    j=json.dumps(d,separators=(",",":")).encode();j+=b" "*(-len(j)%4)
    return struct.pack("<4sII",b"glTF",2,12+8+len(j)+8+len(b))+struct.pack("<II",len(j),0x4e4f534a)+j+struct.pack("<II",len(b),0x004e4942)+b
def repack(source,atlas,name):
    d,b=parse(source)
    assert all(set(n)<= {"mesh","name"} for n in d["nodes"])
    assert len(d["images"])==1
    # The source bake used UV1; every material references the same image.
    assert all(m["pbrMetallicRoughness"]["baseColorTexture"].get("texCoord",0)==1 for m in d["materials"])
    assert all(t["source"]==0 for t in d["textures"])
    v=d["bufferViews"][d["images"][0]["bufferView"]];im=b[v.get("byteOffset",0):v.get("byteOffset",0)+v["byteLength"]]
    assert im==atlas,"Embedded atlas differs from approved PNG"
    fields=[[],[],[]];inds=[]
    # Compact vertices on exact byte tuples; preserves normals and seam UVs.
    remap={}
    for m in d["meshes"]:
        for p in m["primitives"]:
            attrs=p["attributes"];chunks=[raw(d,b,attrs[k]) for k in ("POSITION","NORMAL","TEXCOORD_1")]
            for i in indices(d,b,p["indices"]):
                key=tuple(x[i] for x in chunks)
                if key not in remap:
                    remap[key]=len(remap)
                    for j,x in enumerate(key):fields[j].append(x)
                inds.append(remap[key])
    out=bytearray();views=[];access=[]
    def view(data,target=None):
        out.extend(b"\x00"*(-len(out)%4));i=len(views)
        q=dict(buffer=0,byteOffset=len(out),byteLength=len(data))
        if target:q["target"]=target
        views.append(q);out.extend(data);return i
    for j,rows in enumerate(fields):
        a={"bufferView":view(b"".join(rows),34962),"componentType":5126,"count":len(rows),"type":"VEC3" if j<2 else "VEC2"}
        if j==0:
            xyz=[struct.unpack("<fff",x) for x in rows]
            a["min"]=[min(p[k] for p in xyz) for k in range(3)];a["max"]=[max(p[k] for p in xyz) for k in range(3)]
        access.append(a)
    access.append(dict(bufferView=view(b"".join(struct.pack("<I",i) for i in inds),34963),componentType=5125,count=len(inds),type="SCALAR"))
    image_view=view(atlas)
    doc={"asset":{"version":"2.0","generator":"Black Islands S08 exact atlas repack"},"scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"name":name,"mesh":0}],"meshes":[{"name":name,"primitives":[{"attributes":{"POSITION":0,"NORMAL":1,"TEXCOORD_0":2},"indices":3,"material":0,"mode":4}]}],"materials":[{"name":"BakedAtlas","pbrMetallicRoughness":{"baseColorTexture":{"index":0},"metallicFactor":0,"roughnessFactor":.5},"doubleSided":True}],"textures":[{"sampler":0,"source":0}],"samplers":[{"wrapS":10497,"wrapT":10497}],"images":[{"bufferView":image_view,"mimeType":"image/png","name":"atlas"}],"accessors":access,"bufferViews":views}
    result=encode(doc,out);dd,bb=parse(result)
    assert tris(dd)==tris(d) and triangle_stream(dd,bb,"TEXCOORD_0")==triangle_stream(d,b,"TEXCOORD_1")
    return result,triangle_stream(d,b,"TEXCOORD_1")
def main():
    paths=[]
    for name,_,h,n,run in PROPS:
        src=APP/name/"v1";data=(src/"asset.glb").read_bytes();atlas=(src/"atlas.png").read_bytes()
        assert sha(data)==h
        result,stream=repack(data,atlas,name.capitalize())
        dst=src/"runtime";dst.mkdir(exist_ok=True);(dst/"asset.glb").write_bytes(result)
        write(dst/"manifest.json",dict(schema=1,sourceSha256=h,sha256=sha(result),atlasSha256=sha(atlas),triangleStreamSha256=stream,triangles=n,meshes=1,materials=1,uv="TEXCOORD_0",geometryUnchanged=True))
        paths.append(dst)
    commit(paths,"assets(s08): exact single-mesh UV0 atlas runtime variants")
if __name__=="__main__":main()
