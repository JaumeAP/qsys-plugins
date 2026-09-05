-- Dolby Sweep Generator Plugin for Q-SYS
-- by James Puig / james.puig@elcine.com
-- Jul '20
-- v2.0: rebuilt to the plugin structure/naming convention confirmed against
-- QSC's own vendor/qsys-plugins/{BasePlugin,ExamplePlugin} templates and the
-- community vendor/q-sys-community/q-sys-plugin-guide (2026-07-27): mandatory
-- section order, PascalCase Controls/fns/globals, camelCase locals. Breaking:
-- Controls renamed to PascalCase (Start/Enable/Trigger/Mute/Period/Frequency/
-- Level, were lowercase) -- a design already wired to the old pin names
-- needs those pins reconnected. Two bugs fixed along the way:
-- GetProperties() assigned the undeclared global 'props' (dead code -- the
-- function returns a separate literal table, this assignment was never
-- read), removed; initplugin() compared Controls.Start.Value (boolean,
-- Q-SYS defaults Button controls to false) against the number 0, so the
-- one-time init (Level=-40, Period=4, Frequency=20) never ran on first
-- compile, now compares against false/true, matching the same pattern
-- CPSeries already used correctly.
-- Signal chain: an embedded 'Sine' component swept log-linearly across
-- OCTAVE decades on a Timer, gated by Enable/Trigger/Mute, driven from
-- runtime.lua.
-- v2.0.0.1: the prior 'start.Value == false' one-time-init fix (see v2.0
-- note above) was itself still wrong: .Value is always numeric (confirmed
-- via vendor/qsc-q-sys's Component.GetControls docs), so comparing it
-- against a Lua boolean literal can never match -- the init block still
-- never ran. Now uses start.Boolean (Start IS ControlType="Button" here).
-- Also fixed a second instance of the same confusion in the other
-- direction: mute.EventHandler assigned the Lua boolean result of
-- 'mute.Value == 1 or not running' into Sine.mute.Value, a numeric-only
-- field -- now Sine.mute.Boolean on both sides. enable/mute reads
-- elsewhere converted to .Boolean too for consistency, though those were
-- not actually broken.
-- v2.0.0.2: restructured onto QSC's official PLUGCC.exe build convention
-- (vendor/qsys-plugins/BasePlugin/PluginCompile, PLUGCC.exe) instead of
-- this repo's own build_distributable.sh -- split into this file plus
-- info.lua/properties.lua/controls.lua/layout.lua/runtime.lua, built by
-- PLUGCC.exe on Windows CI (.github/workflows/build-qplug.yml). qknob.lua
-- moved to Developer/shared/ (also used by DolbyFader/CPSeries) and is
-- #include'd via a relative path -- PLUGCC.exe confirmed to resolve
-- cross-folder #include paths (see CLAUDE.md continuity notes). No
-- functional change from v2.0.0.1; the dev-only 'strict' globals guard
-- (previously wired in below the runtime guard, stripped automatically by
-- build_distributable.sh before shipping) is dropped rather than carried
-- over, since PLUGCC.exe has no equivalent stripping step and it never
-- shipped to production anyway -- see MultiFlip-Flop's own restructuring
-- for the same call.

--[[ #include "info.lua" ]]

function GetColor(props)
	return { 164, 212, 176 } --Is Audio
end

function GetPrettyName(props)
	return "Dolby Sweep Generator"
end

function GetProperties()
	local props = {}
	--[[ #include "properties.lua" ]]
	return props
end

function RectifyProperties(props)
	props.Count.IsHidden = props.Type.Value ~= "Multi-channel"
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

function GetComponents(props)
	return { { Name = "Sine", Type = "sine" } }
end

local function getPinsNames(props)
	local names = {}
	if props.Type.Value == "Multi-channel" then
		for num = 1, props.Count.Value do
			table.insert(names, string.format("Output Channel %i", num))
		end
	elseif props.Type.Value == "Stereo" then
		table.insert(names, "Output Left")
		table.insert(names, "Output Right")
	else
		table.insert(names, "Output")
	end
	return names
end

function GetPins(props)
	local pins = {}
	local names = getPinsNames(props)
	for _, name in pairs(names) do
		table.insert(pins, { Name = name, Direction = "output" })
	end
	return pins
end

function GetWiring(props)
	local wiring = {}
	local names = getPinsNames(props)
	for _, name in pairs(names) do
		table.insert(wiring, { "Sine Output", name })
	end
	return wiring
end

if Controls then
	--[[ #include "runtime.lua" ]]
end
