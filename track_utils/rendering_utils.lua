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

function TrackRenderUtils.read_render_stats(proj, scope)
    -- scope can be 0 for entire track, or 1 for time selection only
    local ok = measure_loudness(scope)
    if not ok then return nil end

    local ok, stats = reaper.GetSetProjectInfo_String(proj, "RENDER_STATS", "", false)
    if not ok then return nil end

    return stats
end

function TrackRenderUtils.parse_render_stats(stats)
    if type(stats) ~= "string" or stats == "" then return nil end

    local records = {}
    local current = nil

    local function start_new_record()
        current = {}
        records[#records + 1] = current
        return current
    end

    -- Split by ';' and parse key:value
    for token in stats:gmatch("([^;]+)") do
        local key, value = token:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
        if key then
            key = key:upper()

            if key == "FILE" then
                -- New record boundary (common pattern)
                current = start_new_record()
                current.file = value
            else
                -- numeric values (PEAK, LUFSI, etc.) are typically floats
                local num = tonumber(value)
                if current == nil then current = start_new_record() end

                if num ~= nil then
                    current[key:lower()] = num
                else
                    current[key:lower()] = value
                end
            end
        end
    end

    if #records == 0 then return nil end
    return records
end



return TrackRenderUtils
