-- The host-side helpers themselves: qsys.set (EventHandler only on a real
-- change, as the Q-SYS host does) and the PLUGCC-style include assembler.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")
local plugcc = require("plugcc")

h.section("qsys.set fires the handler only on a change")
do
	local env = qsys.install({ controls = { "A" } })
	local fired = 0
	env.controls.A.EventHandler = function() fired = fired + 1 end
	h.check(qsys.set(env.controls.A, 1) == true and fired == 1, "0 -> 1 fires once")
	h.check(qsys.set(env.controls.A, 1) == false and fired == 1, "1 -> 1 does not fire")
	h.check(qsys.set(env.controls.A, 0) == true and fired == 2, "1 -> 0 fires again")
end

h.section("plugcc.assemble expands includes against the plugin directory")
do
	local dir = os.tmpname()
	os.remove(dir)
	os.execute("mkdir -p " .. dir .. "/sub")
	local function write(path, text) local f = assert(io.open(path, "w")) f:write(text) f:close() end
	write(dir .. "/plugin.lua", 'A = 1\n--[[ #include "a.lua" ]]\n--[[ #include "sub/b.lua" ]]\nreturn A + B + C\n')
	write(dir .. "/a.lua", 'B = 10\n')
	write(dir .. "/sub/b.lua", 'C = 100\n--[[ #include "a.lua" ]]\n')   -- nested, still relative to plugin.lua's dir
	local src = plugcc.assemble(dir .. "/plugin.lua")
	h.check(not src:find("#include"), "no directive is left in the assembled source")
	local ok, value = pcall(plugcc.load(dir .. "/plugin.lua"))
	h.check(ok and value == 111, "the assembled plugin runs (got " .. tostring(value) .. ")")
	h.check(not pcall(plugcc.assemble, dir .. "/missing.lua"), "a missing plugin file is an error")
	os.execute("rm -rf " .. dir)
end

h.report()
