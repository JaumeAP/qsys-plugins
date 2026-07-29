-- The root Dolby Sweep distributable: both host passes, then the one-time
-- init and one sweep-timer tick driven through the real control wiring.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST = arg[1] or h.DIST.sweep
local SWEEP_CONTROLS = { "Start", "Enable", "Trigger", "Mute", "Period", "Frequency", "Level" }

h.section("definition pass")
qsys.install({ definition = true })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "definition pass loads (" .. tostring(err) .. ")")
	h.check(GetPrettyName() == "Dolby Sweep Generator", "GetPrettyName")
	local by_name = {}
	for _, c in ipairs(GetControls()) do by_name[c.Name] = c end
	for _, n in ipairs(SWEEP_CONTROLS) do
		h.check(by_name[n] ~= nil, n .. " is declared")
	end

	local comps = GetComponents({})
	h.check(#comps == 1 and comps[1].Name == "Sine" and comps[1].Type == "sine",
		"GetComponents declares one 'Sine' component of Type sine")

	-- GetPins/GetWiring are dynamic on props.Type -- Mono/Stereo/Multi-channel
	-- each produce a different pin count, and each has to wire back to the
	-- same 'Sine' component GetComponents declared above.
	for _, case in ipairs({
		{ Type = "Mono", Count = 8, pins = 1 },
		{ Type = "Stereo", Count = 8, pins = 2 },
		{ Type = "Multi-channel", Count = 5, pins = 5 },
	}) do
		local p = { Type = { Value = case.Type }, Count = { Value = case.Count } }
		local pins = GetPins(p)
		h.check(#pins == case.pins, "GetPins for Type=" .. case.Type .. " declares " .. case.pins .. " pin(s) (got " .. #pins .. ")")
		local ok, err = pcall(h.check_wiring, comps, pins, GetWiring(p))
		h.check(ok, "GetWiring for Type=" .. case.Type .. " resolves against GetComponents/GetPins (" .. tostring(err) .. ")")
	end
end

h.section("runtime pass")
local env = qsys.install({
	controls = SWEEP_CONTROLS,
	trigger_controls = { "Trigger" },  -- ButtonType="Trigger" (see controls.lua)
	properties = { plugin_show_debug = { Value = 0 } },
})
-- The embedded 'Sine' component: only mute/level/frequency are touched.
Sine = { mute = qsys.control(0), level = qsys.control(0), frequency = qsys.control(0) }
System = { IsEmulating = true }
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "runtime pass executes end to end (" .. tostring(err) .. ")")
end

h.section("one-time init")
-- Regression: .Value is always numeric, never a Lua boolean (confirmed via
-- vendor/qsc-q-sys's Component.GetControls docs); comparing it against the
-- Lua literal false meant this block never ran.
h.check(env.controls.Start.Boolean == true, "Start latches to true")
h.check(env.controls.Level.Value == -40, "Level initializes to -40 dB (got " .. tostring(env.controls.Level.Value) .. ")")
h.check(env.controls.Period.Value == 4, "Period initializes to 4 (got " .. tostring(env.controls.Period.Value) .. ")")
h.check(env.controls.Frequency.Value == 20, "Frequency initializes to 20 Hz (got " .. tostring(env.controls.Frequency.Value) .. ")")
h.check(Sine.mute.Value == 1, "Sine starts muted (Enable defaults off)")

h.section("sweep timer")
env.tick(1)
h.check(env.controls.Frequency.Value == Sine.frequency.Value,
	"Frequency control mirrors Sine.frequency after a tick")
h.check(env.controls.Frequency.Value >= 10, "swept frequency is at or above the 10 Hz floor")

h.report()
