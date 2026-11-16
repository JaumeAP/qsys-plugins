-- A live variant of the Q-SYS host stub: real TCP (luasocket) and a real
-- clock, for driving a plugin's runtime.lua end to end against a real
-- listening peer (for example JaumeAP/CPSeries' processor_sim).
--
-- qsys_stub.lua stays the deterministic one (timers fire only when a test
-- ticks them, sockets are fakes). This module is opt-in and replaces just
-- `Timer` and `TcpSocket`, leaving Controls/Properties/System as the stub
-- built them:
--
--     local env  = qsys.install({ controls = ..., properties = ... })
--     local live = require("live_host").install(env)
--     ... load the plugin ...
--     live.run(10, function() return Controls.Status.Value == 0 end)
--
-- Behaviour modelled (TcpSocket, from the Q-SYS Lua docs as the plugins here
-- use them; the points marked ASSUMED were not confirmable from this
-- environment and follow ordinary TCP-client behaviour):
--   * Connect(host, port) is asynchronous. Success fires Connected; a refused
--     connection fires Error(sock, "Connection refused").
--   * ReconnectTimeout > 0: after an error or a close the socket reconnects
--     by itself after that many seconds and fires Reconnect first (ASSUMED
--     for the exact order of events).
--   * ReadTimeout > 0: that long without received data fires Timeout once,
--     the link stays open (ASSUMED: re-arms on the next data).
--   * The peer closing fires Closed. Disconnect() on our side does not
--     reconnect, and fires Closed (ASSUMED).
--   * Data fires `Data` and `EventHandler(sock, TcpSocket.Events.Data)`.
--   * ReadLine(TcpSocket.EOL.Any) returns one line without its terminator,
--     nil when none is buffered. Write(data) sends; a failed send fires Error.
-- Timer: Start(interval) repeats until Stop(); Timer.CallAfter(fn, delay)
-- runs fn once after `delay` seconds; Timer.Now() is the wall clock.
--
-- Everything is single-threaded: callbacks only run inside run()/step().

local socket = require("socket")

local M = {}

function M.install(env)
	local live = { timers = {}, sockets = {}, later = {} }

	local function now() return socket.gettime() end

	-- ---- Timer ----
	Timer = {
		New = function()
			local t = { running = false, interval = 0, due = 0 }
			function t:Start(interval)
				self.running, self.interval, self.due = true, interval or 1, now() + (interval or 1)
			end
			function t:Stop() self.running = false end
			function t:IsRunning() return self.running end
			live.timers[#live.timers + 1] = t
			env.timers[#env.timers + 1] = t         -- tests that tick by hand still find it
			return t
		end,
		CallAfter = function(fn, delay)
			live.later[#live.later + 1] = { due = now() + (delay or 0), fn = fn }
		end,
		Now = now,
	}

	-- ---- TcpSocket ----
	local Events = { Connected = "connected", Reconnect = "reconnect", Data = "data",
	                 Closed = "closed", Error = "error", Timeout = "timeout" }
	TcpSocket = {
		Events = Events,
		EOL = { Any = "any", CrLf = "crlf", Lf = "lf", Cr = "cr", Null = "null" },
	}

	local function fire(s, event, ...)
		local named = ({ [Events.Connected] = "Connected", [Events.Reconnect] = "Reconnect",
		                 [Events.Data] = "Data", [Events.Closed] = "Closed", [Events.Error] = "Error",
		                 [Events.Timeout] = "Timeout" })[event]
		if named and s[named] then s[named](s, ...) end
		if s.EventHandler then s.EventHandler(s, event, ...) end
	end

	local function drop_link(s)
		if s.conn then s.conn:close() s.conn = nil end
		s.IsConnected, s.connecting = false, false
	end

	local function schedule_reconnect(s)
		if s.manual_close or not s.ReconnectTimeout or s.ReconnectTimeout <= 0 or not s.host then return end
		s.reconnect_at = now() + s.ReconnectTimeout
	end

	local function open(s)
		s.conn = socket.tcp()
		s.conn:settimeout(0)
		local ok, err = s.conn:connect(s.host, s.port)
		if ok then
			s.connecting = true                    -- finished on the next poll, like a pending connect
		elseif err == "timeout" or err == "Operation already in progress" then
			s.connecting = true
		else
			drop_link(s)
			fire(s, Events.Error, err or "connect failed")
			schedule_reconnect(s)
		end
	end

	TcpSocket.New = function()
		local s = { IsConnected = false, ReadTimeout = 0, WriteTimeout = 0, ReconnectTimeout = 0,
		            buffer = "", lines = {}, connecting = false }
		function s:Connect(host, port)
			self.host, self.port, self.manual_close, self.reconnect_at = host, port, false, nil
			drop_link(self)
			open(self)
		end
		function s:Disconnect()
			local was = self.IsConnected
			self.manual_close, self.reconnect_at = true, nil
			drop_link(self)
			if was then fire(self, Events.Closed) end
		end
		function s:Write(data)
			if not self.IsConnected or not self.conn then return false end
			self.conn:settimeout(self.WriteTimeout > 0 and self.WriteTimeout or 2)
			local sent, err = self.conn:send(data)
			self.conn:settimeout(0)
			if not sent then
				drop_link(self)
				fire(self, Events.Error, err or "write failed")
				schedule_reconnect(self)
				return false
			end
			return true
		end
		function s:ReadLine()
			local i, j = self.buffer:find("\r?\n")
			if not i then i, j = self.buffer:find("\r") end
			if not i then return nil end
			local line = self.buffer:sub(1, i - 1)
			self.buffer = self.buffer:sub(j + 1)
			return line
		end
		live.sockets[#live.sockets + 1] = s
		return s
	end

	-- ---- the loop ----
	local function poll_socket(s)
		local t = now()
		if s.reconnect_at and t >= s.reconnect_at then
			s.reconnect_at = nil
			fire(s, Events.Reconnect)
			open(s)
		end
		if s.connecting and s.conn then
			local _, writable = socket.select(nil, { s.conn }, 0)
			if writable[1] then
				-- A refused connection also becomes "writable"; getpeername tells them apart.
				if s.conn:getpeername() then
					s.connecting, s.IsConnected, s.last_data = false, true, t
					fire(s, Events.Connected)
				else
					drop_link(s)
					fire(s, Events.Error, "Connection refused")
					schedule_reconnect(s)
				end
			end
		end
		if s.IsConnected and s.conn then
			local data, err, partial = s.conn:receive(65536)
			data = data or partial
			if data and #data > 0 then
				s.buffer = s.buffer .. data
				s.last_data = t
				fire(s, Events.Data)
			end
			if err == "closed" then
				drop_link(s)
				fire(s, Events.Closed)
				schedule_reconnect(s)
			elseif s.ReadTimeout and s.ReadTimeout > 0 and s.last_data and t - s.last_data > s.ReadTimeout then
				s.last_data = t                    -- fire once per silent period
				fire(s, Events.Timeout)
			end
		end
	end

	function live.step()
		local t = now()
		for _, s in ipairs(live.sockets) do poll_socket(s) end
		for i = #live.later, 1, -1 do
			local item = live.later[i]
			if t >= item.due then
				table.remove(live.later, i)
				item.fn()
			end
		end
		for _, tm in ipairs(live.timers) do
			if tm.running and t >= tm.due then
				tm.due = t + tm.interval
				if tm.EventHandler then tm.EventHandler(tm) end
			end
		end
	end

	-- Run for at most `seconds`, returning true as soon as `done()` holds (or
	-- true at the end when no condition was given). Never waits longer.
	function live.run(seconds, done)
		local stop = now() + seconds
		while now() < stop do
			if done and done() then return true end
			live.step()
			socket.select(nil, nil, 0.005)
		end
		return done == nil or done() and true or false
	end

	return live
end

return M
