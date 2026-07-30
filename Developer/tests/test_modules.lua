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

h.section("command gap and watchdog")
do
	-- The two timing guarantees of the Dolby CP Cinema Control spec the poll
	-- loop has to honour: a minimum gap between sent commands (250ms on a
	-- CP650, 100ms elsewhere) and a 3s no-response watchdog. Measured in
	-- POLLTIME (0.02s) ticks, since that is what Poll actually counts.
	local TICK = 0.02

	-- Gap: answer every tick, so nothing but the gap can hold a send back,
	-- and take the tightest spacing between two consecutive writes.
	local function min_gap_ticks(model, reply)
		local cp, sock, _, timer = started(model)
		local last, smallest = nil, math.huge
		for t = 1, 200 do
			local before = #sock.writes
			timer.EventHandler()
			if #sock.writes > before then
				if last and t - last < smallest then smallest = t - last end
				last = t
			end
			sock.lines = { reply } sock.Data()
		end
		cp:Stop()
		return smallest
	end

	local gap650 = min_gap_ticks("CP 650", "fader_level=42")
	h.check(gap650 * TICK >= 0.25,
		"CP 650: at least 250ms between commands (got " .. string.format("%.2f", gap650 * TICK) .. "s)")
	local gap850 = min_gap_ticks("CP 850", "sys.fader 42")
	h.check(gap850 * TICK >= 0.10,
		"CP 850: at least 100ms between commands (got " .. string.format("%.2f", gap850 * TICK) .. "s)")
	h.check(gap650 > gap850, "the CP 650 gap is the wider of the two")

	-- Watchdog: stop answering and count the ticks to the close event. Not
	-- an exact-equality check -- the point is 3s, not 0.6s (the old value)
	-- and not never.
	do
		local cp, sock, _, timer = started("CP 850")
		sock.lines = { "sys.fader 42" } sock.Data()
		local closed_at
		cp.EventHandler = function(service) if service == "close" and not closed_at then closed_at = true end end
		local fired
		for t = 1, 400 do
			timer.EventHandler()
			if closed_at then fired = t break end
		end
		h.check(fired ~= nil, "silence eventually declares the connection closed")
		h.check(fired and fired * TICK >= 3.0 and fired * TICK < 3.5,
			"the watchdog fires at ~3s of silence (got " .. string.format("%.2f", (fired or 0) * TICK) .. "s)")
		cp:Stop()
	end
end

h.section("CP650 echo fix")
do
	-- CP650 echoes the raw command line before its real response
	-- ("Protocol Guarantees": expect RESPONSE, not echo). Its handshake
	-- query reuses the fader wire key ('fader_level'), so an unfiltered
	-- echo of that query structurally matches the fader/readiness pattern
	-- and used to flip readiness to true on the plugin's own echoed bytes,
	-- before the processor had said anything at all.
	local cp, sock, events, timer = started("CP 650")
	timer.EventHandler()
	local sent = sock.writes[1]
	h.check(sent == "fader_level=?", "CP 650: handshake query sent (got '" .. tostring(sent) .. "')")

	sock.lines = { sent }   -- the device echoing our own line back
	sock.Data()
	h.check(saw(events, "ready") == nil, "the raw echo alone must not fire readiness")

	sock.lines = { "fader_level=42" }   -- the real reply, after the echo
	sock.Data()
	h.check(saw(events, "ready") ~= nil, "the real reply after the echo fires readiness")

	cp:Stop()
end
do
	-- Only the FIRST identical line is treated as the echo; once consumed,
	-- a second occurrence of the same text is a genuine (if repetitive)
	-- reply and must be processed normally, not discarded again.
	local cp, sock, events, timer = started("CP 650")
	timer.EventHandler()
	local sent = sock.writes[1]

	sock.lines = { sent, sent }   -- echo, then a reply identical to the echo
	sock.Data()
	h.check(saw(events, "ready") ~= nil,
		"a second occurrence of the same line (post-echo) is treated as the real reply")
	cp:Stop()
end
do
	-- A device that never echoes at all (or whose echo is already drained
	-- by the time the poll fires) must still reach readiness normally --
	-- the echo filter only discards a match, it never blocks on one.
	local cp, sock, events, timer = started("CP 650")
	timer.EventHandler()

	sock.lines = { "fader_level=42" }   -- no echo, straight to the real reply
	sock.Data()
	h.check(saw(events, "ready") ~= nil, "readiness still fires with no echo at all")
	cp:Stop()
