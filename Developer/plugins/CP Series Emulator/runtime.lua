
   -- ##############################################################
   --			CP Series Emulator Application
   -- ##############################################################
   --
   -- Fakes a Dolby CP650/CP750/CP850/CP950/CP950A processor over TCP, so
   -- "Dolby CPSeries Control" can be bench-tested against it without real
   -- hardware. Models the exact wire vocabulary that plugin's own
   -- CPServices table (../Dolby CPSeries Control/commlib.lua) sends/
   -- expects -- kept in sync by hand, not #include'd from there: that
   -- plugin's models.lua/protocol.lua/commlib.lua are documented as
   -- private to it (repo-layout.md), and this emulator is meant to stay a
   -- fully standalone plugin a design can drop in without pulling in
   -- another plugin's own source tree. Ported from the Control Script
   -- version (Developer/cp-series-emulator/cp-series-emulator.lua, kept
   -- for the bench-testing workflow that predates this plugin and doesn't
   -- need a full Q-SYS component) -- same protocol logic, adapted to read
   -- the model from Properties.Model instead of a hardcoded constant, and
   -- to report Status the way every other plugin in this repo does.

	do

		-- Constants

		-- Per-model TCP port and wire dialect. Mirrors CPModels.CONFIG in
		-- ../Dolby CPSeries Control/models.lua exactly.
		local PORT = { CP650 = 61412, CP750 = 61408, CP850 = 61408, CP950 = 61408, CP950A = 61408 }
		local KEYVALUE = { CP650 = true }  -- CP650 speaks KEY=VALUE; every other model speaks "param value"

		-- Per-model wire params, mirroring commlib.lua's CPServices table.
		local PARAM = {
			CP650  = { fader = 'fader_level',     mute = 'mute',            format = 'format_button',       formname = nil,               formlist = 'format_list' },
			CP750  = { fader = 'cp750.sys.fader', mute = 'cp750.sys.mute',  format = 'cp750.sys.input_mode', formname = nil,               formlist = nil           },
			CP850  = { fader = 'sys.fader',       mute = 'sys.mute',        format = 'sys.macro_preset',     formname = 'sys.macro_name', formlist = 'sys.macros'  },
			CP950  = { fader = 'sys.fader',       mute = 'sys.mute',        format = 'sys.macro_preset',     formname = 'sys.macro_name', formlist = 'sys.macros'  },
			CP950A = { fader = 'sys.fader',       mute = 'sys.mute',        format = 'sys.macro_preset',     formname = 'sys.macro_name', formlist = 'sys.macros'  },
		}

		-- Illustrative bench-test values, not verified against a real unit
		-- (same caveat the Control Script version carries).
		local CP750_FORMATS = { 'dig_1', 'dig_2', 'dig_3', 'dig_4', 'analog', 'non_sync', 'mic' }
		local CP650_FORMAT_LIST = '01, 04, 05, 10, 93, 94, 95, 99'
		local MACROS = { '3:7.1 + Dolby Atmos', '1:5.1 + Dolby Atmos', '4:Music', '11:RCA', '7:BNC 1', '6:BNC 2', '9:HDMI' }

		local endl = '\r\n'

		local MODEL = (Properties.Model.Value):gsub("%s", "")
		local params = PARAM[MODEL]
		assert(params, "CP Series Emulator: unknown MODEL '" .. tostring(MODEL) .. "'")

		-- Mutable state, seeded with plausible defaults (fader/mute values
		-- are the WIRE representation, e.g. "50" for the real plugin's 5.0
		-- -- the plugin does the x10 scaling, not the processor).
		local state = {
			fader = 20,
			mute = 1,
			format = (MODEL == 'CP650' and '0') or (MODEL == 'CP750' and 'analog') or 1,
			version = '1.4.2',  -- CP750's handshake-only cp750.sysinfo.version reply
		}

		-- Objects
		-- Must stay global, never local (same GC-safety rule as Timer/
		-- TcpSocket -- see qsys-plugin-development.md).
		server = TcpSocketServer.New()

		-- Custom functions

		local function escape(s) return (s:gsub('%p', '%%%0')) end

		local function isGet(msg, param)
			if param == nil then return false end
			local pat = KEYVALUE[MODEL] and ('^' .. escape(param) .. '=%?$') or ('^' .. escape(param) .. ' %?$')
			return msg:match(pat) ~= nil
		end

		local function trySet(msg, param)
			if param == nil then return nil end
			local pat = KEYVALUE[MODEL] and ('^' .. escape(param) .. '=(.*)$') or ('^' .. escape(param) .. ' (.*)$')
			return msg:match(pat)
		end

		local function macroName(index)
			for _, entry in ipairs(MACROS) do
				local n, name = entry:match('^(%d+):(.*)$')
				if tonumber(n) == tonumber(index) then return name end
			end
			return nil
		end

		local function macroIndex(name)
			for _, entry in ipairs(MACROS) do
				local n, entryName = entry:match('^(%d+):(.*)$')
				if entryName == name then return n end
			end
			return nil
		end

		-- Status states match this repo's own convention (0=OK, 2=Fault,
		-- 4=Missing/no client, 5=Initializing -- same numbering the real
		-- CPSeries Control plugin's runtime.lua uses).
		local function SetStatus(state_code, msg)
			Controls.Status.Value = state_code
			Controls["Status.Led"].Value = state_code
			Controls.Status.String = msg or ''
		end

		-- Event handlers

		function SocketHandler(sock, event)
			if event ~= TcpSocket.Events.Data then return end

			local function write(msg)
				if sock.IsConnected then
					sock:Write(msg .. endl)
				end
			end

			local function formatMessage(param, value)
				if KEYVALUE[MODEL] then return param .. '=' .. tostring(value) end
				return param .. ' ' .. tostring(value)
			end

			local msg = sock:ReadLine(TcpSocket.EOL.Any)
			if msg == nil then return end

			-- CP650 raw-echoes the sent line before its real response
			-- ("Protocol Guarantees" in the Dolby CP Cinema Control spec)
			-- -- the CPSeries client class works around exactly this (its
			-- own echopending logic), so an accurate CP650 emulation has
			-- to actually do it: a SET's reply text is otherwise
			-- indistinguishable from the raw echo (both are
			-- "param=value"), and without a real echo line first, the
			-- client can't tell the two apart.
			if MODEL == 'CP650' then write(msg) end

			if isGet(msg, params.fader) then write(formatMessage(params.fader, state.fader)) return end
			do
				local v = trySet(msg, params.fader)
				if v then state.fader = v write(formatMessage(params.fader, state.fader)) return end
			end

			if isGet(msg, params.mute) then write(formatMessage(params.mute, state.mute)) return end
			do
				local v = trySet(msg, params.mute)
				if v then state.mute = v write(formatMessage(params.mute, state.mute)) return end
			end

			if isGet(msg, params.format) then write(formatMessage(params.format, state.format)) return end
			do
				local v = trySet(msg, params.format)
				if v then state.format = v write(formatMessage(params.format, state.format)) return end
			end

			if params.formname then
				if isGet(msg, params.formname) then
					write(formatMessage(params.formname, macroName(state.format) or ''))
					return
				end
				local v = trySet(msg, params.formname)
				if v then
					local idx = macroIndex(v)
					if idx then state.format = idx end
					write(formatMessage(params.formname, v))
					return
				end
			end

			if params.formlist and isGet(msg, params.formlist) then
				if MODEL == 'CP650' then
					write(formatMessage(params.formlist, CP650_FORMAT_LIST))
				else
					-- A bare "sys.macros" header line, no value, is what
					-- flips the real plugin's received() into formlist-
					-- collection mode; the "n:name" entries that follow
					-- carry no repeated header, one per line.
					write(params.formlist)
					for _, entry in ipairs(MACROS) do write(entry) end
				end
				return
			end

			-- CP750's read-only handshake param (its own Actions.reset
			-- row, distinct from fader/mute/format -- every other model's
			-- reset row reuses the fader param, already covered above).
			if MODEL == 'CP750' and isGet(msg, 'cp750.sysinfo.version') then
				write('cp750.sysinfo.version ' .. state.version)
				return
			end
		end

		server.EventHandler = function(SocketInstance)
			SocketInstance.ReadTimeout = 10
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
