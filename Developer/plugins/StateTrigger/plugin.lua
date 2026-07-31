-- State Trigger for Q-SYS
-- by Jaume Puig / james.puig@elcine.com
-- Jul '26
-- Inverse of the Multi Flip-Flop component: Flip-Flop converts a Trigger
-- input into a Boolean State output; this converts a Boolean State input
-- into a Trigger pulse output, one shot per state change, either
-- direction. Built to the plugin structure/naming convention confirmed
-- against QSC's own vendor/qsys-plugins/{BasePlugin,ExamplePlugin}
-- templates (see .claude/rules/qsys-plugin-development.md).
-- v1.0.0.1: initial release.
-- v2.0.0.1: added InputCount property (1-256, same range as MultiFlip-Flop's
-- own), for N independent State/Out pairs in one instance, same convention
-- as Gain's Multi-Channel property. Breaking: State/Out renamed to
-- State_N/Out_N -- a design already wired to the old single-instance
-- names needs those pins reconnected.

--[[ #include "info.lua" ]]

function GetColor(props)
	return { 204, 204, 204 }
end

function GetPrettyName(props)
	return "State Trigger"
end

function GetProperties()
	local props = {}
	--[[ #include "properties.lua" ]]
	return props
end

function RectifyProperties(props)
	props.plugin_show_debug.IsHidden = true
	return props
end

function GetControls(props)
	local ctrls = {}
	--[[ #include "controls.lua" ]]
	return ctrls
end

function GetControlLayout(props)
	local layout = {}
	local graphics = {}
	--[[ #include "layout.lua" ]]
	return layout, graphics
end

if Controls then
	--[[ #include "runtime.lua" ]]
end
