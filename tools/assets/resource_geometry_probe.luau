-- Read-only exact original rock scale test; no published mutations.
-- __RS_PACK_HELPERS__
local pack=Assets:LoadAssetAsync(tonumber(cfg.assetId))
assert(pack:IsA("Model") and pack.Parent==nil,"Detached pack")
local cursor=pack
for _,seg in cfg.selector do
    local nextObj=cursor:GetChildren()[seg.index]
    assert(nextObj and nextObj.Name==seg.name and nextObj.ClassName==seg.class,"Selector changed")
    cursor=nextObj
end
assert(cursor:IsA("Model"),"Model required")
local model=cursor:Clone()
assert(model and model.Parent==nil and #model:GetDescendants()==#cursor:GetDescendants(),"Detached clone")
local a=audit(model)
local _,digest=serialize(model)
assert(digest==cfg.sourceDigest,"Original rock source changed")
local deps=fetchDependencies(model,a)
local bb=model:GetBoundingBox()
model.PrimaryPart=nil
model.WorldPivot=CFrame.new(bb.Position)
model:PivotTo(CFrame.new())
local rows={}
for _,factor in cfg.scaleFactors do
    assert(factor>0 and factor<=0.02,"Small rock scale")
    local c=model:Clone()
    c:ScaleTo(c:GetScale()*factor)
    local _,size=c:GetBoundingBox()
    table.insert(rows,{factor=factor,bounds=vector(size),modelScale=c:GetScale()})
    c:Destroy()
end
model:Destroy();pack:Destroy()
return syncResult({assetId=cfg.assetId,digest=digest,sourceBounds=a.bounds,scaledSamples=rows,dependencyFetch=deps,noPlaceWrites=true,codeExecuted=false})
