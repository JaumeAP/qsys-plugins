-- Q-SYS embedded "filter_lowpass" component (Low-Pass Filter).
--
-- NOT independently confirmed against Q-SYS Help (both help.qsys.com and
-- q-syshelp.qsc.com 403'd repeatedly on 2026-07-29, the session this file
-- was written). This mirrors the numbered "Input 1"/"Output 1" convention
-- confirmed for "mixer" (see mixer.lua) and matches what SubharmonicSynth's
-- own GetWiring already ships in production ("Lpf Input 1"/"Lpf Output 1",
-- inherited from an external contribution). Treat this file as the thing to
-- re-verify against Q-SYS Help first if a real Q-SYS host ever disagrees
-- with it -- per this repo's own standing convention, not as settled fact
-- the way mixer.lua/sine.lua are.

return function(props)
	return { "Input 1", "Output 1" }
end
