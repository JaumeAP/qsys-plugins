-- CP Series Emulator protocol core -- private to this plugin, #include'd
-- directly by plugin.lua (depth-1, before runtime.lua). Split out of
-- runtime.lua on its own (2026-07-31) rather than left inline, matching
-- "Dolby CPSeries Control"'s own models.lua/protocol.lua/commlib.lua split
-- (private per-plugin files, not Developer/shared/ -- that directory is
-- for code actually used by more than one plugin).
--
-- History: this file used to also back a standalone Control Script version
-- (Developer/cp-series-emulator/cp-series-emulator.lua, predates this
-- plugin), briefly living in Developer/shared/ so both could reference the
-- same source instead of duplicating ~150 lines by hand. The Control
-- Script was removed the same day once the Plugin covered the same job
-- with less to maintain (no build step needed for a quick paste-into-
-- Designer test was its only remaining edge, judged not worth the
-- duplication) -- see docs/continuity-notes.md. Moved back to a private
-- per-plugin file once it had only one real consumer left.
--
-- Caller (plugin.lua) must declare `local MODEL = '...'` (CP650/CP750/
-- CP850/CP950/CP950A) BEFORE #include'ing this file -- everything here
-- closes over that local. After the #include, `server =
-- TcpSocketServer.New()` / `server.EventHandler = ...` / `server:Listen(
-- PORT[MODEL])` and the Status UI wiring live in runtime.lua instead,
-- since that part is plugin-specific, not protocol logic.

-- Per-model TCP port and wire dialect. Mirrors Developer/plugins/
-- Dolby CPSeries Control/models.lua's CPModels.CONFIG exactly. Kept as its
-- own copy rather than #include'd from there: that plugin's own
-- models.lua/protocol.lua/commlib.lua are documented as private to it
-- (repo-layout.md), and this emulator is meant to stay a standalone
-- drop-in, not coupled to another plugin's file tree.
local PORT = { CP650 = 61412, CP750 = 61408, CP850 = 61408, CP950 = 61408, CP950A = 61408 }
local KEYVALUE = { CP650 = true }  -- CP650 speaks KEY=VALUE; every other model speaks "param value"

-- Per-model wire params, mirroring commlib.lua's CPServices table (its SEP
-- row is omitted here -- SEP only matters for the PLUGIN's own response
-- parsing; this side always writes "prefix.param value" or "KEY=VALUE").
local PARAM = {
	CP650  = { fader = 'fader_level',     mute = 'mute',            format = 'format_button',       formname = nil,               formlist = 'format_list' },
	CP750  = { fader = 'cp750.sys.fader', mute = 'cp750.sys.mute',  format = 'cp750.sys.input_mode', formname = nil,               formlist = nil           },
	CP850  = { fader = 'sys.fader',       mute = 'sys.mute',        format = 'sys.macro_preset',     formname = 'sys.macro_name', formlist = 'sys.macros'  },
	CP950  = { fader = 'sys.fader',       mute = 'sys.mute',        format = 'sys.macro_preset',     formname = 'sys.macro_name', formlist = 'sys.macros'  },
	CP950A = { fader = 'sys.fader',       mute = 'sys.mute',        format = 'sys.macro_preset',     formname = 'sys.macro_name', formlist = 'sys.macros'  },
}

-- CP750's format value is a keyword (matches commlib.lua's own CP750
-- lookup table: dig_1..dig_4/analog/non_sync/mic), not a number. These
-- names are illustrative bench-test values, not verified against a real
-- unit (same "unverified sample data" caveat the cpx50 Python toolkit
-- marks its own illustrative fixtures with).
local CP750_FORMATS = { 'dig_1', 'dig_2', 'dig_3', 'dig_4', 'analog', 'non_sync', 'mic' }

-- CP650's format list is a CSV of numeric codes (commlib.lua parses it as
-- repeated %d+ matches). Illustrative, not verified against a real unit.
local CP650_FORMAT_LIST = '01, 04, 05, 10, 93, 94, 95, 99'

-- Macro list for the CP850/CP950/CP950A "macro models" -- illustrative, not
-- verified against a real unit. "n:name" is the wire format commlib.lua's
-- macro-list accumulator expects, one entry per line, no header line.
local MACROS = { '3:7.1 + Dolby Atmos', '1:5.1 + Dolby Atmos', '4:Music', '11:RCA', '7:BNC 1', '6:BNC 2', '9:HDMI' }

local endl = '\r\n'

-- Resolved once per instance: which of PARAM's five rows this MODEL uses.
local params = PARAM[MODEL]
if not params then error("CP Series Emulator: unknown MODEL '" .. tostring(MODEL) .. "'") end

-- Mutable state, seeded with plausible defaults (fader/mute values are the
-- WIRE representation, e.g. "50" for the plugin's 5.0 -- the plugin does
-- the x10 scaling, not the processor).
local state = {
	fader = 20,
	mute = 1,
	format = (MODEL == 'CP650' and '0') or (MODEL == 'CP750' and 'analog') or 1,
	version = '1.4.2',  -- CP750's handshake-only cp750.sysinfo.version reply
}

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

	-- CP650 raw-echoes the sent line before its real response ("Protocol
	-- Guarantees" in the Dolby CP Cinema Control spec) -- the CPSeries
	-- client class works around exactly this (its own echopending logic),
	-- so an accurate CP650 emulation has to actually do it: a SET's reply
	-- text is otherwise indistinguishable from the raw echo (both are
	-- "param=value"), and without a real echo line first, the client
	-- can't tell the two apart.
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
			-- A bare "sys.macros" header line, no value, is what flips the
			-- real plugin's received() into formlist-collection mode; the
			-- "n:name" entries that follow carry no repeated header, one
			-- per line.
			write(params.formlist)
			for _, entry in ipairs(MACROS) do write(entry) end
		end
		return
	end

	-- CP750's read-only handshake param (its own Actions.reset row,
	-- distinct from fader/mute/format -- every other model's reset row
	-- reuses the fader param, already covered above).
	if MODEL == 'CP750' and isGet(msg, 'cp750.sysinfo.version') then
		write('cp750.sysinfo.version ' .. state.version)
		return
	end
end
