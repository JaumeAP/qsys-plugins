-- CP Series Emulator for Q-SYS
-- by James Puig / james.puig@elcine.com
-- Jul '26
-- v1.0: fakes a Dolby CP650/CP750/CP850/CP950/CP950A processor over TCP, so
-- "Dolby CPSeries Control" can be bench-tested against it without real
-- hardware -- a plugin replacement for the old single-model
-- Dolby CP Emulator/*.quc Control Scripts (CP650/CP750/CP850 only, no
-- CP950/CP950A). Same protocol logic as
-- Developer/cp-series-emulator/cp-series-emulator.lua (kept for the
-- non-Designer bench-testing workflow that predates this plugin), ported
-- into this repo's standard plugin structure: a Model property picks which
-- of the five it emulates, a Status indicator shows whether a client is
-- connected -- one dropped-in instance, reconfigurable, instead of one
-- file per model. Built via PLUGCC.exe like every other plugin here (see
-- qsys-plugin-development.md's "Developer workflow"), not the Control
-- Script paste-into-Designer path the .lua source above still documents.

--[[ #include "info.lua" ]]

-- Constants

-- Supported processor models, as plain records -- same shape "Dolby
-- CPSeries Control"'s own Model table uses (../Dolby CPSeries Control/
-- plugin.lua), kept as this plugin's own copy rather than shared: that
-- plugin's own source is documented as private to it (repo-layout.md), and
-- this emulator is meant to stay a standalone drop-in, not coupled to
-- another plugin's file tree via a cross-folder #include.
Model = {}
for i, m in ipairs({
	{ key = 'CP650',  value = 'CP 650'  },
	{ key = 'CP750',  value = 'CP 750'  },
	{ key = 'CP850',  value = 'CP 850'  },
	{ key = 'CP950',  value = 'CP 950'  },
	{ key = 'CP950A', value = 'CP 950A' },
}) do
	m.index = i
	Model[i] = m
	Model[m.key] = m
end

-- Model value, tolerant of a nil / partial props: Q-SYS may call the Get*
-- functions with no props during plugin registration, before any instance
-- exists.
local function ModelValue(props)
	return (props and props.Model and props.Model.Value) or Model.CP750.value
end

function GetColor(props)
	return { 255, 140, 0 }
end

function GetPrettyName(props)
	return "CP Series Emulator (" .. ModelValue(props) .. ")"
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
