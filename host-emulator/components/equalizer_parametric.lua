-- Q-SYS embedded "equalizer_parametric" component (Parametric Equalizer).
--
-- Confirmed (2026-07-31): direct fetches of help.qsys.com/q-syshelp.qsc.com
-- still 403 (same block hit 2026-07-29), but a web search's own crawled
-- index of Q-SYS Help's equalizer_parametric.htm page states the component
-- defaults to Mono -- one input, one output -- with Stereo (2/2) and
-- Multi-Channel (2-256) as opt-in Properties, the same source category
-- that confirmed sine.lua. That corroborates the "Input 1"/"Output 1"
-- convention for the Mono case this file emulates, and matches
-- SubharmonicSynth's own GetWiring, which wires it as "Peq Input 1"/
-- "Peq Output 1" (previously the only evidence for this file).
-- Stereo/Multi-Channel pin naming is NOT modeled -- no plugin in this repo
-- uses equalizer_parametric outside Mono, so extending this file for an
-- untested channel count would be speculative; revisit if that changes.

return function(props)
	return { "Input 1", "Output 1" }
end
