local top = 20

table.insert(graphics, {
	Type = "Label",
	Text = "Exclusive",
	StrokeWidth = 0,
	VTextAlign = "Center", -- FIX: was 'VAlign = Center' (wrong key, undefined global)
	Position = { 144, 0 },
	Size = { 64, 16 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Set",
	StrokeWidth = 0,
	VTextAlign = "Center",
	Position = { 36 * 1, top },
	Size = { 36, 32 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Reset",
	StrokeWidth = 0,
	VTextAlign = "Center",
	Position = { 36 * 2, top },
	Size = { 36, 32 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Toggle",
	StrokeWidth = 0,
	VTextAlign = "Center",
	Position = { 36 * 3, top },
	Size = { 36, 32 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "State",
	StrokeWidth = 0,
	VTextAlign = "Center",
	Position = { 36 * 4, top },
	Size = { 36, 32 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Out",
	VTextAlign = "Center",
	StrokeWidth = 0,
	Position = { 36 * 5 + 4, top },
	Size = { 36, 32 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Not Out",
	StrokeWidth = 0,
	VTextAlign = "Center",
	Position = { 36 * 6 + 8, top },
	Size = { 36, 32 },
})

for t = 1, props["InputCount"].Value do
	table.insert(graphics, {
		Type = "Label",
		Text = tostring(t),
		StrokeWidth = 0,
		Position = { 0, top + (t + 1) * 16 },
		Size = { 32, 16 },
	})

	layout['Exclusive'] = { PrettyName = "Exclusive", Position = { 210, 0 } }
	layout['Set_' .. t] = { PrettyName = tostring(t) .. "~Set", Position = { 36 * 1, top + (t + 1) * 16 } }
	layout['Reset_' .. t] = { PrettyName = tostring(t) .. "~Reset", Position = { 36 * 2, top + (t + 1) * 16 } }
	layout['Toggle_' .. t] = { PrettyName = tostring(t) .. "~Toggle", Position = { 36 * 3, top + (t + 1) * 16 } }
	layout['State_' .. t] = { PrettyName = tostring(t) .. "~State", Position = { 36 * 4, top + (t + 1) * 16 } }
	layout['Out_' .. t] = { PrettyName = tostring(t) .. "~Out", Position = { 36 * 5 + 16, top + (t + 1) * 16 } }
	layout['Not_' .. t] = { PrettyName = tostring(t) .. "~Not out", Position = { 36 * 6 + 16, top + (t + 1) * 16 } }
end
