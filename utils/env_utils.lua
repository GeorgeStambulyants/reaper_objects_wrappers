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

return EnvUtils
