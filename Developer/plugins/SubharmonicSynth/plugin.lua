-- SubharmonicSynth for Q-SYS
-- Bass enhancement / subharmonic-style boost for LFE/Sub channels.
-- Place after CP850 on LFE or Sub output.
--
-- Signal chain:
--   Input --+-- [LP IIR] -- [PEQ boost at fc/2] -- [GainSub] --+-- [Mixer 2->1] -- Output
--           |                                                    |
--           +------------------- [GainDry] --------------------+
--
-- NOTE: true subharmonic division (f/2 via flip-flop) is not possible inside
-- a Q-SYS plugin (audio runs at block level, not sample level). This plugin
-- uses a resonant PEQ boost one octave below the LPF cutoff to enhance
-- sub-bass.
--
-- v0.6.0 - incorporated from an external contribution (originally
--        SubharmonicSynth_v0_6.qplug) onto this repo's plugin structure/
--        naming convention: split into this file plus info.lua/controls.lua/
--        layout.lua/runtime.lua, built via PLUGCC.exe. Breaking, but only
--        relative to the original upload (nothing in this repo was ever
--        wired to the old names): Controls renamed to PascalCase
--        (DryLevel/SubLevel/SubGain/QFactor/Cutoff/Bypass, were
--        dry_level/sub_level/sub_gain/q_factor/cutoff/bypass). Also:
--        the original's per-control `DefaultValue` field is not a real
--        Q-SYS GetControls key (confirmed against Q-SYS Help and the
--        vendored templates -- none of the four other plugins here use
--        one either), so SubGain/QFactor/Cutoff's intended defaults
--        (9 dB / 1.0 / 80 Hz) were never actually applied on a fresh
--        instantiation; now set via a guarded one-time runtime.lua init,
--        the same pattern the other plugins use. The AddEventHandler
--        chaining helper was dropped -- every control here has exactly
--        one handler, so the indirection bought nothing -- in favor of
--        this repo's own plain `Controls.X.EventHandler = function`
--        style; PrintFormat now gates on `plugin_show_debug` like the
--        rest of this repo's debug output, instead of printing
--        unconditionally.

--[[ #include "info.lua" ]]

function GetColor(props)
	return { 40, 20, 80 }
end

function GetPrettyName(props)
	return "SubharmonicSynth"
end

function GetProperties()
	return {}
end

function RectifyProperties(props)
	props.plugin_show_debug.IsHidden = true
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
		-- LP IIR: isolates sub-bass content (Butterworth, 48 dB/oct)
		{
			Name = "Lpf",
			Type = "filter_lowpass",
			Properties = { ["max_slope"] = 48, ["multi_channel_type"] = 1 },
		},
		-- PEQ 1-band: resonant boost at suboctave centre (fc/2)
		{
			Name = "Peq",
			Type = "equalizer_parametric",
			Properties = { ["n_bands"] = 1, ["bandwidth_q_factor"] = 1, ["multi_channel_type"] = 1 },
		},
		-- Gain: sub path level trim
		{
			Name = "GainSub",
			Type = "gain",
			Properties = { ["max_gain"] = 20, ["min_gain"] = -100, ["multi_channel_type"] = 1 },
		},
		-- Gain: dry path level trim
		{
			Name = "GainDry",
			Type = "gain",
			Properties = { ["max_gain"] = 20, ["min_gain"] = -100, ["multi_channel_type"] = 1 },
		},
		-- Mixer 2-in 1-out: sums dry + sub paths
		{
			Name = "Mix",
			Type = "mixer",
			Properties = { ["n_inputs"] = 2, ["n_outputs"] = 1 },
		},
	}
end

function GetPins(props)
	return {
		{ Name = "Input", Direction = "input" },
		{ Name = "Output", Direction = "output" },
	}
end

function GetWiring(props)
	return {
		-- Sub path
		{ "Input", "Lpf Input 1" },
		{ "Lpf Output 1", "Peq Input 1" },
		{ "Peq Output 1", "GainSub Input 1" },
		{ "GainSub Output 1", "Mix Input 1" },
		-- Dry path
		{ "Input", "GainDry Input 1" },
		{ "GainDry Output 1", "Mix Input 2" },
		-- Output
		{ "Mix Output 1", "Output" },
	}
end

if Controls then
	--[[ #include "runtime.lua" ]]
end
