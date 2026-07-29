-- The root CP Series distributable, exercised the way the Q-SYS host runs
-- it: a definition pass with Controls absent, then a runtime pass with
-- Controls present, which falls through the guard into the inlined modules.
--
-- The runtime pass is the point of this file. A module inlined before
-- something it depends on still compiles, so `luac -p` cannot see the
-- mistake; only running the file does.

-- Resolve the sibling modules whatever the working directory is.
local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST = arg[1] or h.DIST.cpseries

h.section("definition pass")
qsys.install({ definition = true })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "definition pass loads (" .. tostring(err) .. ")")
	h.check(type(GetControls) == "function", "GetControls is defined")
	h.check(#GetProperties()[1].Choices == 5, "five models offered")
	h.check(pcall(GetPrettyName, nil), "GetPrettyName(nil) does not throw")
	h.check(pcall(GetControls, nil), "GetControls(nil) does not throw")
	h.check(pcall(GetControlLayout, nil), "GetControlLayout(nil) does not throw")
	h.check(pcall(RectifyProperties, nil), "RectifyProperties(nil) does not throw")

	local hidden = { ["TCP Log"] = { IsHidden = false }, plugin_show_debug = { Value = 0 } }
	RectifyProperties(hidden)
	h.check(hidden["TCP Log"].IsHidden == true, "TCP Log is hidden when debug is off")

	local shown = { ["TCP Log"] = { IsHidden = true }, plugin_show_debug = { Value = 1 } }
	RectifyProperties(shown)
	h.check(shown["TCP Log"].IsHidden == false, "TCP Log is shown when debug is on")
end

h.section("per model definition")
for _, model in ipairs(h.MODELS) do
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

for _, model in ipairs(h.MODELS) do
	h.section(model .. " runtime pass")
	local env = qsys.install({
		controls = qsys.CPSERIES_CONTROLS,
		trigger_controls = { "Refresh" },  -- ButtonType="Trigger" (see controls.lua)
		selectors = (model == "CP 750") and 7 or 8,
		properties = qsys.cpseries_properties(model),
		emulating = true,          -- no address set, so take the emulation branch
	})

	local ok, err = pcall(assert(loadfile(DIST)))
	if h.check(ok, model .. ": runtime pass executes end to end (" .. tostring(err) .. ")") then
		h.check(type(CPSeries) == "table", model .. ": CPSeries class defined")
		h.check(DKNob ~= nil, model .. ": DKNob built, so qknob was inlined before dolbyfader")
		h.check(env.controls.Start.Value == 1, model .. ": one-time init ran")
		h.check(env.controls.Selector[1].Value == 1, model .. ": init selected format 1")
		h.check(env.controls.Status.Value == 0, model .. ": unset address in emulation reports status 0")
		h.check(math.abs(env.controls.Gain.Value) < 1e-9,
			model .. ": the 7.0 reference level is 0 dB (got " .. tostring(env.controls.Gain.Value) .. ")")
	end
end

h.report()
