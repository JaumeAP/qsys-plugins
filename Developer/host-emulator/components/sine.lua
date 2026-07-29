-- Q-SYS embedded "sine" component (Sine Generator). Exposes exactly one
-- output pin, unnumbered ("Output", not "Output 1"), and no input pin.
--
-- Confirmed (2026-07-29): a web search summary of Q-SYS Help's own Sine
-- Generator page states the component has one output pin by default.
-- Matches Dolby Sweep's own pre-existing GetWiring, which wires it as
-- "Sine Output" -- this file records that as a checked fact, not an
-- inference from the plugin's own code.

return function(props)
	return { "Output" }
end
