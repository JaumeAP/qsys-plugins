for t = 1, Properties["Channels"].Value do
	Controls["State_" .. t].EventHandler = function(ctrl)
		local mode = Properties["Detection"].Value
		local becameActive = ctrl.Boolean
		if mode == "Both" or (mode == "On" and becameActive) or (mode == "Off" and not becameActive) then
			Controls["Out_" .. t]:Trigger()
		end
	end
end
