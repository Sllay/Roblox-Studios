-- __RS_BRANCH_POLICY__
local root=Instance.new("Bone");root.Name="Root"
local a=Instance.new("Bone");a.Name="Bough_2_0";a.Position=Vector3.new(0,5,0);a.Parent=root
local b=Instance.new("Bone");b.Name="Bough_4_0";b.Position=Vector3.new(0,9,0);b.Parent=root
local peak=0;local different=0
for i=0,240 do
    local t=i/30
    a.Transform=B.transform(Vector3.zAxis,t,.8,.5,8,1)
    b.Transform=B.transform(Vector3.zAxis,t,2.2,.9,8,1)
    assert(root.Transform==CFrame.identity and B.transform(Vector3.zAxis,t,0,.4,8,1)==CFrame.identity,"Fixed lower geometry")
    local _,angle=b.Transform:ToAxisAngle();peak=math.max(peak,math.deg(math.abs(angle)))
    if a.Transform~=b.Transform then different+=1 end
end
assert(peak>1 and peak<5.2 and different==241,"Independent branch transforms")
assert(B.transform(Vector3.zAxis,1,1,.9,0,1)==CFrame.identity and B.transform(Vector3.zAxis,1,1,.9,8,0)==CFrame.identity,"Wind fade")
root:Destroy()
return syncResult({nativeBoneTransforms=true,rootFixed=true,independentSamples=different,peakDegrees=peak,noPlaceWrites=true,skinnedRenderVerified=false})
