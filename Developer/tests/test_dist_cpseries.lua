-- The root CP Series distributable, exercised the way the Q-SYS host runs
-- it: a definition pass with Controls absent, then a runtime pass with
-- Controls present, which falls through the guard into the inlined modules.
--
-- The runtime pass is the point of this file. A module inlined before
-- something it depends on still compiles, so `luac -p` cannot see the
-- mistake; only running the file does.

-- Resolve the sibling modules whatever the working directory is.
package.path = (arg[0]:match("^(.*)[/\\]") or ".") .. "/?.lua;" .. package.path

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
end

for _, model in ipairs(h.MODELS) do
	h.section(model .. " runtime pass")
	local env = qsys.install({
		controls = qsys.CPSERIES_CONTROLS,
		selectors = (model == "CP 750") and 7 or 8,
		properties = qsys.cpseries_properties(model),
		emulating = true,          -- no address set, so take the emulation branch
	})

	local ok, err = pcall(assert(loadfile(DIST)))
	if h.check(ok, model .. ": runtime pass executes end to end (" .. tostring(err) .. ")") then
		h.check(type(CPSeries) == "table", model .. ": CPSeries class defined")
		h.check(DKNob ~= nil, model .. ": DKNob built, so qknob was inlined before dolbyfader")
		h.check(env.controls.start.Value == true, model .. ": one-time init ran")
		h.check(env.controls.selector[1].Value == 1, model .. ": init selected format 1")
		h.check(env.controls.status.Value == 0, model .. ": unset address in emulation reports status 0")
		h.check(math.abs(env.controls.gain.Value) < 1e-9,
			model .. ": the 7.0 reference level is 0 dB (got " .. tostring(env.controls.gain.Value) .. ")")
	end
end

h.report()
