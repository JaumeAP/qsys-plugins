-- Dolby Fader for Q-SYS
-- by james.puig@elcine.com
-- Sept '20
-- v2.0: rebuilt to the plugin structure/naming convention confirmed against
-- QSC's own vendor/qsys-plugins/{BasePlugin,ExamplePlugin} templates and the
-- community vendor/q-sys-community/q-sys-plugin-guide (2026-07-27): mandatory
-- section order, PascalCase Controls/fns/globals, camelCase locals. Breaking:
-- Controls renamed Ref/Level/Gain/Increase/Decrease (were ref/level/gain/
-- increase/decrease) -- a design already wired to the old pin names needs
-- those pins reconnected. Two bugs fixed along the way: GetControlLayout had
-- a 'ButtonStype' typo on Ref/Increase/Decrease (should be 'ButtonStyle'),
-- so those three buttons rendered with the default style instead of the
-- intended Momentary style; GetProperties() returned the undefined global
-- 'props' (always nil), now returns {} explicitly.
-- Signal chain: a Text control ('Level') mirrors the Dolby 0.0-10.0 scale,
-- kept in sync with the 'Gain' Knob (dB) and an embedded stepper component
-- via qknob.lua/dolbyfader.lua. No network I/O in this plugin.
-- v2.0.0.1: Controls.Ref.Value == 1 (a Momentary Button) compared a numeric
-- .Value the same way it already worked, but is now .Ref.Boolean --
-- confirmed via vendor/qsc-q-sys's Component.GetControls docs that
-- .Value is always numeric and .Boolean is the canonical boolean
-- accessor for a Button control.
-- v2.0.0.2: restructured onto QSC's official PLUGCC.exe build convention
-- (vendor/qsys-plugins/BasePlugin/PluginCompile, PLUGCC.exe) instead of
-- this repo's own build_distributable.sh -- split into this file plus
-- info.lua/controls.lua/layout.lua. No separate runtime.lua: this file's
-- own `if Controls then` block #include's Developer/shared/dolbyfader.lua
-- (also used by CPSeries, moved there rather than duplicated) directly,
-- which in turn #include's Developer/shared/qknob.lua (also used by
-- Dolby Sweep). Confirmed by trial (2026-07-29), two rules together:
-- (1) a #include path always resolves relative to the ORIGINAL
-- plugin.lua's own directory (the process cwd PLUGCC.exe is invoked
-- from), never relative to whichever file textually contains the
-- directive -- so shared/dolbyfader.lua's own internal include of
-- qknob.lua is written as the path seen from Developer/plugins/DolbyFader/
-- ("../../shared/qknob.lua"), the exact same string this file uses to
-- reach shared/dolbyfader.lua itself, not the path seen from
-- shared/dolbyfader.lua's own folder ("qknob.lua"). (2) a NESTED
-- #include (one inside a file that itself got #include'd, as opposed to
-- one written directly in plugin.lua) is only picked up if it is the
-- FIRST LINE of that file -- a nesting-depth theory was tried and
-- disproved first, and an all-paths-correct-but-not-first-line attempt
-- also silently failed, before this was isolated by comparing against
-- Dolby Sweep's own working runtime.lua -> qknob.lua chain (its
-- #include is line 1 there too). See CLAUDE.md continuity notes. No
-- functional change from v2.0.0.1; the dev-only 'strict'
-- globals guard is dropped rather than carried over, same call as
-- MultiFlip-Flop/Dolby Sweep's own restructuring, since it never shipped
-- to production and PLUGCC.exe has no equivalent stripping step
-- build_distributable.sh had.

--[[ #include "info.lua" ]]

function GetColor(props)
	return { 204, 204, 204 }
end

function GetPrettyName(props)
	return "Dolby Fader "
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

function GetComponents(props)
	local comps = {}
	table.insert(comps, {
		Name = "Step",
		Type = "stepper",
		Properties = {
			control_type = 2, --// Integer
			num_steps = 100,
		},
	})
	return comps
end

if Controls then
	--[[ #include "../../shared/dolbyfader.lua" ]]
end
