-- A terrain edit changes ground, not the model's authored contact anchor.
-- Sample native height/ground from caller's verified field; no terrain carving.
local function supportTarget(model,x,z,yaw,burial,radius,heightAt)
    local h=heightAt(x,z)
    assert(h and burial>=0 and radius>0,"Invalid support")
    local heights={h}
    for _,off in {{radius,0},{-radius,0},{0,radius},{0,-radius}} do
        local y=heightAt(x+off[1],z+off[2])
        assert(y,"Missing support");table.insert(heights,y)
    end
    assert(math.max(table.unpack(heights))-math.min(table.unpack(heights))<=2.5,"Uneven support")
    local old=model:GetPivot()
    local bb,size=model:GetBoundingBox()
    -- Upright model, rotated only about Y. The vertical offset is invariant.
    local bottom=bb.Position.Y-size.Y/2-old.Position.Y
    assert(burial<size.Y*0.45,"Excessive burial")
    return CFrame.new(x,h-bottom-burial,z)*CFrame.Angles(0,math.rad(yaw),0),h,bottom
end
local function moveSupported(model,collider,cf,ground,burial,radius)
    local old=model:GetPivot()
    local delta=cf.Position-old.Position
    model:PivotTo(cf)
    if collider then collider.CFrame=collider.CFrame+delta end
    model:SetAttribute("RSExpectedGroundY",ground)
    model:SetAttribute("RSBuriedDepth",burial)
    model:SetAttribute("RSSupportRadius",radius)
    return delta
end
