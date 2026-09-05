-- Q-SYS embedded "stepper" component. A control-type helper (drives a
-- numeric value control from a stepper button pair), not an audio DSP
-- block -- it has no audio pins at all.
--
-- Confirmed by absence, not by a docs page: DolbyFader and Dolby CPSeries
-- Control both declare a "Step" component of this Type and neither
-- declares GetPins/GetWiring at all (see their own test_dist_*.lua
-- assertions), which is exactly what "no audio pins" predicts.

return function(props)
	return {}
end
