table.insert(props, {
	Name = "Channels",
	Type = "integer",
	Value = 1,
	Min = 1,
	Max = 256,
})

table.insert(props, {
	Name = "Detection",
	Type = "enum",
	Choices = { "On", "Off", "Both" },
	Value = "Both",
})
