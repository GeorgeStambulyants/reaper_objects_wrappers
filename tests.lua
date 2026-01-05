local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path =
  script_path .. "/track_utils/?.lua;" ..
  package.path

package.path =
  script_path .. "/common_utils/?.lua;" ..
  package.path

local TrackRenderUtils = require("rendering_utils")
local CommonUtils = require("common_utils")

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



CommonUtils.print_table(TrackRenderUtils.parse_render_stats(TrackRenderUtils.read_render_stats(0, 1)))




end_edit("8.D: Replace envelope points in time selection")

