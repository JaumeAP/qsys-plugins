-- Shared plumbing for the test scripts: path resolution relative to this
-- file (so the suite runs from any working directory) and a check/report
-- counter. No external dependencies -- plain Lua 5.3, no busted, no luarocks.

local M = { failures = 0, checks = 0 }

local here = arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
M.tests_dir = here
M.repo = here .. "/../.."
M.plugins = M.repo .. "/Developer/plugins"

-- Distributables, by plugin. They are no longer committed: each one is the
-- source assembled by host-emulator/plugcc.lua into <repo>/build/ when this
-- module loads. Set QPLUG_DIR to a folder of real PLUGCC output (for example
-- a release download) to test those files instead.
local BUILD = {
	cpseries         = { dir = "Dolby CPSeries Control", file = "Dolby CPSeries Control V4.0.qplug" },
	fader            = { dir = "DolbyFader",             file = "DolbyFader.qplug" },
	sweep            = { dir = "Dolby Sweep",            file = "Dolby Sweep V2.0.qplug" },
	flipflop         = { dir = "MultiFlip-Flop",         file = "MultiFlip-Flop.qplug" },
	subharmonic      = { dir = "SubharmonicSynth",       file = "SubharmonicSynth.qplug" },
	cpseriesemulator = { dir = "CP Series Emulator",     file = "CP Series Emulator.qplug" },
	statetrigger     = { dir = "StateTrigger",           file = "StateTrigger.qplug" },
	dolbyknobtest    = { dir = "DolbyKnobTest",          file = "DolbyKnobTest.qplug" },
}
M.BUILD = BUILD

local out_dir = os.getenv("QPLUG_DIR")
if not out_dir then
	out_dir = M.repo .. "/build"
	os.execute('mkdir -p "' .. out_dir .. '"')
	local plugcc = dofile(M.repo .. "/Developer/host-emulator/plugcc.lua")
	for _, b in pairs(BUILD) do
		local f = assert(io.open(out_dir .. "/" .. b.file, "wb"))
		f:write(plugcc.assemble(M.plugins .. "/" .. b.dir .. "/plugin.lua"))
		f:close()
	end
end

M.DIST = {}
for key, b in pairs(BUILD) do M.DIST[key] = out_dir .. "/" .. b.file end

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
