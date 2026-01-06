local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path =
  script_path .. "/fx_utils/?.lua;" ..
  script_path .. "/common_utils/?.lua;" ..
  script_path .. "/track_utils/?.lua;" ..
  package.path

local FXUtils = require("fx_utils")
local CommonUtils = require("common_utils")
local TrackUtils = require("track_utils")
local RenderingUtil = require("rendering_utils")
local FX = require("fx")

local Track = {}
Track.__index = Track



local function clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end


function Track.new(project_id, track_idx_or_name)
    local track, idx

    if type(track_idx_or_name) == "number" then
        track = reaper.GetTrack(project_id, track_idx_or_name)
        idx = track_idx_or_name
    elseif type(track_idx_or_name) == "string" then
        track, idx = TrackUtils.find_track_by_name(project_id, track_idx_or_name)
    else
        return nil
    end

    if not track then return nil end

    local attrs = {track = track, idx = idx, project_id = project_id}
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


function Track.get_name(self)
    local _, name = reaper.GetSetMediaTrackInfo_String(self.track, "P_NAME", "", false)
    return name
end


function Track.is_selected(self)
    return reaper.IsTrackSelected(self.track)
end


function Track.get_fader_db(self)
    local vol_lin = reaper.GetMediaTrackInfo_Value(self.track, "D_VOL")
    local vol_db = TrackUtils.lin_to_db(vol_lin)

    return vol_db
end

function Track.set_fader_db(self, db)
    db = clamp(db, -150, 24)
    local vol_lin = TrackUtils.db_to_lin(db)
    reaper.SetMediaTrackInfo_Value(self.track, "D_VOL", vol_lin)
end


function Track.change_fader_db(self, db)
    local cur_vol_db = Track.get_fader_db(self)

    Track.set_fader_db(self, cur_vol_db + db)
end


function Track.normalize_fader_lufsi(self, target_lufsi, scope)
    -- scope: 0 for entire track, 1 for time selection
    local cur_stats = RenderingUtil.parse_render_stats(RenderingUtil.read_render_stats(self.project_id, scope))
    CommonUtils.print_table(cur_stats)
    if cur_stats == nil or #cur_stats == 0 then return false end
    local cur_track_stats = RenderingUtil.get_record_by_filename(self, cur_stats, Track.get_name(self))

    if not cur_track_stats then return false end
    if not cur_track_stats.lufsi then return false end

    local delta_db = target_lufsi - cur_track_stats.lufsi
    local delta_db_clampped = clamp(delta_db, -24, 24)

    -- TODO: if the delta is too big need to do something else
    if delta_db ~= delta_db_clampped then return false end

    Track.change_fader_db(self, delta_db)

    -- TODO: need to add a test after changing -- is new value as requested. Decide what to do if it's not

    return true
end






return Track
