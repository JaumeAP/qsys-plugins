-- Both runtime.lua files, assembled from source with plugcc and run on the
-- deterministic stub: the lifecycle edges the built-distributable tests do
-- not pin. CP Series Emulator: the status follows the client count, and a
-- failed Listen is reported. Dolby CPSeries Control: polling stops on a
-- closed or errored link.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")
local plugcc = require("plugcc")

local function fake_client()
	local s = { IsConnected = true, writes = {}, lines = {} }
	function s:Write(m) self.writes[#self.writes + 1] = m end
	function s:ReadLine() return table.remove(self.lines, 1) end
	function s:Disconnect() self.IsConnected = false end
	return s
end

h.section("CP Series Emulator: status follows the client count")
do
	local env = qsys.install({ controls = { "Status", "Status.Led" },
		properties = { Model = { Value = "CP 850" }, plugin_show_debug = { Value = 0 } } })
	assert(pcall(plugcc.load(h.plugins .. "/CP Series Emulator/plugin.lua")))
	h.check(env.controls.Status.Value == 4, "starts listening with no client")
	local a, b = fake_client(), fake_client()
	server.EventHandler(a)
	server.EventHandler(b)
	h.check(env.controls.Status.Value == 0 and env.controls.Status.String == "2 clients connected",
		"two clients are counted (" .. env.controls.Status.String .. ")")
	a.Closed()
	h.check(env.controls.Status.Value == 0, "one client leaving keeps the status at connected")
	a.Closed()
	h.check(env.controls.Status.Value == 0, "a repeated Closed does not count twice")
	b.Timeout(b)
	h.check(env.controls.Status.Value == 4 and env.controls.Status.String:find("idle client dropped", 1, true),
		"the last client dropped for silence reports no client (" .. env.controls.Status.String .. ")")
	h.check(not b.IsConnected, "the silent client was disconnected")
	b.Closed()
	h.check(env.controls.Status.Value == 4, "Closed after the Timeout drop changes nothing")
end

h.section("CP Series Emulator: Listen failure is reported")
for _, how in ipairs({ "error", "false" }) do
	local env = qsys.install({ controls = { "Status", "Status.Led" },
		properties = { Model = { Value = "CP 850" }, plugin_show_debug = { Value = 0 } } })
	local New = TcpSocketServer.New
	TcpSocketServer.New = function()
		local srv = New()
		function srv:Listen() if how == "error" then error("address in use") end return false end
		return srv
	end
	assert(pcall(plugcc.load(h.plugins .. "/CP Series Emulator/plugin.lua")))
	h.check(env.controls.Status.Value == 2 and env.controls.Status.String:find("Listen failed", 1, true),
		"Listen via " .. how .. " shows a fault (" .. env.controls.Status.String .. ")")
end

h.section("Dolby CPSeries Control: polling stops on a dead link")
do
	local env = qsys.install({ controls = qsys.CPSERIES_CONTROLS, trigger_controls = { "Refresh" }, selectors = 8,
		properties = qsys.cpseries_properties("CP 850") })
	local stops = 0
	local Timer_New = Timer.New
	Timer.New = function()
		local t = Timer_New()
		t.Stop = function() stops = stops + 1 end
		return t
	end
	Controls.Address.String = "127.0.0.1"
	assert(pcall(plugcc.load(h.plugins .. "/Dolby CPSeries Control/plugin.lua")))
	local before = stops
	sock.Socket.Closed(sock.Socket)
	h.check(stops == before + 1, "Closed stops the poll timer")
	before = stops
	sock.Socket.Error(sock.Socket, "Connection refused")
	h.check(stops == before + 1, "Error stops the poll timer")
	h.check(Controls.Status.Value == 2, "Error shows a fault")
end

h.report()
