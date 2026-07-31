-- The root StateTrigger distributable. Inverse of MultiFlip-Flop: one
-- Boolean "State" input, one Trigger "Out" output, fires Out once per
-- State change in either direction. No properties, no shared includes.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST = arg[1] or h.DIST.statetrigger

h.section("definition pass")
qsys.install({ definition = true })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "definition pass loads (" .. tostring(err) .. ")")
	h.check(GetPrettyName() == "State Trigger", "GetPrettyName")

	local ctrls = GetControls({})
	h.check(#ctrls == 2, "control count is 2 (got " .. #ctrls .. ")")

	local ok2, layout = pcall(GetControlLayout, {})
	h.check(ok2, "GetControlLayout does not throw (" .. tostring(layout) .. ")")
	if ok2 then
		h.check(layout["State"] ~= nil, "layout entry exists for State")
		h.check(layout["Out"] ~= nil, "layout entry exists for Out")
	end
end

h.section("runtime pass")
local env = qsys.install({
	controls = { "State", "Out" },
	trigger_controls = { "Out" },
})

local ok, err = pcall(assert(loadfile(DIST)))
h.check(ok, "runtime pass executes end to end (" .. tostring(err) .. ")")

h.section("State change fires Out")
local fired = 0
env.controls.Out.Trigger = function() fired = fired + 1 end

env.controls.State.Value = 1
env.controls.State.EventHandler()
h.check(fired == 1, "State -> true fires Out once (got " .. fired .. ")")

env.controls.State.Value = 0
env.controls.State.EventHandler()
h.check(fired == 2, "State -> false also fires Out (got " .. fired .. ")")

h.report()
