local FX = {}
FX.__index = FX


function FX.new(track, fxidx)
    local guid = reaper.TrackFX_GetFXGUID(track, fxidx)
    local attrs = {track = track, idx = fxidx, guid = guid}
    local self = setmetatable(attrs, FX)
    return self

end

function FX.get_current_state(self)
    FX.resolve_idx(self)
    if not self.idx then return nil end
    
    local _, name = reaper.TrackFX_GetFXName(self.track, self.idx)
    local is_container, container_fx_count_string = reaper.TrackFX_GetNamedConfigParm(self.track, self.idx, "container_count")

    local container_fx_count
    if is_container then
        container_fx_count = tonumber(container_fx_count_string) or 0  -- empty container => 0
    else
        container_fx_count = nil                     -- not a container
    end

    return {
        guid = self.guid,
        idx = self.idx,
        name = name,
        is_container = is_container,
        container_fx_count = container_fx_count
    }

end

function FX.resolve_idx(self)
  -- 1) Validate cached idx
  if self.idx ~= nil then
    local g = reaper.TrackFX_GetFXGUID(self.track, self.idx)
    if g == self.guid then
      return self.idx
    end
  end

  -- 2) Rescan
  local n = reaper.TrackFX_GetCount(self.track)
  for i = 0, n - 1 do
    local g = reaper.TrackFX_GetFXGUID(self.track, i)
    if g == self.guid then
      self.idx = i
      return i
    end
  end

  -- 3) Not found (deleted or moved elsewhere)
  self.idx = nil
  return nil
end


return FX