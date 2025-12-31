local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path = script_path .. "/fx.lua;" .. package.path


local FX = require("fx")


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

local track = reaper.GetTrack(0, 0)


reaper.ShowConsoleMsg("Start\n")

local ok, idx_str = reaper.TrackFX_GetNamedConfigParm(track, 1, "container_item.0")
local fx = FX.new(track, tonumber(idx_str))


reaper.ShowConsoleMsg(FX.toString(fx))




end_edit("test fx")