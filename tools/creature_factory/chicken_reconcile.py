"""Read-only reconciliation of ambiguous chicken upload. Never repeats POST."""
import json,os,sys,urllib.parse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"tools/asset_factory"))
import s08_prop_intake as api
receipt=ROOT/"asset-library/roblox-receipts/s09/chicken-v2-rig.json"
def main():
    r=json.loads(receipt.read_text());assert r["state"]=="rejected_or_uncertain" and r["httpStatus"]==503 and not r.get("operationPath")
    key=os.environ["ROBLOX_OPEN_CLOUD_API_KEY"];name="Black Islands chicken-v2-rig"
    cursor="";rows=[];matches=[];complete=False
    for page in range(5):
        query={"assetType":"Model","isArchived":"false","limit":50}
        if cursor:query["cursor"]=cursor
        code,d=api.request("https://itemconfiguration.roblox.com/v1/creations/get-assets?"+urllib.parse.urlencode(query),key)
        rows.append({"page":page+1,"httpStatus":code})
        if code!=200:break
        data=d.get("data",[]);rows[-1]["count"]=len(data)
        for x in data:
            if x.get("name")==name or x.get("displayName")==name:
                aid=x.get("assetId") or x.get("id")
                if aid:matches.append(str(aid))
        cursor=d.get("nextPageCursor")
        if not cursor:complete=True;break
    meta=[]
    for aid in set(matches):
        if not aid.isdigit():continue
        code,d=api.request("https://apis.roblox.com/assets/v1/assets/"+aid,key)
        meta.append({"assetId":aid,"httpStatus":code,"displayName":d.get("displayName"),"assetType":d.get("assetType"),"creationContext":d.get("creationContext"),"revisionCreateTime":d.get("revisionCreateTime"),"state":d.get("state")})
    proof={"state":"requires_reconciliation","originalHttpStatus":503,"pages":rows,"inventoryComplete":complete,"matches":meta,"noNewPost":True,"noPlaceWrites":True,"retryAllowed":False,"note":"Empty or unavailable listing cannot establish absence; do not repeat upload without owner review or positive provider evidence."}
    p=receipt.with_name("chicken-v2-reconciliation.json");api.write(p,proof);api.commit([p],"evidence(s09): read-only reconciliation of ambiguous model upload")
    print(json.dumps(proof,indent=2))
if __name__=="__main__":main()
