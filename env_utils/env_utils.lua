local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path =
  script_path .. "/env_utils/?.lua;" ..
  package.path

local EnvHelper = require("env_helpers")
local EnvForm = require("env_form_generators")


local EnvUtils = {}

-- Delete envelope points in [t0, t1] inclusive.
-- Uses reverse iteration so indices remain valid.
function EnvUtils.delete_points_in_time_range(env, t0, t1, edges_offset)
    if not env then return false end
    edges_offset = tonumber(edges_offset) or 0
    if edges_offset < 0 then edges_offset = 0 end
    if (t1 - t0) <= 2*edges_offset then return true end


    t0, t1 = EnvHelper.swap_if_needed(t0, t1)

    t0 = t0 + edges_offset
    t1 = t1 - edges_offset


    local pt_count = reaper.CountEnvelopePoints(env)
    if pt_count == 0 then return true end

    for i = pt_count - 1, 0, -1 do
        local ok, time, value, shape, tension, selected = reaper.GetEnvelopePoint(env, i)
        if ok and time >= t0 and time <= t1 then
            reaper.DeleteEnvelopePointEx(env, -1, i) -- -1 = main lane (not automation item)
        end
    end

    return true
end

-- Insert one point (main lane) without sorting. Caller sorts once.
function EnvUtils.insert_point(env, time, value, shape, tension, selected)

    if not env then return false end
    reaper.InsertEnvelopePointEx(
        env,
        -1,                       -- main lane
        time,
        value,
        shape or EnvUtils.SHAPE.LINEAR,
        tension or 0.0,
        selected == true,
        true                      -- noSort (batch)
    )
    return true
end

-- Replace points in [t0 + edges_offset, t1 - edges_offset] with the provided list (batch insert + single sort).
-- points: array of {time=..., value=..., shape=..., tension=..., selected=...}
function EnvUtils.replace_points_in_range(env, t0, t1, points, edges_offset)
    if not env then return false end
    if edges_offset == nil then edges_offset = 0 end

    t0, t1 = EnvHelper.swap_if_needed(t0, t1)

    EnvUtils.delete_points_in_time_range(env, t0, t1, edges_offset)

    if points then
        for _, p in ipairs(points) do
        EnvUtils.insert_point(env, p.time, p.value, p.shape, p.tension, p.selected)
        end
    end

    reaper.Envelope_SortPoints(env)
    return true
end






function EnvUtils.form_points(form_type, t0, t1, start_val, finish_val, fade, shape, tension, selected, edges_offset)
    -- types
    --   square
    --   pulse
    --   triangle
    --   saw
    -- edges_offset if present shifts the edge points by its value

    t0, t1 = EnvHelper.swap_if_needed(t0, t1)

    shape = shape or EnvUtils.SHAPE.LINEAR
    tension = tension or 0.0
    selected = (selected == true)

    fade = fade or 0.0
    if fade < 0 then fade = 0 end
    if edges_offset == nil or edges_offset < 0 then edges_offset = 0 end


    local t0_snapped, t1_snapped = EnvHelper.snap_inward(t0, t1)
    if not t0_snapped or not t1_snapped then return {} end

    t0_snapped = t0_snapped + edges_offset
    t1_snapped = t1_snapped - edges_offset


    local dur_snapped = t1_snapped - t0_snapped
    if dur_snapped <= 0 then
        return {}
    end

    if fade * 2 > dur_snapped then
        fade = dur_snapped / 2
    end

    if form_type == "square" then
        return EnvForm.form_square_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)
    end

    if form_type == "triangle" then
        return EnvForm.form_triangle_points(t0_snapped, t1_snapped, start_val, finish_val, shape, tension, selected)
    end

    if form_type == "pulse" then
        return EnvForm.form_pulse_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)
    end

    if form_type == "saw" then
        return EnvForm.form_saw_points(t0_snapped, t1_snapped, start_val, finish_val, shape, tension, selected)
    end

    return {}

end


function EnvUtils.get_points_in_time_range(env, t0, t1)
    if not env then return {} end
    if t0 > t1 then t0, t1 = t1, t0 end

    local out = {}
    local cnt = reaper.CountEnvelopePoints(env)
    if not cnt or cnt == 0 then return out end

    -- assumes points are time-sorted (generally true; safe if you call Envelope_SortPoints before snapshot)
    for i = 0, cnt - 1 do
        local ok, time, value, shape, tension, selected = reaper.GetEnvelopePoint(env, i)
        if ok then
            if time < t0 then
                -- keep scanning
            elseif time > t1 then
                break -- past the range; can early exit
            else
                out[#out + 1] = {
                    time = time,
                    value = value,
                    shape = shape,
                    tension = tension,
                    selected = selected
                }
            end
        end
    end

    return out



end


function EnvUtils.get_env_amp_at_time(env, t)
    if not env then return nil end

    local _, raw, _, _, _ = reaper.Envelope_Evaluate(env, t, 44100, 0)  -- sr can be any positive value when samplesRequested=0
    local mode = reaper.GetEnvelopeScalingMode(env)
    local amp = reaper.ScaleFromEnvelopeMode(mode, raw)
    return amp
end





return EnvUtils
