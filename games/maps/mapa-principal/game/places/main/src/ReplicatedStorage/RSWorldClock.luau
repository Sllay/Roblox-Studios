--!strict
-- Pure shared clock: elapsed seconds since dawn. No engine side effects.
local Clock = {}
export type Settings = {daySeconds: number, nightSeconds: number}
function Clock.valid(day: number, night: number): boolean
    return day >= 1 and day <= 86400 and night >= 1 and night <= 86400
end
function Clock.at(elapsed: number, day: number, night: number): number
    assert(Clock.valid(day, night), "Invalid cycle durations")
    local phase = elapsed % (day + night)
    if phase < day then
        return 6 + 12 * phase / day
    end
    return (18 + 12 * (phase - day) / night) % 24
end
function Clock.daylight(hour: number): number
    -- Smooth twilight around sunrise/sunset; full brightness in the day.
    local altitude = math.sin((hour - 6) * math.pi / 12)
    local t = math.clamp((altitude + 0.15) / 0.4, 0, 1)
    return t * t * (3 - 2 * t)
end
return Clock
