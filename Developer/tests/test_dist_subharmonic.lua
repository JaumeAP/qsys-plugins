-- The root SubharmonicSynth distributable: both host passes, then the
-- one-time init (unset Cutoff signals "never configured") and the bypass/
-- level event handlers driven through the real control wiring.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST = arg[1] or h.DIST.subharmonic
local CONTROLS = { "DryLevel", "SubLevel", "SubGain", "QFactor", "Cutoff", "Bypass" }

h.section("definition pass")
qsys.install({ definition = true })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "definition pass loads (" .. tostring(err) .. ")")
	h.check(GetPrettyName() == "SubharmonicSynth", "GetPrettyName")
	local by_name = {}
	for _, c in ipairs(GetControls()) do by_name[c.Name] = c end
	for _, n in ipairs(CONTROLS) do
		h.check(by_name[n] ~= nil, n .. " is declared")
	end

	local comps = GetComponents({})
	local comp_by_name = {}
	for _, c in ipairs(comps) do comp_by_name[c.Name] = c end
	for _, n in ipairs({ "Lpf", "Peq", "GainSub", "GainDry", "Mix" }) do
		h.check(comp_by_name[n] ~= nil, "GetComponents declares '" .. n .. "'")
	end
	h.check(comp_by_name.Lpf and comp_by_name.Lpf.Type == "filter_lowpass", "Lpf is Type filter_lowpass")
	h.check(comp_by_name.Peq and comp_by_name.Peq.Type == "equalizer_parametric", "Peq is Type equalizer_parametric")
	h.check(comp_by_name.Mix and comp_by_name.Mix.Type == "mixer"
		and comp_by_name.Mix.Properties["n_inputs"] == 2 and comp_by_name.Mix.Properties["n_outputs"] == 1,
		"Mix is a 2-input 1-output mixer")

	local pins = GetPins({})
	h.check(#pins == 2, "GetPins declares exactly Input/Output (got " .. #pins .. ")")

	local ok, err = pcall(h.check_wiring, comps, pins, GetWiring({}))
	h.check(ok, "GetWiring resolves against GetComponents/GetPins (" .. tostring(err) .. ")")
end

-- Build the embedded DSP components fresh, same ad hoc pattern Dolby
-- Sweep's own test uses for 'Sine' -- only the pins runtime.lua actually
-- touches, per this repo's own "extend the stub via Q-SYS Help, don't
-- guess" convention: these token names come straight from the plugin's
-- own code (confirmed real component types -- filter_lowpass,
-- equalizer_parametric, gain, mixer -- against Q-SYS Help), not invented.
local function embedded_components()
	Lpf = { frequency = qsys.control(0), slope = qsys.control(0), type = qsys.control(0) }
	Peq = { frequency_1 = qsys.control(0), gain_1 = qsys.control(0), q = qsys.control(0) }
	GainSub = { gain = qsys.control(0) }
	GainDry = { gain = qsys.control(0) }
	Mix = { ["input.1.output.1.gain"] = qsys.control(0), ["input.2.output.1.gain"] = qsys.control(0) }
end

h.section("runtime pass")
local env = qsys.install({
	controls = CONTROLS,
	properties = { plugin_show_debug = { Value = 0 } },
})
embedded_components()
local ok, err = pcall(assert(loadfile(DIST)))
h.check(ok, "runtime pass executes end to end (" .. tostring(err) .. ")")

h.section("one-time init (Cutoff unset signals a fresh instance)")
h.check(env.controls.SubGain.Value == 9, "SubGain initializes to 9 dB (got " .. tostring(env.controls.SubGain.Value) .. ")")
h.check(env.controls.QFactor.Value == 1.0, "QFactor initializes to 1.0 (got " .. tostring(env.controls.QFactor.Value) .. ")")
h.check(env.controls.Cutoff.Value == 80, "Cutoff initializes to 80 Hz (got " .. tostring(env.controls.Cutoff.Value) .. ")")
h.check(Lpf.frequency.Value == 80, "Lpf.frequency mirrors Cutoff after init")
h.check(Peq.frequency_1.Value == 40, "Peq.frequency_1 is Cutoff/2 (suboctave centre)")
h.check(Peq.gain_1.Value == 9, "Peq.gain_1 mirrors SubGain after init")
h.check(Peq.q.Value == 1.0, "Peq.q mirrors QFactor after init")

h.section("bypass")
env.controls.SubLevel.Value = -6
env.controls.SubLevel.EventHandler(env.controls.SubLevel)
h.check(GainSub.gain.Value == -6, "SubLevel drives GainSub.gain when not bypassed")

env.controls.Bypass.Value = 1
env.controls.Bypass.EventHandler()
h.check(GainSub.gain.Value == -100, "Bypass mutes GainSub.gain to -100 dB")
h.check(GainDry.gain.Value == 0, "Bypass sets GainDry.gain to unity (0 dB)")

env.controls.Bypass.Value = 0
env.controls.Bypass.EventHandler()
env.controls.SubLevel.EventHandler(env.controls.SubLevel)
h.check(GainSub.gain.Value == -6, "un-bypassing restores GainSub.gain from SubLevel")

h.section("cutoff re-tune (already-configured instance must not re-init)")
env.controls.Cutoff.Value = 60
env.controls.Cutoff.EventHandler()
h.check(Lpf.frequency.Value == 60, "Lpf.frequency follows a manual Cutoff change")
h.check(Peq.frequency_1.Value == 30, "Peq.frequency_1 follows Cutoff/2 after a manual change")
h.check(env.controls.SubGain.Value == 9, "SubGain is untouched by a Cutoff change (no re-init)")

h.report()
