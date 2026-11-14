"""Publish the existing reviewed Chicken V2 render as a 2D Book preview. No Place save."""
import os,sys,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/"tools"),str(ROOT/"tools/asset_factory")]
import s08_prop_intake as api
from scene_sync import task
from deploy import load_all,resolve
from PIL import Image
DIR=ROOT/"asset-library/roblox-receipts/s09";api.RECEIPTS=DIR
def main():
    path=ROOT/"asset-library/candidates/chicken-rig-43578265487-1/idle.png"
    im=Image.open(path);assert im.format=="PNG" and im.mode=="RGBA" and im.getchannel("A").getextrema()==(0,255)
    g,t=load_all();target=resolve(g,t,"mapa-principal","main","staging");key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    c=task(target,key,'do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend',read_version=25,compile_source=True)
    assert c["creatorId"]=="8136365379" and c["creatorType"]=="User" and c["loadedVersion"]==25
    r=api.submit(key,c["creatorId"],c["creatorType"],"chicken-v2-book-preview",path,"Image")
    assert r["state"]=="created"
    code="""do
local cp=game:GetService("ContentProvider")
local label=Instance.new("ImageLabel")
label.Image="rbxassetid://"..cfg.assetId
local statuses={}
local ok,err=pcall(function() cp:PreloadAsync({label},function(uri,status) statuses[tostring(uri)]=status.Name end) end)
local loaded=false
for _,status in pairs(statuses) do if status=="Success" then loaded=true end end
label:Destroy()
return syncResult({assetId=cfg.assetId,loaded=loaded,ok=ok,statuses=statuses,noPlaceWrites=true,clientRenderVerified=false})
end"""
    p=task(target,key,code,read_version=25,compile_source=True,assetId=r["assetId"])
    dest=DIR/"chicken-v2-book-preview-proof.json";api.write(dest,p);api.commit([dest],"evidence(s09.5): Book PNG image preload")
    print(json.dumps(p));assert p["loaded"],p
if __name__=="__main__":main()
