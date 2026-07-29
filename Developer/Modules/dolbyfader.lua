   -- ##############################################################
   --			Dolby Fader
   -- ##############################################################

	do

		require("qknob")

		-- Objects
		-- QKnob wraps the 'Level' Text control; must stay global (never
		-- local) -- Timer/socket-holding objects are killed by the GC once
		-- nothing else references them, and DKNob is that anchor for the
		-- Timer QKnob:init() creates internally.
		DKNob = QKnob:new('Level', 0, 10, 1)

		-- Custom functions

		local function convertToDb(val)
			if val <= 4 then return val * 20 - 90
			else return (val - 7) * 10 / 3 end
		end

		local function convertToDolby(dB)
			if dB <= -10 then return (dB + 90) / 20
			else return (dB * 3 / 10) + 7 end
		end

		-- Event handlers

		-- Step: embedded stepper component (GetComponents); Q-SYS exposes
		-- it as the global 'Step', which is what _G["Step"] would return.
		Step.value.EventHandler = function(ctrl)
			DKNob.Position = Step.value.Value / 100
			DKNob.EventHandler(Step)
		end

		DKNob.EventHandler = function(ctrl)
			if ctrl ~= Controls.Gain then
				Controls.Gain.Value = convertToDb(DKNob.Value)
			end
			Step.value.Value = DKNob.Position * 100
			if DolbyFaderEventHandler then
				DolbyFaderEventHandler(ctrl)
			end
		end

		Controls.Gain.EventHandler = function(ctrl)
			DKNob.Value = convertToDolby(Controls.Gain.Value)
			DKNob.EventHandler(Controls.Gain)
		end

		Controls.Ref.EventHandler = function(ctrl)
			if Controls.Ref.Boolean then
				DKNob.Value = 7.0
				DKNob.EventHandler(Controls.Ref)
			end
		end

		Controls.Increase.EventHandler = function()
			Step.increase.Value = Controls.Increase.Value
		end

		Controls.Decrease.EventHandler = function()
			Step.decrease.Value = Controls.Decrease.Value
		end

		-- Init

		Controls.Gain.EventHandler()
		DolbyFaderEventHandler = nil

	end
