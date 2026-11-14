"""Read native rest hierarchy and mesh-relative bone frames, no writes to Place."""
import json,os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/"tools"),str(ROOT/"tools/asset_factory")]
from scene_sync import task
from deploy import load_all,resolve
from s08_prop_intake import write,commit
def main():
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging")
    code="""do
local m=game:GetService("AssetService"):LoadAssetAsync(76960331636475)
assert(m.Parent==nil)
local mesh=m:FindFirstChildWhichIsA("MeshPart",true)
local rows={}
for _,b in mesh:GetDescendants() do
 if b:IsA("Bone") then
  table.insert(rows,{name=b.Name,parent=b.Parent.Name,parentClass=b.Parent.ClassName,localFrame={b.CFrame:GetComponents()},meshFrame={mesh.CFrame:ToObjectSpace(b.WorldCFrame):GetComponents()},transform={b.Transform:GetComponents()}})
 end
end
local result={meshName=mesh.Name,meshSize={mesh.Size.X,mesh.Size.Y,mesh.Size.Z},bones=rows,noPlaceWrites=true}
m:Destroy()
return syncResult(result)
end"""
    p=task(target,os.environ["ROBLOX_OPEN_CLOUD_API_KEY"],code,read_version=25,compile_source=True)
    assert len(p["bones"])==14 and p["loadedVersion"]==25
    path=ROOT/"asset-library/roblox-receipts/s09/chicken-native-bind.json";write(path,p);commit([path],"evidence(s09): native chicken bind hierarchy")
    print(json.dumps(p))
if __name__=="__main__":main()
