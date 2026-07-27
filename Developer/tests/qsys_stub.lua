-- Minimal stand-in for the Q-SYS host globals, so plugin and module code can
-- be loaded and driven by a plain Lua interpreter instead of Q-SYS Designer.
-- Covers only what the plugins in this repo actually touch: Controls, an
-- embedded stepper component, Timer, TcpSocket, Properties and System.
--
-- Timers here never fire on their own -- there is no event loop. Tests drive
-- them by hand with env:tick(), which is what makes the poll loop testable a
-- step at a time.

local M = {}

-- A single Q-SYS control. Note the explicit nil check rather than `v or 0`:
-- `false or 0` yields 0, and the plugins guard their one-time init with
-- `Controls.start.Value == false`, which 0 does not satisfy.
function M.control(v)
	if v == nil then v = 0 end
	return { Value = v, String = "", Position = 0, Color = "",
	         Choices = {}, IsDisabled = false, EventHandler = nil }
end

-- Globals the plugins define or expect; cleared between runs so one test
-- cannot see another's leftovers.
local PLUGIN_GLOBALS = {
	"PluginInfo", "Model", "QKnob", "CPSeries", "CPModels", "CPProtocol",
	"DKNob", "Print", "DolbyFaderEventHandler", "Class", "class",
	"GetColor", "GetPrettyName", "GetProperties", "RectifyProperties",
	"GetComponents", "GetControls", "GetControlLayout",
}

function M.clear()
	for _, g in ipairs(PLUGIN_GLOBALS) do _G[g] = nil end
end

-- opts.controls   list of control names to create (plus opts.selectors toggles)
-- opts.selectors  how many `selector` buttons to create (0 = none)
-- opts.properties Properties table to expose
-- opts.emulating  System.IsEmulating
-- opts.definition true = definition pass (Controls nil, Reflect present)
--
-- Returns an env handle: .controls, .step, .timers, .socket(), .tick(n)
function M.install(opts)
	opts = opts or {}
	M.clear()

	if opts.definition then
		Reflect = { Types = { AudioIO = 0 } }
		Controls = nil
		Properties = opts.properties
		return { definition = true }
	end

	Reflect = nil

	local controls = {}
	for _, name in ipairs(opts.controls or {}) do
		-- `Start` latches the one-time init and is compared against `false`,
		-- so it must start as a boolean. Spelled out rather than written as
		-- `name == "Start" and false or nil`, which yields nil, not false.
		if name == "Start" then
			controls[name] = M.control(false)
		else
			controls[name] = M.control(nil)
		end
	end
	controls.Selector = {}
	for i = 1, (opts.selectors or 0) do controls.Selector[i] = M.control(0) end
	Controls = controls

	Step = { value = M.control(0), increase = M.control(0), decrease = M.control(0) }

	local env = { controls = controls, step = Step, timers = {} }

	Timer = {
		New = function()
			local t = {}
			function t:Start() end
			function t:Stop() end
			env.timers[#env.timers + 1] = t
			return t
		end,
		CallAfter = function(fn) pcall(fn) end,
	}

	local sock
	TcpSocket = {
		EOL = { Any = "any" },
		New = function()
			local s = { IsConnected = false, WriteTimeout = 0, writes = {}, lines = {} }
			function s:Connect(host, port) self.IsConnected = true self.host, self.port = host, port end
			function s:Disconnect() self.IsConnected = false end
			function s:Write(m) self.writes[#self.writes + 1] = (m:gsub("\r\n$", "")) end
			function s:ReadLine() return table.remove(self.lines, 1) end
			sock = s
			return s
		end,
	}

	Properties = opts.properties
	System = { IsEmulating = opts.emulating or false }

	function env.socket() return sock end

	-- Fire every timer's handler n times. Nothing here is time-based, so one
	-- tick is one poll iteration.
	function env.tick(n)
		for _ = 1, (n or 1) do
			for _, t in ipairs(env.timers) do
				if t.EventHandler then pcall(t.EventHandler) end
			end
		end
	end

	-- Hand the plugin a line as if the processor had sent it.
	function env.receive(...)
		local s = env.socket()
		s.lines = { ... }
		s.Data()
	end

	return env
end

-- The control set the CP Series plugin declares (PascalCase since v4.0).
M.CPSERIES_CONTROLS = {
	"Start", "Ref", "Level", "Gain", "Increase", "Decrease", "Address",
	"Status", "Status.Led", "Refresh", "Select", "Mute",
}

-- The control set the Dolby Fader plugin declares (PascalCase since v2.0).
M.FADER_CONTROLS = { "Ref", "Level", "Gain", "Increase", "Decrease" }

function M.cpseries_properties(model, debug_on)
	return {
		Model = { Value = model },
		["TCP Log"] = { Value = "Command" },
		plugin_show_debug = { Value = debug_on and 1 or 0 },
	}
end

return M
