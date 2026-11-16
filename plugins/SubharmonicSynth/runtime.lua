-- Aliases

-- _G aliases must be global (not local) per QSC Lua Scoping guidance
Lpf = _G["Lpf"]
Peq = _G["Peq"]
GainSub = _G["GainSub"]
GainDry = _G["GainDry"]
Mix = _G["Mix"]

-- Variables

-- Resolved PEQ Q-pin handle; set once in Init, used by ApplyQ
PeqQ = nil

-- Custom functions

-- Debug console output, gated on the standard plugin_show_debug property
-- (hidden from the property panel by RectifyProperties, same as the other
-- plugins in this repo, but the toggle itself still controls this output).
local function PrintFormat(fmt, ...)
	if Properties.plugin_show_debug.Value ~= 0 then
		print(fmt:format(...))
	end
end

-- Resolve an uncertain embedded pin: return the first candidate token that
-- exists on the component, else nil. Avoids nil-index crashes on token drift.
function ResolvePin(comp, candidates)
	for _, name in ipairs(candidates) do
		if comp[name] ~= nil then
			return comp[name], name
		end
	end
	return nil, nil
end

function ApplyBypass()
	local bypassed = Controls.Bypass.Boolean
	GainSub["gain"].Value = bypassed and -100 or Controls.SubLevel.Value
	GainDry["gain"].Value = bypassed and 0 or Controls.DryLevel.Value
	PrintFormat("SubharmonicSynth bypass=%s GainSub=%.1f GainDry=%.1f",
		tostring(bypassed), GainSub["gain"].Value, GainDry["gain"].Value)
end

function ApplyCutoff()
	local fc = Controls.Cutoff.Value
	Lpf["frequency"].Value = fc
	Peq["frequency_1"].Value = fc / 2
	PrintFormat("SubharmonicSynth cutoff=%.0f Hz  PEQ centre=%.0f Hz", fc, fc / 2)
end

function ApplyQ()
	if PeqQ then
		PeqQ.Value = Controls.QFactor.Value
		PrintFormat("SubharmonicSynth Q=%.3f", PeqQ.Value)
	end
end

-- Event handlers

Controls.DryLevel.EventHandler = function(ctrl)
	if not Controls.Bypass.Boolean then
		GainDry["gain"].Value = ctrl.Value
	end
end

Controls.SubLevel.EventHandler = function(ctrl)
	if not Controls.Bypass.Boolean then
		GainSub["gain"].Value = ctrl.Value
	end
end

Controls.SubGain.EventHandler = function(ctrl)
	Peq["gain_1"].Value = ctrl.Value
end

Controls.QFactor.EventHandler = function()
	ApplyQ()
end

Controls.Cutoff.EventHandler = function()
	ApplyCutoff()
end

Controls.Bypass.EventHandler = function()
	ApplyBypass()
end

-- Init

-- Mixer: enable crosspoints at unity (embedded mixer defaults to muted)
Mix["input.1.output.1.gain"].Value = 0
Mix["input.2.output.1.gain"].Value = 0

-- LPF: Butterworth 48 dB/oct
Lpf["slope"].Value = 48
Lpf["type"].Value = 2

-- Resolve the PEQ band-Q token once (bandwidth_q_factor = 1 -> scalar `q`)
PeqQ = ResolvePin(Peq, { "q", "q_1" })

-- One-time defaults: Cutoff's legal range is 20-120, so an unsaved (fresh)
-- control reads back as its Lua-side zero value, which no real save could
-- ever produce -- same "never configured yet" signal the other plugins in
-- this repo get from a dedicated Start control, reused here since this
-- plugin has no such control of its own. Runs once; a later reopen of an
-- already-configured design must not clobber the user's saved knob values.
if Controls.Cutoff.Value == 0 then
	Controls.SubGain.Value = 9
	Controls.QFactor.Value = 1.0
	Controls.Cutoff.Value = 80
end

-- DSP state from control values
ApplyCutoff()
Peq["gain_1"].Value = Controls.SubGain.Value
ApplyQ()
ApplyBypass()
