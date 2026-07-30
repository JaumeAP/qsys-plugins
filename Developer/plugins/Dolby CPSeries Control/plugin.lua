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
-- v4.0.0.9 - Address defaults to "127.0.0.1" on first compile (one-time
--        init block, same as the fader/mute/selector defaults already
--        there) -- Text controls have no real GetControls DefaultValue
--        key (same reason SubharmonicSynth's own defaults live in a
--        one-time init rather than the control declaration, see
--        qsys-plugin-development.md's "Key module patterns").
-- v4.0.0.8 - disconnect(recon)'s recon=false branch documented as
--        intentionally-unreachable-for-now (a future explicit "Disconnect"
--        control that shouldn't auto-reconnect is a plausible caller),
--        not collapsed to a single branch -- found by the same coverage
--        audit as v4.0.0.7, comment only, no functional change.
-- v4.0.0.7 - SocketConn:IsConnected() removed (Developer/shared/socket.lua):
--        a one-line wrapper around sock.Socket.IsConnected, used exactly
--        once, when every other socket field is already read straight off
--        sock.Socket elsewhere in this file (the event handlers). Caught
--        by a karpathy-guidelines pass on the v4.0.0.6 diff as an
--        unnecessary abstraction; sockError() now reads sock.Socket.IsConnected
--        directly, matching the rest of the file.
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
