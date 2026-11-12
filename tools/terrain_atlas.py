"""Native-voxel overview of a pinned staging version; not a rendered screenshot."""
import argparse,base64,json,math,os,struct
from pathlib import Path
from PIL import Image,ImageDraw
from scene_sync import ROOT,read,write,require,state_path,regions,SOURCE,compose_dispatch,canonical,SERVICES
from deploy import load_all,resolve
from cloud_tasks import run_task
SOURCE_ATLAS=ROOT/"tools/sync/terrain_atlas.luau"
def decode(tile):
    data=base64.b64decode(tile["samples"],validate=True)
    require(len(data)==tile["nx"]*tile["nz"]*5,"Atlas length")
    return [(h/10,m,bool(w)) for h,m,w in struct.iter_unpack("<hHB",data)]
def percentile(values,q):
    require(bool(values) and 0<=q<=1,"Invalid percentile")
    return sorted(values)[max(0,math.ceil(len(values)*q)-1)]
def render(report,baseline,out):
    tiles=report["tiles"];materials=report["materials"]
    step=report["stepStuds"];require(step==8 and report["sampleOffsetStuds"]==2,"Sampling contract")
    x0=min(t["bounds"][0] for t in tiles);z0=min(t["bounds"][2] for t in tiles)
    width=(max(t["bounds"][3] for t in tiles)-x0)//step
    height=(max(t["bounds"][5] for t in tiles)-z0)//step
    require(0<width<=512 and 0<height<=512,"Atlas image budget")
    decoded=[(t,decode(t)) for t in tiles]
    heights=[h for _,rows in decoded for h,m,w in rows if materials[str(m)]=="Grass" and not w]
    hi=percentile(heights,.8);lo=min(heights);maxh=max(heights)
    out.mkdir(parents=True,exist_ok=True)
    terrain=Image.new("RGB",(width,height),(25,30,40));alt=terrain.copy()
    for t,rows in decoded:
        ox=(t["bounds"][0]-x0)//step;oz=(t["bounds"][2]-z0)//step
        for n,(h,m,w) in enumerate(rows):
            xy=(ox+n%t["nx"],oz+n//t["nx"]);name=materials[str(m)]
            c=(65,135,190) if w else {"Grass":(80,136,73),"Sand":(205,187,136),"Rock":(114,119,126),"Ground":(137,104,69),"Air":(25,30,40)}.get(name,(118,125,108))
            terrain.putpixel(xy,c)
            level=int(35+180*max(0,min(1,(h-lo)/max(1,maxh-lo))))
            alt.putpixel(xy,(65,135,190) if w else (level,level,level) if name!="Grass" or h<hi else (208,162,68))
    factor=7;terrain=terrain.resize((width*factor,height*factor),Image.Resampling.NEAREST);alt=alt.resize(terrain.size,Image.Resampling.NEAREST)
    terrain.save(out/"materials.png");alt.save(out/"altitude.png")
    placement=terrain.copy();d=ImageDraw.Draw(placement);counts={}
    colors={"RSSceneBuilder":"#adf0b5","RSWorldVegetation":"#e2f2b8","RSEnvironmentP4":"#ffb454","RSEnvironmentP4Detail":"#fa84d3","RSManagedAssets":"#ffffff"}
    for r in baseline["records"].values():
        path=r.get("path",[]);props=r.get("properties",{})
        if r.get("service")!="Workspace" or not path:continue
        root=path[0]["name"]
        if r.get("class")=="Model" and root in colors and len(path)==(2 if root=="RSManagedAssets" else 3):
            p=props.get("pivot")
            if not p:continue
            px,pz=(p[0]-x0)/step*factor,(p[2]-z0)/step*factor
            if not (0<=px<placement.width and 0<=pz<placement.height):continue
            counts[root]=counts.get(root,0)+1
            d.ellipse((px-2,pz-2,px+2,pz+2),fill=colors[root],outline="#15241a")
    for i in range(1,width//32):d.line((i*32*factor,0,i*32*factor,placement.height),fill="#d0d0d0",width=1)
    for i in range(1,height//32):d.line((0,i*32*factor,placement.width,i*32*factor),fill="#d0d0d0",width=1)
    placement.save(out/"placement.png")
    return {"grassAltitudeMin":lo,"grassAltitudeP80":hi,"grassAltitudeMax":maxh,"playableModelCountsByRoot":counts,"sampleCount":sum(len(r) for _,r in decoded),"note":"8-stud decimated voxel estimates, not mesh contact or actual client render"}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--output",type=Path,default=ROOT/"dist/terrain-atlas");a=p.parse_args()
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");base=read(state_path(target))
    cfg=canonical(dict(universeId=target["universeId"],placeId=target["placeId"],services=SERVICES,regions=regions(target),maxObjects=5000))
    require("]=]" not in cfg,"Config encoding")
    src=compose_dispatch(SOURCE.read_text(),"do\n"+SOURCE_ATLAS.read_text()+"\nend").replace("__RS_CONFIG__","[=["+cfg+"]=]")
    report=run_task(target["universeId"],target["placeId"],os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],src,read_version=base["loadedVersion"])
    require(report["noPlaceWrites"] is True and len(report["tiles"])==9 and len({r["id"] for r in report["tiles"]})==9,"Atlas scope")
    for tile in report["tiles"]:
        r=base["records"]["terrain:"+tile["id"]]
        require(tile["digest"]==r["digest"] and tile["bounds"]==r["bounds"],"Native terrain mismatch")
    write(a.output/"atlas.json",report)
    summary=render(report,base,a.output)
    summary.update(loadedVersion=report["loadedVersion"],stateDigest=base["stateDigest"],noPlaceWrites=True)
    write(a.output/"summary.json",summary);print("TERRAIN_ATLAS "+json.dumps(summary),flush=True)
if __name__=="__main__":main()
