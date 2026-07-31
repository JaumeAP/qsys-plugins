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
	cpseries        = M.repo .. "/Dolby CPSeries Control V4.0.qplug",
	fader           = M.repo .. "/DolbyFader.qplug",
	sweep           = M.repo .. "/Dolby Sweep V2.0.qplug",
	flipflop        = M.repo .. "/MultiFlip-Flop.qplug",
	subharmonic     = M.repo .. "/SubharmonicSynth.qplug",
	cpseriesemulator = M.repo .. "/CP Series Emulator.qplug",
	statetrigger    = M.repo .. "/StateTrigger.qplug",
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
