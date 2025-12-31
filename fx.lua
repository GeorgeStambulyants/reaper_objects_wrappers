local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path = script_path .. "/utils.lua;" .. package.path
local Utils = require("utils")


local FX = {}
FX.__index = FX


function FX.new(track, addrs)
    local guid = reaper.TrackFX_GetFXGUID(track, addrs)
    local attrs = {track = track, addrs = addrs, guid = guid}
    local self = setmetatable(attrs, FX)
    return self

end

function FX.get_current_state(self)
    FX.resolve_addrs(self)
    if not self.addrs then return nil end
    
    local _, name = reaper.TrackFX_GetFXName(self.track, self.addrs)
    local is_container, container_fx_count_string = reaper.TrackFX_GetNamedConfigParm(self.track, self.addrs, "container_count")

    local container_fx_count = nil
    if is_container then
        container_fx_count = tonumber(container_fx_count_string) or 0  -- empty container => 0                  -- not a container
    end

    local has_parent, parent_addrs_string = reaper.TrackFX_GetNamedConfigParm(self.track, self.addrs, "parent_container")

    local parent_addrs = nil
    if has_parent then
        parent_addrs = tonumber(parent_addrs_string)
    end


    
    return {
        guid = self.guid,
        addrs = self.addrs,
        name = name,
        is_container = is_container,
        container_fx_count = container_fx_count,
        has_parent = has_parent,
        parent_addrs = parent_addrs
    }

end

function FX.resolve_addrs(self)
    -- 1) Validate cached addrs
    if self.addrs ~= nil then
        local g = reaper.TrackFX_GetFXGUID(self.track, self.addrs)
        if g == self.guid then
        return self.addrs
        end
    end

    -- 2) Rescan
    local n = reaper.TrackFX_GetCount(self.track)
    for i = 0, n - 1 do
        local g = reaper.TrackFX_GetFXGUID(self.track, i)
        if g == self.guid then
        self.addrs = i
        return i
        end
    end

    -- 3) Not found (deleted or moved elsewhere)
    self.addrs = nil
    return nil
end



return FX