-- CP Series Emulator for Q-SYS
-- by James Puig / james.puig@elcine.com
-- Jul '26
-- v1.0: fakes a Dolby CP650/CP750/CP850/CP950/CP950A processor over TCP, so
-- "Dolby CPSeries Control" can be bench-tested against it without real
-- hardware -- a plugin replacement for the old single-model
-- Dolby CP Emulator/*.quc Control Scripts (CP650/CP750/CP850 only, no
-- CP950/CP950A). A Model property picks which of the five it emulates, a
-- Status indicator shows whether a client is connected -- one dropped-in
-- instance, reconfigurable, instead of one file per model. Built via
-- PLUGCC.exe like every other plugin here (see qsys-plugin-development.md's
-- "Developer workflow").
-- v1.0.0.1: the protocol logic (constants, escape/isGet/trySet/macroName/
-- macroIndex, SocketHandler) moved out of runtime.lua into its own
-- protocol.lua, #include'd directly by this file (depth-1, before
-- runtime.lua) rather than inline in runtime.lua. At this point it was
-- also briefly byte-for-byte duplicated in a standalone Control Script
-- version (Developer/cp-series-emulator/cp-series-emulator.lua, predating
-- this plugin) -- that duplication was the reason for the split.
-- v1.0.0.2: the standalone Control Script version removed entirely
-- (explicit user request, once the Plugin covered the same job with less
-- to maintain) -- protocol.lua moved from the briefly-shared
-- Developer/shared/ location back to a private per-plugin file, matching
-- "Dolby CPSeries Control"'s own models.lua/protocol.lua/commlib.lua split
-- (private files, not shared -- Developer/shared/ is for code more than
-- one plugin actually uses). No functional change. See
-- docs/continuity-notes.md for the full history.

-- v1.0.0.3: protocol.lua answers any param, not just fader/mute/format/
-- macros: a SET is stored (and confirmed with the stored value), a later
-- GET reads it back, an unknown GET stays silent; CP750 SETs clip to the
-- documented ranges (including the fixed handlers); numbers are stored
-- canonically (70.0 -> 70, shortest round-trip fractions); the CP650 also
-- answers the CPSeries toolkit's "KEY?" query next to its own "KEY=?".
-- Behaviour taken from the toolkit's simulator (cpp/processor_sim.cpp in
-- JaumeAP/CPSeries); see docs/cross-repo-reference.md.

-- v1.0.0.4: every socket wait is bounded: WriteTimeout (2s) on each client,
-- and a client silent for ReadTimeout (10s) is dropped through a Timeout
-- handler (before, ReadTimeout fired into nothing).

-- v1.0.0.5: the status follows the number of connected clients (one leaving
-- no longer reports "no client" while others remain), and a failed Listen
-- shows a fault instead of "Listening".

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
	-- MODEL must be declared before the protocol.lua #include below --
	-- everything in that file closes over this local. Kept as a depth-1
	-- include directly in plugin.lua, not nested inside runtime.lua:
	-- PLUGCC.exe only recognizes a NESTED #include (one inside a file
	-- that itself got #include'd) if it is that file's own first line
	-- (see qsys-plugin-development.md) -- "Dolby CPSeries Control"'s own
	-- plugin.lua avoids the question the same way, #include'ing
	-- everything it needs directly rather than from inside runtime.lua.
	local MODEL = (Properties.Model.Value):gsub("%s", "")
	--[[ #include "protocol.lua" ]]
	--[[ #include "runtime.lua" ]]
end
