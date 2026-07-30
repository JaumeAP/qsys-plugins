-- Socket-layer coverage the other CP Series tests never reach: every other
-- test that runs the real dist runtime pass (test_dist_cpseries.lua,
-- test_stress.lua) leaves Controls.Address.String empty, so connect()
-- always takes the invalid-address/emulation branch and sock:Connect() is
-- never called; wire_trace.lua does drive a real connect but asserts
-- nothing (run.sh only greps its output for "CRASHED"). Found by an
-- explicit function-level coverage audit, 2026-07-30 (see
-- docs/continuity-notes.md). Covers:
--   1. SocketConn.ValidateAddress's out-of-range-octet branch
--   2. sock.Socket.Closed/.Timeout/.Error/.Reconnect (runtime.lua)
--   3. sockError()'s watchdog-timeout path (runtime.lua) -- fires only when
--      Poll's `waiting > 30` watchdog trips while the socket is still
--      nominally connected, not the "socket already dropped" path
--   4. DolbyCP.EventHandler's "reset" closure (runtime.lua) -- clears the
--      previously-selected Selector when the device reports format 0
-- NOT covered here, and not added: disconnect(recon)'s `recon`-false
-- branch (runtime.lua) is dead code, not just untested -- the only call
-- site in the repo is refreshCNX() calling disconnect(true), so no path
-- ever reaches it. A test would have to call the local function directly,
-- which nothing in the real plugin does either.

-- Resolve the sibling modules whatever the working directory is.
local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

h.section("SocketConn.ValidateAddress")
do
	-- Pure string/number logic, no TcpSocket touched at load time -- safe to
	-- load standalone without the host stub.
	assert(loadfile(h.repo .. "/Developer/shared/socket.lua"))()
	h.check(SocketConn.ValidateAddress("10.0.0.5") == true, "valid dotted-quad accepted")
	h.check(SocketConn.ValidateAddress("") == false, "empty string rejected")
	h.check(SocketConn.ValidateAddress("10.0.0") == false, "too few octets rejected")
	h.check(SocketConn.ValidateAddress("999.1.1.1") == false, "out-of-range octet (>255) rejected")
	h.check(SocketConn.ValidateAddress("not.an.ip.addr") == false, "non-numeric octets rejected")
end

h.section("Dolby CPSeries Control: socket event handlers + sockError watchdog")
do
	local env = qsys.install({
		controls = qsys.CPSERIES_CONTROLS,
		trigger_controls = { "Refresh" },
		selectors = 8,
		properties = qsys.cpseries_properties("CP 850"),
		emulating = false,          -- force the real connect path
	})
	env.controls.Address.String = "10.0.0.5"

	assert(pcall(assert(loadfile(h.DIST.cpseries))))
	local rawsock = env.socket()

	-- The stub's :Connect() only sets flags; the host firing the actual
	-- .Connected event is simulated by hand, same as wire_trace.lua does.
	rawsock.Connected()
	h.check(type(DolbyCP) == "table" and DolbyCP.EventHandler ~= nil, "Connected: DolbyCP:Start ran")

	rawsock.Closed()
	h.check(env.controls.Status.Value == 4, "Closed: status 4 (got " .. tostring(env.controls.Status.Value) .. ")")
	h.check(env.controls.Status.String == "Offline", "Closed: status text 'Offline'")

	rawsock.Timeout()
	h.check(env.controls.Status.Value == 2, "Timeout: status 2")
	h.check(env.controls.Status.String == "Timeout", "Timeout: status text 'Timeout'")

	rawsock.Error(rawsock, "boom")
	h.check(env.controls.Status.Value == 2, "Error: status 2")
	h.check(env.controls.Status.String == "boom", "Error: status text passes the error message through")

	rawsock.Reconnect()
	h.check(env.controls.Status.Value == 5, "Reconnect: status 5")
	h.check(env.controls.Status.String == "Attempt Reconnect", "Reconnect: status text 'Attempt Reconnect'")

	-- sockError's watchdog path: Poll's own `waiting > 30` check trips
	-- while the socket is still connected (no data ever arrives), NOT the
	-- "socket already dropped" case sock.Socket.Closed covers above. Make
	-- the address invalid first so the reconnect cascade sockError kicks
	-- off (disconnect -> refreshCNX -> connect) lands on a stable,
	-- assertable final state instead of silently reconnecting and looping
	-- (this stub's Timer.CallAfter runs synchronously, so the whole
	-- disconnect/reconnect chain completes inside one env.tick() call).
	env.controls.Address.String = ""
	for _ = 1, 35 do env.tick(1) end
	h.check(env.controls.Status.Value == 2, "watchdog timeout: cascades through sockError to status 2 (got " .. tostring(env.controls.Status.Value) .. ")")
	h.check(env.controls.Status.String == "Invalid Address", "watchdog timeout: ends on 'Invalid Address' once the address was cleared")
	h.check(rawsock.IsConnected == false, "watchdog timeout: sockError's Disconnect() stuck (no valid address to reconnect to)")
end

h.section("Dolby CPSeries Control: DolbyCP.EventHandler 'reset' clears the old Selector")
do
	local env = qsys.install({
		controls = qsys.CPSERIES_CONTROLS,
		trigger_controls = { "Refresh" },
		selectors = 8,
		properties = qsys.cpseries_properties("CP 850"),
		emulating = false,
	})
	env.controls.Address.String = "10.0.0.5"

	assert(pcall(assert(loadfile(h.DIST.cpseries))))
	local rawsock = env.socket()
	rawsock.Connected()

	env.receive("sys.fader 42")
	env.receive("sys.macros 3", "1:Flat", "2:Curve A", "3:Curve B")

	-- The one-time boot init sets Selector[1].Value=1 in the UI only (it
	-- calls the EventHandler with ctrl==DolbyCP, which deliberately skips
	-- notifying CPSeries, to avoid echoing back to the device) -- the
	-- internal format value is still 0 until the device itself reports
	-- one. Feed a real "format 1" report first so there is a non-zero
	-- stored value for the device's later "format 0" report to actually
	-- change (setValue's isEqual guard would otherwise make the 0 report
	-- a no-op against an already-0 stored value, and "reset" would never
	-- fire).
	env.receive("sys.macro_preset 1")
	h.check(env.controls.Selector[1].Value == 1, "setup: format 1 selected")

	env.receive("sys.macro_preset 0")
	h.check(env.controls.Selector[1].Value == 0,
		"'reset' EventHandler cleared the previously-selected Selector[1] when the device reported format 0")
end

h.report()
