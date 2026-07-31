-- Developer/cp-series-emulator/cp-series-emulator.lua, driven against the
-- REAL CPSeries/CPModels/CPProtocol classes from Developer/plugins/
-- Dolby CPSeries Control/{models,protocol,commlib}.lua -- not a
-- reimplementation's own idea of what the wire protocol looks like, the
-- actual plugin code that ships. Proves the emulator's replies are ones the
-- real plugin parses into the right control values, for all five defined
-- models: connect (readiness handshake), the default state read back as a
-- genuine inbound update, a SET reaching the wire in the right format AND
-- actually persisting in the emulator's own state (checked from a second,
-- independent connection), format/macro select (both dialects), and the
-- two format-list shapes (CP650's CSV, the macro models' "n:name" burst).
--
-- Read side vs. write side are deliberately verified two different ways,
-- not because it's more thorough for its own sake but because CPSeries's
-- own setValue()/isEqual() logic makes the naive "call Action(), wait for
-- the same EventHandler to fire again" approach silently fail: a value the
-- CLIENT itself just set is applied locally without firing the handler
-- (isevent=true skips it), and the device's own confirmation of that exact
-- value is then swallowed too, by the isEqual() short-circuit in
-- received() -- np event ever fires for a round trip that both sides
-- agree on, which is correct client behaviour, not a bug in it or in the
-- emulator. So: reads are verified by letting the natural poll rotation
-- surface the emulator's own default state as a genuine mismatch against
-- the client's zero-initialized cache (which DOES fire); writes are
-- verified by checking the wire bytes the client actually sent (same
-- technique Developer/tests/test_modules.lua's own "boolean mute" section
-- uses) and, separately, by opening a second connection to the SAME live
-- emulator instance and reading the value back to confirm it was really
-- stored, not just echoed.
--
-- The emulator hardcodes `local MODEL = 'CP750'` at its top (Designer's own
-- convention here is one Control Script instance per model, same as the
-- three existing Dolby CP Emulator/*.quc files) -- this test substitutes
-- that one line per model before loading, the same file byte-for-byte
-- otherwise.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local env = qsys.install({ properties = qsys.cpseries_properties("CP 850") })

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

-- Load the real plugin protocol classes once, same order plugin.lua does.
do
	local dir = h.plugins .. "/Dolby CPSeries Control"
	assert(loadfile(dir .. "/models.lua"))()
	assert(loadfile(dir .. "/protocol.lua"))()
	assert(loadfile(dir .. "/commlib.lua"))()
end

local EMULATOR_SRC
do
	local emu_path = test_dir .. "/../cp-series-emulator/cp-series-emulator.lua"
	local f = assert(io.open(emu_path, "r"))
	EMULATOR_SRC = f:read("a")
	f:close()
end

-- A fake TCP client socket the test drives by hand, mirroring the shape
-- test_modules.lua's own fake_sock() uses for the plugin side -- here it is
-- the CLIENT half of a connection the emulator's server side writes to.
local function fake_client_sock()
	local s = { IsConnected = true, writes = {}, lines = {} }
	function s:Write(m) self.writes[#self.writes + 1] = (m:gsub("\r\n$", "")) end
	function s:ReadLine() if #self.lines == 0 then return nil end return table.remove(self.lines, 1) end
	return s
end

-- Load a fresh emulator instance for `model` (CP650/CP750/CP850/CP950/
-- CP950A). `server`/`SocketHandler` are the emulator's own globals (see
-- PLUGIN_GLOBALS in qsys_stub.lua) -- qsys.install() already cleared any
-- previous instance's leftovers before this runs. Returns the live
-- `server` object too, so a test can open a SECOND independent connection
-- to the same running instance later (to check persisted state).
local function start_emulator(model)
	local src = EMULATOR_SRC:gsub("local MODEL = 'CP750'", "local MODEL = '" .. model .. "'")
	assert(load(src, "cp-series-emulator[" .. model .. "]"))()
	return server, server.port
end

-- Connect a fake client socket to a live emulator `srv` and return it.
local function connect(srv)
	local client = fake_client_sock()
	srv.EventHandler(client)
	return client
end

-- Bring a real CPSeries client instance up against a fake socket fed BY the
-- emulator -- i.e. wire the plugin's own client class to the emulator's
-- server class in-process, no real TCP involved on either side.
local function started_client_against_emulator(model)
	local srv, port = start_emulator(model)
	local emuClient = connect(srv)
	local cp = CPSeries.New(Model[model].value)
	local events = {}
	cp.EventHandler = function(service, result) events[#events + 1] = { service = service, result = result } end

	-- The CPSeries client's own socket: every Write() the client makes is
	-- fed straight to the emulator's SocketHandler, and every write the
	-- emulator makes back is queued for delivery on the NEXT tick (see
	-- `tick()` below) -- delivering it synchronously, within the very same
	-- Poll() call that sent the request, would let received()'s "waiting =
	-- 0" reset land BEFORE Poll()'s own unconditional trailing "waiting =
	-- waiting + 1", which then immediately reincrements it back to 1 and
	-- eventually trips the watchdog. A real link never resolves a request
	-- and its response inside one poll tick either -- this just keeps the
	-- test's timing honest instead of artificially collapsing it.
	local clientSock = { IsConnected = true, writes = {}, lines = {} }
	function clientSock:Write(m)
		local line = (m:gsub("\r\n$", ""))
		self.writes[#self.writes + 1] = line
		emuClient.lines = { line }
		emuClient.EventHandler(emuClient, TcpSocket.Events.Data)
		while #emuClient.writes > 0 do
			self.lines[#self.lines + 1] = table.remove(emuClient.writes, 1)
		end
	end
	function clientSock:ReadLine() return table.remove(self.lines, 1) end

	cp:Start(clientSock)
	local timer = env.timers[#env.timers]
	return cp, clientSock, events, timer, srv
end

-- Advance one poll tick: deliver anything the emulator answered on the
-- PREVIOUS tick first, then let the timer fire (which may send a new
-- request and queue its answer for the tick after this one).
local function tick(clientSock, timer)
	if #clientSock.lines > 0 then clientSock.Data() end
	timer.EventHandler()
end

local function saw(events, service)
	for _, e in ipairs(events) do if e.service == service then return e.result end end
	return nil
end

-- Tick up to maxTicks (default 200) waiting for `service` to appear in
-- events; returns its value or nil if it never showed up.
local function poll_until(sock, timer, events, service, maxTicks)
	for _ = 1, (maxTicks or 200) do
		tick(sock, timer)
		local v = saw(events, service)
		if v ~= nil then return v end
	end
	return nil
end

-- Query a live emulator `srv` directly over a brand-new connection (no
-- CPSeries client involved) and return its reply. Used to confirm a SET
-- made through one connection actually persisted in the emulator's own
-- state, not just that it echoed a plausible-looking reply back down the
-- same connection. The LAST line written, not the first: CP650 writes a
-- raw echo of the query before its real answer (see the emulator's own
-- "CP650 raw-echoes..." comment), so the first line on that model is the
-- echo, not the reply.
local function raw_query(srv, line)
	local client = connect(srv)
	client.lines = { line }
	client.EventHandler(client, TcpSocket.Events.Data)
	return client.writes[#client.writes]
end

h.section("port and readiness handshake, all five models")
for _, model in ipairs(h.MODELS) do
	local key = model:gsub("%s", "")
	local cp, sock, events, timer, srv = started_client_against_emulator(key)

	tick(sock, timer)  -- Start() queued the handshake query; the poll loop sends it, the emulator's reply lands on the tick after
	tick(sock, timer)
	h.check(#sock.writes >= 1, model .. ": the client sent its handshake query")
	h.check(saw(events, "ready") ~= nil, model .. ": readiness fires from the emulator's own reply")

	local expectedPort = ({ CP650 = 61412, CP750 = 61408, CP850 = 61408, CP950 = 61408, CP950A = 61408 })[key]
	h.check(srv.port == expectedPort, model .. ": listens on the documented port (got " .. tostring(srv.port) .. ")")

	cp:Stop()
end

h.section("fader: default state read back as a genuine inbound update")
for _, model in ipairs(h.MODELS) do
	local key = model:gsub("%s", "")
	local cp, sock, events, timer = started_client_against_emulator(key)
	tick(sock, timer)
	tick(sock, timer)

	local got = poll_until(sock, timer, events, "fader")
	h.check(got == 2.0, model .. ": the emulator's default fader (wire 20) reads back as 2.0 (got " .. tostring(got) .. ")")
	cp:Stop()
end

h.section("fader: a client SET reaches the wire and persists in the emulator")
for _, model in ipairs(h.MODELS) do
	local key = model:gsub("%s", "")
	local cp, sock, events, timer, srv = started_client_against_emulator(key)
	tick(sock, timer)
	tick(sock, timer)
	poll_until(sock, timer, events, "fader")  -- drain the default-state read first

	cp:Action("fader", 5.5)
	local sentAt
	for t = 1, 200 do
		tick(sock, timer)
		for _, w in ipairs(sock.writes) do
			if w:match("55$") and not w:match("%?$") then sentAt = w break end
		end
		if sentAt then break end
	end
	h.check(sentAt ~= nil, model .. ": the SET for 5.5 reached the wire as ...55 (writes: " .. table.concat(sock.writes, " | ") .. ")")

	local param = ({ CP650 = "fader_level", CP750 = "cp750.sys.fader", CP850 = "sys.fader", CP950 = "sys.fader", CP950A = "sys.fader" })[key]
	local sep = (key == "CP650") and "=" or " "
	local reply = raw_query(srv, param .. sep .. "?")
	h.check(reply == param .. sep .. "55", model .. ": a fresh connection reads the persisted value back (got " .. tostring(reply) .. ")")

	cp:Stop()
end

h.section("mute: default state read + a client SET persists")
for _, model in ipairs(h.MODELS) do
	local key = model:gsub("%s", "")
	local cp, sock, events, timer, srv = started_client_against_emulator(key)
	tick(sock, timer)
	tick(sock, timer)

	local got = poll_until(sock, timer, events, "mute")
	h.check(got == 1, model .. ": the emulator's default mute (1) reads back as a genuine update (got " .. tostring(got) .. ")")

	cp:Action("mute", false)
	for t = 1, 200 do
		tick(sock, timer)
		local found = false
		for _, w in ipairs(sock.writes) do if w:match("0$") and not w:match("%?$") then found = true end end
		if found then break end
	end

	local param = ({ CP650 = "mute", CP750 = "cp750.sys.mute", CP850 = "sys.mute", CP950 = "sys.mute", CP950A = "sys.mute" })[key]
	local sep = (key == "CP650") and "=" or " "
	local reply = raw_query(srv, param .. sep .. "?")
	h.check(reply == param .. sep .. "0", model .. ": a boolean unmute persists as 0 on a fresh connection (got " .. tostring(reply) .. ")")

	cp:Stop()
end

h.section("CP650: numeric format default read, SET persists, CSV format list")
do
	local cp, sock, events, timer, srv = started_client_against_emulator("CP650")
	tick(sock, timer)
	tick(sock, timer)

	-- Checked BEFORE any format SET: once the client's own formlist cache
	-- equals what the emulator keeps returning, isEqual() in received()
	-- suppresses the event on every later poll that sees the same
	-- unchanged list -- same reasoning as the fader/mute sections above,
	-- just for a table instead of a scalar. Reading it first, while the
	-- cache is still the zero-initialized {}, is what lets the event fire.
	local list = poll_until(sock, timer, events, "formlist")
	h.check(list and #list == 8 and list[1] == "Format 01",
		"CP650: the emulator's CSV format_list becomes an 8-entry {Format NN, ...} (got " .. tostring(list and #list) .. ")")

	local got = poll_until(sock, timer, events, "format")
	h.check(got == 1, "CP650: default format_button=0 reads back as index 1 (got " .. tostring(got) .. ")")

	cp:Action("format", 3)
	for _ = 1, 200 do tick(sock, timer) end
	local reply = raw_query(srv, "format_button=?")
	h.check(reply == "format_button=2", "CP650: selecting index 3 persists as wire token 2 (0-indexed, got " .. tostring(reply) .. ")")

	cp:Stop()
end

h.section("CP750: keyword format default read, SET persists (no formlist -- host builds it locally)")
do
	local cp, sock, events, timer, srv = started_client_against_emulator("CP750")
	tick(sock, timer)
	tick(sock, timer)
	h.check(saw(events, "ready") ~= nil, "CP750: readiness via cp750.sysinfo.version")

	local got = poll_until(sock, timer, events, "format")
	h.check(got == 5, "CP750: default 'analog' reads back as CP750-table index 5 (got " .. tostring(got) .. ")")

	cp:Action("format", 1)  -- CP750 table index 1 = 'dig_1'
	for _ = 1, 200 do tick(sock, timer) end
	local reply = raw_query(srv, "cp750.sys.input_mode ?")
	h.check(reply == "cp750.sys.input_mode dig_1", "CP750: selecting index 1 persists as the keyword 'dig_1' (got " .. tostring(reply) .. ")")

	cp:Stop()
end

h.section("macro models (CP850/CP950/CP950A): macro_preset default read, SET persists, macros burst")
for _, model in ipairs({ "CP850", "CP950", "CP950A" }) do
	local cp, sock, events, timer, srv = started_client_against_emulator(model)
	tick(sock, timer)
	tick(sock, timer)

	-- Checked BEFORE any format SET -- see the CP650 section above for why
	-- (isEqual() suppresses a later poll that finds the same, now-cached,
	-- unchanged list).
	local list = poll_until(sock, timer, events, "formlist")
	h.check(list and #list == 7, model .. ": the macro burst drains into a 7-entry format list (got " .. tostring(list and #list) .. ")")

	local got = poll_until(sock, timer, events, "format")
	h.check(got == 1, model .. ": default sys.macro_preset=1 reads back as index 1 (got " .. tostring(got) .. ")")

	cp:Action("format", 3)
	for _ = 1, 200 do tick(sock, timer) end
	local reply = raw_query(srv, "sys.macro_preset ?")
	h.check(reply == "sys.macro_preset 3", model .. ": selecting macro 3 persists (got " .. tostring(reply) .. ")")

	cp:Stop()
end

h.report()
