-- Read-only permission and UV connectivity probe; no asset or place writes.
assert(game.PlaceId==93428341652658 and game.GameId==10769712441 and game.PlaceVersion==23,"Staging v23")
local A=game:GetService("AssetService")
local V=workspace.RSVegetationS06.Models
local names={Tree_01="Canopy_01",Tree_03="Canopy_03",Tree_08="Canopy_08",Tree_12="Canopy_12"}
local rows={};local count=0
for _,m in V:GetChildren() do
 local species=m:GetAttribute("RSSpecies")
 if names[species] then
  count+=1
  local p=m:FindFirstChild(names[species]);assert(p and p:IsA("MeshPart"))
  if rows[species] then continue end
  local meshParts=0;for _,o in m:GetDescendants() do if o:IsA("MeshPart") then meshParts+=1 end end
  local r={mesh=p.MeshId,meshParts=meshParts,status="unavailable"};rows[species]=r
  local e
  local ok,err=pcall(function()
   e=A:CreateEditableMeshAsync(p.MeshContent,{FixedSize=true})
   assert(e,"EditableMesh allocation")
   local faces=e:GetFaces();local vertices=e:GetVertices()
   local parent={}
   local function find(x)
    parent[x]=parent[x] or x
    if parent[x]~=x then parent[x]=find(parent[x]) end
    return parent[x]
   end
   for _,f in faces do
    local vs=e:GetFaceVertices(f);local first=find(vs[1])
    for i=2,#vs do parent[find(vs[i])]=first end
   end
   local groups={}
   for _,f in faces do local vs=e:GetFaceVertices(f);local k=find(vs[1]);groups[k]=(groups[k] or 0)+1 end
   local sizes={};for _,n in groups do table.insert(sizes,n) end;table.sort(sizes)
   r.faces=#faces;r.vertices=#vertices;r.connectedGroups=#sizes;r.groupFaceCounts=sizes
   r.status="readable"
  end)
  if not ok then r.reason=tostring(err):sub(1,400) end
  if e then e:Destroy() end
 end
end
assert(count==250,"Tree population")
return syncResult({trees=count,species=rows,noPlaceWrites=true,geometryChanged=false,clientRenderVerified=false})
