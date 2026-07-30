
   -- ##############################################################
   --			CPSeries Application
   -- ##############################################################

	do

		-- Objects
		-- CPSeries instance and TcpSocket: must stay global (never local),
		-- same GC rule as Timer -- both are captured as upvalues by closures
		-- already reachable from global Controls.*.EventHandler fields, so
		-- nothing here was actually leaking, but this keeps the convention
		-- uniform and removes any doubt.
		DolbyCP = CPSeries.New(Properties.Model.Value)

		DolbyFaderEventHandler = function(ctrl)
			if ctrl ~= DolbyCP then
				DolbyCP:Action("fader", DKNob.Value)
			end
		end

		-- sock wraps TcpSocket.New() via the shared SocketConn module
		-- (Developer/shared/socket.lua) -- construction, address
		-- validation, and Connect/Disconnect/IsConnected all go through
		-- it; event-handler wiring stays here since it's plugin-specific
		-- (SetStatus, DolbyCP). The raw TcpSocket is sock.Socket.
		sock = SocketConn.New(2)

		-- Custom functions

		local function SetStatus(state, msg)
			if Controls.Status.Value ~= state then
				Print(true, 'Set Status ' .. state)
				Controls.Status.Value = state
			end
			Controls["Status.Led"].Value = state
			if Controls.Status.Value == 0 then Controls["Status.Led"].Color = 'lightgreen'
			end
			if msg ~= nil then Controls.Status.String = string.sub(msg, 1, 30)
			else Controls.Status.String = '' end
		end

		local function connect()
			Controls.Refresh.IsDisabled = false
			if SocketConn.ValidateAddress(Controls.Address.String) then
				SetStatus(5, '')
				-- port comes from the CPModels config (adds CP950 / CP950A)
				local CPPort = CPModels.DefaultPort((Properties.Model.Value):gsub("%s", ""))
				sock:Connect(Controls.Address.String, CPPort)
			else
				if System.IsEmulating then
					SetStatus(0, "Emulation")
				else
					SetStatus(2, "Invalid Address")
				end
			end
		end

		-- recon=false is unreachable today (refreshCNX() is the only call
		-- site and always passes true) -- kept, not collapsed to a single
		-- branch, since a future explicit "Disconnect" control that should
		-- NOT auto-reconnect is a plausible caller of this exact case.
		local function disconnect(recon)
			DolbyCP:Stop()
			sock:Disconnect()
			if recon then SetStatus(5, 'Connect')
			else SetStatus(2, 'Offline') end
		end

		local function refreshCNX()
			disconnect(true)
			Controls.Refresh.IsDisabled = true
			Timer.CallAfter(connect, 1)
		end

		local function sockError(msg)
			if sock.Socket.IsConnected then
				sock:Disconnect()
				Print(true, 'SOCK', msg)
				Print(true, 'SOCK', "Closed")
				SetStatus(2, msg)
				DolbyCP:Stop()
				Timer.CallAfter(refreshCNX, 2)
			end
		end

		-- Event handlers

		sock.Socket.Connected = function()
			Print(true, 'SOCK', "Connected")
			DolbyCP:Start(sock.Socket)
		end

		sock.Socket.Closed = function()
			Print(true, 'SOCK', 'Closed')
			SetStatus(4, "Offline")
		end

		sock.Socket.Timeout = function()
			Print(true, 'SOCK', 'Timeout')
			SetStatus(2, "Timeout")
		end

		sock.Socket.Error = function(_, err)
			Print(true, 'SOCK', "Remote Server Error " .. err)
			SetStatus(2, err)
		end

		sock.Socket.Reconnect = function()
			Print(true, 'SOCK', "Reconnecting")
			SetStatus(5, "Attempt Reconnect")
		end

		Controls.Address.EventHandler = refreshCNX
		Controls.Refresh.EventHandler = refreshCNX

		DolbyCP.EventHandler = function(service, result)
			local action = {
				["close"] = function() local msg = 'unknown Dolby ' .. result sockError(msg) end,
				["ready"] = function() Print(true, 'found "Dolby ' .. result .. '"') SetStatus(0) end,
				["formlist"] = function() Controls.Select.Choices = result end,
				["formname"] = function() Controls.Select.String = result end,
				["mute"] = function() Controls.Mute.Boolean = (result ~= 0) end,
				["fader"] = function()
					DKNob.Value = result
					DKNob.EventHandler(DolbyCP)
				end,
				["format"] = function()
					local i = tonumber(result)
					-- bound-check: a format index outside the selector range is
					-- ignored rather than indexing a nil button (out-of-bounds crash)
					if not i or i < 1 or i > #Controls.Selector then return end
					Controls.Selector[i].Value = 1
					Controls.Selector[i].EventHandler(DolbyCP)
				end,
				["reset"] = function()
					local i = tonumber(result)
					if not i or i < 1 or i > #Controls.Selector then return end
					Controls.Selector[i].Value = 0
				end,
			}
			assert(service, "Plugin Event Error: service=nil")
			assert(result, "Plugin Event Error: result=nil")
			assert(action[service], "Plugin Event Error: service")
			action[service]()
		end

		Controls.Mute.EventHandler = function(ctrl)
			DolbyCP:Action("mute", Controls.Mute.Boolean)
		end

		Controls.Select.EventHandler = function(ctrl)
			DolbyCP:Action("formname", Controls.Select.String)
		end

		for numBtn, ctl in ipairs(Controls.Selector) do
			ctl.EventHandler = function(ctrl)
				if ctl.Boolean then
					for _, ctrl in ipairs(Controls.Selector) do
						if ctrl ~= ctl then ctrl.Value = 0 end
					end
					if ctrl ~= DolbyCP then DolbyCP:Action("format", numBtn) end
				else
					for _, ctl in ipairs(Controls.Selector) do
						if ctl.Boolean then return end
					end
					DolbyCP:Action("reset")
				end
			end
		end

		-- Init

		-- 'Start' has no declared ControlType (GetControls just says
		-- { Name = "Start" }), so .Boolean isn't confirmed safe on it --
		-- unlike DolbySweep/MultiFlip-Flop's own 'Start', which are both
		-- explicit ControlType="Button". .Value is always numeric
		-- regardless of ControlType (confirmed via vendor/qsc-q-sys's
		-- Component.GetControls docs), so this compares/assigns numerically
		-- rather than risking .Boolean on an unconfirmed control. Previously
		-- compared against the Lua literal `false`, which a number can never
		-- equal -- this block never ran, so the one-time init below never
		-- fired on first compile.
		if Controls.Start.Value == 0 then
			Controls.Start.Value = 1
			Controls.Address.String = "127.0.0.1"
			DKNob.Value = 7.0
			DKNob.EventHandler(DolbyCP)
			Controls.Mute.Boolean = false
			Controls.Selector[1].Value = 1
			Controls.Selector[1].EventHandler(DolbyCP)
		end

		refreshCNX()

	end
