local function reset(t)
	if not Controls.Exclusive.Boolean then return end
	for v = 1, Properties["InputCount"].Value do
		if v ~= t then
			Controls["Reset_" .. v]:Trigger()
			Controls["State_" .. v].Boolean = false
			Controls['Out_' .. v].Value = 0
			Controls['Not_' .. v].Value = 1
		end
	end
end

Controls.Exclusive.EventHandler = function(ctrl)
	local first = false
	for t = 1, Properties["InputCount"].Value do
		if first then
			Controls["State_" .. t].Boolean = false
			Controls["Reset_" .. t]:Trigger()
			Controls['Out_' .. t].Value = 0
			Controls['Not_' .. t].Value = 1
		elseif Controls["State_" .. t].Boolean then
			first = true
		end
	end
end

for t = 1, Properties["InputCount"].Value do

	Controls["State_" .. t].EventHandler = function(ctrl)
		reset(t)
		if Controls["State_" .. t].Boolean then
			Controls["Set_" .. t]:Trigger()
			Controls['Out_' .. t].Value = 1
			Controls['Not_' .. t].Value = 0
		else
			Controls["Reset_" .. t]:Trigger()
			Controls['Out_' .. t].Value = 0
			Controls['Not_' .. t].Value = 1
		end
	end

	Controls["Set_" .. t].EventHandler = function(ctrl)
		reset(t)
		Controls["State_" .. t].Boolean = true
		Controls['Out_' .. t].Value = 1
		Controls['Not_' .. t].Value = 0
	end

	Controls["Reset_" .. t].EventHandler = function(ctrl)
		Controls["State_" .. t].Boolean = false
		Controls['Out_' .. t].Value = 0
		Controls['Not_' .. t].Value = 1
	end

	Controls["Toggle_" .. t].EventHandler = function(ctrl)
		Controls["State_" .. t].Boolean = not Controls["State_" .. t].Boolean
		Controls["State_" .. t].EventHandler()
	end

end

for t = 1, Properties["InputCount"].Value do
	if Controls["State_" .. t].Boolean then
		Controls["Set_" .. t]:Trigger()
		Controls['Out_' .. t].Value = 1
		Controls['Not_' .. t].Value = 0
	else
		Controls["Reset_" .. t]:Trigger()
		Controls['Out_' .. t].Value = 0
		Controls['Not_' .. t].Value = 1
	end
end
