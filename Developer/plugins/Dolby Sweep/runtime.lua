--[[ #include "../../shared/qknob.lua" ]]

function QKnob:SetString(val)
	return val .. 's'
end

local start = Controls.Start
local enable = Controls.Enable
local trigger = Controls.Trigger
local mute = Controls.Mute
local frequency = Controls.Frequency
local level = Controls.Level

local running = false
local step = 0

period = QKnob:new('Period', 1, 8, 1)
timer = Timer.New()

local OCTAVE = 11
local numloops = System.IsEmulating and 130 or 130 * 4

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
	if not start.Boolean then
		start.Boolean = true
		level.Value = -40
		period.Value = 4
		frequency.Value = 20
	end
	Sine.level.Value = 0
	enable.EventHandler()
end

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

mute.EventHandler = function(ctrl)
	Sine.mute.Boolean = mute.Boolean or not running
end

initplugin()
