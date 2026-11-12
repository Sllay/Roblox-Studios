-- Disposable native recovery experiment, never saves or destroys live defaults.
local starter=game:GetService("StarterPlayer")
local before=inventory()
assert(before.total==cfg.expectedTotal,"Baseline inventory")
local roots={}
for _,c in starter:GetChildren() do
    if c.Name=="PlayerModule" and c:IsA("ModuleScript") then table.insert(roots,c) end
end
assert(#roots==16,"Expected default copy count")
local function equal(a,b)
    if typeof(a)~=typeof(b) then return false end
    if typeof(a)~="table" then return a==b end
    for k,v in a do if not equal(v,b[k]) then return false end end
    for k in b do if a[k]==nil then return false end end
    return true
end
local function normalizedTree(obj)
    local rows={}
    for _,x in {obj,table.unpack(obj:GetDescendants())} do
        local r=record(starter,x)
        r.path[1].ordinal=1
        local key={}
        for _,s in r.path do table.insert(key,{s.name,s.class,s.ordinal}) end
        local id=Http:JSONEncode(key)
        assert(rows[id]==nil and r.managedId=="","Default identity")
        rows[id]=r
    end
    return rows
end
local reference=normalizedTree(roots[1])
assert(#roots[1]:GetDescendants()+1==162,"Default size")
for i=2,#roots do assert(equal(reference,normalizedTree(roots[i])),"Nonidentical copy") end
local function isRemoved(obj)
    for i=2,#roots do if obj==roots[i] or obj:IsDescendantOf(roots[i]) then return true end end
    return false
end
local externalRefs=0
for _,x in game:GetDescendants() do
    if x:IsA("ObjectValue") and x.Value and isRemoved(x.Value) and not isRemoved(x) then externalRefs+=1 end
end
assert(externalRefs==0,"External ObjectValue reference")
-- Remove from the disposable DataModel only. Retain objects and references in
-- memory; no delete, no SavePlaceAsync, no script execution.
for i=2,#roots do roots[i].Parent=nil end
local reduced=inventory()
assert(reduced.total==before.total-15*162,"Reduced count")
local function key(r)
    return r.service..":"..Http:JSONEncode(r.path)
end
local reducedRows={}
for _,r in reduced.objects do reducedRows[key(r)]=r end
local unaffected=0
for _,r in before.objects do
    local root=r.path[1]
    if r.service~="StarterPlayer" or root.name~="PlayerModule" or root.class~="ModuleScript" then
        assert(equal(r,reducedRows[key(r)]),"Unexpected unaffected delta");unaffected+=1
    end
end
assert(equal(before.terrain,reduced.terrain) and equal(before.lighting,reduced.lighting) and equal(before.workspaceSettings,reduced.workspaceSettings),"Environment changed")
for i=2,#roots do roots[i].Parent=starter end
local restored=inventory()
assert(restored.total==before.total,"Restored count")
local restoredRows={}
for _,r in restored.objects do restoredRows[key(r)]=r end
for _,r in before.objects do assert(equal(r,restoredRows[key(r)]),"Restore mismatch") end
return syncResult({before=before.total,reduced=reduced.total,restored=restored.total,removedTemporarily=15*162,unaffected=unaffected,externalObjectValueReferences=externalRefs,restoredExact=true,noPlaceWrites=true,runtimeSafeDeletionVerified=false})
