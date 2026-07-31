-- The root CP Series Emulator distributable (the PLUGCC-built plugin --
-- there is no separate Control Script version any more, removed
-- 2026-07-31 once this plugin covered the same job with less to maintain,
-- see docs/continuity-notes.md). Definition pass: Model property (5
-- choices), Status/Status.Led controls, layout doesn't throw. Runtime
-- pass: server:Listen on the right port per model, Status reflects
-- connect/disconnect, one GET round trip per model confirms SocketHandler
-- actually answers (not just that it's reachable) -- checked against the
-- BUILT distributable (post-PLUGCC #include expansion of plugin.lua +
-- protocol.lua + runtime.lua), not just the Developer source it was built
-- from.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST = arg[1] or h.DIST.cpseriesemulator

local function props(modelValue)
	return {
		Model = { Value = modelValue },
		plugin_show_debug = { Value = 0 },
	}
end

h.section("definition pass")
qsys.install({ definition = true, properties = props("CP 750") })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "definition pass loads (" .. tostring(err) .. ")")
	h.check(GetPrettyName(props("CP 850")) == "CP Series Emulator (CP 850)",
		"GetPrettyName reflects the Model property")

	local p = GetProperties()
	local modelProp
	for _, entry in ipairs(p) do if entry.Name == "Model" then modelProp = entry end end
	h.check(modelProp ~= nil, "GetProperties declares a Model property")
	h.check(modelProp and #modelProp.Choices == 5, "Model offers all five processors (got " .. tostring(modelProp and #modelProp.Choices) .. ")")

	local rectified = RectifyProperties({ plugin_show_debug = { Value = 0, IsHidden = false } })
	h.check(rectified.plugin_show_debug.IsHidden == true, "RectifyProperties hides plugin_show_debug")

	local ctrls = GetControls(props("CP 850"))
	local names = {}
	for _, c in ipairs(ctrls) do names[c.Name] = true end
	h.check(names["Status"] and names["Status.Led"], "GetControls declares Status and Status.Led")

	local ok2, layout = pcall(GetControlLayout, props("CP 850"))
	h.check(ok2, "GetControlLayout does not throw (" .. tostring(layout) .. ")")
end

-- A fake client socket the test drives by hand -- same shape
-- test_modules.lua's own fake_sock() uses.
local function fake_client_sock()
	local s = { IsConnected = true, writes = {}, lines = {} }
	function s:Write(m) self.writes[#self.writes + 1] = (m:gsub("\r\n$", "")) end
	function s:ReadLine() if #self.lines == 0 then return nil end return table.remove(self.lines, 1) end
	return s
end

local EXPECT = {
	["CP 650"]  = { port = 61412, query = "fader_level=?", answer = "fader_level=20" },
	["CP 750"]  = { port = 61408, query = "cp750.sys.fader ?", answer = "cp750.sys.fader 20" },
	["CP 850"]  = { port = 61408, query = "sys.fader ?", answer = "sys.fader 20" },
	["CP 950"]  = { port = 61408, query = "sys.fader ?", answer = "sys.fader 20" },
	["CP 950A"] = { port = 61408, query = "sys.fader ?", answer = "sys.fader 20" },
}

for _, model in ipairs(h.MODELS) do
	h.section("runtime pass, Model=" .. model)
	local exp = EXPECT[model]

	local env = qsys.install({ controls = { "Status", "Status.Led" }, properties = props(model) })
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, model .. ": runtime pass executes end to end (" .. tostring(err) .. ")")

	h.check(server.port == exp.port, model .. ": listens on the documented port (got " .. tostring(server.port) .. ")")
	h.check(env.controls.Status.Value == 4, model .. ": Status starts at 4 (no client) before any connection")

	local client = fake_client_sock()
	server.EventHandler(client)
	h.check(env.controls.Status.Value == 0, model .. ": Status goes to 0 once a client connects")

	client.lines = { exp.query }
	client.EventHandler(client, TcpSocket.Events.Data)
	h.check(client.writes[1] == exp.answer or (model == "CP 650" and client.writes[2] == exp.answer),
		model .. ": a GET round-trips correctly (writes: " .. table.concat(client.writes, " | ") .. ")")

	client.Closed()
	h.check(env.controls.Status.Value == 4, model .. ": Status returns to 4 once the client disconnects")
end

h.report()
