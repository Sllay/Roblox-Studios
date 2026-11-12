"""Original stylized conifer canopy GLB, no external assets.
Branches have independently weighted bones; lower foliage stays on root.
Deterministic, glTF 2.0 single skinned mesh, normals and vertex colors.
"""
import argparse,json,math,struct,hashlib
from pathlib import Path
def build():
    pos=[];normal=[];colors=[];joints=[];weights=[];indices=[];bones=[("Root",(0,0,0))]
    def tri(a,b,c,joint,shade):
        u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
        n=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]);l=math.sqrt(sum(x*x for x in n));assert l>1e-6
        for p in (a,b,c):
            idx=len(pos);indices.append(idx);pos.append(p);normal.append(tuple(x/l for x in n));colors.append((.12*shade,.41*shade,.22*shade,1))
            h=max(0,min(1,(p[1]-4.5)/5.5));w=h*h*(3-2*h) if joint else 0
            joints.append((0,joint,0,0));weights.append((1-w,w,0,0))
    # Tapered, angular branch fans with thickness, one bone per upper bough.
    for tier,(y,length) in enumerate(((1.5,4.5),(3.2,3.8),(5.0,3.0),(6.8,2.15),(8.3,1.25))):
        for k in range(6):
            a=2*math.pi*k/6+tier*.37;d=(math.cos(a),0,math.sin(a));side=(-d[2],0,d[0]);j=0
            if tier>=2:
                j=len(bones);bones.append((f"Bough_{tier}_{k}",(0,y,0)))
            def p(r,h,w=0):return (d[0]*r+side[0]*w,y+h,d[2]*r+side[2]*w)
            base=p(.12,0);tip=p(length,.45);l=p(length*.43,.08,length*.26);r=p(length*.43,.08,-length*.26);ridge=p(length*.36,.75);under=p(length*.38,-.22)
            for a1,b1,c1,shade in ((base,l,ridge,.95),(l,tip,ridge,1.13),(tip,r,ridge,.92),(r,base,ridge,.84),(l,base,under,.73),(tip,l,under,.72),(r,tip,under,.68),(base,r,under,.76)):
                tri(a1,b1,c1,j,shade)
    # pointed crown is independently weighted.
    j=len(bones);bones.append(("Crown",(0,8.7,0)))
    for k in range(6):
        a=math.tau*k/6;b=math.tau*(k+1)/6
        tri((math.cos(a)*.65,8.7,math.sin(a)*.65),(math.cos(b)*.65,8.7,math.sin(b)*.65),(0,10,0),j,1.04)
    assert all(abs(sum(w)-1)<1e-7 and all(0<=x<=1 for x in w) for w in weights)
    assert all(w[1]==0 for p,w in zip(pos,weights) if p[1]<=4.5)
    blob=bytearray();views=[];acc=[]
    def add(values,fmt,ctype,typ,target=None,limits=False):
        while len(blob)%4:blob.append(0)
        offset=len(blob)
        for v in values:blob.extend(struct.pack("<"+fmt,*(v if isinstance(v,(tuple,list)) else (v,))))
        view={"buffer":0,"byteOffset":offset,"byteLength":len(blob)-offset}
        if target:view["target"]=target
        views.append(view);a={"bufferView":len(views)-1,"componentType":ctype,"count":len(values),"type":typ}
        if limits:a.update(min=[min(v[i] for v in values) for i in range(3)],max=[max(v[i] for v in values) for i in range(3)])
        acc.append(a);return len(acc)-1
    attributes={"POSITION":add(pos,"3f",5126,"VEC3",34962,True),"NORMAL":add(normal,"3f",5126,"VEC3",34962),"COLOR_0":add(colors,"4f",5126,"VEC4",34962),"JOINTS_0":add(joints,"4H",5123,"VEC4",34962),"WEIGHTS_0":add(weights,"4f",5126,"VEC4",34962)}
    ind=add(indices,"H",5123,"SCALAR",34963)
    ibm=add([(1,0,0,0,0,1,0,0,0,0,1,0,-x,-y,-z,1) for _,(x,y,z) in bones],"16f",5126,"MAT4")
    nodes=[{"name":"RS_PineCanopy","mesh":0,"skin":0},{"name":"Root","children":list(range(2,len(bones)+1))}]
    nodes += [{"name":name,"translation":list(t)} for name,t in bones[1:]]
    doc={"asset":{"version":"2.0","generator":"Roblox Studios IA original canopy authoring"},"scene":0,"scenes":[{"nodes":[0,1]}],"nodes":nodes,"meshes":[{"name":"RS_PineCanopy","primitives":[{"attributes":attributes,"indices":ind,"material":0}]}],"skins":[{"name":"RS_PineWindRig","joints":list(range(1,len(bones)+1)),"skeleton":1,"inverseBindMatrices":ibm}],"materials":[{"name":"Pine needles","doubleSided":True,"pbrMetallicRoughness":{"baseColorFactor":[1,1,1,1],"metallicFactor":0,"roughnessFactor":1}}],"buffers":[{"byteLength":len(blob)}],"bufferViews":views,"accessors":acc}
    js=json.dumps(doc,separators=(",",":"),sort_keys=True).encode();js+=b" "*((-len(js))%4);blob+=b"\0"*((-len(blob))%4)
    glb=struct.pack("<4sII",b"glTF",2,12+8+len(js)+8+len(blob))+struct.pack("<I4s",len(js),b"JSON")+js+struct.pack("<I4s",len(blob),b"BIN\0")+blob
    return glb,{"vertices":len(pos),"triangles":len(indices)//3,"bones":len(bones),"weightedVertices":sum(w[1]>0 for w in weights),"fixedVertices":sum(w[1]==0 for w in weights),"sha256":hashlib.sha256(glb).hexdigest(),"original":True,"importVerified":False}
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    glb,report=build();(a.output/"pine-canopy.glb").write_bytes(glb);(a.output/"rig-report.json").write_text(json.dumps(report,indent=2)+"\n");print("S064_RIG "+json.dumps(report),flush=True)
if __name__=="__main__":main()
