-- Stress and fuzz pass over all five plugins.
--
-- The other test files pin down exact values for known-good inputs. This one
-- does the opposite: it hammers each plugin with volume, boundary values and
-- deliberate garbage, and asserts only the invariants that have to survive
-- all of it -- nothing throws, nothing publishes a nil, and every value a
-- plugin writes stays inside the range it declares. That split is deliberate:
-- an exact-value test tells you the happy path still works, this one tells
-- you the component does not take a Q-SYS core down when a processor sends
-- something nobody anticipated.
--
-- Deterministic on purpose. math.randomseed is fixed, so a failure here is
-- reproducible from the same seed rather than a once-per-run mystery that
-- disappears when you look at it.
--
-- Each section reports one aggregate check per invariant rather than one per
-- iteration -- 9000 individually-reported poll ticks would bury every other
-- result in the suite without saying anything more.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

math.randomseed(20260729)

-- Shuffle in place, so the fuzz corpus arrives in a different order per pass
-- without changing what is in it (ordering bugs and content bugs are
-- different failures; this keeps both reachable).
local function shuffled(t)
	local c = {}
	for i, v in ipairs(t) do c[i] = v end
	for i = #c, 2, -1 do
		local j = math.random(i)
		c[i], c[j] = c[j], c[i]
	end
	return c
end

-- ---------------------------------------------------------------------------
-- CP Series: the protocol surface, which is the only place in this repo where
-- untrusted bytes from a physical device reach plugin code.
-- ---------------------------------------------------------------------------

local env = qsys.install({ properties = qsys.cpseries_properties("CP 850") })

-- install() clears the plugin globals, Model among them, so it is rebuilt
-- here rather than before -- same reason test_modules.lua does it in this
-- order.
Model = {}
for i, m in ipairs({
	{ key = "CP650",  value = "CP 650"  },
	{ key = "CP750",  value = "CP 750"  },
	{ key = "CP850",  value = "CP 850"  },
	{ key = "CP950",  value = "CP 950"  },
	{ key = "CP950A", value = "CP 950A" },
}) do
	m.index = i
	Model[i] = m
	Model[m.key] = m
end

do
	local dir = h.plugins .. "/Dolby CPSeries Control"
	assert(loadfile(dir .. "/models.lua"))()
	assert(loadfile(dir .. "/protocol.lua"))()
	assert(loadfile(dir .. "/commlib.lua"))()
end

