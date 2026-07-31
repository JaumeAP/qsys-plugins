for t = 1, Properties["InputCount"].Value do
	Controls["State_" .. t].EventHandler = function(ctrl)
		Controls["Out_" .. t]:Trigger()
	end
end
