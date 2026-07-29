-- Throwaway probe: does PLUGCC.exe resolve an #include path outside this
-- file's own folder? If the built .qplug's GetControls contains
-- "SharedMarkerControl", the cross-folder include worked.

--[[ #include "info.lua" ]]

function GetColor(props)
	return { 100, 100, 100 }
end

function GetPrettyName(props)
	return "Include Test"
end

function GetProperties()
	local props = {}
	return props
end

function GetControls(props)
	local ctrls = {}
	--[[ #include "../shared/shared.lua" ]]
	return ctrls
end

function GetControlLayout(props)
	local layout = {}
	local graphics = {}
	return layout, graphics
end

if Controls then
end
