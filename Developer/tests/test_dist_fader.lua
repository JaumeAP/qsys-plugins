-- The root Dolby Fader distributable: both host passes, then the dB to
-- Dolby-scale mapping driven through the real control wiring rather than by
-- calling the conversion helpers directly (they are local to the module).
--
-- The mapping has two segments, meeting at 4.0 on the Dolby scale:
--   Dolby <= 4  ->  dB = value * 20 - 90
--   Dolby >  4  ->  dB = (value - 7) * 10 / 3      (so 7.0 is the 0 dB reference)

-- Resolve the sibling modules whatever the working directory is.
package.path = (arg[0]:match("^(.*)[/\\]") or ".") .. "/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST = arg[1] or h.DIST.fader

h.section("definition pass")
qsys.install({ definition = true })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "definition pass loads (" .. tostring(err) .. ")")
	h.check(GetPrettyName() == "Dolby Fader ", "GetPrettyName")
	local by_name = {}
	for _, c in ipairs(GetControls()) do by_name[c.Name] = c end
	h.check(by_name.level and by_name.level.ControlType == "Text",
		"level is a Text control, which QKnob requires")
	h.check(by_name.gain and by_name.gain.Min == -100 and by_name.gain.Max == 20,
		"gain knob spans -100..20 dB")
end

h.section("runtime pass")
local env = qsys.install({
	controls = qsys.FADER_CONTROLS,
	properties = { plugin_show_debug = { Value = 0 } },
})
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "runtime pass executes end to end (" .. tostring(err) .. ")")
	h.check(DKNob ~= nil, "DKNob built, so qknob was inlined before dolbyfader")
end

h.section("dB to Dolby scale")
for _, case in ipairs({ { -90, 0.0 }, { -50, 2.0 }, { -10, 4.0 }, { 0, 7.0 }, { 10, 10.0 } }) do
	local db, dolby = case[1], case[2]
	env.controls.gain.Value = db
	env.controls.gain.EventHandler()
	h.check(math.abs(DKNob.Value - dolby) < 1e-6,
		("%d dB is Dolby %.1f (got %s)"):format(db, dolby, tostring(DKNob.Value)))
end

h.section("controls")
env.controls.gain.Value = -20
env.controls.gain.EventHandler()
env.controls.ref.Value = 1
env.controls.ref.EventHandler()
h.check(math.abs(DKNob.Value - 7.0) < 1e-6, "the ref button snaps the level to 7.0")
h.check(math.abs(env.controls.gain.Value) < 1e-9,
	"the reference level is 0 dB (got " .. tostring(env.controls.gain.Value) .. ")")

env.controls.increase.Value = 1
env.controls.increase.EventHandler()
h.check(env.step.increase.Value == 1, "increase drives the stepper")
env.controls.decrease.Value = 1
env.controls.decrease.EventHandler()
h.check(env.step.decrease.Value == 1, "decrease drives the stepper")

h.report()
