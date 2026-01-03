local EnvUtils = {}

-- Envelope point shapes
EnvUtils.SHAPE = {
  LINEAR = 0,
  SQUARE = 1,
  SLOW_START_END = 2,
  FAST_START = 3,
  FAST_END = 4,
  BEZIER = 5
}

local function swap_if_needed(a, b)
    if a > b then return b, a end
    return a, b
end

local function is_on_grid(t, eps)
    eps = eps or 1e-9
    local tg = reaper.BR_GetClosestGridDivision(t)
    return tg and math.abs(tg - t) <= eps
end


local function snap_inward(t0, t1)
    local eps = 1e-9

    local t0g
    if is_on_grid(t0, eps) then
        t0g = t0
    else
        t0g = reaper.BR_GetNextGridDivision(t0)
    end

    local t1g
    if is_on_grid(t1, eps) then
        t1g = t1
    else
        t1g = reaper.BR_GetPrevGridDivision(t1)
    end

    return t0g or t0, t1g or t1
end


-- Delete envelope points in [t0, t1] inclusive.
-- Uses reverse iteration so indices remain valid.
function EnvUtils.delete_points_in_time_range(env, t0, t1)
    if not env then return false end
    t0, t1 = swap_if_needed(t0, t1)

    local pt_count = reaper.CountEnvelopePoints(env)
    if pt_count == 0 then return true end

    for i = pt_count - 1, 0, -1 do
        local ok, time = reaper.GetEnvelopePoint(env, i)
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

-- Replace points in [t0, t1] with the provided list (batch insert + single sort).
-- points: array of {time=..., value=..., shape=..., tension=..., selected=...}
function EnvUtils.replace_points_in_range(env, t0, t1, points)
    if not env then return false end
    t0, t1 = swap_if_needed(t0, t1)

    EnvUtils.delete_points_in_time_range(env, t0, t1)

    if points then
        for _, p in ipairs(points) do
        EnvUtils.insert_point(env, p.time, p.value, p.shape, p.tension, p.selected)
        end
    end

    reaper.Envelope_SortPoints(env)
    return true
end


local function form_square_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)
    


    local eps = 1e-6
    local t_in_a = t0_snapped + fade
    local t_in_b = t1_snapped - fade




    if fade == 0 then
        shape = EnvUtils.SHAPE.SQUARE
        t_in_a = t0_snapped + eps
        t_in_b = t1_snapped - eps
        if t_in_a > t_in_b then
            return {
                {time = t0_snapped, value = start_val, shape = shape, tension = tension, selected = selected},
                {time = t1_snapped, value = finish_val, shape = shape, tension = tension, selected = selected}
            }
        end
    end

    
    return {
        {time = t0_snapped, value = start_val, shape = shape, tension = tension, selected = selected},
        {time = t_in_a, value = finish_val, shape = shape, tension = tension, selected = selected},
        {time = t_in_b, value = finish_val, shape = shape, tension = tension, selected = selected},
        {time = t1_snapped, value = start_val, shape = shape, tension = tension, selected = selected},
    }

end

local function form_pulse_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)

end

local function form_sawup_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)

end

local function form_sawdown_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)

end

local function form_triangle_points(t0, t1, v0, v1, shape, tension, selected)
    local points = {}
    local t = t0
    local up = true

    while t < t1 do
        local t_next = reaper.BR_GetNextGridDivision(t)
        if not t_next or t_next <= t then break end
        if t_next > t1 then t_next = t1 end

        local a = up and v0 or v1
        local b = up and v1 or v0

        points[#points+1] = { time = t,      value = a, shape = shape, tension = tension, selected = selected }
        points[#points+1] = { time = t_next, value = b, shape = shape, tension = tension, selected = selected }

        t = t_next
        up = not up
    end

    return points
end



function EnvUtils.form_points(form_type, t0, t1, start_val, finish_val, fade, shape, tension, selected)
    -- types
    --   square
    --   pulse
    --   triangle
    --   saw_up
    --   saw_down

    t0, t1 = swap_if_needed(t0, t1)

    shape = shape or EnvUtils.SHAPE.LINEAR
    tension = tension or 0.0
    selected = (selected == true)

    fade = fade or 0.0
    if fade < 0 then fade = 0 end

    local dur = t1 - t0
    if fade * 2 > dur then
        fade = dur / 2
    end

    if dur <= 0 then
        return {
            {time = t0, value = start_val, shape = shape, tension = tension, selected = selected}
        }
    end

    local t0_snapped, t1_snapped = snap_inward(t0, t1)

    if t1_snapped <= t0_snapped then
        return {
            {time = t0_snapped, value = start_val, shape = shape, tension = tension, selected = selected}
        }
    end

    if form_type == "square" then
        return form_square_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)
    end

    if form_type == "triangle" then
        return form_triangle_points(t0_snapped, t1_snapped, start_val, finish_val, shape, tension, selected)
    end

    if form_type == "pulse" then
        return form_pulse_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)
    end

    if form_type == "saw_up" then
        return form_sawup_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)
    end

    if form_type == "saw_down" then
        return form_sawdown_points(t0_snapped, t1_snapped, start_val, finish_val, fade, shape, tension, selected)
    end


    return {}
    
end





return EnvUtils
