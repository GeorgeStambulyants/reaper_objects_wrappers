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

begin_edit()
reaper.ClearConsole()

local track = Track.new(0, 0)

reaper.ShowConsoleMsg(Track.get_fx_string_repr(track))



end_edit("test fx")