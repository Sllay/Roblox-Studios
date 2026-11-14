--!strict
-- Virtual grass forage sites, NOT inventory items. Server claims one food resource per cell.
export type Site={owner:string?,availableAt:number,leaseUntil:number}
export type Store={sites:{[string]:Site},capacity:number,count:number}
local F={}
function F.new(capacity:number):Store assert(capacity>=1 and capacity%1==0);return {sites={},capacity=capacity,count=0} end
function F.key(x:number,z:number):string return ("%d:%d"):format(math.floor(x/4),math.floor(z/4)) end
function F.claim(s:Store,key:string,owner:string,now:number):boolean
 local site=s.sites[key]
 if not site then
  if s.count>=s.capacity then return false end
  site={owner=nil,availableAt=0,leaseUntil=0};s.sites[key]=site;s.count+=1
 end
 if now<site.availableAt or (site.owner and site.owner~=owner and now<site.leaseUntil) then return false end
 site.owner=owner;site.leaseUntil=now+30;return true
end
function F.consume(s:Store,key:string,owner:string,now:number):boolean
 local site=s.sites[key]
 if not site or site.owner~=owner or now>=site.leaseUntil or now<site.availableAt then return false end
 site.owner=nil;site.availableAt=now+120;site.leaseUntil=0;return true
end
function F.release(s:Store,key:string,owner:string)
 local site=s.sites[key];if site and site.owner==owner then site.owner=nil;site.leaseUntil=0 end
end
function F.prune(s:Store,now:number,maxChecks:number)
 local checked=0
 for k,v in pairs(s.sites) do
  if checked>=maxChecks then break end;checked+=1
  if now>=v.availableAt and now>=v.leaseUntil then s.sites[k]=nil;s.count-=1 end
 end
end
return table.freeze(F)
