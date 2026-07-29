-- The root MultiFlip-Flop distributable. Unlike the other three plugins its
-- runtime logic was already inline (`if Controls then ... end`) even before
-- the PLUGCC.exe restructuring -- see CLAUDE.md. Covers the per-instance
-- control count for a given InputCount, the Exclusive interlock, and the
-- init pass.

local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path

local h = require("harness")
local qsys = require("qsys_stub")

local DIST = arg[1] or h.DIST.flipflop
local N = 3 -- InputCount used for the runtime checks below

h.section("definition pass")
qsys.install({ definition = true })
do
	local ok, err = pcall(assert(loadfile(DIST)))
	h.check(ok, "definition pass loads (" .. tostring(err) .. ")")
	h.check(GetPrettyName() == "Multi Flip-Flop ", "GetPrettyName")

	local ctrls = GetControls({ InputCount = { Value = N } })
	h.check(#ctrls == 2 + N * 7, "control count for InputCount=" .. N .. " is 2 + N*7 (got " .. #ctrls .. ")")

	local ok2, layout, graphics = pcall(GetControlLayout, { InputCount = { Value = N } })
	h.check(ok2, "GetControlLayout does not throw (" .. tostring(layout) .. ")")
	if ok2 then
		h.check(layout['Set_2'] ~= nil, "layout entry exists for a dynamic control (Set_2)")
		-- Regression: the 7 column-header labels used to set 'VAlign = Center'
		-- -- not a real layout key, and 'Center' an undeclared global -- so
		-- this was silently always VTextAlign=nil. (The per-row number
		-- labels never set vertical alignment at all, before or after.)
		local headers = { Exclusive = 1, Set = 1, Reset = 1, Toggle = 1, State = 1, Out = 1, ["Not Out"] = 1 }
		local centeredHeaders = 0
		for _, g in ipairs(graphics) do
			if headers[g.Text] then
				if g.VTextAlign == "Center" then centeredHeaders = centeredHeaders + 1 end
			end
		end
		h.check(centeredHeaders == 7, "all 7 column-header labels set VTextAlign=Center (got " .. centeredHeaders .. ")")
	end
end

h.section("runtime pass, InputCount=" .. N)
local controls_list = { "Start", "Exclusive" }
for t = 1, N do
	for _, prefix in ipairs({ "Set_", "Reset_", "Toggle_", "State_", "Led_", "Out_", "Not_" }) do
		table.insert(controls_list, prefix .. t)
	end
end
local env = qsys.install({ controls = controls_list, properties = { InputCount = { Value = N } } })
-- Trigger buttons need a :Trigger() method, which qsys_stub's plain
-- control() doesn't provide -- add it.
for _, c in pairs(env.controls) do c.Trigger = function() end end

local ok, err = pcall(assert(loadfile(DIST)))
h.check(ok, "runtime pass executes end to end (" .. tostring(err) .. ")")

h.section("init pass (all State_N start at 0)")
h.check(env.controls.Out_1.Value == 0 and env.controls.Not_1.Value == 1,
	"Out_1/Not_1 reflect an initially-cleared State_1")

h.section("Exclusive interlock")
env.controls.State_2.Value = 1
env.controls.State_2.EventHandler()
h.check(env.controls.Out_2.Value == 1 and env.controls.Not_2.Value == 0, "setting State_2 sets Out_2/clears Not_2")

env.controls.Exclusive.Value = 1
env.controls.State_1.Value = 1
env.controls.State_1.EventHandler()
h.check(env.controls.State_2.Value == 0, "Exclusive clears State_2 when State_1 is set")
h.check(env.controls.Out_2.Value == 0 and env.controls.Not_2.Value == 1, "Exclusive clears Out_2/sets Not_2 for the deselected instance")

h.section("Toggle_N")
-- Regression: Toggle_N used to assign `Controls[...].Value == 0` directly,
-- a Lua boolean, then read it back with `== 1` inside State_N's own
-- EventHandler in the same synchronous call -- always false in Lua, so
-- Toggle_N corrupted State_N.Value to true/false without ever flipping
-- Out_N/Not_N.
env.controls.Exclusive.Value = 0
env.controls.State_3.Value = 0
env.controls.Out_3.Value = 0
env.controls.Not_3.Value = 1
env.controls.Toggle_3.EventHandler()
h.check(env.controls.State_3.Value == 1, "Toggle_3 flips State_3 to 1 (got " .. tostring(env.controls.State_3.Value) .. ")")
h.check(env.controls.Out_3.Value == 1 and env.controls.Not_3.Value == 0, "Toggle_3 (0->1) sets Out_3/clears Not_3")
env.controls.Toggle_3.EventHandler()
h.check(env.controls.State_3.Value == 0, "Toggle_3 flips State_3 back to 0 (got " .. tostring(env.controls.State_3.Value) .. ")")
h.check(env.controls.Out_3.Value == 0 and env.controls.Not_3.Value == 1, "Toggle_3 (1->0) clears Out_3/sets Not_3")

h.report()
