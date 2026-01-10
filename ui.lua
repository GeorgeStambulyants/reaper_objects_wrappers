local info = debug.getinfo(1, "S")
local script_path = info.source:match("@(.+)[/\\]")

package.path =
  script_path .. "/reaper_objects_wrappers/fx_utils/?.lua;" ..
  script_path .. "/reaper_objects_wrappers/common_utils/?.lua;" ..
  script_path .. "/reaper_objects_wrappers/track_utils/?.lua;" ..
  script_path .. "/reaper_objects_wrappers/env_utils/?.lua;" ..
  script_path .. "/reaper_objects_wrappers/?.lua;" ..
  package.path

local FXUtils = require("fx_utils")
local CommonUtils = require("common_utils")
local TrackUtils = require("track_utils")
local RenderingUtil = require("rendering_utils")
local FX = require("fx")
local Track = require('track')
local EnvUtils = require("env_utils")
local EnvHelpers = require("env_helpers")


local function begin_edit()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
end

local function end_edit(desc)
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock(desc or "UI automation", -1)
  reaper.UpdateArrange()
end

local function get_time_selection()
  local t0, t1 = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if t0 >= t1 then return nil, nil end
  return t0, t1
end






local function resolve_target()
    local fx = FXUtils.resolve_touched_fx()
    if not fx then return {ok = false, error = "No valid target. Touch a Track FX parameter."} end

    local ok, track_name = reaper.GetSetMediaTrackInfo_String(fx.track, "P_NAME", "", false)
    if not ok or track_name == "" then track_name = "(unknown)" end
    if fx.is_master then track_name = "MASTER" end

    local ok2, fx_name = reaper.TrackFX_GetFXName(fx.track, fx.fxidx)
    if not ok2 or fx_name == "" then fx_name = "(uknown)" end

    local ok3, param_name = reaper.TrackFX_GetParamName(fx.track, fx.fxidx, fx.param)

    if not ok3 or param_name == "" then param_name = "(uknown)" end

    local cur, min, max = reaper.TrackFX_GetParam(fx.track, fx.fxidx, fx.param)
    local env = reaper.GetFXEnvelope(fx.track, fx.fxidx, fx.param, false)

 
    return {
        ok = true,
        type = fx.kind,
        track = fx.track,
        track_name = track_name,
        is_master = fx.is_master,
        
        fxidx = fx.fxidx,
        fx_name = fx_name,

        param = fx.param,
        param_name = param_name,

        cur = cur,
        min = min,
        max = max,

        env = env,
        in_container = fx.in_container
    }
end


local function apply_square_automation(ui_state)
    local t0, t1 = get_time_selection()
    if not t0 then
        return false, "No time selection."
    end

    local target = resolve_target()
    if not target.ok then
        return false, target.error
    end

    begin_edit()

    -- create envelope if needed
    local env = reaper.GetFXEnvelope(target.track, target.fxidx, target.param, true)
    if not env then
        end_edit("Apply automation (failed)")
        return false, "Could not get/create FX envelope."
    end

    local v0 = target.cur
    local v1 = target.min -- “duck to minimum” baseline for now

    local points = EnvUtils.form_points(
        "square",
        t0, t1,
        v0, v1,
        ui_state.fade,
        ui_state.shape,
        ui_state.tension,
        false
    )


    EnvUtils.replace_points_in_range(env, t0, t1, points)

    end_edit("Apply square automation")
    return true, "Applied."
end




local ctx = reaper.ImGui_CreateContext("FX Automation Tool")
local ui = {
    fade = 0.05,
    tension = 0.0,
    shape = EnvHelpers.SHAPE.LINEAR,
    status = "Ready"
}


local shape_labels = {
    [EnvHelpers.SHAPE.LINEAR] = "Linear",
    [EnvHelpers.SHAPE.SQUARE] = "Square",
    [EnvHelpers.SHAPE.SLOW_START_END] = "Slow start/end",
    [EnvHelpers.SHAPE.FAST_START] = "Fast start",
    [EnvHelpers.SHAPE.FAST_END] = "Fast end",
    [EnvHelpers.SHAPE.BEZIER] = "Bezier"
}
local shape_values = {
    EnvHelpers.SHAPE.LINEAR,
    EnvHelpers.SHAPE.SQUARE,
    EnvHelpers.SHAPE.SLOW_START_END,
    EnvHelpers.SHAPE.FAST_START,
    EnvHelpers.SHAPE.FAST_END,
    EnvHelpers.SHAPE.BEZIER
}


local shape_items = {"Linear","Square","Slow start/end","Fast start","Fast end","Bezier"}


local function loop()
    local visible, open = reaper.ImGui_Begin(ctx, "My Tool", true)
        

    if visible then
        local target = resolve_target()

        if not target.ok then
            reaper.ImGui_Text(ctx, target.error)
        else
            reaper.ImGui_Text(ctx, "Target:")
            reaper.ImGui_Text(ctx, "Type:");     reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, target.type)
            reaper.ImGui_Text(ctx, "Track:");    reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, target.track_name)
            reaper.ImGui_Text(ctx, "FX:");       reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, target.fx_name)
            reaper.ImGui_Text(ctx, "Param:");    reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, target.param_name)
            reaper.ImGui_Text(ctx, "Envelope:"); reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, target.env and "exists" or "none")
            if target.in_container then
                reaper.ImGui_Text(ctx, "Container:"); reaper.ImGui_SameLine(ctx); reaper.ImGui_Text(ctx, "yes")
            end
        end 
        reaper.ImGui_Separator(ctx)

        local changed

        changed, ui.fade = reaper.ImGui_SliderDouble(ctx, "Fade (sec)", ui.fade, 0.0, 1.0)
        changed, ui.tension = reaper.ImGui_SliderDouble(ctx, "Tension", ui.tension, -1.0, 1.0)

        local cur_idx = 1
        for i, v in ipairs(shape_values) do
            if v == ui.shape then cur_idx = i break end
        end

        local changed2
        changed2, cur_idx = reaper.ImGui_Combo(ctx, "Ramp shape", cur_idx, table.concat(shape_items, "\0") .. "\0\0")
        if changed2 then ui.shape = shape_values[cur_idx] end

        reaper.ImGui_Separator(ctx)

        if reaper.ImGui_Button(ctx, "Apply square in time selection") then
            local ok2, msg = apply_square_automation(ui)
            ui.status = msg
        end

        reaper.ImGui_Text(ctx, "Status: " .. ui.status)

    end

    reaper.ImGui_End(ctx)
    if open then
        reaper.defer(loop)
    end
end

reaper.defer(loop)
