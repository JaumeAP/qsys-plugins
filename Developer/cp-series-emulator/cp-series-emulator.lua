-- CP Series Emulator (Q-SYS Control Script)
--
-- A single Control Script that fakes a Dolby CP650/CP750/CP850/CP950/CP950A
-- cinema processor, for bench-testing the "Dolby CPSeries Control" plugin
-- without real hardware. Unlike the three older single-model
-- Dolby CP Emulator/*.quc scripts (CP650/CP750/CP850 only, each its own
-- ad-hoc param subset, no CP950/CP950A), this one models the full wire
-- vocabulary from Developer/plugins/Dolby CPSeries Control/commlib.lua
-- (CPServices) for all five defined models, and is exercised against the
-- REAL CPSeries/CPModels/CPProtocol classes by
-- Developer/tests/test_cp_series_emulator.lua -- not a separate simulator
-- with its own, possibly-diverging idea of the protocol.
--
-- USAGE: this file is plain Lua, meant to be pasted into a new Control
-- Script component in Q-SYS Designer (Designer produces the .quc binary on
-- save; this repo cannot generate that format directly -- see
-- Dolby CP Emulator/README.md). Edit MODEL below to the processor you want
-- to emulate, one instance per model, same as the three existing .quc files.

local MODEL = 'CP750'  -- CP650 / CP750 / CP850 / CP950 / CP950A

-- Per-model TCP port and wire dialect. Mirrors Developer/plugins/
-- Dolby CPSeries Control/models.lua's CPModels.CONFIG exactly. This script
-- is standalone (pasted into its own Control Script, not #include'd by the
-- plugin), so it can't require that module directly -- kept in sync by
-- hand; CPModels.CONFIG is the source of truth if these ever drift.
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

local endl = '\r\n'

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

-- TcpSocketServer objects must stay global, never local (the same
-- GC-safety requirement documented for Timer/TcpSocket in
-- qsys-plugin-development.md: a local one can be collected once nothing
-- else references it, silently killing the listener).
server = TcpSocketServer.New()

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
	-- so an accurate CP650 emulation has to actually do it, not just reply
	-- once: a SET's reply text is otherwise indistinguishable from the raw
	-- echo (both are "param=value"), and without a real echo line first,
	-- the client can't tell the two apart.
	if MODEL == 'CP650' then write(msg) end

	-- FADER
	if isGet(msg, params.fader) then write(formatMessage(params.fader, state.fader)) return end
	do
		local v = trySet(msg, params.fader)
		if v then state.fader = v write(formatMessage(params.fader, state.fader)) return end
	end

	-- MUTE
	if isGet(msg, params.mute) then write(formatMessage(params.mute, state.mute)) return end
	do
		local v = trySet(msg, params.mute)
		if v then state.mute = v write(formatMessage(params.mute, state.mute)) return end
	end

	-- FORMAT (CP650: numeric wire token; CP750: keyword; macro models: 1-indexed number)
	if isGet(msg, params.format) then write(formatMessage(params.format, state.format)) return end
	do
		local v = trySet(msg, params.format)
		if v then state.format = v write(formatMessage(params.format, state.format)) return end
	end

	-- FORMNAME (macro models only -- CP650/CP750 resolve names locally, no wire param)
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

	-- FORMLIST (device-populated, get-only; CP750 has none -- the plugin
	-- builds its list locally for that model instead of querying it)
	if params.formlist and isGet(msg, params.formlist) then
		if MODEL == 'CP650' then
			write(formatMessage(params.formlist, CP650_FORMAT_LIST))
		else
			-- The macro models' received() only recognizes this as a
			-- formlist reply (as opposed to 512 unrelated "unrecognized
			-- action" lines) if the FIRST line matches the sys.macros
			-- param pattern itself -- that's what flips it into formlist-
			-- collection mode, which then drains the "n:name" lines that
			-- follow. A bare "sys.macros" header line, no value, is what
			-- the plugin's own CPServices sep (" ?" optional) matches; the
			-- rest of the burst carries no repeated header, one entry per
			-- line.
			write(params.formlist)
			for _, entry in ipairs(MACROS) do write(entry) end
		end
		return
	end

	-- CP750's read-only handshake param (also its own Actions.reset row --
	-- distinct from fader/mute/format, unlike every other model, whose
	-- reset row reuses the fader param and is already covered above)
	if MODEL == 'CP750' and isGet(msg, 'cp750.sysinfo.version') then
		write('cp750.sysinfo.version ' .. state.version)
		return
	end
end

server.EventHandler = function(SocketInstance)
	SocketInstance.ReadTimeout = 10
	SocketInstance.EventHandler = SocketHandler
end

server:Listen(PORT[MODEL])
