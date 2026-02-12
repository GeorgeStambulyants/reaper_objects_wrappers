local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path =
  script_path .. "/fx_utils/?.lua;" ..
  script_path .. "/common_utils/?.lua;" ..
  script_path .. "/track_utils/?.lua;" ..
  script_path .. "/env_utils/?.lua;" ..
  package.path

local FXUtils = require("fx_utils")
local CommonUtils = require("common_utils")
local TrackUtils = require("track_utils")
local RenderingUtil = require("rendering_utils")
local EnvUtils = require("env_utils")
local EnvHelpers = require("env_helpers")
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
    if not vol_lin or vol_lin <= 0 then return -150 end
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


function Track.toggle_solo(self)
    local state = reaper.GetMediaTrackInfo_Value(self.track, "I_SOLO")
    reaper.SetMediaTrackInfo_Value(self.track, "I_SOLO", state == 0 and 1 or 0)
end








-- TODO: Need refactor code below 



-- normalizes track's main lane volume envelope.
-- deletes all existing points on the envelope if present
function Track.normalize_track_volume_envelope(self, target_lufsi)
    local track_name = Track.get_name(self)

    local function get_cur_track_stats()
        local cur_stats = RenderingUtil.parse_render_stats(RenderingUtil.measure_and_read_render_stats(self.project_id, 0))
        if cur_stats == nil or #cur_stats == 0 then return nil, "error reading stats" end
        local cur_track_stats = RenderingUtil.get_record_by_filename(self, cur_stats, track_name)

        if not cur_track_stats then return nil, "stats record for track not found" end
        if cur_track_stats.lufsi == nil then return nil, "lufsi missing" end

        return cur_track_stats, "success"
    end

    local env = reaper.GetTrackEnvelopeByName(self.track, "Volume")
    if not env then return false, "couldn't get track's envelope" end

    local old_points = EnvUtils.get_envelope_points(env)
    EnvUtils.delete_env_points(env)

    -- time doesn't matter here, because envelope is linear and has only one value
    local before_amp = EnvUtils.get_env_amp_at_time(env, 1)
    if before_amp == nil then
        return false, "couldn't read envelope's value at a given time"
    end
    local before_db = TrackUtils.lin_to_db(before_amp)

    local cur_track_stats, status = get_cur_track_stats()
    if cur_track_stats == nil then return false, status end

    local delta_db = target_lufsi - cur_track_stats.lufsi
    if math.abs(delta_db) > 64 then return false, "too big delta" end


    local mode = reaper.GetEnvelopeScalingMode(env)
    local new_value = reaper.ScaleToEnvelopeMode(mode, TrackUtils.db_to_lin(before_db + delta_db))

    EnvUtils.insert_point(env, 0, new_value, EnvHelpers.SHAPE.LINEAR, 0.0, false)
    reaper.Envelope_SortPoints(env)

    local cur_track_stats_after_change, status_after_change = get_cur_track_stats()
    if cur_track_stats_after_change == nil then
        EnvUtils.replace_envelope_points(env, old_points)
        return false, status_after_change
    end

    if math.abs(target_lufsi - cur_track_stats_after_change.lufsi) > 0.3 then
        EnvUtils.replace_envelope_points(env, old_points)
        return false, string.format("normalization failed: got %.3f LUFS-I (target %.3f)", cur_track_stats_after_change.lufsi, target_lufsi)
    end
    return true, "success"
end





