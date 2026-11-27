local function probeApprovedVegetation(world,vegetation)
    local folder=Instance.new("Folder")
    folder.Name="AssetProbe"
    folder.Parent=workspace
    local parts,contents,names={}, {}, {}
    for index,kind in ipairs({"tree","broadleaf","pine","bush","rock","pebble","stick","log"}) do
        local model=vegetation.place(folder,kind,Vector3.new(10*index,24,-25),1,0,2,false)
        names[kind]=model:GetAttribute("ER_AssetTemplate")
        local cf,sz=model:GetBoundingBox()
        assert(math.abs(cf.Y-sz.Y/2-24)<0.02,"incorrect bottom for "..kind)
        for _,part in ipairs(model:GetChildren()) do
            assert(part:IsA("MeshPart") and part.MeshId~="" and not part.CanCollide and not part.CanQuery)
            table.insert(parts,part)
            contents[part.MeshId]=true
            if part.TextureID~="" then contents[part.TextureID]=true end
            for _,surface in ipairs(part:GetChildren()) do
                assert(surface:IsA("SurfaceAppearance"))
                for _,map in ipairs({surface.ColorMapContent,surface.RoughnessMapContent,
                    surface.NormalMapContent,surface.MetalnessMapContent}) do
                    if map.Uri and map.Uri~="" then contents[map.Uri]=true end
                end
            end
        end
    end
    local requests={}
    for id in pairs(contents) do table.insert(requests,id) end
    local failures={}
    local checked=0
    game:GetService("ContentProvider"):PreloadAsync(requests,function(id,status)
        checked+=1
        if status~=Enum.AssetFetchStatus.Success then failures[id]=status.Name end
    end)
    assert(checked>=#parts and not next(failures),game:GetService("HttpService"):JSONEncode(failures))
    assert(workspace.Terrain.Decoration,"native grass is disabled")
    assert(#workspace.ER_World_3D:FindFirstChild("Scenery_0_1"):GetChildren()==0,"maritime vegetation")
    local metrics=world.metrics()
    assert(metrics.vegetationModels>0 and metrics.decorations>metrics.vegetationModels)
    folder:Destroy()
    return {templates=names,meshes=#parts,preloaded=checked,nativeGrass=true,
        worldModels=metrics.vegetationModels,worldDecorInstances=metrics.decorations,
        generationMs=metrics.vegetationMs}
end
