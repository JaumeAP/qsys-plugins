local list = {}
for _, elem in ipairs(Model) do
	table.insert(list, elem.value)
end
table.insert(props, { Name = "Model", Type = "enum", Choices = list, Value = Model.CP750.value })
