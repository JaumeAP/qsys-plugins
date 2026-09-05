local left = -4
local top = -4

layout["GainDb"] = {
	PrettyName = "GainDb (native Knob, dB)",
	Style = "Knob",
	Color = { 0, 226, 113 },
	Position = { left + 26, top + 28 },
	Size = { 36, 36 },
}

table.insert(graphics, {
	Type = "GroupBox",
	Text = "DolbyKnob Test",
	HTextAlign = "Left",
	StrokeWidth = 1,
	CornerRadius = 8,
	Position = { left + 8, top + 8 },
	Size = { 90, 100 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "GainDb\n(dB)",
	Position = { left + 12, top + 72 },
	Size = { 64, 32 },
})
