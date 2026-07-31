table.insert(ctrls, {
	Name = "Gain",
	ControlType = "Knob",
	ControlUnit = "dB",
	Min = -100,
	Max = 20,
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "GainDb",
	ControlType = "Text",
	UserPin = true,
	PinStyle = "Both",
})
