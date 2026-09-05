table.insert(ctrls, {
	Name = "DryLevel",
	ControlType = "Knob",
	ControlUnit = "dB",
	Min = -100,
	Max = 20,
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "SubLevel",
	ControlType = "Knob",
	ControlUnit = "dB",
	Min = -100,
	Max = 20,
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "SubGain",
	ControlType = "Knob",
	ControlUnit = "dB",
	Min = -20,
	Max = 20,
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "QFactor",
	ControlType = "Knob",
	ControlUnit = "Float",
	Min = 0.1,
	Max = 10.0,
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "Cutoff",
	ControlType = "Knob",
	ControlUnit = "Hz",
	Min = 20,
	Max = 120,
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "Bypass",
	ControlType = "Button",
	ButtonType = "Toggle",
	UserPin = true,
	PinStyle = "Both",
})
