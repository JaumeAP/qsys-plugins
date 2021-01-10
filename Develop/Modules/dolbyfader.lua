	--##  Code for Dolby Fader  

		require("qknob")

		DKNob = QKnob:new('level',0,10,1)

		local function convertToDb(val) 
			if val <= 4 then return val*20-90 
			else return (val-7)*10/3 end 
		end

		local function convertToDolby(dB) 
			if dB <= -10 then return (dB+90)/20 
			else return (dB*3/10)+7 end 
		end

		Step.value.EventHandler = function(ctrl)
		   DKNob.Position = Step.value.Value / 100	
			DKNob.EventHandler(Step)			
		end	

		DKNob.EventHandler  = function(ctrl)
			if ctrl ~= Controls.gain then 
				Controls.gain.Value = convertToDb( DKNob.Value ) 
			end
			Step.value.Value = DKNob.Position * 100
			if DolbyFaderEventHandler then
				DolbyFaderEventHandler(ctrl)
			end
		end

		Controls.gain.EventHandler  = function(ctrl)
			DKNob.Value = convertToDolby( Controls.gain.Value)
			DKNob.EventHandler(Controls.gain)
		end 

		Controls.ref.EventHandler = function(ctrl)
			if Controls.ref.Value == 1 then
		  		DKNob.Value = 7.0
		  		DKNob.EventHandler(Controls.ref)
			end
		end

		Controls.increase.EventHandler = function()
			Step.increase.Value = Controls.increase.Value
		end	

		Controls.decrease.EventHandler = function()
			Step.decrease.Value = Controls.decrease.Value
		end	

		-- Execute at StartUp
		Controls.gain.EventHandler()
		DolbyFaderEventHandler = nil

