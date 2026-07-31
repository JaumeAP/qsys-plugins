local top = 20

table.insert(graphics, {
	Type = "Label",
	Text = "State",
	StrokeWidth = 0,
	VTextAlign = "Center",
	Position = { 36 * 1, top },
	Size = { 36, 32 },
})

table.insert(graphics, {
	Type = "Label",
	Text = "Out",
	StrokeWidth = 0,
	VTextAlign = "Center",
	Position = { 36 * 2 + 4, top },
	Size = { 36, 32 },
})

for t = 1, props["Channels"].Value do
	table.insert(graphics, {
		Type = "Label",
		Text = tostring(t),
		StrokeWidth = 0,
		Position = { 0, top + (t + 1) * 16 },
		Size = { 32, 16 },
	})

	layout["State_" .. t] = { PrettyName = tostring(t) .. "~State", Position = { 36 * 1, top + (t + 1) * 16 } }
	layout["Out_" .. t] = { PrettyName = tostring(t) .. "~Out", Position = { 36 * 2 + 16, top + (t + 1) * 16 } }
end
