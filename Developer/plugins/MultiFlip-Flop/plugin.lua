-- Multi Flip-Flop for Q-SYS
-- by James Puig / james.puig@elcine.com
-- Jul '20
-- v2.0: rebuilt to the plugin structure/naming convention confirmed against
-- QSC's own vendor/qsys-plugins/{BasePlugin,ExamplePlugin} templates and the
-- community vendor/q-sys-community/q-sys-plugin-guide (2026-07-27): mandatory
-- section order, PascalCase Controls/fns/globals, camelCase locals.
-- Breaking: Controls renamed to PascalCase (Start/Exclusive/Set_N/Reset_N/
-- Toggle_N/State_N/Led_N/Out_N/Not_N, were lowercase) and the "Input Count"
-- property renamed to "InputCount" (property names may not contain spaces
-- per the plugin spec; a control name may, a property name may not) -- a
-- design already wired to the old pin/property names needs those
-- reconnected. One bug fixed: every layout Label used 'VAlign = Center',
-- which is not a real layout key (the real one is VTextAlign) and 'Center'
-- was never a declared value anywhere in the file (an undeclared global, so
-- the whole assignment was `VTextAlign = nil`) -- vertical centering on
-- these labels was silently never applied; now VTextAlign = "Center".
-- v2.0.0.1: State_N/Exclusive reads converted from '== 1'/'== 0' numeric
-- comparisons to .Boolean (the confirmed canonical accessor for a Button's
-- state); Toggle_N's handler fixed a real bug where it assigned a Lua
-- boolean into .Value (always numeric) instead of using .Boolean. See
-- CLAUDE.md continuity notes.
-- v2.0.0.2: restructured onto QSC's official PLUGCC.exe build convention
-- (vendor/qsys-plugins/BasePlugin/PluginCompile, PLUGCC.exe) instead of
-- this repo's own build_distributable.sh -- split into this file plus
-- info.lua/properties.lua/controls.lua/layout.lua/runtime.lua, built by
-- PLUGCC.exe on Windows CI (.github/workflows/build-qplug.yml). No
-- functional change from v2.0.0.1; the runtime logic (runtime.lua) is
-- byte-for-byte the same as the old inline `if Controls then ... end`
-- block. This is the pilot plugin for the restructuring -- picked because
-- it has no Developer/Modules/ dependency, so it needed no cross-folder
-- #include (confirmed working separately, see CLAUDE.md continuity notes,
-- before committing to the restructuring for the other three plugins,
-- which do share modules).

--[[ #include "info.lua" ]]

function GetColor(props)
	return { 204, 204, 204 }
end

function GetPrettyName(props)
	return "Multi Flip-Flop "
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
