local EnvHelper = {}

-- Envelope point shapes
EnvHelper.SHAPE = {
  LINEAR = 0,
  SQUARE = 1,
  SLOW_START_END = 2,
  FAST_START = 3,
  FAST_END = 4,
  BEZIER = 5
}

function EnvHelper.clamp(x, lo, hi)
    -- clamps x to lo or hi, so it's not out of boundaries

    if x < lo then return lo end
    if x > hi then return hi end
    return x
end


function EnvHelper.swap_if_needed(a, b)
    -- returns min, max

    if a > b then return b, a end
    return a, b
end

function EnvHelper.is_on_grid(t, eps)
    -- checks of provided time is on grid
    eps = eps or 1e-9
    local tg = reaper.BR_GetClosestGridDivision(t)
    return tg and math.abs(tg - t) <= eps
end


function EnvHelper.snap_inward(t0, t1)
    local eps = 1e-5

    local t0g
    if EnvHelper.is_on_grid(t0, eps) then
        t0g = t0
    else
        t0g = reaper.BR_GetNextGridDivision(t0)
    end

    local t1g
    if EnvHelper.is_on_grid(t1, eps) then
        t1g = t1
    else
        t1g = reaper.BR_GetPrevGridDivision(t1)
    end

    return t0g, t1g
end

return EnvHelper
