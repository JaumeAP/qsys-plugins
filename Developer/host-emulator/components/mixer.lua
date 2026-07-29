-- Q-SYS embedded "mixer" component. Pins are numbered per its own
-- n_inputs/n_outputs Properties: "Input 1".."Input n_inputs" and
-- "Output 1".."Output n_outputs".
--
-- Confirmed (2026-07-29) against a real plugin's GetWiring, not guessed:
-- gdyr/qsys-plugin-docs wires a 1-output mixer as
-- "main_mixer Input i" / "main_mixer Output 1".

return function(props)
	props = props or {}
	local pins = {}
	for i = 1, (props["n_inputs"] or 1) do
		table.insert(pins, "Input " .. i)
	end
	for i = 1, (props["n_outputs"] or 1) do
		table.insert(pins, "Output " .. i)
	end
	return pins
end
