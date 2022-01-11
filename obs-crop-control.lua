--[[
**
**  OBS-Crop-Control ~ Remote Crop-Filter Control for OBS Studio
**  Copyright (c) 2021-2022 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under GPL 3.0 license <https://spdx.org/licenses/GPL-3.0-only.html>
**
--]]

--  global OBS API
local obs = obslua

--  global Lua APIs
local bit = require("bit")

--  recall a define on control UI
local function recall (control, define)
    --  locate control UI source
    local controlSource = obs.obs_get_source_by_name(control)
	if controlSource == nil then
        obs.script_log(obs.LOG_ERROR,
            string.format("no such control UI source named \"%s\" found", control))
        return false
	end

    --  send keyboard event to source
    local event = obs.obs_key_event()
    event.native_vkey      = 0
    event.modifiers        = 0
    event.native_scancode  = 0
    event.native_modifiers = 0
    event.text             = define
    obs.obs_source_send_key_click(controlSource, event, false)
    obs.obs_source_send_key_click(controlSource, event, true)

    --  release resource
	obs.obs_source_release(controlSource)
    return true
end

--  create obs_source_info structure
local info = {}
info.id           = "recall_crop_control_define"
info.type         = obs.OBS_SOURCE_TYPE_FILTER
info.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO)

--  hook: provide name of filter
info.get_name = function ()
    return "Recall Crop Control Define"
end

--  hook: provide default settings (initialization before create)
info.get_defaults = function (settings)
    --  provide default values
    obs.obs_data_set_default_string(settings, "control", "")
    obs.obs_data_set_default_string(settings, "define1", "none")
    obs.obs_data_set_default_string(settings, "define2", "none")
end

--  hook: create filter context
info.create = function (_settings, source)
    --  create new filter context object
    local ctx = {}
    ctx.filter = source
    ctx.source = nil
    ctx.scene  = nil
    ctx.cfg    = { control = "", define1 = "none", define2 = "none" }
    return ctx
end

--  hook: destroy filter context
info.destroy = function (ctx)
    --  free resources only (notice: no more logging possible)
    ctx.filter = nil
    ctx.source = nil
    ctx.scene  = nil
    ctx.cfg    = nil
end

--  helper function for finding own scene
local function findMyScene (ctx)
    local myScene = nil
    if ctx.source ~= nil then
        local scenes = obs.obs_frontend_get_scenes()
        for _, source in ipairs(scenes) do
            local scene = obs.obs_scene_from_source(source)
            local sourceName = obs.obs_source_get_name(ctx.source)
            local sceneItem = obs.obs_scene_find_source_recursive(scene, sourceName)
            if sceneItem then
                myScene = source
            end
        end
        obs.source_list_release(scenes)
    end
    return myScene
end

--  hook: after loading settings
info.load = function (ctx, settings)
    --  take current parameters
    ctx.cfg.control = obs.obs_data_get_string(settings, "control")
    ctx.cfg.define1 = obs.obs_data_get_string(settings, "define1")
    ctx.cfg.define2 = obs.obs_data_get_string(settings, "define2")

    --  find own scene
    ctx.scene = findMyScene(ctx)

    --  hook: activate (preview)
    obs.obs_frontend_add_event_callback(function (ev)
        if ctx.scene == nil then
            ctx.scene = findMyScene(ctx)
        end
        if ev == obs.OBS_FRONTEND_EVENT_PREVIEW_SCENE_CHANGED then
            if ctx.scene ~= nil and ctx.source ~= nil and ctx.cfg.define1 ~= "none" then
                local previewScene     = obs.obs_frontend_get_current_preview_scene()
                local previewSceneName = obs.obs_source_get_name(previewScene)
                obs.obs_source_release(previewScene)
                local sceneName = obs.obs_source_get_name(ctx.scene)
                if previewSceneName == sceneName then
                    local sourceName = obs.obs_source_get_name(ctx.source)
                    local filterName = obs.obs_source_get_name(ctx.filter)
                    obs.script_log(obs.LOG_INFO, string.format(
                        "scene \"%s\" with source \"%s\" and filter \"%s\" went into PREVIEW: " ..
                        "recalling define #%s on control source \"%s\"",
                        sceneName, sourceName, filterName, ctx.cfg.define1, ctx.cfg.control))
                    recall(ctx.cfg.control, ctx.cfg.define1)
                end
            end
        end
    end)
