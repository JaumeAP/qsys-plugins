-- CPSeries class, driven directly from Developer/plugins/Dolby CPSeries
-- Control/{models,protocol,commlib}.lua -- no plugin.lua, no distributable.
-- Covers the protocol surface per model: the query framing Start() emits,
-- the readiness handshake, fader scaling, the two format-list dialects, and
-- the guards that keep bad wire data from crashing the class.

-- Resolve the sibling modules whatever the working directory is.
local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

-- install() clears the plugin globals, Model among them, so the table has to
-- be built after it rather than before.
local env = qsys.install({ properties = qsys.cpseries_properties("CP 850") })

-- Mirrors the Model table the .qplug defines; the modules expect it global.
Model = {}
for i, m in ipairs({
	{ key = "CP650",  value = "CP 650"  },
	{ key = "CP750",  value = "CP 750"  },
	{ key = "CP850",  value = "CP 850"  },
	{ key = "CP950",  value = "CP 950"  },
	{ key = "CP950A", value = "CP 950A" },
}) do
	m.index = i
	Model[i] = m
	Model[m.key] = m
end

-- These are plain #include'd files, not require()-based modules (see
-- CLAUDE.md's PLUGCC.exe restructuring notes): load them in the same order
-- plugin.lua does, since commlib.lua expects CPModels/CPProtocol already
-- defined as globals.
do
	local dir = h.plugins .. "/Dolby CPSeries Control"
	assert(loadfile(dir .. "/models.lua"))()
	assert(loadfile(dir .. "/protocol.lua"))()
	assert(loadfile(dir .. "/commlib.lua"))()
end

