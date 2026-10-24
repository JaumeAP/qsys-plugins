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

-- CP750 key parameter ranges (dB / ms / Hz), from the Dolby CP Cinema Control
-- spec's "Key Parameters (CP750)" table via the CPSeries toolkit
-- (cpx50.comms.models). The ch_level_* and eq_* families share one range each.
-- Real hardware clips a SET to these silently, so the emulator does too.
local RANGES = {
	['cp750.sys.master_level']       = { 0, 96 },
	['cp750.sys.ch_level']           = { -96, 12 },
	['cp750.sys.mute']               = { 0, 1 },
	['cp750.sys.surround_delay']     = { 0, 150 },
	['cp750.sys.subwoofer_filter']   = { 50, 100 },
	['cp750.sys.eq']                 = { -60, 60 },
	['cp750.sys.mute_fade_out_time'] = { 200, 5000 },
}

local function rangeOf(param)
	if RANGES[param] then return RANGES[param] end
	if param:find('cp750.sys.ch_level_', 1, true) == 1 then return RANGES['cp750.sys.ch_level'] end
	if param:find('cp750.sys.eq_', 1, true) == 1 then return RANGES['cp750.sys.eq'] end
	return nil
end

local function isDigit(c) return c ~= '' and c >= '0' and c <= '9' end

-- float(str) as Python parses it (the CPSeries reference): optional sign,
-- digits with '_' between digits, fraction, exponent, or inf / nan. Anything
-- else (hex, empty, words) is not a number and is stored as text.
local function parseNumber(s)
	local sign, word = s:lower():match('^([+-]?)(%a+)$')
	if word == 'inf' or word == 'infinity' then return sign == '-' and -math.huge or math.huge end
	if word == 'nan' then return 0 / 0 end
	local clean = {}
	for k = 1, #s do
		local c = s:sub(k, k)
		if c == '_' then
			if not (isDigit(s:sub(k - 1, k - 1)) and isDigit(s:sub(k + 1, k + 1))) then return nil end
		else
			clean[#clean + 1] = c
		end
	end
	clean = table.concat(clean)
	local body = clean:match('^[+-]?(.*)$')
	local mantissa, exponent = body:match('^([^eE]*)[eE](.*)$')
	if not mantissa then mantissa = body end
	if exponent and not exponent:match('^[+-]?%d+$') then return nil end
	if not (mantissa:match('^%d+%.?%d*$') or mantissa:match('^%.%d+$')) then return nil end
	return tonumber(clean)
end

-- Wire text of a number: whole values as integers, others as the shortest
-- string that round-trips (tostring would keep only 14 digits).
local function formatNumber(v)
	if v ~= v then return 'nan' end
	if v == math.huge then return 'inf' end
	if v == -math.huge then return '-inf' end
	if v == math.floor(v) then
		if v == 0 then return '0' end
		return string.format('%.0f', v)
	end
	for prec = 1, 17 do
		local text = string.format('%.' .. prec .. 'g', v)
		if tonumber(text) == v then return text end
	end
	return string.format('%.17g', v)
end

-- What a SET leaves in the state: a number is clipped to the param's
-- documented range (when it has one) and re-printed canonically; anything
-- else is kept verbatim.
local function normalize(param, raw)
	local num = parseNumber(raw)
	if num == nil then return raw end
	local range = rangeOf(param)
	if range and not (num >= range[1] and num <= range[2]) then
		num = math.max(range[1], math.min(range[2], num))
	end
	return formatNumber(num)
end

-- Every param the fixed handlers below do not know: SET stores, GET reads it
-- back, an unknown GET stays silent (like the real processor).
local other = {}

local function strip(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

-- (param, 'get') / (param, 'set', value) for any wire line, or nil.
local function parseAny(msg)
	if KEYVALUE[MODEL] then
		if msg:sub(-1) == '?' then
			return strip((msg:sub(1, -2):gsub('=$', ''))), 'get'
		end
		local p, v = msg:match('^(.-)=(.*)$')
		if p then return strip(p), 'set', strip(v) end
		return nil
	end
	local p, v = msg:match('^%s*(%S+)%s+(%S.*)$')
	if not p then return nil end
	v = strip(v)
	if v == '?' then return p, 'get' end
	return p, 'set', v
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

	-- The CP650 query is "KEY=?" (this plugin's Dolby-verified framing); the
	-- CPSeries toolkit sends "KEY?". Accept both.
	if KEYVALUE[MODEL] and msg:sub(-1) == '?' and msg:sub(-2) ~= '=?' then
		msg = msg:sub(1, -2) .. '=?'
	end

	if isGet(msg, params.fader) then write(formatMessage(params.fader, state.fader)) return end
	do
		local v = trySet(msg, params.fader)
		if v then state.fader = normalize(params.fader, v) write(formatMessage(params.fader, state.fader)) return end
	end

	if isGet(msg, params.mute) then write(formatMessage(params.mute, state.mute)) return end
	do
		local v = trySet(msg, params.mute)
		if v then state.mute = normalize(params.mute, v) write(formatMessage(params.mute, state.mute)) return end
	end

	if isGet(msg, params.format) then write(formatMessage(params.format, state.format)) return end
	do
		local v = trySet(msg, params.format)
		if v then state.format = normalize(params.format, v) write(formatMessage(params.format, state.format)) return end
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

	-- Any other param: a stateful GET/SET, with CP750 range clipping.
	local param, kind, value = parseAny(msg)
	if kind == 'get' then
		if other[param] ~= nil then write(formatMessage(param, other[param])) end
	elseif kind == 'set' then
		other[param] = normalize(param, value)
		write(formatMessage(param, other[param]))
	end
end
