"""Prove exact copies of known Roblox defaults, never arbitrary StarterPlayer changes."""
from copy import deepcopy
from scene_sync import key_for

def verify_default_clones(base,after,changes):
    before=base["records"];now=after["records"]
    bykey={c["key"]:c["change"] for c in changes}
    accepted=set()
    roots=[r for r in before.values() if r.get("service")=="StarterPlayer" and len(r.get("path",[]))==1 and r["name"]=="PlayerModule" and r["class"]=="ModuleScript"]
    ordinals=sorted(r["path"][0]["ordinal"] for r in roots)
    if len(roots)>=2 and ordinals==list(range(1,len(roots)+1)):
        old=len(roots);new=old+1
        prefix=[{"class":"ModuleScript","name":"PlayerModule","ordinal":old}]
        newprefix=[{**prefix[0],"ordinal":new}]
        originals=[r for r in before.values() if r.get("service")=="StarterPlayer" and r.get("path",[])[:1]==prefix]
        copies=[]
        for r in originals:
            q=deepcopy(r);q["path"][0]["ordinal"]=new;k=key_for(q)
            if now.get(k)!=q or bykey.get(k)!="added":break
            copies.append(k)
        else:
            actual={k for k,r in now.items() if r.get("service")=="StarterPlayer" and r.get("path",[])[:1]==newprefix}
            if copies and actual==set(copies):accepted.update(copies)
    parent_path=[{"class":"StarterPlayerScripts","name":"StarterPlayerScripts","ordinal":1},{"class":"LocalScript","name":"RbxCharacterSounds","ordinal":1},{"class":"ModuleScript","name":"AtomicBinding","ordinal":1}]
    parent_key=key_for({"service":"StarterPlayer","path":parent_path,"managedId":""})
    p=before.get(parent_key)
    if p and p["childCount"]>=2 and bykey.get(parent_key)=="modified":
        q=deepcopy(p);q["childCount"]+=1
        old_path=parent_path+[{"class":"ModuleScript","name":"AtomicBinding","ordinal":p["childCount"]}]
        child=before.get(key_for({"service":"StarterPlayer","path":old_path,"managedId":""}))
        if child and child.get("childCount")==0 and now.get(parent_key)==q:
            c=deepcopy(child);c["path"][-1]["ordinal"]+=1;k=key_for(c)
            if now.get(k)==c and bykey.get(k)=="added":accepted.update((parent_key,k))
    return accepted

def split_default_clones(base,after,changes):
    keys=verify_default_clones(base,after,changes)
    return ([x for x in changes if x["key"] not in keys],[x for x in changes if x["key"] in keys])
