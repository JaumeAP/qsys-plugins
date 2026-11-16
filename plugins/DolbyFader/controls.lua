table.insert(ctrls, {
	Name = "Ref",
	ControlType = "Button",
	ButtonType = "Momentary",
})

table.insert(ctrls, {
	Name = "Level",
	ControlType = "Text",
	UserPin = true,
	PinStyle = "Both",
})

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
	Name = "Increase",
	ControlType = "Button",
	ButtonType = "Momentary",
	IconType = "Icon",
	Icon = "Plus",
	IconColor = { 0, 0, 0 },
})

table.insert(ctrls, {
	Name = "Decrease",
	ControlType = "Button",
	ButtonType = "Momentary",
	IconType = "Icon",
	Icon = "Minus",
	IconColor = { 0, 0, 0 },
})
