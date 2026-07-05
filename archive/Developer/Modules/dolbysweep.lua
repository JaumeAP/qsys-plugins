
  do
    require("qknob")	

    function QKnob:SetString(val) 
      return val .. 's' 
    end	

    local period = QKnob:new('period',1,8,1)

    --     CONSTANTS

    local emul = System.IsEmulating

    local OCTAVE = 11
    --local numloops = emul and OCTAVE*6 or OCTAVE*24
    local numloops = emul and 130 or 130 * 4

    local start = Controls.start
    local enable = Controls.enable
    local trigger =Controls.trigger
    local mute =Controls.mute
    local frequency = Controls.frequency
    local level = Controls.level

    --     Local Variables
    local timer = Timer.New()
    local running = false
    local step = 0

    --     Internal funtions & events

    local function Start()
      timer:Start(period.Value/numloops) 		
      Sine.mute.Value = 0
      running = true
    end

    local function Stop()
      timer:Stop()
      Sine.mute.Value = 1
      Sine.level.Position = 0
      running = false
    end

    local function initplugin()
      if start.Value == 0 then	
        start.Value = 1
        level.Value = -40
        period.Value = 4
        frequency.Value = 20
      end
      Sine.level.Value = 0
      enable.EventHandler()
    end

    timer.EventHandler= function(ctimer)
      local freq = 10 * 2^( step * OCTAVE/numloops )		
      if freq > 22000 then freq = 22000 end
      frequency.Value = freq
      Sine.frequency.Value = freq
      step = step +  1 
      if freq == 22000 then 
        step = 0
        if enable.Value == 0 then 
          Stop() 
        end
      end 
    end

    --     EVENTS

    enable.EventHandler = function(ctrl)
      if enable.Value == 0 then 
        Stop()	
      else 
        trigger.EventHandler(enable) 
      end	
    end

    trigger.EventHandler = function(ctrl)
      if ctrl ~= enable then 
        Stop()	
        step = 0 
        frequency.Value = 10 
        Sine.frequency.Value = 10			
      end
      Timer.CallAfter(Start,0.1)
      Sine.mute.Value = mute.Value
    end

    period.EventHandler = function(ctrl)
      if running then 
        Stop()
        Timer.CallAfter(Start,0.1)
        Sine.mute.Value = mute.Value
      end
    end

    mute.EventHandler = function(ctrl)
      Sine.mute.Value = mute.Value == 1 or not running
    end


    --     PLUGIN INITIALIZATION

    initplugin()

  end
