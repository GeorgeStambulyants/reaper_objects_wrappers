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
    local output = {}
    local seen = {}

    local function push(line)
        output[#output+1] = line
    end


    for i = 0, fx_count - 1 do
        local fx = FX.new(self.track, i)

        if not seen[fx.addrs] then
            seen[fx.addrs] = true
            push(FX.toString(fx))
        end

        if FXUtils.is_container(self.track, fx.addrs) then
            local nodes = FXUtils.enumerate_container_tree_nodes(self.track, fx.addrs, -1)
            if nodes ~= nil then
                for _, node in ipairs(nodes) do
                    if not seen[node.addrs] then
                        local child_fx = FX.new(self.track, node.addrs)
                        push(string.rep("\t", node.depth) .. FX.toString(child_fx))
                        seen[node.addrs] = true
                    end
                end
            end
        end
    end

    return table.concat(output, "\n") .. "\n"
end


return Track