function Track.normalize_time_selection_envelope(self, t0, t1, target_lufsi, edges_offset)
    local track_name = Track.get_name(self)

    edges_offset = tonumber(edges_offset) or 0
    if edges_offset < 0 then edges_offset = 0 end
    if t1 - t0 <= 2*edges_offset then edges_offset = 0 end

    local function get_cur_track_stats()
        local cur_stats = RenderingUtil.parse_render_stats(RenderingUtil.measure_and_read_render_stats(self.project_id, 1))
        if cur_stats == nil or #cur_stats == 0 then return nil, "error reading stats" end
        local cur_track_stats = RenderingUtil.get_record_by_filename(self, cur_stats, track_name)

        if not cur_track_stats then return nil, "stats record for track not found" end
        if cur_track_stats.lufsi == nil then return nil, "lufsi missing" end

        return cur_track_stats, "success"
    end

    local env = reaper.GetTrackEnvelopeByName(self.track, "Volume")
    if not env then return false, "couldn't get track's envelope" end

    local t_mid = ((t0 + edges_offset) + (t1 - edges_offset)) / 2
    local before_amp = EnvUtils.get_env_amp_at_time(env, t_mid) -- sample inside selection
    if before_amp == nil then
        return false, "couldn't read envelope's value at a given time"
    end

    local before_db = TrackUtils.lin_to_db(before_amp)


    local cur_track_stats, status = get_cur_track_stats()
    if cur_track_stats == nil then return false, status end


    local delta_db = target_lufsi - cur_track_stats.lufsi
    if math.abs(delta_db) > 64 then return false, "too big delta" end

    local mode = reaper.GetEnvelopeScalingMode(env)
    local start_value_raw = reaper.ScaleToEnvelopeMode(mode, TrackUtils.db_to_lin(before_db))
    local finish_value_raw = reaper.ScaleToEnvelopeMode(mode, TrackUtils.db_to_lin(before_db + delta_db))

    local points = EnvUtils.form_points("square", t0, t1, start_value_raw, finish_value_raw, 0.02, EnvHelpers.SHAPE.LINEAR, 0.0, false, edges_offset)
    if points == nil or #points == 0 then return false, "couldn't create points for envelope" end

    reaper.Envelope_SortPoints(env)
    local old_points = EnvUtils.get_points_in_time_range(env, t0 + edges_offset, t1 - edges_offset)

    EnvUtils.replace_points_in_range(env, t0, t1, points, edges_offset)

    local cur_track_stats_after_change, status_after_change = get_cur_track_stats()
    if cur_track_stats_after_change == nil then
        EnvUtils.replace_points_in_range(env, t0, t1, old_points, edges_offset)
        return false, status_after_change
    end

    if math.abs(target_lufsi - cur_track_stats_after_change.lufsi) > 0.3 then
        EnvUtils.replace_points_in_range(env, t0, t1, old_points, edges_offset)
        return false, string.format("normalization failed: got %.3f LUFS-I (target %.3f)", cur_track_stats_after_change.lufsi, target_lufsi)
    end
    return true, "success"

end

function Track.normalize_fader_lufsi(self, target_lufsi, scope)
    -- scope: 0 for entire track, 1 for time selection
    -- status

    local track_name = Track.get_name(self)

    local function get_cur_track_stats()
        local cur_stats = RenderingUtil.parse_render_stats(RenderingUtil.measure_and_read_render_stats(self.project_id, scope))
        if cur_stats == nil or #cur_stats == 0 then return nil, "error reading stats" end
        local cur_track_stats = RenderingUtil.get_record_by_filename(self, cur_stats, track_name)

        if not cur_track_stats then return nil, "stats record for track not found" end
        if cur_track_stats.lufsi == nil then return nil, "lufsi missing" end

        return cur_track_stats, "success"
    end

    local before_db = Track.get_fader_db(self)

    local cur_track_stats, status = get_cur_track_stats()
    if cur_track_stats == nil then return false, status end


    local delta_db = target_lufsi - cur_track_stats.lufsi
    local delta_db_clamped = clamp(delta_db, -24, 24)

    if delta_db ~= delta_db_clamped then return false, "too big delta" end

    Track.change_fader_db(self, delta_db)

    local cur_track_stats_after_change, status_after_change = get_cur_track_stats()
    if cur_track_stats_after_change == nil then
        Track.set_fader_db(self, before_db)
        return false, status_after_change

    end


    if math.abs(target_lufsi - cur_track_stats_after_change.lufsi) > 0.3 then
        Track.set_fader_db(self, before_db)
        return false, string.format("normalization failed: got %.3f LUFS-I (target %.3f)", cur_track_stats_after_change.lufsi, target_lufsi)
    end
    return true, "success"
end






return Track
