
  do
    require("qknob")

    -- Deviates from the usual Aliases->Variables->Objects->Constants->
    -- Custom-fns section order: this override must run BEFORE any QKnob is
    -- constructed below, since QKnob:new() -> :init() sets self.String
    -- immediately, which calls self:SetString(). Overrides the global
    -- QKnob:SetString for every QKnob instance loaded in the same design,
    -- including DolbyFader's DKNob -- pre-existing behavior, not
    -- introduced by this rewrite (see CLAUDE.md).
    function QKnob:SetString(val)
      return val .. 's'
    end

    -- Aliases: local names onto this plugin's own Controls, for brevity below.
    local start = Controls.Start
    local enable = Controls.Enable
    local trigger = Controls.Trigger
    local mute = Controls.Mute
    local frequency = Controls.Frequency
    local level = Controls.Level

    -- Variables

    local running = false
    local step = 0

    -- Objects
    -- QKnob wraps the 'Period' Text control and the Timer below; both must
    -- stay global (never local), same GC-safety convention as everywhere
    -- else in this repo.
    period = QKnob:new('Period', 1, 8, 1)
    timer = Timer.New()

    -- Constants

    local OCTAVE = 11
    local numloops = System.IsEmulating and 130 or 130 * 4

    -- Custom functions

    local function Start()
      timer:Start(period.Value / numloops)
      Sine.mute.Boolean = false
      running = true
    end

    local function Stop()
      timer:Stop()
      Sine.mute.Boolean = true
      Sine.level.Position = 0
      running = false
    end

    local function initplugin()
      -- FIX: a control's .Value is always numeric, never a Lua boolean
      -- (confirmed via vendor/qsc-q-sys's Component.GetControls docs --
      -- the boolean accessor is the separate .Boolean property). The prior
      -- 'start.Value == false' / '= true' form here compared a number
      -- against a Lua boolean literal, which can never be equal -- this
      -- one-time init never ran, on top of the still-earlier 'Value == 0'
      -- form it had replaced (also broken, but for the opposite reason:
      -- 0 is truthy in Lua). 'Start' IS declared ControlType="Button" here
      -- (unlike CPSeries's own bare 'Start'), so .Boolean is safe.
      if not start.Boolean then
        start.Boolean = true
        level.Value = -40
        period.Value = 4
        frequency.Value = 20
      end
      Sine.level.Value = 0
      enable.EventHandler()
    end

    -- Event handlers

    timer.EventHandler = function(ctimer)
      local freq = 10 * 2 ^ (step * OCTAVE / numloops)
      if freq > 22000 then freq = 22000 end
      frequency.Value = freq
      Sine.frequency.Value = freq
      step = step + 1
      if freq == 22000 then
        step = 0
        if not enable.Boolean then
          Stop()
        end
      end
    end

    enable.EventHandler = function(ctrl)
      if not enable.Boolean then
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
      Timer.CallAfter(Start, 0.1)
      Sine.mute.Boolean = mute.Boolean
    end

    period.EventHandler = function(ctrl)
      if running then
        Stop()
        Timer.CallAfter(Start, 0.1)
        Sine.mute.Boolean = mute.Boolean
      end
    end

    -- FIX: this used to assign a Lua boolean (the result of
    -- 'mute.Value == 1 or not running') into .Value, which is always
    -- numeric -- the mirror-image of the initplugin() bug above. .Boolean
    -- on both sides fixes it.
    mute.EventHandler = function(ctrl)
      Sine.mute.Boolean = mute.Boolean or not running
    end

    -- Init

    initplugin()

  end
