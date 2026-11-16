-- Behavioural trace of a single-file plugin build, deliberately blind to how
-- the build is structured internally. It loads the file, lets it construct
-- its own socket, drives the poll loop, and prints every byte the plugin puts
-- on the wire plus the resulting control state.
--
-- The point is comparison. Two builds that print the same trace for the same
-- inputs behave the same, no matter how their internals are named or laid
-- out, so this is what to run against a reference build after a refactor:
--
--   lua wire_trace.lua "Dolby CPSeries Control V3.0.qplug" > a.txt
--   lua wire_trace.lua /path/to/reference.qplug            > b.txt
--   diff a.txt b.txt
--
-- With --no-formlist the format button is pressed before the processor has
-- reported its format list. That path used to publish a nil format name and
-- crash on the plugin's own assert; the trace records whether it still does.

-- Resolve the sibling modules whatever the working directory is.
local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST, with_formlist = h.DIST.cpseries, true
for i = 1, #arg do
	if arg[i] == "--no-formlist" then with_formlist = false else DIST = arg[i] end
end

local out = {}
local function emit(s) out[#out + 1] = s end

-- Per-model wire parameter names for the lines the trace feeds back in.
local RX = {
	["CP 650"]  = { ready = "fader_level=42",           fader = "fader_level=55",     mute = "mute=1" },
	["CP 750"]  = { ready = "cp750.sysinfo.version 1.0", fader = "cp750.sys.fader 55", mute = "cp750.sys.mute 1" },
	["CP 850"]  = { ready = "sys.fader 42",             fader = "sys.fader 55",       mute = "sys.mute 1" },
	["CP 950"]  = { ready = "sys.fader 42",             fader = "sys.fader 55",       mute = "sys.mute 1" },
	["CP 950A"] = { ready = "sys.fader 42",             fader = "sys.fader 55",       mute = "sys.mute 1" },
}

for _, model in ipairs(h.MODELS) do
	local env = qsys.install({
		controls = qsys.CPSERIES_CONTROLS,
		selectors = (model == "CP 750") and 7 or 8,
		properties = qsys.cpseries_properties(model),
		emulating = false,          -- force the real connect path
	})
	env.controls.Address.String = "10.0.0.5"

	assert(pcall(assert(loadfile(DIST))))
	local sock = env.socket()

	emit(("== %s =="):format(model))
	emit(("connect -> %s:%s"):format(tostring(sock.host), tostring(sock.port)))

	-- Bring the link up, then let one poll tick put the first query out.
	sock.writes = {}
	sock.Connected()
	env.tick(1)
	emit("first TX: " .. tostring(sock.writes[1]))

	-- The processor answers: readiness, then a fader and a mute report.
	local rx = RX[model]
	env.receive(rx.ready)
	env.receive(rx.fader)
	env.receive(rx.mute)
	emit(("after RX: dolby=%s gain=%s mute=%s"):format(
		tostring(DKNob and DKNob.Value), tostring(env.controls.Gain.Value),
		tostring(env.controls.Mute.Value)))

	-- The format list. Feeding it is the normal case; skipping it is the
	-- regression case, where the format name cannot be resolved.
	if with_formlist then
		if model == "CP 650" then
			env.receive("format_list=1,2,3")
		elseif model ~= "CP 750" then   -- CP 750 seeds its list locally at Start
			env.receive("sys.macros 3", "1:Flat", "2:Curve A", "3:Curve B")
		end
	end

	-- The operator moves the fader and picks a format.
	sock.writes = {}
	DKNob.Value = 4.0
	DKNob.EventHandler(DKNob)
	local ok, err = pcall(function()
		env.controls.Selector[2].Value = 1
		env.controls.Selector[2].EventHandler(env.controls.Selector[2])
	end)
	emit("format button: " .. (ok and "accepted" or ("CRASHED: " .. tostring(err):gsub("^.*:%d+: ", ""))))
	env.tick(12)

	local seen, uniq = {}, {}
	for _, w in ipairs(sock.writes) do seen[w] = true end
	for w in pairs(seen) do uniq[#uniq + 1] = w end
	table.sort(uniq)
	emit("TX after user input: " .. table.concat(uniq, " | "))
end

print(table.concat(out, "\n"))
