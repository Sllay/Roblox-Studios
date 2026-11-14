"""Read-only S09 provider diagnostics. Never creates or modifies assets."""
import json,os,sys,urllib.request,urllib.error,urllib.parse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools/asset_factory"))
import s08_prop_intake as api
OWNER="8136365379";KNOWN="91515745821527";NAME="Black Islands chicken-v2-rig"
key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
def get(url,auth=True):
    req=urllib.request.Request(url,headers={"x-api-key":key} if auth else {})
    try:
        with urllib.request.urlopen(req,timeout=25) as r:code=r.status;body=r.read();h=r.headers
    except urllib.error.HTTPError as e:code=e.code;body=e.read();h=e.headers
    except Exception as e:return {"status":0,"error":type(e).__name__},{}
    try:d=json.loads(body)
    except ValueError:d={}
    info={"status":code,"requestId":h.get("x-request-id") or h.get("roblox-request-id"),"contentType":h.get("content-type")}
    if code>=400:info["error"]={k:d[k] for k in ("code","message","errors","details") if k in d} if isinstance(d,dict) else {}
    return info,d
def main():
    proof={"noNewPost":True,"noPlaceWrites":True,"knownAsset":KNOWN,"probes":{},"matches":[]}
    p=proof["probes"]
    i,d=get("https://apis.roblox.com/assets/v1/assets/"+KNOWN);p["knownAssetMetadata"]={**i,"displayName":d.get("displayName"),"assetType":d.get("assetType"),"state":d.get("state")}
    i,d=get("https://apis.roblox.com/cloud/v2/users/"+OWNER+"/inventory-items?"+urllib.parse.urlencode({"filter":"assetIds="+KNOWN,"maxPageSize":25}));p["cloudKnownOwnership"]={**i,"count":len(d.get("inventoryItems",[]))}
    for label,url,auth in [
        ("creatorListing","https://itemconfiguration.roblox.com/v1/creations/get-assets?assetType=Model&isArchived=false&limit=50",True),
        ("publicModelInventory","https://inventory.roblox.com/v2/users/"+OWNER+"/inventory/10?limit=100&sortOrder=Desc",False),
        ("cloudModelInventory","https://apis.roblox.com/cloud/v2/users/"+OWNER+"/inventory-items?"+urllib.parse.urlencode({"filter":"inventoryItemAssetTypes=MODEL","maxPageSize":100}),True)]:
        i,d=get(url,auth);rows=d.get("data",d.get("inventoryItems",[]));p[label]={**i,"count":len(rows),"hasNextPage":bool(d.get("nextPageCursor") or d.get("nextPageToken"))}
        for row in rows:
            item=row.get("assetDetails",row);name=item.get("name") or item.get("displayName");aid=item.get("assetId") or item.get("id")
            if name==NAME and aid:proof["matches"].append({"route":label,"assetId":str(aid)})
        # A player-owned inventory is not an authoritative creator inventory.
    proof["absenceConfirmed"]=False;proof["retryAllowed"]=False
    dest=ROOT/"asset-library/roblox-receipts/s09/chicken-v2-api-diagnostics.json";api.write(dest,proof);api.commit([dest],"evidence(s09): diagnose asset metadata and inventory access")
    print(json.dumps(proof,indent=2))
if __name__=="__main__":main()
