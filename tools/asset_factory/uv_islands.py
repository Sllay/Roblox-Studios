import bpy,sys,json
from pathlib import Path
from PIL import Image,ImageDraw
src,out=map(Path,sys.argv[sys.argv.index("--")+1:])
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src.resolve()))
im=Image.new("RGB",(1024,1024),(24,24,24));draw=ImageDraw.Draw(im)
report={}
for o in bpy.context.scene.objects:
    if o.type!="MESH":continue
    m=o.data;uv=m.uv_layers[1].data
    parent=list(range(len(m.polygons)));edges={}
    def find(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    def key(j):
        v=m.vertices[m.loops[j].vertex_index].co
        return tuple(round(float(x),6) for x in (*v,*uv[j].uv))
    for p in m.polygons:
        js=list(p.loop_indices)
        for a,b in zip(js,js[1:]+js[:1]):
            k=tuple(sorted((key(a),key(b))))
            if k in edges:parent[find(p.index)]=find(edges[k])
            else:edges[k]=p.index
    groups={}
    for p in m.polygons:groups.setdefault(find(p.index),[]).append(p)
    report[o.name]={"islands":len(groups),"facesPerIsland":sorted(map(len,groups.values()),reverse=True)}
    for i,ps in enumerate(groups.values()):
        color=(80+(i*73)%175,80+(i*113)%175,80+(i*43)%175)
        for p in ps:
            xy=[(float(uv[j].uv.x)*1023,(1-float(uv[j].uv.y))*1023) for j in p.loop_indices]
            draw.polygon(xy,fill=color,outline=(240,240,240))
        p=ps[0];j=p.loop_indices[0];draw.text((float(uv[j].uv.x)*1023,(1-float(uv[j].uv.y))*1023),f"{o.name}:{i+1}",fill="white")
im.save(out/"uv-layout.png")
(out/"islands.json").write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
