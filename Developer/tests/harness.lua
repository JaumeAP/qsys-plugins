-- Shared plumbing for the test scripts: path resolution relative to this
-- file (so the suite runs from any working directory) and a check/report
-- counter. No external dependencies -- plain Lua 5.3, no busted, no luarocks.

local M = { failures = 0, checks = 0 }

local here = arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
M.tests_dir = here
M.repo = here .. "/../.."
M.plugins = M.repo .. "/Developer/plugins"

-- Root distributables, by plugin.
M.DIST = {
	cpseries     = M.repo .. "/Dolby CPSeries Control V4.0.qplug",
	fader        = M.repo .. "/DolbyFader.qplug",
	sweep        = M.repo .. "/Dolby Sweep V2.0.qplug",
	flipflop     = M.repo .. "/MultiFlip-Flop.qplug",
	subharmonic  = M.repo .. "/SubharmonicSynth.qplug",
}

M.MODELS = { "CP 650", "CP 750", "CP 850", "CP 950", "CP 950A" }

function M.check(cond, msg)
	M.checks = M.checks + 1
	if cond then
		print("ok   " .. msg)
	else
		M.failures = M.failures + 1
		print("FAIL " .. msg)
	end
	return cond and true or false
end

function M.section(name)
	print("-- " .. name)
end

-- Structural validation for GetComponents/GetPins/GetWiring, the one part of
-- a plugin's definition pass none of the test_dist_*.lua files checked
-- before this (2026-07-29) -- a table literal with a typo'd or stale
-- component/pin name still returns successfully from all three functions,
-- so nothing catches a rename in GetComponents that GetWiring's own strings
-- were never updated to match. Returns true, or raises with a descriptive
-- message identifying exactly which component/pin/wire is wrong; callers
-- wrap this in pcall and report through M.check the same way every other
-- assertion-style check in this suite does.
function M.check_wiring(comps, pins, wiring)
	local comp_names = {}
	for _, c in ipairs(comps or {}) do
		assert(c.Name, "a GetComponents entry is missing Name")
		assert(c.Type, "component '" .. tostring(c.Name) .. "' is missing Type")
		comp_names[c.Name] = true
	end
	local pin_names = {}
	for _, p in ipairs(pins or {}) do
		assert(p.Name, "a GetPins entry is missing Name")
		assert(p.Direction == "input" or p.Direction == "output",
			"pin '" .. tostring(p.Name) .. "' has an invalid Direction (" .. tostring(p.Direction) .. ")")
		pin_names[p.Name] = true
	end
	-- A wiring endpoint is either a plugin pin's own name (GetPins) or
	-- "<ComponentName> <PinName>" for a component GetComponents declared --
	-- Q-SYS's own convention (confirmed 2026-07-29 against a real GetWiring
	-- example: "main_mixer Input 1"/"main_mixer Output 1").
	local function resolves(endpoint)
		if pin_names[endpoint] then return true end
		local comp = endpoint:match("^(.-)%s")
		return comp ~= nil and comp_names[comp] == true
	end
	for _, w in ipairs(wiring or {}) do
		assert(type(w) == "table" and #w == 2,
			"a GetWiring entry is not a 2-element {source, dest} table")
		for _, endpoint in ipairs(w) do
			assert(resolves(endpoint),
				"wiring endpoint '" .. tostring(endpoint) ..
				"' does not resolve to a declared plugin pin or component pin")
		end
	end
	return true
end

function M.report()
	print("")
	if M.failures == 0 then
		print(("ALL OK (%d checks)"):format(M.checks))
		os.exit(0)
	end
	print(("%d FAILURE(S) of %d checks"):format(M.failures, M.checks))
	os.exit(1)
end

return M