-- A socket the test feeds by hand, independent of the stub's own.
local function fake_sock()
	local s = { IsConnected = true, writes = {}, lines = {} }
	function s:Write(m) self.writes[#self.writes + 1] = (m:gsub("\r\n$", "")) end
	function s:ReadLine() if #self.lines == 0 then return nil end return table.remove(self.lines, 1) end
	return s
end

-- Wire parameter names differ per model; these are the ones the tests poke.
local PARAM = {
	["CP 650"]  = { fader = "fader_level",     sep = "=", query = "fader_level=?" },
	["CP 750"]  = { fader = "cp750.sys.fader", sep = " ", query = "cp750.sysinfo.version ?" },
	["CP 850"]  = { fader = "sys.fader",       sep = " ", query = "sys.fader ?" },
	["CP 950"]  = { fader = "sys.fader",       sep = " ", query = "sys.fader ?" },
	["CP 950A"] = { fader = "sys.fader",       sep = " ", query = "sys.fader ?" },
}

-- Bring a fresh instance up to the ready state and hand it back.
local function started(model)
	local cp = CPSeries.New(model)
	local events = {}
	cp.EventHandler = function(service, result) events[#events + 1] = { service = service, result = result } end
	local sock = fake_sock()
	local timers_before = #env.timers
	cp:Start(sock)
	-- the poll timer is the one created by CPSeries.New for this instance
	local timer = env.timers[#env.timers]
	return cp, sock, events, timer, timers_before
end

local function saw(events, service)
	for _, e in ipairs(events) do if e.service == service then return e.result end end
	return nil
end

for _, model in ipairs(h.MODELS) do
	h.section(model)
	local p = PARAM[model]
	local cp, sock, events, timer = started(model)

	-- Start() queues a query; the poll loop is what puts it on the wire.
	timer.EventHandler()
	h.check(#sock.writes == 1, model .. ": one message written per poll tick")
	h.check(sock.writes[1] == p.query,
		model .. ": query framing is '" .. p.query .. "' (got '" .. tostring(sock.writes[1]) .. "')")

	-- Readiness: the processor echoes the query row's own parameter.
	local ready_line = (model == "CP 650" and "fader_level=42")
		or (model == "CP 750" and "cp750.sysinfo.version 1.0")
		or "sys.fader 42"
	sock.lines = { ready_line }
	sock.Data()
	h.check(saw(events, "ready") ~= nil, model .. ": readiness handshake fires 'ready'")

	-- The fader is scaled by ten on the wire.
	events = {}
	cp.EventHandler = function(s, r) events[#events + 1] = { service = s, result = r } end
	sock.lines = { p.fader .. p.sep .. "55" }
	sock.Data()
	h.check(saw(events, "fader") == 5.5,
		model .. ": fader 55 on the wire is 5.5 (got " .. tostring(saw(events, "fader")) .. ")")

	-- Garbage in the value must be ignored, not propagated and not fatal.
	events = {}
	sock.lines = { p.fader .. p.sep .. "NaN" }
	local ok = pcall(sock.Data)
	h.check(ok, model .. ": a non-numeric fader value does not throw")
	h.check(saw(events, "fader") == nil, model .. ": a non-numeric fader value fires no event")

	cp:Stop()
end

h.section("format lists")
do
	-- CP650 reports its formats as a CSV of numbers.
	local cp, sock, events = started("CP 650")
	sock.lines = { "fader_level=42" } sock.Data()
	sock.lines = { "format_list=1,2,3" } sock.Data()
	local list = saw(events, "formlist")
	h.check(list and #list == 3 and list[1] == "Format 1",
		"CP 650: CSV format list becomes {Format 1, Format 2, Format 3}")
	cp:Stop()
end
do
	-- The macro models stream an 'n:name' line per macro after the header.
	local cp, sock, events = started("CP 850")
	sock.lines = { "sys.fader 42" } sock.Data()
	sock.lines = { "sys.macros 3", "1:Flat", "2:Curve A", "3:Curve B" } sock.Data()
	local list = saw(events, "formlist")
	h.check(list and #list == 3 and list[2] == "Curve A",
		"CP 850: macro list drains the n:name lines (got " .. tostring(list and #list) .. ")")
	cp:Stop()
end

h.section("guards")
do
	local cp, sock = started("CP 850")
	sock.lines = { "sys.fader 42" } sock.Data()

	sock.lines = { "sys.macro_preset 9999" }
	h.check(pcall(sock.Data), "a format index past the end of the list does not crash the parser")

	h.check(pcall(function() cp:Action("bogus", 1) end), "Action() on an unknown control is ignored")
	h.check(pcall(function() cp:Action("formlist", 5) end), "Action() writing the device-owned formlist is ignored")

	-- Regression: selecting a format before the list arrived used to resolve
	-- the name to nil and publish it, which the plugin's handler asserts on.
	local published = {}
	cp.EventHandler = function(s, r) published[#published + 1] = { service = s, result = r } end
	h.check(pcall(function() cp:Action("format", 2) end),
		"selecting a format before the list arrives does not throw")
	local bad = false
	for _, e in ipairs(published) do if e.result == nil then bad = true end end
	h.check(not bad, "no event is published with a nil result")

	cp:Stop()
end

h.section("format token bounds-check (CP 750)")
do
	-- CP750 resolves a wire format token by key lookup (CP750 array), unlike
	-- the macro models' numeric parsing already covered above. A garbage
	-- token used to be indexed straight into that lookup; getButtonNum's
	-- nil return is what the reset/format bounds-check in the v3.0 header
	-- comment refers to for this model.
	local cp, sock, events = started("CP 750")
	sock.lines = { "cp750.sysinfo.version 1.0" } sock.Data()

	events = {}
	cp.EventHandler = function(s, r) events[#events + 1] = { service = s, result = r } end
	sock.lines = { "cp750.sys.input_mode not_a_real_input" }
	local ok = pcall(sock.Data)
	h.check(ok, "CP 750: an unrecognized format token does not throw")
	h.check(saw(events, "format") == nil, "CP 750: an unrecognized format token fires no event")

	cp:Stop()
end

h.section("macro-list accumulator cap")
do
	local cp, sock, events = started("CP 850")
	sock.lines = { "sys.fader 42" } sock.Data()

	events = {}
	cp.EventHandler = function(s, r) events[#events + 1] = { service = s, result = r } end
	local lines = { "sys.macros 600" }
	for i = 1, 600 do lines[#lines + 1] = i .. ":Preset " .. i end
	sock.lines = lines
	local ok = pcall(sock.Data)
	h.check(ok, "CP 850: 600 macro-list lines do not throw")
	local list = saw(events, "formlist")
	h.check(list and #list == 512,
		"CP 850: macro-list accumulator caps at 512 entries (got " .. tostring(list and #list) .. ")")

	cp:Stop()
end

h.report()