end
do
	-- Non-CP650 models never echo and must be completely unaffected by the
	-- echopending machinery. CP850 reuses 'sys.fader' for its readiness
	-- row too, so a line equal to the sent query is a structurally valid
	-- reply here (unlike the CP650 case above, this isn't a mechanical
	-- echo, just a coincidence of shared wire keys) -- with no echopending
	-- logic gated in for this model, it must be processed normally and
	-- fire readiness immediately, in contrast to CP650's suppression.
	local cp, sock, events, timer = started("CP 850")
	timer.EventHandler()
	local sent = sock.writes[1]
	h.check(sent == "sys.fader ?", "CP 850: handshake query sent (got '" .. tostring(sent) .. "')")

	sock.lines = { sent }
	sock.Data()
	h.check(saw(events, "ready") ~= nil,
		"CP 850: unlike CP650, a line equal to what was sent is processed normally, firing readiness")
	cp:Stop()
end

h.section("query timeout")
do
	-- A lost response is not a dead link. At QUERY_TIMEOUT (1.5s) the
	-- in-flight message is retransmitted once; the watchdog keeps counting
	-- underneath, so a link that really is dead still dies on schedule.
	local TICK = 0.02
	local cp, sock, _, timer = started("CP 850")
	timer.EventHandler()
	sock.lines = { "sys.fader 42" } sock.Data()   -- handshake answered, then silence

	local closed
	cp.EventHandler = function(service) if service == "close" and not closed then closed = true end end

	local sendTick, retryTick, closeTick
	for t = 1, 400 do
		local before = #sock.writes
		timer.EventHandler()
		if #sock.writes > before then
			if not sendTick then sendTick = t else retryTick = retryTick or t end
		end
		if closed then closeTick = t break end
	end

	h.check(retryTick ~= nil, "an unanswered message is retransmitted at all")
	h.check(retryTick and math.abs((retryTick - sendTick) * TICK - 1.5) < 0.05,
		"the retransmit lands ~1.5s after the send (got " ..
		string.format("%.2f", ((retryTick or 0) - (sendTick or 0)) * TICK) .. "s)")
	local n = #sock.writes
	h.check(n >= 2 and sock.writes[n] == sock.writes[n - 1],
		"the retransmit is byte-identical to the message it retries")
	h.check(n == 3, "exactly one retransmit, not a retry storm (got " .. (n - 2) .. ")")
	h.check(closeTick and closeTick * TICK >= 3.0 and closeTick * TICK < 3.5,
		"the watchdog still closes at ~3s despite the retry (got " ..
		string.format("%.2f", (closeTick or 0) * TICK) .. "s)")
	cp:Stop()
end
do
	-- The point of the retry, against a realistic request/response device:
	-- it answers whatever it receives, except that ONE response goes
	-- missing in transit. Without a retransmit there is no second request,
	-- so no second answer, and the watchdog tears the link down; with one,
	-- the device is asked again and the link recovers. Driving the replies
	-- off the device's own Write side (rather than injecting them
	-- unprompted) is what makes this discriminating -- an unprompted
	-- injection would keep the link alive either way and prove nothing.
	local cp, sock, _, timer = started("CP 850")
	timer.EventHandler()
	sock.lines = { "sys.fader 42" } sock.Data()   -- handshake answered by hand

	-- Only now does the device start behaving as request/response, with the
	-- very next request's answer lost. Hooking Write before the handshake
	-- would spend the "lost" response on the handshake instead, and the
	-- test would pass with or without the fix.
	local dropped = false
	local realWrite = sock.Write
	sock.Write = function(s, m)
		realWrite(s, m)
		if not dropped then
			dropped = true       -- this one's response never arrives
		else
			s.lines = { "sys.fader 55" }   -- every later request is answered
		end
	end

	local closed
	cp.EventHandler = function(service) if service == "close" then closed = true end end
	for t = 1, 200 do
		timer.EventHandler()
		if #sock.lines > 0 then sock.Data() end
		if closed then break end
	end
	h.check(not closed,
		"a single lost response is recovered by the retransmit instead of killing the link")
	cp:Stop()
end

h.report()
