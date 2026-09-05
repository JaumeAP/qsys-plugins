-- Minimal stand-in for the Q-SYS host globals, so plugin and module code can
-- be loaded and driven by a plain Lua interpreter instead of Q-SYS Designer.
-- Covers only what the plugins in this repo actually touch: Controls, an
-- embedded stepper component, Timer, TcpSocket, Properties and System.
--
-- Timers here never fire on their own -- there is no event loop. Tests drive
-- them by hand with env:tick(), which is what makes the poll loop testable a
-- step at a time.
--
-- Standing convention (2026-07-29): this file models real Q-SYS Lua host
-- behavior, checked against Q-SYS Help (help.qsys.com / q-syshelp.qsc.com),
-- not guessed. A new plugin that needs a host feature this stub doesn't
-- have yet (a different embedded component, a Q-SYS Lua extension beyond
-- Controls/Timer/TcpSocket/Properties/System, a control property this file
-- doesn't model) should get that feature looked up in Q-SYS Help first, the
-- same way the Trigger/Meter control-kind split and the Timer.CallAfter
-- error-swallowing fix above were done, rather than guessed from how the
-- plugin code merely happens to be written. Extend this file to add the
-- capability, don't work around its absence in the plugin or the test.

local M = {}

-- This file's own directory, resolved via debug info rather than arg[0] or
-- package.path (qsys_stub.lua is always require()'d, never the top-level
-- chunk, so it has no arg[0] of its own -- and computing this from
-- package.path would force every caller to extend their own path just to
-- reach components/, even the ones that never call check_wiring). Real Lua
-- 5.3, no dependency beyond the standard debug library.
local STUB_DIR = debug.getinfo(1, "S").source:match("^@(.*)[/\\][^/\\]*$") or "."

-- Per-Type audio pin definitions for GetComponents-declared embedded
-- components, one file per Type under components/ (e.g. components/
-- mixer.lua). Loaded lazily and cached so a test that never calls
-- check_wiring never pays for it. An unregistered Type (no matching file)
-- returns nil, not an error -- see M.check_wiring below for what that means
-- for validation strictness. This is the same "extend the stub via Q-SYS
-- Help, don't guess" convention as the rest of this file, just organized as
-- one file per component instead of one big table, per the folder split
-- requested when this was added (2026-07-29).
local COMPONENT_DEFS = {}
local function component_pins(comp_type, props)
	if COMPONENT_DEFS[comp_type] == nil then
		local chunk = loadfile(STUB_DIR .. "/components/" .. comp_type .. ".lua")
		COMPONENT_DEFS[comp_type] = chunk and chunk() or false
	end
	local def = COMPONENT_DEFS[comp_type]
	return def and def(props) or nil
end

-- A single Q-SYS control. kind selects which properties actually exist,
-- checked against Q-SYS Help's Controls IO page (2026-07-29): a Trigger-type
-- Button has no .Value/.String/.Position/.Boolean at all, only :Trigger()
-- and .EventHandler -- omitted here entirely rather than defaulted to 0/"",
-- so a future plugin that mistakenly reads .Value on its own Trigger button
-- gets the same nil a missing field gives in real Lua, not a silently-passing
-- 0. A Meter-type Indicator uses a separate .Values (plural) array property
-- instead of .Value. Every other control type (Knob/Text/Toggle-or-Momentary
-- Button/non-Meter Indicator) shares the normal kind: .Value and .Boolean
-- are two accessors onto the SAME underlying numeric storage, not
-- independent fields -- confirmed via vendor/qsc-q-sys's Component.GetControls
-- docs: .Value is always a number, .Boolean is a computed true/false view of
-- it (reads as Value~=0, writes as Value=1/0). A metatable keeps the two in
-- sync so plugin code can read or write either one interchangeably, matching
-- real Q-SYS behavior.
function M.control(v, kind)
	kind = kind or "normal"

	if kind == "trigger" then
		local c = { EventHandler = nil }
		function c:Trigger() end
		return c
	end

	if kind == "meter" then
		return { Values = {}, EventHandler = nil }
	end

	if v == nil then v = 0 end
	local c = { String = "", Position = 0, Color = "",
	            Choices = {}, IsDisabled = false, EventHandler = nil }
	local numeric = v
	return setmetatable(c, {
		__index = function(_, k)
			if k == "Value" then return numeric end
			if k == "Boolean" then return numeric ~= 0 end
			return nil
		end,
		__newindex = function(t, k, val)
			if k == "Value" then numeric = val
			elseif k == "Boolean" then numeric = val and 1 or 0
			else rawset(t, k, val) end
		end,
	})
end

-- Globals the plugins define or expect; cleared between runs so one test
-- cannot see another's leftovers.
local PLUGIN_GLOBALS = {
	"PluginInfo", "Model", "QKnob", "CPSeries", "CPModels", "CPProtocol",
	"DKNob", "Print", "DolbyFaderEventHandler", "Class", "class",
	"GetColor", "GetPrettyName", "GetProperties", "RectifyProperties",
	"GetComponents", "GetControls", "GetControlLayout",
	-- GetPins/GetWiring/GetPages are optional (only Dolby Sweep and
	-- SubharmonicSynth declare them) -- omitted here until 2026-07-29,
	-- which meant a test loading two full distributables in one process
	-- (test_stress.lua does, for its runtime checks) could see one
	-- plugin's leftover GetPins/GetWiring still defined while testing a
	-- later plugin that declares neither. Harmless while nothing called
	-- them across that boundary, but the same latent gap PLUGIN_GLOBALS
	-- exists to close for every other definition-pass function.
	"GetPins", "GetWiring", "GetPages",
	-- Dolby Sweep's own globals (see CLAUDE.md's strict.lua wiring notes)
	"period", "timer",
	-- Dolby CPSeries Control's own globals
	"DolbyCP", "sock",
	-- CP Series Emulator's own globals (TcpSocketServer objects are kept
	-- global for the same GC-safety reason as Timer/TcpSocket, see
	-- qsys-plugin-development.md)
	"server", "SocketHandler",
}

