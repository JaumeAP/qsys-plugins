local left = -4
local top = -4

layout['Ref'] = {
	PrettyName = "Ref Level",
	Style = "Button",
	ButtonStyle = "Momentary",
	Color = { 242, 137, 174 },
	Size = { 36, 16 },
	Position = { left + 26, top + 48 },
}
layout['Level'] = {
	PrettyName = 'Dolby Level',
	Style = "Knob",
	Color = { 0, 226, 113 },
	Position = { left + 90, top + 28 },
	Size = { 36, 36 },
}
layout['Increase'] = {
	PrettyName = "Increase",
	Style = "Button",
	ButtonStyle = "Momentary",
	Color = { 255, 255, 255 },
	Position = { left + 154, top + 28 },
	Size = { 36, 16 },
}
layout['Decrease'] = {
	PrettyName = "Decrease",
	Style = "Button",
	ButtonStyle = "Momentary",
	Color = { 255, 255, 255 },
	Size = { 36, 16 },
	Position = { left + 154, top + 48 },
}
layout["Gain"] = {
	PrettyName = "Gain",
	Style = "Knob",
	Position = { left + 214, top + 28 },
	Size = { 36, 36 },
}

table.insert(graphics, {
	Type = "GroupBox",
	Text = "Knob",
	HTextAlign = "Left",
	StrokeWidth = 1,
	CornerRadius = 8,
	Position = { left + 8, top + 8 },
	Size = { 265, 100 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Reference",
	Position = { left + 12, top + 72 },
	Size = { 64, 16 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Dolby\nLevel",
	Position = { left + 76, top + 72 },
	Size = { 64, 32 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Inc/Dec",
	Position = { left + 140, top + 72 },
	Size = { 64, 16 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "RMS Level (dBFS)",
	Position = { left + 202, top + 72 },
	Size = { 64, 32 },
})
