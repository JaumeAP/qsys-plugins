local list = {}
for _, elem in ipairs(Model) do
	table.insert(list, elem.value)
end
table.insert(props, { Name = "Model", Type = "enum", Choices = list, Value = Model.CP850.value })
table.insert(props, { Name = "TCP Log", Type = "enum", Choices = { 'Command', 'All' }, Value = 'Command' })
