local left1 = 5
local left2 = 149
local top = 5

table.insert(graphics, {
	Type = "GroupBox",
	Text = "Run",
	HTextAlign = "Left",
	StrokeWidth = 1,
	CornerRadius = 8,
	Position = { left1, top },
	Size = { 136, 100 },
})

table.insert(graphics, {
	Type = "GroupBox",
	Text = "Sweep",
	HTextAlign = "Left",
	StrokeWidth = 1,
	CornerRadius = 8,
	Position = { left2, top },
	Size = { 208 + 64, 100 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Free-Run",
	HTextAlign = "Center",
	VTextAlign = "Center",
	StrokeWidth = 0,
	CornerRadius = 0,
	Position = { left1 + 4, top + 40 + 24 },
	Size = { 64, 16 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "One-Shot/Sync",
	HTextAlign = "Center",
	VTextAlign = "Center",
	StrokeWidth = 0,
	CornerRadius = 0,
	Position = { left1 + 4 + 64, top + 40 + 24 },
	Size = { 64, 32 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Mute",
	HTextAlign = "Center",
	VTextAlign = "Center",
	StrokeWidth = 0,
	CornerRadius = 0,
	Position = { left2 + 4, top + 40 + 24 },
	Size = { 64, 16 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Period",
	HTextAlign = "Center",
	VTextAlign = "Center",
	StrokeWidth = 0,
	CornerRadius = 0,
	Position = { left2 + 4 + 64, top + 40 + 24 },
	Size = { 64, 16 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Frequency",
	HTextAlign = "Center",
	VTextAlign = "Center",
	StrokeWidth = 0,
	CornerRadius = 0,
	Position = { left2 + 4 + 128, top + 40 + 24 },
	Size = { 64, 16 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "RMS Level (dBFS)",
	HTextAlign = "Center",
	VTextAlign = "Center",
	StrokeWidth = 0,
	CornerRadius = 0,
	Position = { left2 + 4 + 128 + 64, top + 40 + 24 },
	Size = { 64, 32 },
})

left1 = left1 + 18
left2 = left2 + 18
top = top + 20

layout["Enable"] = {
	PrettyName = "Enable",
	Style = "Button",
	ButtonStyle = "Toggle",
	Position = { left1, top + 20 },
	Color = { 242, 137, 174 },
	Size = { 36, 16 },
}
layout["Trigger"] = {
	PrettyName = "Trigger",
	Style = "Button",
	ButtonStyle = "Trigger",
	Position = { left1 + 64, top + 20 },
	Color = { 255, 255, 255 },
	Size = { 36, 16 },
}
layout["Mute"] = {
	PrettyName = "Mute",
	Style = "Button",
	ButtonStyle = "Toggle",
	Position = { left2, top + 20 },
	Color = { 223, 0, 36 },
	Size = { 36, 16 },
}
layout["Period"] = {
	PrettyName = "Duty Cycle",
	Style = "Knob",
	Color = { 254, 248, 174 },
	Position = { left2 + 64, top },
	Size = { 36, 36 },
}
layout["Frequency"] = {
	PrettyName = "Frequency",
	Style = "Knob",
	IsReadOnly = true,
	Position = { left2 + 128, top },
	Size = { 36, 36 },
}
layout["Level"] = {
	PrettyName = "RMS Level (dBFS)",
	Style = "Knob",
	Position = { left2 + 128 + 64, top },
	Size = { 36, 36 },
}
