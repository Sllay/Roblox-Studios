--!strict
-- Actual Roblox DataStore adapter. No data writes occur until explicit service startup/use.
local S={}
function S.new(name:string,scope:string?):any
 local ds=game:GetService("DataStoreService")
 local store=ds:GetDataStore(name,scope)
 return {
  canRead=function()return ds:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)>0 end,
  canWrite=function()return ds:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)>0 end,
  get=function(key:string)return store:GetAsync(key) end,
  update=function(key:string,transform:(any)->any)
   return store:UpdateAsync(key,function(old:any,info:DataStoreKeyInfo?)
    local nextValue=transform(old)
    if info then return nextValue,info:GetUserIds(),info:GetMetadata() end
    return nextValue
   end)
  end,
  removeProbe=function(key:string)return store:RemoveAsync(key) end,
 }
end
return table.freeze(S)
