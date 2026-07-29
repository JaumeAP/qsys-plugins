table.insert(props, {
	Name = "Type",
	Type = "enum",
	Choices = { "Mono", "Stereo", "Multi-channel" },
	Value = "Mono",
})

table.insert(props, {
	Name = "Count",
	Type = "integer",
	Value = 8,
	Min = 2,
	Max = 256,
})
