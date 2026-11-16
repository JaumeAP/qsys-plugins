table.insert(ctrls, {
	Name = "Start",
	ControlType = "Button",
	ButtonType = "Toggle",
})

table.insert(ctrls, {
	Name = "Exclusive",
	ControlType = "Button",
	ButtonType = "Toggle",
})

for t = 1, props["InputCount"].Value do
	table.insert(ctrls, {
		Name = "Set_" .. t,
		ControlType = "Button",
		ButtonType = "Trigger",
		UserPin = true,
		PinStyle = "Both",
	})

	table.insert(ctrls, {
		Name = "Reset_" .. t,
		ControlType = "Button",
		ButtonType = "Trigger",
		UserPin = true,
		PinStyle = "Both",
	})

	table.insert(ctrls, {
		Name = "Toggle_" .. t,
		ControlType = "Button",
		ButtonType = "Trigger",
		UserPin = true,
		PinStyle = "Both",
	})

	table.insert(ctrls, {
		Name = "State_" .. t,
		ControlType = "Button",
		ButtonType = "Toggle",
		UserPin = true,
		PinStyle = "Both",
	})

	table.insert(ctrls, {
		Name = "Led_" .. t,
		ControlType = "Indicator",
		IndicatorType = "Led",
		Count = 2,
		UserPin = true,
		PinStyle = "Both",
	})

	table.insert(ctrls, {
		Name = "Out_" .. t,
		ControlType = "Indicator",
		IndicatorType = "Led",
		UserPin = true,
		PinStyle = "Output",
	})

	table.insert(ctrls, {
		Name = "Not_" .. t,
		ControlType = "Indicator",
		IndicatorType = "Led",
		UserPin = true,
		PinStyle = "Output",
	})
end
