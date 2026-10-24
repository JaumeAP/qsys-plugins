-- Live bridge: the Dolby CPSeries Control plugin logic against a real
-- processor simulator over a real TCP socket, with no Q-SYS Designer.
--
-- The plugin's CPSeries class (Developer/plugins/Dolby CPSeries Control/
-- {models,protocol,commlib}.lua) is driven through the host stub, the same
-- way test_modules.lua does, except that its socket is a luasocket adapter
-- connected to JaumeAP/CPSeries' processor_sim (cpp/processor_sim.cpp). Poll
-- ticks are stepped by hand, as everywhere in this suite. Proves, per model:
-- the readiness handshake, the seeded fader scaled to 0-10, a fader and a
-- mute SET landing in the processor's state with the right framing, and for
-- the CP650 the raw-echo fix over a real wire.
--
--   lua5.3 Developer/tests/live_bridge.lua [model ...]     default: all five
--   CPSIM_BIN=/path/to/processor_sim                       the simulator binary
--
-- Not part of run.sh: it needs the binary and luasocket. Exit 1 on a failure,
-- 77 (skipped) when either is missing.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local ok_socket, socket = pcall(require, "socket")
local BIN = os.getenv("CPSIM_BIN") or "/home/user/CPSeries/cpp/build/processor_sim"
local probe = io.open(BIN, "rb")
if not ok_socket or not probe then
	print("skipped: needs luasocket and the processor_sim binary (set CPSIM_BIN)")
	os.exit(77)
end
probe:close()

local h = require("harness")
local qsys = require("qsys_stub")

-- Per model: the simulator name, the plugin's wire names, and what to seed.
local MODELS = {
	["CP 650"]  = { sim = "CP650",  fader = "fader_level",     mute = "mute",         ready = "fader_level",
	                sep = "=", seed = { fader_level = 70, mute = 0, format_button = 1, format_list = "01, 04, 05, 10" } },
	["CP 750"]  = { sim = "CP750",  fader = "cp750.sys.fader", mute = "cp750.sys.mute", ready = "cp750.sysinfo.version",
	                sep = " ", seed = { ["cp750.sysinfo.version"] = "1.4.2", ["cp750.sys.fader"] = 70, ["cp750.sys.mute"] = 0, ["cp750.sys.input_mode"] = "analog" } },
	["CP 850"]  = { sim = "CP850",  fader = "sys.fader",       mute = "sys.mute",     ready = "sys.fader",
	                sep = " ", seed = { ["sys.fader"] = 70, ["sys.mute"] = 0, ["sys.macro_preset"] = 1, ["sys.macro_name"] = "Music", ["sys.macros"] = "1:Music" } },
	["CP 950"]  = { sim = "CP950",  fader = "sys.fader",       mute = "sys.mute",     ready = "sys.fader",
	                sep = " ", seed = { ["sys.fader"] = 70, ["sys.mute"] = 0, ["sys.macro_preset"] = 1, ["sys.macro_name"] = "Music", ["sys.macros"] = "1:Music" } },
	["CP 950A"] = { sim = "CP950A", fader = "sys.fader",       mute = "sys.mute",     ready = "sys.fader",
	                sep = " ", seed = { ["sys.fader"] = 70, ["sys.mute"] = 0, ["sys.macro_preset"] = 1, ["sys.macro_name"] = "Music", ["sys.macros"] = "1:Music" } },
}

-- Start the simulator on a free port; returns pid and port.
local function start_sim(spec)
	local seeds = {}
	-- Double quotes: the whole command already sits inside sh -c '...'.
	for k, v in pairs(spec.seed) do seeds[#seeds + 1] = ('--seed "%s=%s"'):format(k, v) end
	-- `timeout` bounds the simulator's whole life (and so the banner read
	-- below, which cannot itself time out on a pipe).
	local cmd = ("sh -c 'echo $$; exec timeout 300 %s --model %s --port 0 %s' 2>&1"):format(
		BIN, spec.sim, table.concat(seeds, " "))
	local pipe = assert(io.popen(cmd, "r"))
	local pid = pipe:read("*l")
	local banner = pipe:read("*l") or ""
	local port = tonumber(banner:match(":(%d+) "))
	assert(port, "simulator did not start: " .. banner)
	return pid, port, pipe
end

