-- GainDbKnob: same QKnob mechanism as DolbyFader's own DKNob (Text
-- control wrapped as a Knob), but a plain linear dB range (-90..10)
-- instead of Dolby's own piecewise 0.0-10.0 scale. QKnob's own
-- Position<->Value mapping is already linear (see qknob.lua's
-- setposition/getposition), so no extra convertToDb/convertToDolby step
-- is needed. The only control in this plugin -- no other control to
-- sync with.
GainDbKnob = QKnob:new('GainDb', -90, 10, 1)
