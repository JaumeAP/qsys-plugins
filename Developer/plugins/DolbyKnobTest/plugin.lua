-- DolbyKnob Test for Q-SYS
-- by Jaume Puig / james.puig@elcine.com
-- Jul '26
-- Scratch/test plugin, NOT for production: clones DolbyFader's own DKNob
-- mechanism (QKnob wrapping a Text control, styled as a Knob) but with a
-- plain linear dB range (-100..20) instead of Dolby's own piecewise 0.0-
-- 10.0 scale, to confirm the QKnob mechanism works for a simple linear
-- knob too. Two controls, bidirectionally synced: Gain (a real native
-- Knob) and GainDb (the QKnob clone). DolbyFader itself is untouched by
-- this -- this is a separate plugin, built purely to try the idea out.
-- v1.0.0.1: initial release.

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
