local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path =
  script_path .. "/fx_utils/?.lua;" ..
  script_path .. "/common_utils/?.lua;" ..
  script_path .. "/track_utils/?.lua;" ..
  script_path .. "/env_utils/?.lua;" ..
  script_path .. "/?.lua;" ..
  package.path

local FXUtils = require("fx_utils")
local CommonUtils = require("common_utils")
local TrackUtils = require("track_utils")
local RenderingUtil = require("rendering_utils")
local EnvUtils = require("env_utils")
local EnvHelpers = require("env_helpers")
local FX = require("fx")


local Track = require("track")


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

reaper.ClearConsole()



begin_edit()


local track = Track.new(0, "Track Print")
local ok, string = Track.normalize_time_selection_envelope(track, ts_start, ts_end, -23, 1/44100)
reaper.ShowConsoleMsg(string)

reaper.ShowConsoleMsg(tostring(Track.get_fader_db(track)))

reaper.UpdateArrange()


end_edit("8.D: Replace envelope points in time selection")

