-- Batch up to three logical pages in one bounded response.
local pages={}
local allCount=0
local manifest={}
for _,name in cfg.services do
    local root=game:GetService(name)
    local entries={}
    for _,obj in root:GetDescendants() do
        local path=pathFor(root,obj);local parts={}
        for _,s in path do table.insert(parts,tostring(#s.name)..":"..s.name..":"..s.class..":"..tostring(s.ordinal)) end
        table.insert(entries,{key=table.concat(parts,"/"),obj=obj})
    end
    assert(#entries<=cfg.serviceLimit,"Service scan budget")
    table.sort(entries,function(a,b)return a.key<b.key end)
    local keys={}
    for i,e in entries do
        assert(i==1 or entries[i-1].key~=e.key,"Duplicate path")
        keys[i]=tostring(#e.key)..":"..e.key
    end
    local digest=hash(table.concat(keys,""))
    table.insert(manifest,{service=name,total=#entries,identityDigest=digest})
    allCount+=#entries
    local count=math.max(1,math.ceil(#entries/cfg.pageSize))
    for pi=1,count do
        local slot=#pages+1
        if slot>=cfg.firstPage and slot<cfg.firstPage+cfg.batchSize then
            local first=(pi-1)*cfg.pageSize+1;local last=math.min(#entries,first+cfg.pageSize-1)
            local rows={}
            for i=first,last do table.insert(rows,record(root,entries[i].obj)) end
            table.insert(pages,{service=name,total=#entries,identityDigest=digest,first=first,last=last,objects=rows,noPlaceWrites=true})
        else table.insert(pages,false) end
    end
end
local selected={}
for _,p in pages do if p then table.insert(selected,p) end end
assert(#selected>0 and allCount<=cfg.totalLimit,"Batch scope")
local r={schemaVersion=1,firstPage=cfg.firstPage,totalPages=#pages,manifest=manifest,pages=selected,total=allCount,noPlaceWrites=true}
if cfg.firstPage==1 then r.terrain=terrainState();r.lighting=lightingState();r.workspaceSettings=workspaceSettings() end
local result=syncResult(r)
assert(#result<=2500000,"Response budget")
return result