end

--  hook: provide filter properties (for dialog)
info.get_properties = function (_ctx)
    --  create properties
    local props = obs.obs_properties_create()
    obs.obs_properties_add_text(props, "control", "Source Name of Control UI:", obs.OBS_TEXT_DEFAULT)
    local function addList (prop)
        obs.obs_property_list_add_string(prop, "none", "none")
        obs.obs_property_list_add_string(prop, "1", "1")
        obs.obs_property_list_add_string(prop, "2", "2")
        obs.obs_property_list_add_string(prop, "3", "3")
        obs.obs_property_list_add_string(prop, "4", "4")
        obs.obs_property_list_add_string(prop, "5", "5")
        obs.obs_property_list_add_string(prop, "6", "6")
        obs.obs_property_list_add_string(prop, "7", "7")
        obs.obs_property_list_add_string(prop, "8", "8")
        obs.obs_property_list_add_string(prop, "9", "9")
    end
    local define1 = obs.obs_properties_add_list(props, "define1", "Recall Define on PREVIEW:",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    local define2 = obs.obs_properties_add_list(props, "define2", "Recall Define on PROGRAM:",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    addList(define1)
    addList(define2)
    return props
end

--  hook: react on filter property update (during dialog)
info.update = function (ctx, settings)
    ctx.cfg.control = obs.obs_data_get_string(settings, "control")
    ctx.cfg.define1 = obs.obs_data_get_string(settings, "define1")
    ctx.cfg.define2 = obs.obs_data_get_string(settings, "define2")
end

--  hook: activate (program)
info.activate = function (ctx)
    if ctx.scene == nil then
        ctx.scene = findMyScene(ctx)
    end
    if ctx.scene ~= nil and ctx.source ~= nil and ctx.cfg.define2 ~= "none" then
        local sceneName  = obs.obs_source_get_name(ctx.scene)
        local sourceName = obs.obs_source_get_name(ctx.source)
        local filterName = obs.obs_source_get_name(ctx.filter)
        obs.script_log(obs.LOG_INFO, string.format(
            "scene \"%s\" with source \"%s\" and filter \"%s\" went into PROGRAM: " ..
            "recalling define #%s on control source \"%s\"",
            sceneName, sourceName, filterName, ctx.cfg.define2, ctx.cfg.control))
        recall(ctx.cfg.control, ctx.cfg.define2)
    end
end

--  hook: render video
info.video_render = function (ctx, _effect)
    if ctx.source == nil then
        ctx.source = obs.obs_filter_get_parent(ctx.filter)
    end
    obs.obs_source_skip_video_filter(ctx.filter)
end

--  hook: provide size
info.get_width = function (_ctx)
    return 0
end
info.get_height = function (_ctx)
    return 0
end

--  register the filter
obs.obs_register_source(info)

--  script hook: description displayed on script window
function script_description ()
    return [[
        <h2>Recall Crop Control Define</h2>

        Copyright &copy; 2021-2022 <a style="color: #ffffff; text-decoration: none;"
        href="http://engelschall.com">Dr. Ralf S. Engelschall</a><br/>
        Distributed under <a style="color: #ffffff; text-decoration: none;"
        href="https://spdx.org/licenses/GPL-3.0-only.html">GPL 3.0 license</a>

        <p>
        Recall a Crop Control define if the scene with the source of the filter
        <b>Recall Crop Control Define</b> becomes visible in the PREVIEW (for
        enabled studio mode only) and/or in the PROGRAM.
        </p>
    ]]
end

