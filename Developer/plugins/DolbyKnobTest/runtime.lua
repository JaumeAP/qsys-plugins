-- GainDbKnob: same QKnob mechanism as DolbyFader's own DKNob, but with
-- Min/Max set directly to the dB range (-100..20) instead of the Dolby
-- 0.0-10.0 scale -- QKnob's own Position<->Value mapping is already
-- linear (see qknob.lua's setposition/getposition), so no extra
-- convertToDb/convertToDolby step is needed for a plain dB knob.
GainDbKnob = QKnob:new('GainDb', -100, 20, 1)

GainDbKnob.EventHandler = function(ctrl)
	if ctrl ~= Controls.Gain then
		Controls.Gain.Value = GainDbKnob.Value
	end
end

Controls.Gain.EventHandler = function(ctrl)
	GainDbKnob.Value = Controls.Gain.Value
	GainDbKnob.EventHandler(Controls.Gain)
end

Controls.Gain.EventHandler()
