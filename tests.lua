local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path = script_path .. "/fx.lua;" .. package.path
package.path = script_path .. "/utils.lua;" .. package.path

local FX = require("fx")
local Utils = require("utils")

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
local container_fxs = Utils.enumerate_container_descendants(track, 1, 1)

if container_fxs ~= nil then
    
    for k, v in ipairs(container_fxs) do
        local _, name = reaper.TrackFX_GetFXName(track, v)
        reaper.ShowConsoleMsg(k .. " ".. name .. " " .. v .. "\n")
    end
end




end_edit("test fx")