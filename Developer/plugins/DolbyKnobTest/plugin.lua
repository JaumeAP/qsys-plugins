-- DolbyKnob Test for Q-SYS
-- by Jaume Puig / james.puig@elcine.com
-- Jul '26
-- Scratch/test plugin, NOT for production: the QKnob mechanism (Text
-- control wrapped as a Knob, same class DolbyFader's own DKNob uses) but
-- with a plain linear dB range (-90..10) instead of Dolby's own piecewise
-- 0.0-10.0 scale, to confirm the mechanism works for a simple linear knob
-- too. DolbyFader itself is untouched by this -- separate plugin, built
-- purely to try the idea out.
-- v1.0.0.1: initial release, two controls (a native Gain Knob and a
-- GainDb QKnob clone, bidirectionally synced).
-- v1.0.0.2: down to a single, standalone control -- GainDb only, no
-- native Gain Knob, no sync logic, range changed to -90..10. Explicit
-- user request: no relation to any other control in this plugin.

--[[ #include "info.lua" ]]

function GetColor(props)
	return { 204, 204, 204 }
end

function GetPrettyName(props)
	return "DolbyKnob Test"
end

function GetProperties()
	return {}
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
	--[[ #include "../../shared/qknob.lua" ]]
	--[[ #include "runtime.lua" ]]
end