function M.clear()
	for _, g in ipairs(PLUGIN_GLOBALS) do _G[g] = nil end
end

-- opts.controls         list of control names to create (plus opts.selectors toggles)
-- opts.trigger_controls list of control names to create as ButtonType="Trigger"
--                       (no .Value/.String/.Position/.Boolean, only :Trigger()
--                       and .EventHandler -- see M.control's own comment)
-- opts.selectors        how many `selector` buttons to create (0 = none)
-- opts.properties       Properties table to expose
-- opts.emulating        System.IsEmulating
-- opts.definition       true = definition pass (Controls nil, Reflect present)
--
-- Returns an env handle: .controls, .step, .timers, .socket(), .tick(n)
function M.install(opts)
	opts = opts or {}
	M.clear()

	if opts.definition then
		Reflect = { Types = { AudioIO = 0 } }
		Controls = nil
		Properties = opts.properties
		return { definition = true }
	end

	Reflect = nil

	local is_trigger = {}
	for _, name in ipairs(opts.trigger_controls or {}) do is_trigger[name] = true end

	local controls = {}
	for _, name in ipairs(opts.controls or {}) do
		controls[name] = M.control(nil, is_trigger[name] and "trigger" or nil)
	end
	controls.Selector = {}
	for i = 1, (opts.selectors or 0) do controls.Selector[i] = M.control(0) end
	Controls = controls

	Step = { value = M.control(0), increase = M.control(0), decrease = M.control(0) }

	local env = { controls = controls, step = Step, timers = {} }

	Timer = {
		New = function()
			local t = {}
			function t:Start() end
			function t:Stop() end
			env.timers[#env.timers + 1] = t
			return t
		end,
		-- Runs fn immediately (no fake clock here, same simplification as
		-- Timer objects needing env.tick() by hand) -- but unlike a bare
		-- pcall(fn), a real Q-SYS host doesn't silently eat an exception
		-- thrown inside a scheduled callback either, so this doesn't hide
		-- one from the test: any error inside fn propagates straight out
		-- of CallAfter, same as calling fn() directly would. The delay
		-- argument is accepted for signature compatibility but ignored.
		CallAfter = function(fn) fn() end,
	}

	local sock
	TcpSocket = {
		EOL = { Any = "any" },
		New = function()
			local s = { IsConnected = false, WriteTimeout = 0, writes = {}, lines = {} }
			function s:Connect(host, port) self.IsConnected = true self.host, self.port = host, port end
			function s:Disconnect() self.IsConnected = false end
			function s:Write(m) self.writes[#self.writes + 1] = (m:gsub("\r\n$", "")) end
			function s:ReadLine() return table.remove(self.lines, 1) end
			sock = s
			return s
		end,
		-- Only .Events.Data is ever compared against in this repo's Control
		-- Scripts (Dolby CP Emulator's SocketHandler(sock, event) guard);
		-- the real host defines more (Connected/Closed/Reconnect/Error/
		-- Timeout) but nothing here reads them yet -- extend on demand, same
		-- convention as the rest of this file.
		Events = { Data = "data" },
	}

	-- Listening side of TcpSocket -- used by Dolby CP Emulator/*.quc-style
	-- Control Scripts to fake a Dolby processor, not by any plugin (added
	-- 2026-07-31 for the CP Series Emulator's own test). Listen() just
	-- records the port, no real network; a test simulates an inbound
	-- connection by calling `server.EventHandler(a_fake_socket)` by hand,
	-- the same way env.receive() drives TcpSocket's own Data callback.
	TcpSocketServer = {
		New = function()
			local srv = { EventHandler = nil, port = nil }
			function srv:Listen(port) self.port = port end
			function srv:Close() self.port = nil end
			return srv
		end,
	}

	Properties = opts.properties
	System = { IsEmulating = opts.emulating or false }

	function env.socket() return sock end

	-- Fire every timer's handler n times. Nothing here is time-based, so one
	-- tick is one poll iteration.
	function env.tick(n)
		for _ = 1, (n or 1) do
			for _, t in ipairs(env.timers) do
				if t.EventHandler then pcall(t.EventHandler) end
			end
		end
	end

	-- Hand the plugin a line as if the processor had sent it.
	function env.receive(...)
		local s = env.socket()
		s.lines = { ... }
		s.Data()
	end

	return env
end

-- The control set the CP Series plugin declares (PascalCase since v4.0).
M.CPSERIES_CONTROLS = {
	"Start", "Ref", "Level", "Gain", "Increase", "Decrease", "Address",
	"Status", "Status.Led", "Refresh", "Select", "Mute",
}

-- The control set the Dolby Fader plugin declares (PascalCase since v2.0).
M.FADER_CONTROLS = { "Ref", "Level", "Gain", "Increase", "Decrease" }

function M.cpseries_properties(model, debug_on)
	return {
		Model = { Value = model },
		["TCP Log"] = { Value = "Command" },
		plugin_show_debug = { Value = debug_on and 1 or 0 },
	}
end

-- Structural validation for GetComponents/GetPins/GetWiring, the audio-path
-- half of a plugin's definition pass that nothing in this file modeled
-- until 2026-07-29. Belongs here, not in Developer/tests/harness.lua (test-
-- runner plumbing -- path resolution, the check counter, nothing about Q-SYS
-- itself): what this function encodes is real Q-SYS platform behavior, the
-- same category as the Trigger/Meter control-kind split and the .Value/
-- .Boolean split above, not a property of how the test suite is organized.
--
-- A wiring endpoint is either a plugin pin's own name (declared via
-- GetPins) or "<ComponentName> <PinName>" for a component GetComponents
-- declared. When that component's Type has a registered definition under
-- components/ (see component_pins above), the exact pin name is checked
-- against what that Type actually exposes for its own Properties -- so
-- "Mix Output 2" is caught as wrong for a 1-output mixer, not just accepted
-- because "Mix" exists. An unregistered Type falls back to only checking
-- that the component itself exists, the same permissive check this
-- function shipped with originally -- an unmodeled Type is a gap to fill
-- in components/, not a reason to fail every plugin that uses it.
--
-- A table literal with a typo'd or stale component/pin name still returns
-- successfully from all three functions on its own -- nothing here throws
-- without this check, which is exactly the gap it closes: a component
-- rename in GetComponents that GetWiring's own strings were never updated
-- to match used to compile fine and pass every test that existed before it.
--
-- Returns true, or raises with a descriptive message identifying exactly
-- which component/pin/wire is wrong; callers wrap this in pcall and report
-- through harness.lua's M.check the same way every other assertion-style
-- check in the suite does.
function M.check_wiring(comps, pins, wiring)
	local comp_names = {}
	local comp_pins = {} -- component Name -> set of "Name PinX" strings, or nil if Type is unregistered
	for _, c in ipairs(comps or {}) do
		assert(c.Name, "a GetComponents entry is missing Name")
		assert(c.Type, "component '" .. tostring(c.Name) .. "' is missing Type")
		comp_names[c.Name] = true
		local pin_list = component_pins(c.Type, c.Properties)
		if pin_list then
			local set = {}
			for _, p in ipairs(pin_list) do set[c.Name .. " " .. p] = true end
			comp_pins[c.Name] = set
		end
	end
	local pin_names = {}
	for _, p in ipairs(pins or {}) do
		assert(p.Name, "a GetPins entry is missing Name")
		assert(p.Direction == "input" or p.Direction == "output",
			"pin '" .. tostring(p.Name) .. "' has an invalid Direction (" .. tostring(p.Direction) .. ")")
		pin_names[p.Name] = true
	end
	local function resolves(endpoint)
		if pin_names[endpoint] then return true end
		local comp = endpoint:match("^(.-)%s")
		if comp == nil or not comp_names[comp] then return false end
		if comp_pins[comp] then return comp_pins[comp][endpoint] == true end
		return true
	end
	for _, w in ipairs(wiring or {}) do
		assert(type(w) == "table" and #w == 2,
			"a GetWiring entry is not a 2-element {source, dest} table")
		for _, endpoint in ipairs(w) do
			assert(resolves(endpoint),
				"wiring endpoint '" .. tostring(endpoint) ..
				"' does not resolve to a declared plugin pin or a valid component pin")
		end
	end
	return true
end

return M
