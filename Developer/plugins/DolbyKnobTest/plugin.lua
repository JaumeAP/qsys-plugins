-- DolbyKnob Test for Q-SYS
-- by Jaume Puig / james.puig@elcine.com
-- Jul '26
-- Scratch/test plugin, NOT for production. DolbyFader itself is untouched
-- by this -- separate plugin, built purely to try ideas out.
-- v1.0.0.1: initial release, two controls (a native Gain Knob and a
-- GainDb QKnob clone, bidirectionally synced).
-- v1.0.0.2: down to a single, standalone control -- GainDb only, no
-- native Gain Knob, no sync logic, range changed to -90..10.
-- v1.0.0.3: GainDb is now a native ControlType="Knob" (ControlUnit="dB"),
-- no QKnob/Text wrapper -- removes the shared/qknob.lua dependency and
-- the runtime.lua file entirely, nothing left to run.
-- v1.0.0.4: added GainDbText, a plain editable Text control bidirectionally
-- linked to GainDb -- typing a value into GainDbText updates GainDb.Value
-- (clamped to -90..10) and vice versa. Brings runtime.lua back, but as a
-- direct Controls.* wiring, no QKnob wrapper.

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
	--[[ #include "runtime.lua" ]]
end
