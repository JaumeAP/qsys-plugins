-- CP Series Emulator protocol core, straight from Developer/plugins/
-- CP Series Emulator/protocol.lua (not the built distributable, which
-- test_dist_cpseriesemulator.lua covers). The file is a PLUGCC #include
-- chunk that closes over a `MODEL` local the plugin declares first, so the
-- test prepends that line. Covers what the generic handler adds: stateful
-- GET/SET of any param, CP750 range clipping, number normalization, both
-- CP650 query framings, and silence on an unknown GET.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local SOURCE = h.plugins .. "/CP Series Emulator/protocol.lua"

-- A fresh emulator for `model`; returns send(line) -> list of lines written.
local function emulator(model)
	qsys.install({ properties = { Model = { Value = model }, plugin_show_debug = { Value = 0 } } })
	SocketHandler = nil
	local f = assert(io.open(SOURCE))
	local src = f:read("a")
	f:close()
	assert(load("local MODEL = '" .. model .. "'\n" .. src, "@protocol.lua"))()
	local handler = SocketHandler
	return function(line)
		local sock = { IsConnected = true, writes = {}, lines = { line } }
		function sock:Write(m) self.writes[#self.writes + 1] = (m:gsub("\r\n$", "")) end
		function sock:ReadLine() return table.remove(self.lines, 1) end
		handler(sock, TcpSocket.Events.Data)
		return sock.writes
	end
end

h.section("CP750: generic params")
do
	local send = emulator("CP750")
	local w = send("sys.name MainScreen")
	h.check(w[1] == "sys.name MainScreen", "an unknown param SET is stored and confirmed (" .. tostring(w[1]) .. ")")
	h.check(send("sys.name ?")[1] == "sys.name MainScreen", "a later GET reads it back")
	h.check(#send("sys.never_set ?") == 0, "a GET for a param never set stays silent")
	h.check(send("sys.level 70.0")[1] == "sys.level 70", "a whole float is stored as an integer")
	h.check(send("sys.level 0.1")[1] == "sys.level 0.1", "a fraction keeps its shortest round-trip text")
	h.check(send("sys.id 0x1F")[1] == "sys.id 0x1F", "a hex-looking value stays text")
end

h.section("CP750: range clipping")
do
	local send = emulator("CP750")
	h.check(send("cp750.sys.master_level 200")[1] == "cp750.sys.master_level 96", "above the range clips to the maximum")
	h.check(send("cp750.sys.master_level -5")[1] == "cp750.sys.master_level 0", "below the range clips to the minimum")
	h.check(send("cp750.sys.master_level inf")[1] == "cp750.sys.master_level 96", "inf clips to the maximum")
	h.check(send("cp750.sys.master_level nan")[1] == "cp750.sys.master_level 96", "nan clips to the maximum")
	h.check(send("cp750.sys.ch_level_3 -100")[1] == "cp750.sys.ch_level_3 -96", "the ch_level_* family shares one range")
	h.check(send("cp750.sys.eq_2 99")[1] == "cp750.sys.eq_2 60", "the eq_* family shares one range")
	h.check(send("cp750.sys.mute 7")[1] == "cp750.sys.mute 1", "the fixed mute handler clips too")
	h.check(send("cp750.sys.master_level ?")[1] == "cp750.sys.master_level 96", "the clipped value is what a GET returns")
end

h.section("CP650: KEY=VALUE dialect")
do
	local send = emulator("CP650")
	local w = send("MASTER=100")
	h.check(w[1] == "MASTER=100" and w[2] == "MASTER=100", "a SET is echoed raw, then confirmed")
	w = send("MASTER=?")
	h.check(w[1] == "MASTER=?" and w[2] == "MASTER=100", "the verified 'KEY=?' query reads it back after the echo")
	w = send("MASTER?")
	h.check(w[2] == "MASTER=100", "the CPSeries toolkit's 'KEY?' query is accepted too")
	h.check(#send("NOPE=?") == 1, "an unknown query gets the echo and nothing else")
	w = send("fader_level?")
	h.check(w[2] == "fader_level=20", "'KEY?' reaches the fixed fader handler as well")
end

h.section("fixed handlers unchanged")
do
	local send = emulator("CP850")
	h.check(send("sys.fader ?")[1] == "sys.fader 20", "default fader")
	h.check(send("sys.fader 5.0")[1] == "sys.fader 5", "a SET is stored canonically")
	h.check(send("sys.macro_preset ?")[1] == "sys.macro_preset 1", "default macro preset")
end

h.report()
