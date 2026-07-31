-- GainDb (native Knob) <-> GainDbText (editable Text), bidirectionally
-- linked. No QKnob wrapper -- GainDb is already a native numeric control,
-- so this is plain Controls.* wiring, same style as MultiFlip-Flop/
-- StateTrigger's own runtime blocks.

local MIN, MAX = -90, 10

local function syncText()
	Controls.GainDbText.String = string.format("%.1f", Controls.GainDb.Value)
end

Controls.GainDb.EventHandler = function()
	syncText()
end

Controls.GainDbText.EventHandler = function()
	local v = tonumber(Controls.GainDbText.String)
	if v then
		v = v < MIN and MIN or v
		v = v > MAX and MAX or v
		Controls.GainDb.Value = v
	end
	syncText()
end

syncText()
