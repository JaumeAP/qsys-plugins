local W, H = 360, 180

table.insert(graphics, {
	Type = "GroupBox",
	Text = "SubharmonicSynth",
	Position = { 5, 5 },
	Size = { W - 10, H - 10 },
	Fill = { 30, 30, 30 },
	StrokeColor = { 80, 80, 80 },
	StrokeWidth = 1,
	CornerRadius = 6,
})

local knobs = {
	{ name = "DryLevel", x = 15,  label = "Dry"    },
	{ name = "SubLevel", x = 75,  label = "Sub"    },
	{ name = "SubGain",  x = 135, label = "Boost"  },
	{ name = "QFactor",  x = 195, label = "Sub Q"  },
	{ name = "Cutoff",   x = 248, label = "LPF Hz" },
}

for _, k in ipairs(knobs) do
	layout[k.name] = {
		Style = "Knob",
		Position = { k.x, 35 },
		Size = { 50, 80 },
	}
	table.insert(graphics, {
		Type = "Label",
		Text = k.label,
		Position = { k.x, 120 },
		Size = { 50, 14 },
		FontSize = 9,
		HTextAlign = "Center",
		Color = { 180, 180, 180 },
	})
end

layout["Bypass"] = {
	Style = "Button",
	ButtonStyle = "Toggle",
	Legend = "Bypass",
	Position = { 308, 65 },
	Size = { 44, 26 },
	Color = { 180, 60, 0 },
	OffColor = { 60, 60, 60 },
	UnlinkOffColor = true,
}
