
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
      -- FIX: was 'start.Value == 0' / 'start.Value = 1' -- a Button
      -- control's Value is boolean (Q-SYS defaults it to false), so that
      -- comparison was never true and this one-time init never ran.
      if start.Value == false then
        start.Value = true
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
        if enable.Value == 0 then
          Stop()
        end
      end
    end

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
      Timer.CallAfter(Start, 0.1)
      Sine.mute.Value = mute.Value
    end

    period.EventHandler = function(ctrl)
      if running then
        Stop()
        Timer.CallAfter(Start, 0.1)
        Sine.mute.Value = mute.Value
      end
    end

    mute.EventHandler = function(ctrl)
      Sine.mute.Value = mute.Value == 1 or not running
    end

    -- Init

    initplugin()

  end
