
   -- ##############################################################
   --			CP Series Emulator Application
   -- ##############################################################
   --
   -- Wires the protocol core (protocol.lua, #include'd directly by
   -- plugin.lua before this file -- see its own header comment for why)
   -- to this plugin's own Status controls and TcpSocketServer lifecycle.
   -- MODEL/PORT/SocketHandler are already defined by the time this file
   -- runs.

	do

		-- Objects
		-- Must stay global, never local (same GC-safety rule as Timer/
		-- TcpSocket -- see qsys-plugin-development.md).
		server = TcpSocketServer.New()

		-- Custom functions

		-- Status states match this repo's own convention (0=OK, 2=Fault,
		-- 4=Missing/no client, 5=Initializing -- same numbering the real
		-- CPSeries Control plugin's runtime.lua uses).
		local function SetStatus(state_code, msg)
			Controls.Status.Value = state_code
			Controls["Status.Led"].Value = state_code
			Controls.Status.String = msg or ''
		end

		-- Event handlers

		-- Clients currently connected: the status follows this count, so one
		-- client leaving does not report "no client" while others remain.
		local clients = 0

		local function ReportClients(note)
			if clients > 0 then
				SetStatus(0, clients == 1 and "Client connected" or clients .. " clients connected")
			else
				SetStatus(4, "Listening on " .. PORT[MODEL] .. (note or ", no client"))
			end
		end

		server.EventHandler = function(SocketInstance)
			-- Every wait bounded: a client silent for ReadTimeout is dropped
			-- (Dolby CPSeries Control polls every second, so a live one never
			-- is), and a write to a client that stopped reading gives up after
			-- WriteTimeout.
			SocketInstance.ReadTimeout = 10
			SocketInstance.WriteTimeout = 2
			local counted = true   -- leaving may be reported twice (Disconnect, then Closed)
			local function Leave(note)
				if not counted then return end
				counted = false
				clients = clients - 1
				ReportClients(note)
			end
			SocketInstance.Timeout = function(s)
				s:Disconnect()
				Leave(", idle client dropped")
			end
			SocketInstance.EventHandler = SocketHandler
			clients = clients + 1
			ReportClients()
			SocketInstance.Closed = function() Leave() end
		end

		-- Init

		SetStatus(5, "Starting")
		-- Listen can fail (port taken by another script or device): report it
		-- instead of claiming to listen. ASSUMED: a failure surfaces as a Lua
		-- error or a false return; the Q-SYS docs do not say which.
		local ok, err = pcall(server.Listen, server, PORT[MODEL])
		if ok and err ~= false then
			ReportClients()
		else
			SetStatus(2, "Listen failed on " .. PORT[MODEL])
		end

	end
