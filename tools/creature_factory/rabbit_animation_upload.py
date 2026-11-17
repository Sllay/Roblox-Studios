"""Original rabbit animation export, journalled Open Cloud upload and detached playback probe.

Never re-POST a clip if an intent exists. Does not save or publish any Roblox Place.
"""
from __future__ import annotations
import hashlib,json,os,subprocess,sys,time
from pathlib import Path
sys.path[:0]=[str(Path(__file__).resolve().parents[2]/'tools'),str(Path(__file__).resolve().parents[2]/'tools/asset_factory')]
import s08_prop_intake as api
from deploy import load_all,resolve
from scene_sync import task
from rabbit_animation_author import main as _author_main
ROOT=Path(__file__).resolve().parents[2]
ASSET=ROOT/'asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/asset.glb'
DIR=ROOT/'asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/native-animations'
RECEIPTS=ROOT/'asset-library/roblox-receipts/s0910-rabbit'
api.RECEIPTS=RECEIPTS
BRANCH='feat/creature-factory-next'
SHA='779ac4210bf77c19e8ec40f79dab9f7439a9630522ffd88f990d27c0be026133'

def persist(paths,message):
    names=[str(Path(p).relative_to(ROOT)) for p in paths]
    subprocess.run(['git','add',*names],cwd=ROOT,check=True)
    if subprocess.run(['git','diff','--cached','--quiet'],cwd=ROOT).returncode==0:return
    subprocess.run(['git','commit','-m',message],cwd=ROOT,check=True)
    for _ in range(4):
        subprocess.run(['git','fetch','origin',BRANCH],cwd=ROOT,check=True)
        subprocess.run(['git','rebase','origin/'+BRANCH],cwd=ROOT,check=True)
        if subprocess.run(['git','push','origin','HEAD:refs/heads/'+BRANCH],cwd=ROOT).returncode==0:return
        time.sleep(4)
    raise RuntimeError('Could not journal upload: prevent further POST')
api.commit=persist

def upload(clip,key,owner,row):
    path=DIR/row['file'];b=path.read_bytes();sha=hashlib.sha256(b).hexdigest()
    assert sha==row['sha256']
    receipt=RECEIPTS/('rabbit-v3-'+clip.lower()+'-animation.json')
    if receipt.exists():
        r=json.loads(receipt.read_text());assert r['sha256']==sha
        if r.get('operationPath') and r['state']!='created':api.poll(key,r,receipt)
        if r['state']!='created':raise RuntimeError(f'Unresolved prior upload {clip}: {r["state"]}; will not re-POST')
        return str(r['assetId'])
    r={'id':clip,'source':str(path.relative_to(ROOT)),'sha256':sha,'bytes':len(b),'state':'post_intent','noPlaceWrites':True,'retryAllowed':False}
    api.write(receipt,r);persist([receipt],f'intent(s0910): publish rabbit {clip} keyframes once')
    desc={'assetType':'Animation','displayName':f'Black Islands Rabbit V3 {clip}',
          'description':f'Original skinned 19-bone rabbit {clip} on asset 87498816533548',
          'creationContext':{'creator':{'userId':owner}}}
    boundary='RabbitAnimS0910'+sha[:16]
    body=(f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'+json.dumps(desc)+
          f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\nContent-Type: model/x-rbxm\r\n\r\n').encode()+b+f'\r\n--{boundary}--\r\n'.encode()
    try:
        code,data=api.request('https://apis.roblox.com/assets/v1/assets',key,'POST',body,{'Content-Type':f'multipart/form-data; boundary={boundary}'})
        r.update(httpStatus=code,response=data,state='operation_created' if code<300 else 'rejected_or_uncertain')
        if code<300:r['operationPath']=data['path']
    except Exception as exc:r.update(state='requires_reconciliation',error=str(exc)[:350])
    api.write(receipt,r);persist([receipt],f'evidence(s0910): {clip} upload response')
    if r.get('operationPath'):api.poll(key,r,receipt)
    if r['state']!='created':raise RuntimeError(f'Animation {clip} not confirmed: {r["state"]}')
    return str(r['assetId'])

def hierarchy(glb,proof):
    import struct
    raw=glb.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);ids=doc['skins'][0]['joints'];nodes=doc['nodes']
    names={i:nodes[i]['name'] for i in ids}; parent={j:i for i in ids for j in nodes[i].get('children',[]) if j in ids}
    expected={names[i]:names[parent[i]] if i in parent else 'RootPart' for i in ids}
    native=proof['boneRows'];assert len(native)==19
    actual={row['name']:row['parent'] for row in native}
    assert actual==expected,{'native':actual,'source':expected}
    assert proof['meshCount']==9 and proof['bones']==19 and proof['poseRoundtrip'] and proof['scripts']==0

def main():
    assert hashlib.sha256(ASSET.read_bytes()).hexdigest()==SHA
    native=json.loads((RECEIPTS/'rabbit-native-proof.json').read_text())
    hierarchy(ASSET,native)
    # Author outputs deterministically in CI; content is archived before any network upload.
    argv=sys.argv[:];sys.argv=['rabbit_animation_author.py',str(ASSET),str(DIR)]
    try:_author_main()
    finally:sys.argv=argv
    manifest=json.loads((DIR/'manifest.json').read_text());assert manifest['rig_bones']==19
    persist([DIR],'assets(s0910): deterministic original six rabbit animations for native rig')
    key=os.environ['ROBLOX_OPEN_CLOUD_API_KEY'];g,t=load_all();target=resolve(g,t,'mapa-principal','main','staging')
    assert target['universeId']=='10769712441' and target['placeId']=='93428341652658'
    ident=task(target,key,'do\nreturn syncResult({creatorId=tostring(game.CreatorId),creatorType=game.CreatorType.Name,noPlaceWrites=true})\nend',compile_source=True)
    assert ident['creatorId']=='8136365379' and ident['creatorType']=='User'
    assets={}
    for clip,row in manifest['clips'].items():
        assets[clip]=upload(clip,key,ident['creatorId'],row)
        print('RABBIT_ANIM_UPLOAD',clip,assets[clip],flush=True)
    code=(ROOT/'tools/sync/s0910_rabbit_animation_probe.luau').read_text()
    probe=task(target,key,code,compile_source=True,modelAssetId=native['assetId'],animationIds=assets,
               expected={k:{'keyframes':v['frames'],'duration':v['duration']} for k,v in manifest['clips'].items()})
    assert probe['noPlaceWrites']
    dest=RECEIPTS/'rabbit-animation-playback.json';api.write(dest,probe);persist([dest],'evidence(s0910): native rabbit animation playback proof')
    print('RABBIT_ANIMATION_PROOF',json.dumps(probe,sort_keys=True),flush=True)
    assert probe['playbackVerified'],probe
    final=RECEIPTS/'rabbit-animations-published.json'
    api.write(final,{'schema':1,'source_sha256':SHA,'assetId':native['assetId'],'animations':assets,'playbackVerified':True,'stagingPlaceWritten':False})
    persist([final],'evidence(s0910): verified original rabbit animation asset IDs')
if __name__=='__main__':main()