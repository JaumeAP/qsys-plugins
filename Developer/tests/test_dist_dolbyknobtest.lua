-- The root DolbyKnobTest distributable -- scratch/test plugin, not
-- production. Confirms the QKnob mechanism (Text control wrapped as a
-- Knob, same class DolbyFader's own DKNob uses) works for a plain linear
-- dB scale: Gain (a real native Knob) and GainDb (the QKnob clone) stay
-- in sync in both directions, with no piecewise conversion needed.

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
	h.check(#ctrls == 2, "control count is 2 (Gain, GainDb) (got " .. #ctrls .. ")")
end

h.section("runtime pass")
local env = qsys.install({ controls = { "Gain", "GainDb" } })
local ok, err = pcall(assert(loadfile(DIST)))
h.check(ok, "runtime pass executes end to end (" .. tostring(err) .. ")")

h.section("init: GainDb mirrors Gain's starting value")
h.check(tonumber(env.controls.GainDb.Value) == 0, "GainDb starts at 0, matching Gain's default (got " .. tostring(env.controls.GainDb.Value) .. ")")

h.section("Gain -> GainDb")
env.controls.Gain.Value = 5
env.controls.Gain.EventHandler()
h.check(tonumber(env.controls.GainDb.Value) == 5, "setting Gain=5dB updates GainDb to 5 (got " .. tostring(env.controls.GainDb.Value) .. ")")

env.controls.Gain.Value = -37
env.controls.Gain.EventHandler()
h.check(tonumber(env.controls.GainDb.Value) == -37, "setting Gain=-37dB updates GainDb to -37 (got " .. tostring(env.controls.GainDb.Value) .. ")")

h.section("GainDb -> Gain (typed into the text control)")
env.controls.GainDb.String = "12"
env.controls.GainDb.EventHandler()
h.check(env.controls.Gain.Value == 12, "typing 12 into GainDb updates Gain to 12 (got " .. tostring(env.controls.Gain.Value) .. ")")

env.controls.GainDb.String = "-80"
env.controls.GainDb.EventHandler()
h.check(env.controls.Gain.Value == -80, "typing -80 into GainDb updates Gain to -80 (got " .. tostring(env.controls.Gain.Value) .. ")")

h.section("range clamping (-100..20, same as Gain's own Min/Max)")
env.controls.Gain.Value = 1000
env.controls.Gain.EventHandler()
h.check(tonumber(env.controls.GainDb.Value) == 20, "GainDb clamps to Max=20 for an out-of-range Gain (got " .. tostring(env.controls.GainDb.Value) .. ")")

env.controls.GainDb.String = "-99999"
env.controls.GainDb.EventHandler()
h.check(env.controls.Gain.Value == -100, "Gain clamps to Min=-100 for out-of-range text typed into GainDb (got " .. tostring(env.controls.Gain.Value) .. ")")

h.section("value storm: many dB values across and beyond the range never throw")
local threw, out_of_range = nil, 0
local values = { -1e9, -1000, -100, -50, 0, 19.9, 20, 21, 1000, 1e9 }
for i = 1, 200 do values[#values + 1] = -150 + math.random() * 300 end
for _, v in ipairs(values) do
	env.controls.Gain.Value = v
	local ok2, err2 = pcall(env.controls.Gain.EventHandler)
	if not ok2 then threw = err2 break end
	local gdb = tonumber(env.controls.GainDb.Value)
	if not (gdb and gdb >= -100 and gdb <= 20) then out_of_range = out_of_range + 1 end
end
h.check(threw == nil, #values .. " dB values across and beyond the range never throw (" .. tostring(threw) .. ")")
h.check(out_of_range == 0, "GainDb stays within -100..20 for every dB input (got " .. out_of_range .. " outside)")

h.report()
