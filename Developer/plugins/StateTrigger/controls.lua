for t = 1, props["Channels"].Value do
	table.insert(ctrls, {
		Name = "State_" .. t,
		ControlType = "Button",
		ButtonType = "Toggle",
		UserPin = true,
		PinStyle = "Input",
	})

	table.insert(ctrls, {
		Name = "Out_" .. t,
		ControlType = "Button",
		ButtonType = "Trigger",
		UserPin = true,
		PinStyle = "Output",
	})
end
