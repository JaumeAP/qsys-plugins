-- Definition-side callbacks of the Developer plugin files. Q-SYS calls these
-- to build the component, and calls some of them with no props at all during
-- plugin registration, before any instance exists -- so they have to survive
-- a nil argument.

-- Resolve the sibling modules whatever the working directory is.
package.path = (arg[0]:match("^(.*)[/\\]") or ".") .. "/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local function load_definition(path)
	qsys.install({ definition = true })
	-- The definition pass returns nothing: the guard bails with a bare
	-- `return`, so the result is not something to assert on.
	assert(loadfile(path))()
end

h.section("CP Series: nil props")
load_definition(h.DEV.cpseries)
h.check(pcall(GetPrettyName, nil), "GetPrettyName(nil) does not throw")
h.check(pcall(GetControls, nil), "GetControls(nil) does not throw")
h.check(pcall(GetControlLayout, nil), "GetControlLayout(nil) does not throw")
h.check(pcall(RectifyProperties, nil), "RectifyProperties(nil) does not throw")

h.section("CP Series: per model")
local model_prop
for _, p in ipairs(GetProperties()) do if p.Name == "Model" then model_prop = p end end
h.check(model_prop and #model_prop.Choices == 5,
	"five models offered (got " .. tostring(model_prop and #model_prop.Choices) .. ")")

for _, model in ipairs(model_prop.Choices) do
	local props = { Model = { Value = model } }
	local expected = (model == "CP 750") and 7 or 8

	local ok, ctrls = pcall(GetControls, props)
	h.check(ok, model .. ": GetControls does not throw")
	local count
	for _, c in ipairs(ctrls) do if c.Name == "Selector" then count = c.Count end end
	h.check(count == expected, model .. ": " .. expected .. " selector buttons (got " .. tostring(count) .. ")")

	local ok2, layout = pcall(GetControlLayout, props)
	h.check(ok2, model .. ": GetControlLayout does not throw (" .. tostring(layout) .. ")")
	if ok2 then
		local laid = 0
		for k in pairs(layout) do if k:match("^Selector ") then laid = laid + 1 end end
		h.check(laid == expected, model .. ": " .. expected .. " selector entries laid out (got " .. laid .. ")")
	end
end

h.section("CP Series: RectifyProperties")
-- Regression: this used to read `not props.plugin_show_debug.Value`, which
-- never hid anything, because 0 is truthy in Lua.
local hidden = { ["TCP Log"] = { IsHidden = false }, plugin_show_debug = { Value = 0 } }
RectifyProperties(hidden)
h.check(hidden["TCP Log"].IsHidden == true, "TCP Log is hidden when debug is off")

local shown = { ["TCP Log"] = { IsHidden = true }, plugin_show_debug = { Value = 1 } }
RectifyProperties(shown)
h.check(shown["TCP Log"].IsHidden == false, "TCP Log is shown when debug is on")

h.section("Dolby Fader")
load_definition(h.DEV.fader)
h.check(GetPrettyName() == "Dolby Fader ", "GetPrettyName")
local by_name = {}
for _, c in ipairs(GetControls()) do by_name[c.Name] = c end
h.check(by_name.Level and by_name.Level.ControlType == "Text",
	"Level is a Text control, which QKnob requires")
h.check(by_name.Gain and by_name.Gain.Min == -100 and by_name.Gain.Max == 20,
	"Gain knob spans -100..20 dB")

h.report()
