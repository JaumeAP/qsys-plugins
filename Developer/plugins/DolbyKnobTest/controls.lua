table.insert(ctrls, {
	Name = "GainDb",
	ControlType = "Knob",
	ControlUnit = "dB",
	Min = -90,
	Max = 10,
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "GainDbText",
	ControlType = "Text",
	UserPin = false,
})
