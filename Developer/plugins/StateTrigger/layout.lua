table.insert(graphics, {
	Type = "Label",
	Text = "State",
	StrokeWidth = 0,
	VTextAlign = "Center",
	Position = { 0, 0 },
	Size = { 64, 32 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Out",
	StrokeWidth = 0,
	VTextAlign = "Center",
	Position = { 96, 0 },
	Size = { 64, 32 },
})

layout["State"] = { PrettyName = "State", Position = { 0, 32 } }
layout["Out"] = { PrettyName = "Out", Position = { 96, 32 } }
