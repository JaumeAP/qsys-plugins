local mv = ModelValue(props)
table.insert(graphics, { Type = "GroupBox", CornerRadius = 5, Fill = { 255, 237, 213, 255 }, StrokeWidth = 1, StrokeColor = { 255, 140, 0 }, Position = { -5, -5 }, Size = { 260, 110 }, Padding = 0, Margin = 0 })
table.insert(graphics, { Type = "Label", Text = "CP Series Emulator", Fill = { 255, 237, 213, 255 }, Size = { 200, 24 }, Position = { 10, 6 }, IsBold = true, FontSize = 16 })
table.insert(graphics, { Type = "Label", Text = mv, Fill = { 255, 237, 213, 255 }, Size = { 200, 18 }, Position = { 10, 30 }, FontSize = 12 })
table.insert(graphics, { Type = "GroupBox", HTextAlign = "Left", Text = "Status", StrokeWidth = 1, CornerRadius = 8, Position = { 10, 54 }, Size = { 240, 44 } })
layout['Status.Led'] = { PrettyName = 'Emulator Status', Style = "Led", Margin = 3, Position = { 24, 76 }, Size = { 16, 16 } }
layout['Status'] = { PrettyName = 'Emulator Status', Position = { 48, 68 }, Size = { 190, 32 } }
