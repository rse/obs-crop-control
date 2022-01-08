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
local bit      = require("bit")

--  recall a define on control UI
local function recall (control, define)
    obs.script_log(obs.LOG_INFO,
        string.format("recalling crop define %d on control UI source \"%s\"", define, control))

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
    local filter = {}
    filter.source = source
    filter.parent = nil
    filter.width  = 0
    filter.height = 0
    filter.name = obs.obs_source_get_name(source)
    filter.cfg = {
        program = true,
        control = "",
        define1 = "none",
        define2 = "none"
    }
    obs.script_log(obs.LOG_INFO, string.format("hook: create: filter name: \"%s\"", filter.name))
    return filter
end

--  hook: destroy filter context
info.destroy = function (filter)
    --  free resources only (notice: no more logging possible)
    filter.source = nil
    filter.name   = nil
    filter.cfg    = nil
end

--  hook: after loading settings
info.load = function (filter, settings)
    --  take current parameters
    filter.cfg.control = obs.obs_data_get_string(settings, "control")
    filter.cfg.define1 = obs.obs_data_get_string(settings, "define1")
    filter.cfg.define2 = obs.obs_data_get_string(settings, "define2")

    --  hook: activate (preview)
    obs.obs_frontend_add_event_callback(function (ev)
        if ev == obs.OBS_FRONTEND_EVENT_PREVIEW_SCENE_CHANGED then
            if filter.parent ~= nil then
                local sceneSource      = obs.obs_frontend_get_current_preview_scene()
                local sceneSourceName  = obs.obs_source_get_name(sceneSource)
                local filterSourceName = obs.obs_source_get_name(filter.parent)
                local scene            = obs.obs_scene_from_source(sceneSource)
                local sceneItem        = obs.obs_scene_find_source_recursive(scene, filterSourceName)
                obs.obs_source_release(sceneSource)
                if sceneItem then
                    if filter.cfg.define1 ~= "none" then
                        obs.script_log(obs.LOG_INFO, string.format(
                            "hook: scene \"%s\" with filter source \"%s\" is in PREVIEW now -- reacting",
                            sceneSourceName, filterSourceName))
                        recall(filter.cfg.control, filter.cfg.define1)
                    end
                end
            end
        end
    end)
end

--  hook: provide filter properties (for dialog)
info.get_properties = function (_filter)
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
info.update = function (filter, settings)
    filter.cfg.control = obs.obs_data_get_string(settings, "control")
    filter.cfg.define1 = obs.obs_data_get_string(settings, "define1")
    filter.cfg.define2 = obs.obs_data_get_string(settings, "define2")
end

--  hook: activate (program)
info.activate = function (filter)
    if filter.cfg.define2 ~= "none" then
        if filter.parent ~= nil then
            local sceneSource      = obs.obs_frontend_get_current_scene()
            local sceneSourceName  = obs.obs_source_get_name(sceneSource)
            local filterSourceName = obs.obs_source_get_name(filter.parent)
            obs.obs_source_release(sceneSource)
            obs.script_log(obs.LOG_INFO, string.format(
                "hook: scene \"%s\" with filter source \"%s\" is in PROGRAM now -- reacting",
                sceneSourceName, filterSourceName))
            recall(filter.cfg.control, filter.cfg.define2)
        end
    end
end

--  hook: render video
info.video_render = function (filter, _effect)
    if filter.parent == nil then
        filter.parent = obs.obs_filter_get_parent(filter.source)
    end
    if filter.parent ~= nil then
        filter.width  = obs.obs_source_get_base_width(filter.parent)
        filter.height = obs.obs_source_get_base_height(filter.parent)
    end
    obs.obs_source_skip_video_filter(filter.source)
end

--  hook: provide size
info.get_width = function (filter)
    return filter.width
end
info.get_height = function (filter)
    return filter.height
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