-- The plugin's socket, backed by a real TCP connection. Lines are buffered
-- here; `Data` is the callback commlib installs, called when lines arrived.
local function real_socket(port)
	local conn = assert(socket.tcp())
	conn:settimeout(5)
	assert(conn:connect("127.0.0.1", port))
	conn:settimeout(0)
	local s = { IsConnected = true, buffer = "", lines = {}, writes = {} }
	function s:Write(m)
		self.writes[#self.writes + 1] = (m:gsub("\r\n$", ""))
		print(">> " .. self.writes[#self.writes])
		conn:send(m)
	end
	function s:ReadLine() return table.remove(self.lines, 1) end
	-- The plugin closes the link itself when its watchdog trips; after that
	-- there is nothing to select on (luasocket blocks on a closed socket).
	function s:Disconnect()
		if self.IsConnected then self.IsConnected = false conn:close() end
		self.closed = true
	end
	-- Pull whatever the processor has sent and hand it to the plugin.
	function s:pump(wait)
		io.stdout:setvbuf("line")
		if self.closed or not self.IsConnected then return end
		if not socket.select({ conn }, nil, wait) then return end
		local data, err, partial = conn:receive(65536)
		data = data or partial
		if data and #data > 0 then
			self.buffer = self.buffer .. data
			for line in self.buffer:gmatch("([^\r\n]*)\r?\n") do
				self.lines[#self.lines + 1] = line
				print("<< " .. line)
			end
			self.buffer = self.buffer:gsub("^.*\n", "")
			if self.Data then self.Data(self) end
		end
		if err == "closed" then self.IsConnected = false end
	end
	return s
end

-- Ask the processor directly, on a second connection, what it holds.
local function ask(port, line, model_sim)
	local conn = assert(socket.tcp())
	conn:settimeout(2)
	assert(conn:connect("127.0.0.1", port))
	conn:send(line .. "\n")
	local reply = conn:receive("*l")
	if model_sim == "CP650" then reply = conn:receive("*l") end    -- skip the raw echo
	conn:close()
	return reply
end

-- The whole run is bounded too: no single step may keep it going past this.
local DEADLINE = socket.gettime() + 240
local function check_deadline()
	if socket.gettime() > DEADLINE then error("live bridge: overall deadline exceeded") end
end

local wanted = {}
for i = 1, #arg do wanted[#wanted + 1] = arg[i] end
if #wanted == 0 then wanted = h.MODELS end

local function run_model(model, spec, sim)

	local env = qsys.install({ properties = qsys.cpseries_properties(model) })
	Model = {}
	for i, m in ipairs({ { key = "CP650", value = "CP 650" }, { key = "CP750", value = "CP 750" },
	                     { key = "CP850", value = "CP 850" }, { key = "CP950", value = "CP 950" },
	                     { key = "CP950A", value = "CP 950A" } }) do
		m.index = i
		Model[i] = m
		Model[m.key] = m
	end
	local dir = h.plugins .. "/Dolby CPSeries Control"
	assert(loadfile(dir .. "/models.lua"))()
	assert(loadfile(dir .. "/protocol.lua"))()
	assert(loadfile(dir .. "/commlib.lua"))()

	local port = sim.port
	local cp = CPSeries.New(model)
	local events = {}
	cp.EventHandler = function(service, result) events[#events + 1] = { service = service, result = result } end
	local sock = real_socket(port)
	cp:Start(sock)
	local timer = env.timers[#env.timers]

	-- Step the poll loop, listening to the processor between ticks.
	local function run_until(done, ticks)
		local t0 = socket.gettime()
		for i = 1, ticks or 400 do
			check_deadline()
			if done() then print(("   (%d ticks, %.2fs)"):format(i, socket.gettime() - t0)) return true end
			timer.EventHandler()
			sock:pump(0.01)
		end
		print(("   (%d ticks, %.2fs, gave up)"):format(ticks or 400, socket.gettime() - t0))
		return done()
	end
	local function saw(service)
		for _, e in ipairs(events) do if e.service == service then return e.result end end
		return nil
	end

	h.check(run_until(function() return saw("ready") ~= nil end), model .. ": readiness handshake completes over TCP")
	h.check(run_until(function() return saw("fader") ~= nil end), model .. ": the seeded fader arrives")
	h.check(saw("fader") == 7.0, model .. ": wire 70 is fader 7.0 (got " .. tostring(saw("fader")) .. ")")

	-- Step the poll loop until the processor holds `expected` for `param`
	-- (the CP650's command gap is longer, so a fixed tick count is not enough).
	local function until_held(param, expected)
		local query = param .. (spec.sep == "=" and "=?" or " ?")
		local wire
		for _ = 1, 60 do
			wire = ask(port, query, spec.sim)
			if wire == param .. spec.sep .. expected then break end
			run_until(function() return false end, 10)
		end
		return wire
	end

	cp:Action("fader", 5.5)
	local fader_wire = until_held(spec.fader, "55")
	h.check(fader_wire == spec.fader .. spec.sep .. "55",
		model .. ": a fader SET of 5.5 leaves 55 in the processor (got " .. tostring(fader_wire) .. ")")

	cp:Action("mute", 1)
	local mute_wire = until_held(spec.mute, "1")
	h.check(mute_wire == spec.mute .. spec.sep .. "1",
		model .. ": a mute SET leaves 1 in the processor (got " .. tostring(mute_wire) .. ")")

	cp:Stop()
	sock:Disconnect()
end

for _, model in ipairs(wanted) do
	local spec = assert(MODELS[model], "unknown model " .. model)
	h.section("live " .. model)
	local pid, port, pipe = start_sim(spec)
	-- Whatever happens in the run, the simulator is stopped before moving on
	-- (closing its pipe would otherwise wait for it to exit by itself).
	local ok, err = pcall(run_model, model, spec, { port = port })
	os.execute("kill -INT " .. pid .. " 2>/dev/null")
	pipe:close()
	h.check(ok, model .. ": run completed (" .. tostring(err) .. ")")
end

h.report()
