
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

		server.EventHandler = function(SocketInstance)
			-- Every wait bounded: a client silent for ReadTimeout is dropped
			-- (Dolby CPSeries Control polls every second, so a live one never
			-- is), and a write to a client that stopped reading gives up after
			-- WriteTimeout.
			SocketInstance.ReadTimeout = 10
			SocketInstance.WriteTimeout = 2
			SocketInstance.Timeout = function(s)
				s:Disconnect()
				SetStatus(4, "Listening on " .. PORT[MODEL] .. ", idle client dropped")
			end
			SocketInstance.EventHandler = SocketHandler
			SetStatus(0, "Client connected")
			SocketInstance.Closed = function()
				SetStatus(4, "Listening on " .. PORT[MODEL] .. ", no client")
			end
		end

		-- Init

		SetStatus(5, "Starting")
		server:Listen(PORT[MODEL])
		SetStatus(4, "Listening on " .. PORT[MODEL] .. ", no client")

	end
