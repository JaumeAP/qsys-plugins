table.insert(ctrls, {
	Name = "Start",
	ControlType = "Button",
	ButtonType = "Toggle",
})

table.insert(ctrls, {
	Name = "Enable",
	ControlType = "Button",
	ButtonType = "Toggle",
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "Trigger",
	ControlType = "Button",
	ButtonType = "Trigger",
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "Mute",
	ControlType = "Button",
	ButtonType = "Toggle",
	UserPin = true,
	PinStyle = "Both",
})

table.insert(ctrls, {
	Name = "Period",
	ControlType = "Text",
})

table.insert(ctrls, {
	Name = "Frequency",
	ControlType = "Knob",
	ControlUnit = "Hz",
	Min = 10,
	Max = 22000,
	UserPin = true,
	PinStyle = "Output",
})

table.insert(ctrls, {
	Name = "Level",
	ControlType = "Knob",
	ControlUnit = "dB",
	Min = -100,
	Max = 20,
	UserPin = true,
	PinStyle = "Both",
})
