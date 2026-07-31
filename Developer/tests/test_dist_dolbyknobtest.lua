-- The root DolbyKnobTest distributable -- scratch/test plugin, not
-- production. v1.0.0.3: a single native ControlType="Knob" control
-- (GainDb, ControlUnit="dB", -90..10) with no QKnob/Text wrapper and no
-- runtime.lua -- Min/Max clamping is handled by the Q-SYS host itself, not
-- by plugin logic, so there is nothing left to drive at runtime beyond
-- confirming the built distributable loads cleanly in both host passes.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST = arg[1] or h.DIST.dolbyknobtest

h.section("definition pass")
qsys.install({ definition = true })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "definition pass loads (" .. tostring(err) .. ")")
	h.check(GetPrettyName() == "DolbyKnob Test", "GetPrettyName")

	local ctrls = GetControls({})
	h.check(#ctrls == 1, "control count is 1 (GainDb) (got " .. #ctrls .. ")")

	local gainDb = ctrls[1]
	h.check(gainDb and gainDb.Name == "GainDb", "control Name is GainDb")
	h.check(gainDb and gainDb.ControlType == "Knob", "GainDb is a native Knob (got " .. tostring(gainDb and gainDb.ControlType) .. ")")
	h.check(gainDb and gainDb.ControlUnit == "dB", "GainDb ControlUnit is dB (got " .. tostring(gainDb and gainDb.ControlUnit) .. ")")
	h.check(gainDb and gainDb.Min == -90, "GainDb Min is -90 (got " .. tostring(gainDb and gainDb.Min) .. ")")
	h.check(gainDb and gainDb.Max == 10, "GainDb Max is 10 (got " .. tostring(gainDb and gainDb.Max) .. ")")
	h.check(gainDb and gainDb.UserPin == true, "GainDb is a user pin")
	h.check(gainDb and gainDb.PinStyle == "Both", "GainDb PinStyle is Both (got " .. tostring(gainDb and gainDb.PinStyle) .. ")")

	local ok2, layout = pcall(GetControlLayout, {})
	h.check(ok2, "GetControlLayout does not throw (" .. tostring(layout) .. ")")
	if ok2 then
		h.check(layout["GainDb"] ~= nil, "layout entry exists for GainDb")
	end
end

h.section("runtime pass")
qsys.install({ controls = { "GainDb" } })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "runtime pass loads with no throw (no runtime logic left to run) (" .. tostring(err) .. ")")
end

h.report()
