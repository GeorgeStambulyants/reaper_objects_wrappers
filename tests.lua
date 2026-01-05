local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path = script_path .. "/?.lua;" .. package.path

local Track = require("track")


local function begin_edit()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
end

local function end_edit(desc)
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock(desc, -1)
end

-- local ts_start, ts_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
-- if ts_start >= ts_end then
--   reaper.ShowMessageBox("No time selection. Create a time selection first.", "8.D", 0)
--   return
-- end

reaper.ClearConsole()





begin_edit()


local track = Track.new(0, 0)

Track.change_fader_db(track, 40)
reaper.ShowConsoleMsg(tostring(Track.get_fader_db(track)))




end_edit("8.D: Replace envelope points in time selection")

