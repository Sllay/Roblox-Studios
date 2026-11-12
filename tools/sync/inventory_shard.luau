-- Version-pinned, read-only inventory page. Identity order is independent of
-- GetDescendants order (except duplicate siblings' existing ordinal contract).
local name=cfg.shardService
local root=game:GetService(name)
local function identity(obj)
    local path=pathFor(root,obj)
    local pieces={}
    for _,s in path do
        table.insert(pieces,tostring(#s.name)..":"..s.name..":"..s.class..":"..tostring(s.ordinal))
    end
    return table.concat(pieces,"/")
end
local entries={}
for _,obj in root:GetDescendants() do table.insert(entries,{key=identity(obj),obj=obj}) end
assert(#entries<=cfg.serviceLimit,"Service scan budget")
table.sort(entries,function(a,b)return a.key<b.key end)
local keys={}
for i,e in entries do
    assert(i==1 or entries[i-1].key~=e.key,"Duplicate path")
    keys[i]=tostring(#e.key)..":"..e.key
end
local signature=hash(table.concat(keys,""))
local rows={}
local first=cfg.first
local last=math.min(#entries,first+cfg.pageSize-1)
assert(first>=1 and first<=#entries+1,"Page bounds")
for i=first,last do table.insert(rows,record(root,entries[i].obj)) end
local out={schemaVersion=1,service=name,total=#entries,first=first,last=last,identityDigest=signature,objects=rows,noPlaceWrites=true}
if cfg.includeEnvironment then
    out.terrain=terrainState();out.lighting=lightingState();out.workspaceSettings=workspaceSettings()
end
return syncResult(out)
