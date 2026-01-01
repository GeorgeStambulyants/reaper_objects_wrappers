local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path =
  script_path .. "/utils/?.lua;" ..
  script_path .. "/fx/?.lua;" ..
  package.path

local FXUtils = require("fx_utils")
local CommonUtils = require("common_utils")
local FX = require("fx")

local Track = {}
Track.__index = Track


function Track.new(project_id, track_id)
    local track = reaper.GetTrack(project_id, track_id)
    local attrs = {track = track}
    local self = setmetatable(attrs, Track)
    return self
end

function Track.get_fx_string_repr(self)
    local fx_count = reaper.TrackFX_GetCount(self.track)
    local output = ""

    for i = 0, fx_count - 1 do
        local fx = FX.new(self.track, i)
        if FXUtils.is_container(self.track, fx.addrs) then
            local enum_children = FXUtils.enumerate_container_descendants(self.track, fx.addrs, -1)
            output = output .. string.format("%s\n", FX.toString(fx))
            if enum_children ~= nil then
                for _, node in ipairs(enum_children) do
                    output = output .. "\t"
                    local child_fx = FX.new(self.track, node.addrs)
                    local state = FX.get_current_state(child_fx)
                    if child_fx ~= nil and state ~= nil then
                        output = output .. string.rep("\t", node.depth) .. FX.toString(FX.new(self.track, node.addrs)) .. "\n"
                        end
                end
            end

        else
            output = output .. FX.toString(fx) .. "\n" 
        end
    end
    return output
end


return Track
