local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path =
  script_path .. "/utils/?.lua;" ..
  package.path

local EnvUtils = require("env_utils")

local function begin_edit()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
end

local function end_edit(desc)
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock(desc, -1)
end

local ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
if ts_start >= ts_end then
  reaper.ShowMessageBox("No time selection. Create a time selection first.", "8.D", 0)
  return
end

local retval, trackidx, itemidx, takeidx, fxidx, parm = reaper.GetTouchedOrFocusedFX(0)
if not retval then
  reaper.ShowMessageBox("No last-touched FX parameter.\nTouch a knob, then run again.", "8.D", 0)
  return
end

if itemidx ~= -1 then
  reaper.ShowMessageBox("Take FX not supported in this script.\nTouch a Track FX knob.", "8.D", 0)
  return
end

local track = (trackidx == -1) and reaper.GetMasterTrack(0) or reaper.GetTrack(0, trackidx)
if not track then
  reaper.ShowMessageBox("Could not resolve track.", "8.D", 0)
  return
end

begin_edit()

local env = reaper.GetFXEnvelope(track, fxidx, parm, true)
if not env then
  end_edit("8.D: Replace envelope points")
  reaper.ShowMessageBox("Failed to get/create FX envelope.", "8.D", 0)
  return
end

local cur, min, max = reaper.TrackFX_GetParam(track, fxidx, parm)

-- Example: write a linear ramp 0 -> 1 over time selection
local points = EnvUtils.form_ramp_points(ts_start, ts_end, cur, min, 0, EnvUtils.SHAPE.LINEAR, 0.0, false)
EnvUtils.replace_points_in_range(env, ts_start, ts_end, points)

end_edit("8.D: Replace envelope points in time selection")

