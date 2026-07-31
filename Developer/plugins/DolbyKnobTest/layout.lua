local left = -4
local top = -4

layout["Gain"] = {
	PrettyName = "Gain (native Knob)",
	Style = "Knob",
	Position = { left + 26, top + 28 },
	Size = { 36, 36 },
}
layout["GainDb"] = {
	PrettyName = "GainDb (QKnob clone)",
	Style = "Knob",
	Color = { 0, 226, 113 },
	Position = { left + 90, top + 28 },
	Size = { 36, 36 },
}

table.insert(graphics, {
	Type = "GroupBox",
	Text = "DolbyKnob Test",
	HTextAlign = "Left",
	StrokeWidth = 1,
	CornerRadius = 8,
	Position = { left + 8, top + 8 },
	Size = { 155, 100 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Native",
	Position = { left + 12, top + 72 },
	Size = { 64, 16 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "QKnob\nclone",
	Position = { left + 76, top + 72 },
	Size = { 64, 32 },
})
