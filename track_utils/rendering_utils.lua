local TrackRenderUtils = {}

TrackRenderUtils.FULL_TRACK_DRY_RENDER_ACTION_ID = 42438
TrackRenderUtils.TS_TRACK_DRY_RENDER_ACTION_ID = 42439


local function run_action(action_id)
    reaper.Main_OnCommand(action_id, 0)
end

local function measure_loudness(scope)
    -- scope can be 0 for entire track, or 1 for time selection only
    if scope == 0 then 
        run_action(TrackRenderUtils.FULL_TRACK_DRY_RENDER_ACTION_ID)
        return true
    elseif scope == 1 then
        run_action(TrackRenderUtils.TS_TRACK_DRY_RENDER_ACTION_ID)
        return true
    else
        return false
    end
end

local function read_render_stats(proj, scope)
    -- scope can be 0 for entire track, or 1 for time selection only
    local ok = measure_loudness(scope)
    if not ok then return nil end

    local ok, stats = reaper.GetSetProjectInfo_String(proj, "RENDER_STATS", "", false)
    if not ok then return nil end

    return stats
end

function TrackRenderUtils.parse_render_stats(proj, scope)
    return read_render_stats(proj, scope)
end


return TrackRenderUtils
