-- The root StateTrigger distributable. Inverse of MultiFlip-Flop: N
-- independent State_n/Out_n pairs (Channels property, 1-256, same
-- convention as MultiFlip-Flop's own InputCount / Gain's Multi-Channel),
-- each firing its own Out per State change, gated by the Detection
-- property (On/Off/Both, default Both = fires on either direction).

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST = arg[1] or h.DIST.statetrigger
local N = 3 -- Channels used for the runtime checks below

h.section("definition pass")
qsys.install({ definition = true })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "definition pass loads (" .. tostring(err) .. ")")
	h.check(GetPrettyName() == "State Trigger", "GetPrettyName")

	local ctrls = GetControls({ Channels = { Value = N } })
	h.check(#ctrls == N * 2, "control count for Channels=" .. N .. " is N*2 (got " .. #ctrls .. ")")

	local ok2, layout = pcall(GetControlLayout, { Channels = { Value = N } })
	h.check(ok2, "GetControlLayout does not throw (" .. tostring(layout) .. ")")
	if ok2 then
		h.check(layout["State_2"] ~= nil, "layout entry exists for a dynamic control (State_2)")
		h.check(layout["Out_2"] ~= nil, "layout entry exists for a dynamic control (Out_2)")
	end
end

local controls_list = {}
local trigger_controls = {}
for t = 1, N do
	table.insert(controls_list, "State_" .. t)
	table.insert(controls_list, "Out_" .. t)
	table.insert(trigger_controls, "Out_" .. t)
end

local function install(detection)
	return qsys.install({
		controls = controls_list,
		trigger_controls = trigger_controls,
		properties = { Channels = { Value = N }, Detection = { Value = detection } },
	})
end

h.section("runtime pass, Channels=" .. N .. ", Detection=Both (default)")
do
	local env = install("Both")
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "runtime pass executes end to end (" .. tostring(err) .. ")")

	local fired = {}
	for t = 1, N do
		fired[t] = 0
		env.controls["Out_" .. t].Trigger = function() fired[t] = fired[t] + 1 end
	end

	env.controls.State_2.Value = 1
	env.controls.State_2.EventHandler()
	h.check(fired[2] == 1, "Both: State_2 -> true fires Out_2 once (got " .. fired[2] .. ")")
	h.check(fired[1] == 0 and fired[3] == 0, "Both: State_2 does not fire Out_1/Out_3")

	env.controls.State_2.Value = 0
	env.controls.State_2.EventHandler()
	h.check(fired[2] == 2, "Both: State_2 -> false also fires Out_2 (got " .. fired[2] .. ")")
end

h.section("Detection=On (rising edge only)")
do
	local env = install("On")
	assert(loadfile(DIST))()

	local fired = 0
	env.controls.Out_1.Trigger = function() fired = fired + 1 end

	env.controls.State_1.Value = 1
	env.controls.State_1.EventHandler()
	h.check(fired == 1, "On: State_1 -> true fires Out_1 (got " .. fired .. ")")

	env.controls.State_1.Value = 0
	env.controls.State_1.EventHandler()
	h.check(fired == 1, "On: State_1 -> false does NOT fire Out_1 (got " .. fired .. ")")
end

h.section("Detection=Off (falling edge only)")
do
	local env = install("Off")
	assert(loadfile(DIST))()

	local fired = 0
	env.controls.Out_1.Trigger = function() fired = fired + 1 end

	env.controls.State_1.Value = 1
	env.controls.State_1.EventHandler()
	h.check(fired == 0, "Off: State_1 -> true does NOT fire Out_1 (got " .. fired .. ")")

	env.controls.State_1.Value = 0
	env.controls.State_1.EventHandler()
	h.check(fired == 1, "Off: State_1 -> false fires Out_1 (got " .. fired .. ")")
end

h.report()
