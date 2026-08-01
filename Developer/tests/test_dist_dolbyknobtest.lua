-- The root DolbyKnobTest distributable -- scratch/test plugin, not
-- production. v1.0.0.3: a single native ControlType="Knob" control
-- (GainDb, ControlUnit="dB", -90..10), no QKnob/Text wrapper, no
-- shared/qknob.lua dependency, no runtime logic at all.

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
	local c = ctrls[1]
	h.check(c.Name == "GainDb", "control is named GainDb")
	h.check(c.ControlType == "Knob", "GainDb is a native Knob (got " .. tostring(c.ControlType) .. ")")
	h.check(c.ControlUnit == "dB", "GainDb.ControlUnit is dB (got " .. tostring(c.ControlUnit) .. ")")
	h.check(c.Min == -90, "GainDb.Min is -90 (got " .. tostring(c.Min) .. ")")
	h.check(c.Max == 10, "GainDb.Max is 10 (got " .. tostring(c.Max) .. ")")

	local layout, graphics = GetControlLayout({})
	h.check(layout.GainDb ~= nil, "layout declares GainDb")
	h.check(layout.GainDb.Style == "Knob", "GainDb layout style is Knob")
end

h.section("runtime pass (no runtime logic -- just confirms it loads with Controls present)")
qsys.install({ controls = { "GainDb" } })
local ok, err = pcall(assert(loadfile(DIST)))
h.check(ok, "runtime pass executes end to end (" .. tostring(err) .. ")")

h.report()
