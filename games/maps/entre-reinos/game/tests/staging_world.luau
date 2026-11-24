-- Called in an unsaved engine session after generating the central window.
local function probeWorld(service,profile,seed)
    local prior=service.getChunkCount()
    assert(prior==5,"initial window must be five chunks")
    assert(service.isLoadedAt(120) and service.isLoadedAt(-120))
    assert(not service.isLoadedAt(330) and not service.isLoadedAt(-330))
    local measure=os.clock()
    for _,side in ipairs({-1,1}) do
        local last=service.getChunkCount()
        for x=136,520,64 do
            local ok,reason=service.ensureNear(seed,x*side)
            assert(ok,reason)
            assert(service.isLoadedAt(x*side))
            local now=service.getChunkCount()
            assert(now>=last and now-last<=2,"terrain growth exceeded adjacent window")
            last=now
        end
        assert(service.ensureNear(seed,profile.PLAY_EDGE*side))
        assert(service.isLoadedAt(profile.PLAY_EDGE*side))
    end
    local count=service.getChunkCount()
    assert(count==17,count)
    assert(service.ensureNear(seed,0))
    assert(service.getChunkCount()==count)
    return {initial=prior,complete=count,progressive=true,
        generationMs=(os.clock()-measure)*1000}
end
