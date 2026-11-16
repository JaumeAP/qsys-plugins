-- Dolby CPSeries Control's runtime.lua, assembled from source and run on the
-- live host (real TCP, real clock) against JaumeAP/CPSeries' processor_sim:
-- the connection lifecycle the deterministic stub cannot reach. Status codes
-- are the plugin's own: 0 OK, 2 fault, 4 offline/missing, 5 connecting.
--
--   CPSIM_BIN=/path/to/processor_sim lua5.3 Developer/tests/test_runtime_live.lua [model]
--
-- Not part of run.sh (needs the binary and luasocket); exits 77 without them.
-- Every wait is bounded. Scenarios per model:
--   1. the processor is up before the plugin starts      -> reaches Status 0
--   2. the processor is stopped, then started again       -> falls away, recovers by itself
--   3. the processor goes silent (cable pulled), then back -> falls away, recovers
--   4. the processor is absent at start, appears later     -> reaches Status 0

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
local plugcc = require("plugcc")
io.stdout:setvbuf("line")

local PORT = { ["CP 650"] = 61412, ["CP 750"] = 61408, ["CP 850"] = 61408, ["CP 950"] = 61408, ["CP 950A"] = 61408 }
local SIM = { ["CP 650"] = "CP650", ["CP 750"] = "CP750", ["CP 850"] = "CP850", ["CP 950"] = "CP950", ["CP 950A"] = "CP950A" }
local SEED = {
	["CP 650"]  = { fader_level = 70, mute = 0, format_button = 1, format_list = "01, 04, 05, 10" },
	["CP 750"]  = { ["cp750.sysinfo.version"] = "1.4.2", ["cp750.sys.fader"] = 70, ["cp750.sys.mute"] = 0,
	                ["cp750.sys.input_mode"] = "analog" },
	["CP 850"]  = { ["sys.fader"] = 70, ["sys.mute"] = 0, ["sys.macro_preset"] = 1, ["sys.macro_name"] = "Music", ["sys.macros"] = "1:Music" },
}
SEED["CP 950"], SEED["CP 950A"] = SEED["CP 850"], SEED["CP 850"]

local S = os.getenv("TMPDIR") or "/tmp"
local DEADLINE = socket.gettime() + 280

-- A processor on its fixed port with a control FIFO on stdin.
local function start_sim(model)
	local fifo = ("%s/rt_live_%d.fifo"):format(S, math.random(1, 1e9))
	os.execute("rm -f " .. fifo .. "; mkfifo " .. fifo)
	local seeds = {}
	for k, v in pairs(SEED[model]) do seeds[#seeds + 1] = ('--seed "%s=%s"'):format(k, v) end
	local pipe = assert(io.popen(("sh -c 'exec 3<>%s; echo $$; exec timeout 200 %s --model %s --port %d --control %s <&3' 2>&1"):format(
		fifo, BIN, SIM[model], PORT[model], table.concat(seeds, " "))))
	local pid = pipe:read("*l")
	local banner = pipe:read("*l") or ""
	if not banner:match("listening") then pipe:close() os.execute("rm -f " .. fifo) return nil, banner end
	local ctl = assert(io.open(fifo, "w"))
	ctl:setvbuf("line")
	return { pid = pid, pipe = pipe, ctl = ctl, fifo = fifo }
end
local function stop_sim(sim)
	os.execute("kill -INT " .. sim.pid .. " 2>/dev/null")
	pcall(sim.ctl.close, sim.ctl)
	sim.pipe:close()
	os.execute("rm -f " .. sim.fifo)
end

local function run_model(model)
	h.section("runtime.lua live, " .. model)
	local selectors = (model == "CP 750") and 7 or 8
	local env = qsys.install({
		controls = qsys.CPSERIES_CONTROLS, trigger_controls = { "Refresh" }, selectors = selectors,
		properties = qsys.cpseries_properties(model),
	})
	local live = require("live_host").install(env)
	-- The plugin's Print override reads Properties.plugin_show_debug; quiet it.
	local chunk = plugcc.load(h.plugins .. "/Dolby CPSeries Control/plugin.lua")
	Controls.Address.String = "127.0.0.1"
	local sim = assert(start_sim(model))
	local ok, err = pcall(chunk)
	h.check(ok, model .. ": runtime pass executes (" .. tostring(err) .. ")")
	if not ok then stop_sim(sim) return end

	local function status() return Controls.Status.Value end
	local function until_status(pred, limit)
		return live.run(limit, function()
			if socket.gettime() > DEADLINE then error("overall deadline exceeded") end
			return pred(status())
		end)
	end

	-- 1. processor up before the plugin starts
	h.check(until_status(function(v) return v == 0 end, 12), model .. ": reaches Status 0 against a running processor")

	-- 2. processor stopped, then started again
	stop_sim(sim)
	h.check(until_status(function(v) return v ~= 0 end, 8), model .. ": leaves Status 0 when the processor stops")
	sim = assert(start_sim(model))
	h.check(until_status(function(v) return v == 0 end, 20), model .. ": recovers to Status 0 when the processor is back")

	-- 3. processor goes silent (cable pulled without a reset), then answers again
	sim.ctl:write("set silent 1\n")
	h.check(until_status(function(v) return v ~= 0 end, 10), model .. ": leaves Status 0 when the processor goes silent")
	sim.ctl:write("set silent 0\n")
	h.check(until_status(function(v) return v == 0 end, 20), model .. ": recovers to Status 0 when it answers again")
	stop_sim(sim)

	-- 4. absent at start: a fresh plugin instance, processor appears later
	local env2 = qsys.install({
		controls = qsys.CPSERIES_CONTROLS, trigger_controls = { "Refresh" }, selectors = selectors,
		properties = qsys.cpseries_properties(model),
	})
	live = require("live_host").install(env2)
	local chunk2 = plugcc.load(h.plugins .. "/Dolby CPSeries Control/plugin.lua")
	Controls.Address.String = "127.0.0.1"
	h.check(pcall(chunk2), model .. ": starts with no processor around")
	live.run(4)
	h.check(status() ~= 0, model .. ": stays off Status 0 with nothing to talk to (Status " .. tostring(status()) .. ")")
	sim = assert(start_sim(model))
	h.check(until_status(function(v) return v == 0 end, 25), model .. ": reaches Status 0 once the processor appears")
	stop_sim(sim)
end

local wanted = arg[1]
for _, model in ipairs(h.MODELS) do
	if not wanted or wanted == model then
		local ok, err = pcall(run_model, model)
		h.check(ok, model .. ": scenario ran without an error (" .. tostring(err) .. ")")
	end
end
h.report()