local function fake_sock()
	local s = { IsConnected = true, writes = {}, lines = {} }
	function s:Write(m) self.writes[#self.writes + 1] = (m:gsub("\r\n$", "")) end
	function s:ReadLine() if #self.lines == 0 then return nil end return table.remove(self.lines, 1) end
	return s
end

local READY = {
	["CP 650"]  = "fader_level=42",
	["CP 750"]  = "cp750.sysinfo.version 1.0",
	["CP 850"]  = "sys.fader 42",
	["CP 950"]  = "sys.fader 42",
	["CP 950A"] = "sys.fader 42",
}

-- Wire junk: real parameter names carrying broken values, malformed macro-list
-- rows, oversized payloads, and tokens that only look numeric. Values like
-- "1e400" and "9999999999999999" matter specifically because they survive
-- tonumber() and then fail string.format('%.f') round-tripping, which is the
-- exact path commlib.lua guards against.
local FUZZ = {
	"", " ", "\t", "\r", "\r\n",
	"sys.fader", "sys.fader ", "sys.fader ?", "sys.fader NaN", "sys.fader nan",
	"sys.fader inf", "sys.fader -inf", "sys.fader 1e400", "sys.fader -1e400",
	"sys.fader 0x10", "sys.fader --5", "sys.fader 9999999999999999",
	"sys.fader " .. string.rep("9", 400),
	"sys.mute yes", "sys.mute 2", "sys.mute -1", "sys.mute ",
	"sys.macro_preset -1", "sys.macro_preset 0", "sys.macro_preset 2147483648",
	"sys.macro_preset abc", "sys.macro_preset ",
	"sys.macro_name", "sys.macro_name ",
	"sys.macros", "sys.macros -5", "sys.macros 999999", "sys.macros abc",
	":", "0:", ":name", "-1:x", "999999:x", "1:", "1:" .. string.rep("n", 512),
	string.rep("A", 4096),
	"fader_level=", "fader_level=?", "fader_level=abc", "fader_level==5",
	"fader_level=1e400",
	"format_list=", "format_list=,,,", "format_list=1,,3", "format_list=a,b,c",
	"format_list=" .. string.rep("1,", 900) .. "1",
	"cp750.sys.fader ", "cp750.sys.fader abc",
	"cp750.sys.input_mode ", "cp750.sys.input_mode dig_9",
	"cp750.sys.input_mode " .. string.rep("z", 300),
	"cp750.sys.mute maybe",
	"%d%s%%", "^$.*+?()[]", "\0", "a\0b",

	-- Values that are extreme but genuinely parseable, in each model's own
	-- dialect. Without these the corpus above is all rejected before it
	-- reaches the fader/mute/format handlers, and the invariants below would
	-- pass without those code paths ever running -- measured directly: CP 650
	-- and CP 750 saw nothing but formlist until these were added. Each model
	-- also gets the other dialects' lines, which is worth exercising in its
	-- own right: a CP 650 must ignore CP 850 traffic rather than misparse it.
	"fader_level=0", "fader_level=-1", "fader_level=100", "fader_level=999999",
	"mute=0", "mute=1", "mute=2",
	"format_button=0", "format_button=-5", "format_button=99999",
	"cp750.sys.fader 0", "cp750.sys.fader -1", "cp750.sys.fader 999999",
	"cp750.sys.mute 0", "cp750.sys.mute 1", "cp750.sys.mute 2",
	"cp750.sys.input_mode dig_1", "cp750.sys.input_mode mic",
	"sys.fader 0", "sys.fader -1", "sys.fader 999999",
	"sys.mute 0", "sys.mute 1",
	"sys.macro_preset 1", "sys.macro_name Flat",
	"sys.macros 2", "1:Flat", "2:Curve A",
}

h.section("CP Series: wire fuzzing, every model")
for _, model in ipairs(h.MODELS) do
	local cp = CPSeries.New(model)
	local sock = fake_sock()
	local nil_results, bad_number, bad_list, published = 0, 0, 0, 0

	cp.EventHandler = function(service, result)
		published = published + 1
		if result == nil then nil_results = nil_results + 1 end
		if (service == "fader" or service == "mute") and type(result) ~= "number" then
			bad_number = bad_number + 1
		end
		if service == "formlist" and type(result) ~= "table" then
			bad_list = bad_list + 1
		end
	end

	cp:Start(sock)
	sock.lines = { READY[model] }
	sock.Data()

	-- Only fuzz-driven events should count towards the "did this actually
	-- reach the parser" check below; the readiness handshake above fires one
	-- on its own and would mask a corpus that gets rejected wholesale.
	published = 0

	-- Three passes: one line at a time, then the whole corpus in a single
	-- readData drain, then reshuffled one-at-a-time again. The bulk pass is
	-- the one that exercises readData's own loop and the macro-list
	-- accumulator draining mid-stream.
	local threw = nil
	for pass = 1, 3 do
		local corpus = shuffled(FUZZ)
		if pass == 2 then
			sock.lines = corpus
			local ok, err = pcall(sock.Data)
			if not ok then threw = err end
		else
			for _, line in ipairs(corpus) do
				sock.lines = { line }
				local ok, err = pcall(sock.Data)
				if not ok then threw = err break end
			end
		end
		if threw then break end
	end

	h.check(threw == nil, model .. ": " .. (#FUZZ * 3) .. " junk lines never throw (" .. tostring(threw) .. ")")
	h.check(nil_results == 0, model .. ": no event published with a nil result (got " .. nil_results .. ")")
	h.check(bad_number == 0, model .. ": fader/mute always publish a number (got " .. bad_number .. " that did not)")
	h.check(bad_list == 0, model .. ": formlist always publishes a table (got " .. bad_list .. " that did not)")
	-- Guards the three checks above against passing vacuously: if a refactor
	-- ever makes this model reject the whole corpus before parsing it, the
	-- invariants would still hold trivially and say nothing.
	h.check(published > 0, model .. ": the corpus actually reached the parser (" .. published .. " events published)")

	cp:Stop()
end

h.section("CP Series: sustained polling past the npoll wraparound")
do
	-- pollAction cycles on npoll % 0x2000, so the counter has to be pushed
	-- past 8192 for the wraparound itself to be covered rather than assumed.
	local TICKS = 9000
	local cp = CPSeries.New("CP 850")
	local sock = fake_sock()
	local closed = 0
	cp.EventHandler = function(service) if service == "close" then closed = closed + 1 end end
	cp:Start(sock)
	sock.lines = { "sys.fader 42" }
	sock.Data()

	local timer = env.timers[#env.timers]
	local threw = nil
	for i = 1, TICKS do
		-- Feed the device's side often enough that the no-data watchdog never
		-- trips; this section is about the poll loop, not the watchdog.
		if i % 4 == 0 then
			sock.lines = { "sys.fader " .. (i % 100) }
			local ok, err = pcall(sock.Data)
			if not ok then threw = err break end
		end
		local ok, err = pcall(timer.EventHandler)
		if not ok then threw = err break end
	end

	h.check(threw == nil, TICKS .. " poll ticks never throw (" .. tostring(threw) .. ")")
	h.check(closed == 0, "a continuously-answering device is never declared closed (got " .. closed .. ")")
	h.check(#sock.writes > 0, "the poll loop actually wrote to the socket (" .. #sock.writes .. " messages)")

	local malformed = 0
	for _, w in ipairs(sock.writes) do
		if type(w) ~= "string" or w == "" or w:find("\n") then malformed = malformed + 1 end
	end
	h.check(malformed == 0, "every written message is a non-empty single line (got " .. malformed .. " malformed)")

	cp:Stop()
end

h.section("CP Series: the no-data watchdog still fires")
do
	-- The mirror of the section above: a device that stops answering has to be
	-- declared closed rather than polled forever.
	local cp = CPSeries.New("CP 850")
	local sock = fake_sock()
	local closed = 0
	cp.EventHandler = function(service) if service == "close" then closed = closed + 1 end end
	cp:Start(sock)
	sock.lines = { "sys.fader 42" }
	sock.Data()

	local timer = env.timers[#env.timers]
	for _ = 1, 40 do pcall(timer.EventHandler) end
	h.check(closed > 0, "40 unanswered polls declare the connection closed")

	cp:Stop()
end

-- ---------------------------------------------------------------------------
-- Dolby Fader: the dB/Dolby conversion and the QKnob text control behind it.
-- ---------------------------------------------------------------------------

h.section("Dolby Fader: full-range value storm")
do
	local fenv = qsys.install({
		controls = qsys.FADER_CONTROLS,
		properties = { plugin_show_debug = { Value = 0 } },
	})
	assert(loadfile(h.DIST.fader))()

	local out_of_range, threw = 0, nil

	-- Well past both ends of the declared -100..20 dB range, plus the segment
	-- boundary at -10 dB (Dolby 4.0) where the conversion changes formula.
	local dbs = { -1e9, -1000, -100.5, -100, -90, -10.0001, -10, -9.9999, 0, 19.9, 20, 21, 1000, 1e9 }
	for i = 1, 400 do dbs[#dbs + 1] = -150 + math.random() * 300 end

	for _, db in ipairs(dbs) do
		fenv.controls.Gain.Value = db
		local ok, err = pcall(fenv.controls.Gain.EventHandler)
		if not ok then threw = err break end
		if not (DKNob.Value >= 0 and DKNob.Value <= 10) then out_of_range = out_of_range + 1 end
	end
	h.check(threw == nil, #dbs .. " dB values across and beyond the range never throw (" .. tostring(threw) .. ")")
	h.check(out_of_range == 0, "the Dolby value stays within 0.0-10.0 for every dB input (got " .. out_of_range .. " outside)")

	-- The Level text control is user-editable, so it is a garbage-in surface
	-- in its own right: QKnob parses whatever string is typed into it.
	local junk = {
		"", " ", "abc", "-", ".", "..", "1.2.3", "--5", "1e999", "-0", "0",
		"10", "10.0000001", "-99999", string.rep("9", 60), "7 ", " 7", "7dB",
		"\t", "\0", "%d", "NaN", "inf",
	}
	local text_threw, text_out = nil, 0
	for _, s in ipairs(shuffled(junk)) do
		fenv.controls.Level.String = s
		local ok, err = pcall(fenv.controls.Level.EventHandler)
		if not ok then text_threw = err break end
		if not (DKNob.Value >= 0 and DKNob.Value <= 10) then text_out = text_out + 1 end
	end
	h.check(text_threw == nil, "junk typed into the Level text control never throws (" .. tostring(text_threw) .. ")")
	h.check(text_out == 0, "the Dolby value stays within 0.0-10.0 for every typed string (got " .. text_out .. " outside)")

	-- The stepper drives Position directly rather than Value, which is the
	-- one path that bypasses the string parsing above.
	local step_threw, step_out = nil, 0
	for _ = 1, 300 do
		fenv.step.value.Value = -500 + math.random() * 1500
		local ok, err = pcall(fenv.step.value.EventHandler)
		if not ok then step_threw = err break end
		if not (DKNob.Value >= 0 and DKNob.Value <= 10) then step_out = step_out + 1 end
	end
	h.check(step_threw == nil, "300 stepper positions well outside 0-100 never throw (" .. tostring(step_threw) .. ")")
	h.check(step_out == 0, "the Dolby value stays within 0.0-10.0 for every stepper position (got " .. step_out .. " outside)")
end

-- ---------------------------------------------------------------------------
-- Dolby Sweep: the swept oscillator, run for far more cycles than a test
-- normally would, since the sweep resets itself at the top of its range.
-- ---------------------------------------------------------------------------

h.section("Dolby Sweep: sustained sweep")
do
	local SWEEP_CONTROLS = { "Start", "Enable", "Trigger", "Mute", "Period", "Frequency", "Level" }
	local senv = qsys.install({
		controls = SWEEP_CONTROLS,
		trigger_controls = { "Trigger" },
		properties = { plugin_show_debug = { Value = 0 } },
	})
	Sine = { mute = qsys.control(0), level = qsys.control(0), frequency = qsys.control(0) }
	System = { IsEmulating = true }
	assert(loadfile(h.DIST.sweep))()

	senv.controls.Enable.Value = 1
	senv.controls.Enable.EventHandler()

	-- Driven through the plugin's own global timer rather than env.tick, which
	-- pcalls its handlers and would swallow exactly the crash this is looking
	-- for.
	local TICKS = 3000
	local threw, out_of_band, mismatched = nil, 0, 0
	for _ = 1, TICKS do
		local ok, err = pcall(timer.EventHandler)
		if not ok then threw = err break end
		local f = senv.controls.Frequency.Value
		if not (f >= 10 and f <= 22000) then out_of_band = out_of_band + 1 end
		if Sine.frequency.Value ~= f then mismatched = mismatched + 1 end
	end
	h.check(threw == nil, TICKS .. " sweep ticks never throw (" .. tostring(threw) .. ")")
	h.check(out_of_band == 0, "the swept frequency stays within 10-22000 Hz (got " .. out_of_band .. " outside)")
	h.check(mismatched == 0, "Sine.frequency tracks the Frequency control on every tick (got " .. mismatched .. " adrift)")

	-- Control chatter while the sweep runs: retriggering, muting and
	-- re-periodising mid-sweep are all things an operator can actually do.
	local chatter_threw = nil
	for i = 1, 300 do
		local ok, err = pcall(function()
			if i % 3 == 0 then
				senv.controls.Mute.Value = math.random(0, 1)
				senv.controls.Mute.EventHandler()
			end
			if i % 5 == 0 then
				senv.controls.Trigger.EventHandler(senv.controls.Trigger)
			end
			if i % 7 == 0 then
				senv.controls.Period.String = tostring(math.random(1, 8))
				senv.controls.Period.EventHandler()
			end
			if i % 11 == 0 then
				senv.controls.Enable.Value = math.random(0, 1)
				senv.controls.Enable.EventHandler()
			end
			timer.EventHandler()
		end)
		if not ok then chatter_threw = err break end
	end
	h.check(chatter_threw == nil, "300 rounds of mid-sweep control chatter never throw (" .. tostring(chatter_threw) .. ")")
end

-- ---------------------------------------------------------------------------
-- SubharmonicSynth: the newest plugin, and the only one whose DSP parameters
-- are derived rather than passed straight through.
-- ---------------------------------------------------------------------------

h.section("SubharmonicSynth: parameter storm")
do
	local CONTROLS = { "DryLevel", "SubLevel", "SubGain", "QFactor", "Cutoff", "Bypass" }
	local uenv = qsys.install({
		controls = CONTROLS,
		properties = { plugin_show_debug = { Value = 0 } },
	})
	Lpf = { frequency = qsys.control(0), slope = qsys.control(0), type = qsys.control(0) }
	Peq = { frequency_1 = qsys.control(0), gain_1 = qsys.control(0), q = qsys.control(0) }
	GainSub = { gain = qsys.control(0) }
	GainDry = { gain = qsys.control(0) }
	Mix = { ["input.1.output.1.gain"] = qsys.control(0), ["input.2.output.1.gain"] = qsys.control(0) }
	assert(loadfile(h.DIST.subharmonic))()

	local threw, centre_wrong, bypass_wrong, bypassed_rounds = nil, 0, 0, 0
	for i = 1, 1500 do
		local ok, err = pcall(function()
			-- Deliberately reaches past the declared ranges (Cutoff 20-120,
			-- levels -100..20): a Q-SYS control can be driven from a script or
			-- a snapshot, not only from the knob that bounds it.
			uenv.controls.Cutoff.Value = -200 + math.random() * 600
			uenv.controls.Cutoff.EventHandler()

			uenv.controls.SubLevel.Value = -200 + math.random() * 400
			uenv.controls.SubLevel.EventHandler(uenv.controls.SubLevel)

			uenv.controls.DryLevel.Value = -200 + math.random() * 400
			uenv.controls.DryLevel.EventHandler(uenv.controls.DryLevel)

			uenv.controls.SubGain.Value = -50 + math.random() * 100
			uenv.controls.SubGain.EventHandler(uenv.controls.SubGain)

			uenv.controls.QFactor.Value = math.random() * 100
			uenv.controls.QFactor.EventHandler()

			if i % 3 == 0 then
				uenv.controls.Bypass.Value = math.random(0, 1)
				uenv.controls.Bypass.EventHandler()
			end
		end)
		if not ok then threw = err break end

		-- The suboctave centre is the whole point of the plugin: it must track
		-- half the cutoff no matter what the cutoff was set to.
		if math.abs(Peq.frequency_1.Value - uenv.controls.Cutoff.Value / 2) > 1e-9 then
			centre_wrong = centre_wrong + 1
		end
		-- Bypass has to win over any level change that arrives while it is on.
		if uenv.controls.Bypass.Boolean then
			bypassed_rounds = bypassed_rounds + 1
			if GainSub.gain.Value ~= -100 then bypass_wrong = bypass_wrong + 1 end
		end
	end
	h.check(threw == nil, "1500 rounds of out-of-range parameter changes never throw (" .. tostring(threw) .. ")")
	h.check(centre_wrong == 0, "the PEQ centre is always half the cutoff (got " .. centre_wrong .. " adrift)")
	h.check(bypass_wrong == 0, "a level change while bypassed never unmutes the sub path (got " .. bypass_wrong .. " leaks)")
	-- The leak check above only means anything if the storm actually spent
	-- time bypassed while levels were being driven.
	h.check(bypassed_rounds > 0, "the storm did run while bypassed (" .. bypassed_rounds .. " of 1500 rounds)")
end

-- ---------------------------------------------------------------------------
-- MultiFlip-Flop: a wider instance than any other test uses, driven randomly,
-- since the Exclusive interlock is the one piece of cross-instance state here.
-- ---------------------------------------------------------------------------

h.section("MultiFlip-Flop: random operation storm, InputCount=8")
do
	local N = 8
	local controls_list = { "Start", "Exclusive" }
	local trigger_controls = {}
	for t = 1, N do
		for _, prefix in ipairs({ "Set_", "Reset_", "Toggle_", "State_", "Led_", "Out_", "Not_" }) do
			table.insert(controls_list, prefix .. t)
		end
		table.insert(trigger_controls, "Set_" .. t)
		table.insert(trigger_controls, "Reset_" .. t)
		table.insert(trigger_controls, "Toggle_" .. t)
	end
	local menv = qsys.install({
		controls = controls_list,
		trigger_controls = trigger_controls,
		properties = { InputCount = { Value = N } },
	})
	assert(loadfile(h.DIST.flipflop))()

	local threw, complement_broken, exclusive_broken = nil, 0, 0
	local exclusive_rounds, max_set_while_open = 0, 0
	for i = 1, 4000 do
		local t = math.random(N)
		local ok, err = pcall(function()
			local op = math.random(4)
			if op == 1 then
				menv.controls["Set_" .. t].EventHandler()
			elseif op == 2 then
				menv.controls["Reset_" .. t].EventHandler()
			elseif op == 3 then
				menv.controls["Toggle_" .. t].EventHandler()
			else
				menv.controls["State_" .. t].Value = math.random(0, 1)
				menv.controls["State_" .. t].EventHandler()
			end
			if i % 13 == 0 then
				menv.controls.Exclusive.Value = math.random(0, 1)
				menv.controls.Exclusive.EventHandler()
			end
		end)
		if not ok then threw = err break end

		-- Out_N and Not_N are complementary by definition; if they ever agree,
		-- something downstream is being told two contradictory things.
		local set_count = 0
		for k = 1, N do
			local out = menv.controls["Out_" .. k].Value
			local notout = menv.controls["Not_" .. k].Value
			if out + notout ~= 1 then complement_broken = complement_broken + 1 end
			if menv.controls["State_" .. k].Boolean then set_count = set_count + 1 end
		end
		if menv.controls.Exclusive.Boolean then
			exclusive_rounds = exclusive_rounds + 1
			if set_count > 1 then exclusive_broken = exclusive_broken + 1 end
		elseif set_count > max_set_while_open then
			max_set_while_open = set_count
		end
	end
	h.check(threw == nil, "4000 random flip-flop operations never throw (" .. tostring(threw) .. ")")
	h.check(complement_broken == 0, "Out_N and Not_N stay complementary throughout (got " .. complement_broken .. " violations)")
	h.check(exclusive_broken == 0, "at most one instance is ever set while Exclusive is on (got " .. exclusive_broken .. " violations)")
	-- Both halves of the interlock check need the storm to have actually
	-- reached the states they describe: time spent with Exclusive on, and a
	-- multi-set state that is genuinely reachable when it is off. Without the
	-- second one the invariant above would hold for a plugin that simply never
	-- lets two instances be set at all, which is a different component.
	h.check(exclusive_rounds > 0, "the storm did run with Exclusive on (" .. exclusive_rounds .. " of 4000 rounds)")
	h.check(max_set_while_open > 1, "multiple simultaneous instances are reachable with Exclusive off (peak " .. max_set_while_open .. ")")
end

h.report()
