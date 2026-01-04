local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path =
  script_path .. "/env_utils/?.lua;" ..
  package.path

local EnvHelper = require("env_helpers")


local EnvForm = {}


function EnvForm.form_square_points(t0, t1, v0, v1, fade, shape, tension, selected)
    -- t0 and t1 must be snapped
    local eps = 1e-6
    local t_in_a = t0 + fade
    local t_in_b = t1 - fade

    if fade == 0 then
        shape = EnvHelper.SHAPE.SQUARE
        t_in_a = t0 + eps
        t_in_b = t1 - eps
    end

    if t_in_a >= t_in_b then
        shape = EnvHelper.SHAPE.LINEAR
        return {
            {time = t0, value = v0, shape = shape, tension = tension, selected = selected},
            {time = t1, value = v1, shape = shape, tension = tension, selected = selected}
        }
    end

    
    return {
        {time = t0, value = v0, shape = shape, tension = tension, selected = selected},
        {time = t_in_a, value = v1, shape = EnvHelper.SHAPE.SQUARE, tension = tension, selected = selected},
        {time = t_in_b, value = v1, shape = shape, tension = tension, selected = selected},
        {time = t1, value = v0, shape = shape, tension = tension, selected = selected},
    }

end

function EnvForm.form_pulse_points(t0, t1, v0, v1, fade, shape, tension, selected)
    -- t0 and t1 must be snapped

    local points = {}
    local eps = 1e-6

    fade = fade or 0.0
    if fade < 0 then fade = 0 end
    if fade == 0 then fade = eps end

    local cur_t = t0
    while cur_t < t1 do
        local mid_t = reaper.BR_GetNextGridDivision(cur_t)
        if not mid_t or mid_t <= cur_t then break end
        if mid_t > t1 then
            points[#points+1] = {time = cur_t, value = v0, shape = shape, tension = tension, selected = selected}
            points[#points+1] = {time = t1,  value = v0, shape = shape, tension = tension, selected = selected}
            return points
        end

        local next_t = reaper.BR_GetNextGridDivision(mid_t)
        if not next_t or next_t <= mid_t then break end
        if next_t > t1 then next_t = t1 end

        
        -- clamp fade to the half of each segment
        local seg1 = mid_t - cur_t
        local seg2 = next_t - mid_t
        local f1 = math.min(fade, seg1 / 2)
        local f2 = math.min(fade, seg2 / 2)

        local mid_pre = EnvHelper.clamp(mid_t - f1, cur_t, mid_t)
        local next_pre = EnvHelper.clamp(next_t - f2, mid_t, next_t)

        -- low portion
        points[#points+1] = {time = cur_t, value = v0, shape = shape, tension = tension, selected = selected}
        if mid_pre > cur_t + eps then
            points[#points+1] = {time = mid_pre, value = v0, shape = shape, tension = tension, selected = selected}
        end

        -- step/ramp up at mid
        points[#points+1] = {time = mid_t, value = v1, shape = shape, tension = tension, selected = selected}

        if next_pre > mid_pre + eps then
            -- high portion
            points[#points+1] = {time = next_pre, value = v1, shape = shape, tension = tension, selected = selected}
        end
            
        -- next cycle begins at nxt (low again)
        if next_t >= t1 then
            points[#points+1] = {time = t1, value = v0, shape = shape, tension = tension, selected = selected}
            break
        end
        points[#points+1] = {time = next_t, value = v0, shape = shape, tension = tension, selected = selected}
        
        cur_t = next_t 
    end

    return points
end

function EnvForm.form_saw_points(t0, t1, v0, v1, shape_ramp, tension_ramp, selected)
    -- t0 and t1 must be snapped

    local points = {}
    local eps = 1e-6

    shape_ramp = shape_ramp or EnvHelper.SHAPE.LINEAR
    tension_ramp = tension_ramp or 0.0

    local cur_t = t0
    while cur_t < t1 do
        local next_t = reaper.BR_GetNextGridDivision(cur_t)
        if not next_t or next_t <= cur_t then break end
        if next_t > t1 then next_t = t1 end

        -- Ramp segment: shape belongs on the start point (cur)
        points[#points+1] = {time = cur_t, value = v0, shape = shape_ramp, tension = tension_ramp, selected = selected}
        points[#points+1] = {time = next_t, value = v1, shape = EnvHelper.SHAPE.SQUARE, tension = 0.0, selected = selected}

        if next_t >= t1 then break end

         -- Reset: step back to v0 just after the boundary
        local reset_t = next_t + eps
        if reset_t >= t1 then break end

        points[#points+1] = {time = reset_t, value = v0, shape = EnvHelper.SHAPE.SQUARE, tension = 0.0, selected = selected}

        cur_t = reset_t

    end

    return points
end


function EnvForm.form_triangle_points(t0, t1, v0, v1, shape, tension, selected)
    -- t0 and t1 must be snapped

    local points = {}
    local up = true

    local cur_t = t0
    while cur_t < t1 do
        local t_next = reaper.BR_GetNextGridDivision(cur_t)
        if not t_next or t_next <= cur_t then break end
        if t_next > t1 then t_next = t1 end

        local a = up and v0 or v1
        local b = up and v1 or v0

        points[#points+1] = { time = cur_t,  value = a, shape = shape, tension = tension, selected = selected }
        points[#points+1] = { time = t_next, value = b, shape = shape, tension = tension, selected = selected }

        cur_t = t_next
        up = not up
    end

    return points
end

return EnvForm
