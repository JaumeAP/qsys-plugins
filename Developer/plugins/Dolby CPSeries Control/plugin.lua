-- CP Series Control Plugin for Q-SYS
-- by James Puig / james.puig@elcine.com
-- Febr '20
--
-- v3.0 - adds CP950 and CP950A. Wire communication now goes through the
--        cpseries_models / cpseries_protocol modules instead of per-model
--        string concatenation, and the old setmeta/searchelem reflection
--        hack on Model/CP750/Actions is gone -- Model is now a plain array
--        with real index/key/value fields. Bug fixes: RectifyProperties hid
--        the TCP Log with 'not Value' (0 is truthy in Lua -> never hid) ->
--        '== 0'; guard Get* against a nil props (Q-SYS can call them with no
--        props during plugin registration, before any instance exists).
-- v3.0.0.3 - pressing a format button before the processor had reported its
--        format list published a nil format name, which the plugin's event
--        handler asserts on, crashing the component. The name mirror is now
--        left alone when the format index resolves to no list entry.
-- v4.0 - rebuilt to the plugin structure/naming convention confirmed against
--        QSC's own vendor/qsys-plugins/{BasePlugin,ExamplePlugin} templates
--        and the community vendor/q-sys-community/q-sys-plugin-guide
--        (2026-07-27): mandatory section order, PascalCase Controls/fns/
--        globals, camelCase locals. Breaking: Controls renamed to PascalCase
--        (Start/Ref/Level/Gain/Increase/Decrease/Address/Status/Status.Led/
--        Refresh/Select/Selector/Mute, were start/ref/level/.../mute) -- a
--        design already wired to the old pin names needs those pins
--        reconnected. Also: TcpSocket.New() uses dot-notation construction
--        (was TcpSocket:New() with colon; confirmed correct against the
--        Q-SYS Lua reference); the socket and the CPSeries instance are now
--        global (were local), matching the documented Timer/socket
--        GC-safety convention -- neither was actually being collected
--        (both are reachable through closures already stored in global
--        Controls.*.EventHandler fields), but this removes any doubt.
--        Bugfix: GetControlLayout had layout['decrease'].PrettyName =
--        "decrease" (lowercase, inconsistent with the sibling "Increase"
--        label).
--        Signal chain: DKNob (a QKnob wrapping the 'Level' Text control)
--        mirrors the Dolby 0.0-10.0 fader scale against the 'Gain' Knob
--        (dB); CPSeries (commlib/models/protocol) drives a TcpSocket
--        connection to the processor and reports fader/mute/format/
--        formname/formlist back through DolbyCP.EventHandler in runtime.lua.
-- v4.0.0.1 - a fader/mute value that round-trips through the '%.f' formatting
--        step to "inf"/"nan" (e.g. the wire reporting a value like 1e400,
--        which overflows to +/-inf) turned back into a nil on the second
--        tonumber() call, crashing the next arithmetic on it. Found by a
--        stress test feeding malformed numeric payloads; now bails out like
--        the first non-numeric check already does.
-- v4.0.0.2 - the one-time init block (fader=7.0, Mute=0, Selector[1]=1) never
--        ran on first compile: it was gated on 'Controls.Start.Value == false',
--        and .Value is always numeric (confirmed via vendor/qsc-q-sys's
--        Component.GetControls docs), so a number can never equal the Lua
--        literal false. Now compares against 0/1 (Start has no declared
--        ControlType, so .Boolean isn't confirmed safe on it, unlike
--        DolbySweep/MultiFlip-Flop's own explicitly-Button 'Start'). Also:
--        the Selector radio-button reads (ctl.Value == 1) now use ctl.Boolean
--        instead -- not a bug fix, Selector IS ControlType="Button", just the
--        clearer accessor now that the type is confirmed.
-- v4.0.0.3 - restructured onto QSC's official PLUGCC.exe build convention
--        (vendor/qsys-plugins/BasePlugin/PluginCompile, PLUGCC.exe) instead
--        of this repo's own build_distributable.sh -- split into this file
--        plus info.lua/properties.lua/controls.lua/layout.lua, and the
--        former Developer/Modules/cpseries_models.lua /
--        cpseries_protocol.lua / cpseries_commlib.lua / cpseries.lua (this
--        plugin's own private code, not shared with any other plugin) moved
--        here as models.lua/protocol.lua/commlib.lua/runtime.lua, their own
--        require() calls dropped in favor of a fixed load order enforced
--        directly by this file's own #include sequence below. Reuses
--        Developer/shared/dolbyfader.lua (also used by DolbyFader), which
--        pulls in Developer/shared/qknob.lua itself. All #include's here
--        are direct, depth-1 includes (written straight in this file), so
--        PLUGCC.exe's nested-include-must-be-first-line rule (see
--        DolbyFader's own plugin.lua header, and CLAUDE.md continuity
--        notes) doesn't apply to any of them. No functional change from
--        v4.0.0.2; guard style switched from `if not Controls and Reflect
--        then return end` to `if Controls then ... end` to match the other
--        three restructured plugins (behaviorally identical, both just
--        skip runtime logic during the definition pass); the dev-only
--        'strict' globals guard is dropped rather than carried over, same
--        call as the other three restructurings, since it never shipped to
--        production and PLUGCC.exe has no equivalent stripping step
--        build_distributable.sh had.
-- v4.0.0.4 - commlib.lua's readData(self,true) call passed a second argument
--        readData() doesn't take (it only takes self), silently ignored by
--        Lua -- dead/misleading, not a functional bug; dropped. Also: Mute
--        (ControlType="Button", ButtonType="Toggle") was the one Button
--        control in this plugin still read/written via .Value instead of
--        .Boolean -- not a bug (.Value is always numeric and valid on any
--        control type), just inconsistent with the .Boolean idiom the rest
--        of this codebase already settled on; switched for consistency.
-- v4.0.0.12 - crash fix, long-standing and unrelated to the timer work
--        above: pressing Mute threw out of the poll timer. runtime.lua
--        wires the button through as Action("mute", Controls.Mute.Boolean),
--        a Lua boolean, and the poll loop fed that straight to
--        string.format('%.0f', ...), which rejects a boolean outright --
--        "bad argument #2 to 'format' (number expected, got boolean)". The
--        value is now normalized to 0/1 first, exactly the way isEqual()
--        already did for the same boolean-vs-number reason, and anything
--        still not numeric falls back to a query rather than crashing or
--        putting garbage on the wire, matching the rule the format branch
--        already applied. Found while testing the poll-interval change; no
--        test had ever driven the boolean path, which is how it survived.
--        Unmute from the default state remains a deliberate no-op: the
--        mirror already reads 0, so isEqual() drops it -- it only travels
--        once the device has reported itself muted.
-- v4.0.0.11 - idle poll interval, completing the spec's four separated
--        timers. The loop used to query the processor on every tick the gap
--        allowed -- ~10 queries/s, or ~4 on a CP650 -- where the spec asks
--        for one per second. Queries are now rate-limited to POLL_INTERVAL.
--        Deliberately queries ONLY: a pending local change (fader, mute,
--        format) still goes out at gap rate, mirroring how the reference
--        implementation keeps its poll loop (1s) separate from its command
--        drain loop (continuous). Rate-limiting both would have put up to a
--        second of latency on every fader move. The check sits before
--        pollAction() so a held tick doesn't consume a rotation slot, and
--        gates the whole send block rather than individual messages --
--        holding only the query slots would stall the rotation on a held
--        slot and never reach the one carrying the SET.
--        Consequence worth knowing on the bench: state changed at the
--        processor's own front panel is now reflected in Q-SYS within a
--        couple of seconds rather than a couple of hundred milliseconds.
--        That is the spec's own trade, not an accident of this change.
-- v4.0.0.10 - query timeout, the last of the spec's four separated timers
--        the poll loop was missing. A response lost in transit used to be
--        indistinguishable from a dead link: nothing was retransmitted, so
--        the connection simply sat idle until the 3s watchdog tore it down,
--        losing the link over a single dropped packet. writeSocket() now
--        remembers the message in flight and Poll() retransmits it once, at
--        1.5s, byte-identical. The waiting counter deliberately keeps
--        running underneath, so a link that really is dead is still
--        declared dead on the same 3s schedule -- the retry buys a lost
--        response a second chance, it does not extend the watchdog. Fires
--        on exact tick equality, so it can never become a retry storm.
-- v4.0.0.9 - CP650 echo fix ("Protocol Guarantees": expect RESPONSE, not
--        echo). readData() had no way to tell the device's own raw echo of
--        the sent line from a real reply. This was concretely wrong, not
--        just theoretically: CP650's readiness handshake reuses the fader
--        wire key ('fader_level'), so the echoed query structurally matched
--        the fader/readiness pattern and flipped readiness to true on the
--        plugin's own bytes bouncing back, before the processor had said
--        anything at all -- confirmed by a reproduction script before this
--        fix, not just by inspection. writeSocket() now records the raw
--        sent line; readData() discards exactly one matching line before
--        treating anything as a real response, without touching the
--        watchdog/busy counter for that discarded line. Only armed for
--        CP650 -- the other four models are unaffected, don't echo, and
--        their own coincidental reuse of the same wire key across rows
--        (e.g. CP850's 'sys.fader') is unrelated existing behaviour, not
--        something this touches.
-- v4.0.0.8 - private.cache (the pending-message queue ahead of the regular
--        poll cycle) honours two more of the "Protocol Guarantees": it now
--        drains oldest-first (was table.remove() with no index, which pops
--        the LAST item -- LIFO, not FIFO) and is capped at QMAX=10, dropping
--        the oldest entry first past capacity. request() is currently the
--        queue's only producer and is only ever called once per Start(), so
--        the queue never actually holds more than one entry today -- this
--        guards a future second caller from inheriting silently wrong
--        ordering or unbounded growth, not an observed bug in current
--        behaviour.
-- v4.0.0.7 - commlib.lua now honours two of the "Protocol Guarantees" of the
--        Dolby CP Cinema Control spec it previously ignored. (1) Minimum gap
--        between sent commands: there was none -- the poll loop sent again
--        on the first 0.02s tick after a response, which on a CP650 is far
--        under the 250ms that model's hardware needs (100ms for the others).
--        Poll now holds the wire until the model's gap has elapsed,
--        measured from the last send. (2) The no-response watchdog was 30
--        ticks, i.e. 0.6s, five times more aggressive than the documented
--        3.0s, so a merely slow link was declared dead; it is now 150 ticks.
--        Both are expressed as seconds and converted to ticks against
--        POLLTIME rather than hardcoded as tick counts. The waiting counter
--        now only advances once a command is actually in flight, which is
--        what keeps the new gap a hold rather than a deadlock.
-- v4.0.0.6 - TcpSocket construction, IPv4 address validation, and
--        Connect/Disconnect/IsConnected now go through the new shared
--        Developer/shared/socket.lua module (SocketConn), so any future
--        plugin needing a TCP client can reuse them instead of duplicating
--        this boilerplate -- per an explicit request to put socket
--        operations in a module other plugins can call. Connection
--        orchestration (when to reconnect, what status to show) stays in
--        this plugin's own runtime.lua, since that part is plugin-specific.
--        sock is now a SocketConn instance; the raw TcpSocket is
--        sock.Socket (needed by CPSeries:Start(sock.Socket), which still
--        wants the raw socket object). No functional change.
-- v4.0.0.5 - commlib.lua's isEqual() compared a stored value against an
--        incoming one with plain '==', so a value stored as a Lua boolean
--        (Actions.reset's `value or true`, Mute's .Boolean writes) never
--        matched the same value arriving off the wire as a number (no
--        boolean/number coercion in Lua) -- the "already equal, skip"
--        check silently missed, redundantly re-firing the EventHandler on
--        every wire echo of an already-known value. Not a crash, just a
--        needless re-fire; found while double-checking the Mute .Boolean
--        switch against Q-SYS Help's docs. Now normalizes booleans to 0/1
--        before comparing.

--[[ #include "info.lua" ]]

-- Constants

-- Supported processor models, as plain records. `Model` is an ordered
-- array (iterate with ipairs / #Model) AND is keyed by symbol
-- (Model.CP650, ...); every entry carries value (display name), key
-- and index.
Model = {}
for i, m in ipairs({
	{ key = 'CP650',  value = 'CP 650'  },
	{ key = 'CP750',  value = 'CP 750'  },
	{ key = 'CP850',  value = 'CP 850'  },
	{ key = 'CP950',  value = 'CP 950'  },
	{ key = 'CP950A', value = 'CP 950A' },
}) do
	m.index = i
	Model[i] = m
	Model[m.key] = m
end

local ButtonLabel = { { '01', '04', '05', '10', '11', 'U1', 'U2', 'NS' },
					  { 'Dig1', 'Dig2', 'Dig3', 'Dig4', 'Ana', 'NS', 'Mic' },
					  { '1', '2', '3', '4', '5', '6', '7', '8' },
					  { '1', '2', '3', '4', '5', '6', '7', '8' },
					  { '1', '2', '3', '4', '5', '6', '7', '8' } }

-- Model value, tolerant of a nil / partial props: Q-SYS may call the
-- Get* functions with no props during plugin registration, before any
-- instance exists. Without this guard `props.Model.Value` throws
-- "index a nil value".
local function ModelValue(props)
	return (props and props.Model and props.Model.Value) or Model.CP850.value
end

function GetColor(props)
	return { 0, 127, 255 }
end

function GetPrettyName(props)
	return "Dolby " .. ModelValue(props) .. " Control"
end

function GetProperties()
	local props = {}
	--[[ #include "properties.lua" ]]
	return props
end

function RectifyProperties(props)
	if props and props["TCP Log"] and props.plugin_show_debug then
		props["TCP Log"].IsHidden = (props.plugin_show_debug.Value == 0) -- FIX: 'not Value' never hid (0 is truthy in Lua)
	end
	return props
end

function GetControls(props)
	local ctrls = {}
	--[[ #include "controls.lua" ]]
	return ctrls
end

function GetControlLayout(props)
	local layout = {}
	local graphics = {}
	--[[ #include "layout.lua" ]]
	return layout, graphics
end

function GetComponents(props)
	return {
		{
			Name = "Step",
			Type = "stepper",
			Properties =
			{
				control_type = 2,
				num_steps = 100,
			}
		},
	}
end

if Controls then
	--[[ #include "../../shared/dolbyfader.lua" ]]
	--[[ #include "../../shared/socket.lua" ]]
	--[[ #include "models.lua" ]]
	--[[ #include "protocol.lua" ]]
	--[[ #include "commlib.lua" ]]
	--[[ #include "runtime.lua" ]]
end
