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
    event.text             = "" .. define
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
    obs.obs_data_set_default_bool(settings, "program", true)
    obs.obs_data_set_default_string(settings, "control", "")
    obs.obs_data_set_default_int(settings, "define", 1)
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
        define  = 1
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
    filter.cfg.program = obs.obs_data_get_bool(settings, "program")
    filter.cfg.control = obs.obs_data_get_string(settings, "control")
    filter.cfg.define  = obs.obs_data_get_int(settings, "define")
end

--  hook: provide filter properties (for dialog)
info.get_properties = function (_filter)
    --  create properties
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "program", "Activate define when scene becomes active in Program only")
    obs.obs_properties_add_text(props, "control", "Source Name of Control UI:", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(props, "define", "Recall Crop Control Define (1-9):", 1, 9, 1)
    return props
end

--  hook: react on filter property update (during dialog)
info.update = function (filter, settings)
    filter.cfg.program = obs.obs_data_get_string(settings, "program")
    filter.cfg.control = obs.obs_data_get_string(settings, "control")
    filter.cfg.define  = obs.obs_data_get_int(settings, "define")
end

--  hook: activate (program)
info.activate = function (filter)
    if filter.cfg.program then
        recall(filter.cfg.control, filter.cfg.define)
    end
end

--  hook: show (anywhere)
info.show = function (filter)
    if not filter.cfg.program then
        recall(filter.cfg.control, filter.cfg.define)
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
        <b>Recall a Crop Control Define filter for sources. This is intended
        to allow OBS Studio to force Crop Control to recall a crop
        define in case the source becomes visible (aka shown) in any
        display or visible (aka active) in the Program.</b>
        </p>
    ]]
end

