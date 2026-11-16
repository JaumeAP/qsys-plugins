local col = 70
local row = 6
local gutter = 50
local mv = ModelValue(props)
local numButtons = mv == Model.CP750.value and 7 or 8
table.insert(graphics, { Type = "GroupBox", CornerRadius = 5, Fill = { 255, 245, 232, 255 }, StrokeWidth = 1, StrokeColor = { 241, 199, 245 }, Position = { -5, -5 }, Size = { 358, 368 }, Padding = 0, Margin = 0 })
table.insert(graphics, { Type = "Label", Text = mv, Fill = { 255, 245, 232, 255 }, Size = { 160, 28 }, Position = { 46 + gutter, row }, IsBold = true, FontSize = 24 })
row = row + 40
table.insert(graphics, { Type = "Label", HTextAlign = "Right", Text = "IP:", Position = { gutter, row }, Size = { 44, 16 } })
layout['Address'] = { PrettyName = 'Address', Position = { gutter + 50, row }, Size = { 140, 16 } }
layout['Refresh'] = { PrettyName = 'Refresh Connection', FontStyle = 'Black', Position = { gutter + 190, row }, Size = { 36, 16 }, Margin = 0 }
row = row + 32
table.insert(graphics, { Type = "GroupBox", HTextAlign = "Left", Text = "Status", StrokeWidth = 1, CornerRadius = 8, Position = { 10, row - 5 }, Size = { 330, 64 } })
layout['Status.Led'] = { PrettyName = 'CP Status', Style = "Led", Margin = 3, Position = { gutter - 14, row + 22 }, Size = { 16, 16 } }
layout['Status'] = { PrettyName = 'CP Status', Position = { gutter + 10, row + 14 }, Size = { 262, 32 } }
row = row + 48 + 24
local left = 0
local top = row
layout['Ref'] = { PrettyName = "Ref Level", Style = "Button", ButtonStyle = "Momentary", Color = { 242, 137, 174 }, Size = { 36, 16 }, Position = { left + 26, top + 48 } }
layout['Level'] = { PrettyName = 'Dolby Level', Style = "Knob", Color = { 0, 226, 113 }, Position = { left + 90, top + 28 }, Size = { 36, 36 } }
layout['Increase'] = { PrettyName = "Increase", Style = "Button", ButtonStyle = "Momentary", Color = { 255, 255, 255 }, Position = { left + 154, top + 28 }, Size = { 36, 16 } }
layout['Decrease'] = { PrettyName = "Decrease", Style = "Button", ButtonStyle = "Momentary", Color = { 255, 255, 255 }, Size = { 36, 16 }, Position = { left + 154, top + 48 } }
layout["Gain"] = { PrettyName = "Gain", Style = "Knob", Position = { left + 214, top + 28 }, Size = { 36, 36 } }
layout['Mute'] = { PrettyName = 'Mute', CornerRadius = 20, Color = { 255, 0, 0 }, UnlinkOffColor = true, OffColor = { 100, 100, 100 }, Padding = 10, Radius = 5, Position = { left + 214 + 64, top + 22 }, Size = { 46, 46 } }
table.insert(graphics, { Type = "GroupBox", Text = "Level", HTextAlign = "Left", StrokeWidth = 1, CornerRadius = 8, Position = { left + 10, top + 8 }, Size = { 330, 100 } })
table.insert(graphics, { Type = "Label", Text = "Reference", Position = { left + 12, top + 72 }, Size = { 64, 16 } })
table.insert(graphics, { Type = "Label", Text = "Dolby\nLevel", Position = { left + 76, top + 72 }, Size = { 64, 32 } })
table.insert(graphics, { Type = "Label", Text = "Inc/Dec", Position = { left + 140, top + 72 }, Size = { 64, 16 } })
table.insert(graphics, { Type = "Label", Text = "RMS Level (dBFS)", Position = { left + 202, top + 72 }, Size = { 64, 32 } })
table.insert(graphics, { Type = "Label", Text = "Mute", Position = { left + 202 + 64, top + 72 }, Size = { 64, 32 } })
row = row + 130
table.insert(graphics, { Type = "Label", Text = "Format:", HTextAlign = "Right", Position = { gutter - 46, row + 1 }, Size = { 90, 16 } })
layout['Select'] = { PrettyName = 'Select', Style = "ComboBox", TextFontSize = 12, Position = { gutter + 50, row }, Size = { 170, 18 } }
row = row + 32 col = 36
local btnLayout, macro, proc
local assign = {
	[Model.CP650.value] = function() macro = 'Button' proc = Model.CP650.index btnLayout = ButtonLabel[1] end,
	[Model.CP750.value] = function() macro = 'Button' proc = Model.CP750.index btnLayout = ButtonLabel[2] end,
	[Model.CP850.value] = function() macro = 'Macro'  proc = Model.CP850.index btnLayout = ButtonLabel[3] end,
	[Model.CP950.value] = function() macro = 'Macro'  proc = Model.CP950.index btnLayout = ButtonLabel[4] end,
	[Model.CP950A.value] = function() macro = 'Macro'  proc = Model.CP950A.index btnLayout = ButtonLabel[5] end,
}
assign[mv]()
local v = mv == Model.CP750.value and gutter or gutter - 20
for i = 1, numButtons do
	layout['Selector ' .. i] = { PrettyName = macro .. '~' .. ButtonLabel[proc][i], Legend = btnLayout[i], Position = { v, row },
			Color = { 0, 255, 0 }, FontStyle = 'Bold', fontSize = 14, CornerRadius = 20, ButtonStyle = "On", Size = { 36, 36 } }
	v = v + col
end
