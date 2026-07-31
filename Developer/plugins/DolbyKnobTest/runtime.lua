-- GainDb (native Knob) <-> GainDbText (editable Text) <-> GainComponent's
-- own "gain" control (embedded native "gain" component, same Type
-- SubharmonicSynth uses for GainSub/GainDry). Composition, not derivation:
-- GainComponent is an opaque host DSP block, this file just keeps its
-- exposed "gain" control in sync with the two UI controls.

local MIN, MAX = -90, 10

local function syncFrom(dbValue)
	Controls.GainDb.Value = dbValue
	Controls.GainDbText.String = string.format("%.1f", dbValue)
	GainComponent["gain"].Value = dbValue
end

Controls.GainDb.EventHandler = function()
	syncFrom(Controls.GainDb.Value)
end

Controls.GainDbText.EventHandler = function()
	local v = tonumber(Controls.GainDbText.String)
	if not v then
		v = Controls.GainDb.Value
	end
	v = v < MIN and MIN or v
	v = v > MAX and MAX or v
	syncFrom(v)
end

syncFrom(Controls.GainDb.Value)
