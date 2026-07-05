-- Dolby test Plugin for Q-SYS
-- by James Puig / james.puig@dolby.com
-- Sept '20

local netbase = '//Mac/Home'   --<<-- use in MacOS/Parallels 
local base = os.getenv('USERPROFILE') or os.getenv('HOME')
local pathtree = '/Documents/QSC/Q-Sys Designer/Modules' 
local path = base .. pathtree .. '/?.lua;'
path = path .. netbase .. pathtree .. '/?.lua;'
path = path .. base .. pathtree .. '/?/init.lua;'
path = path .. netbase .. pathtree .. '/?/init.lua;'
package.path = path .. package.path

PluginInfo = 
{
   Name = "test",
    Version = "1.0",
    BuildVersion = "1.0.0.0",
    Id = "afac5c69-fadd-43f6-b9cd-a647d75c684b",
    Description = "",
    Manufacturer = "",
    Author = "James Puig - james.puig@dolby.com",
    Type = Reflect and Reflect.Types.AudioIO or 0,
}

function GetColor(props)
    return {204,204,204 }  --Is  Control
end

function GetPrettyName(props)
    return "test"
end

function GetProperties()
  return {
    {
    	Name = "multi_channel_type",
    	Type = "integer",
    	Min = 1,
    	Max = 3,
    	Value = 3,
    },
    {
    	Name = "multi_channel_count",
    	Type = "integer",
    	Min = 1,
    	Max = 256,
    	Value = 4,
    }
  }
end




function GetComponents(props)
	return 
  	{ 
    	{   
 		 	Name = "mixer",
      		Type = "mixer", 
			Properties = 
      		{
      		 	n_inputs = 1,
      		 	n_outputs = 1,
      		 	n_vca_groups = 1,
      		 	label_controls = false,
      		}
    	},
   		{	
      		Name = "Gain",
      		Type = "gain", 
      		Properties = 
      		{
      		   max_gain = 20,	
      		   min_gain = -100,
        	   ["multi_channel_type"] = 3,
        	   ["multi_channel_count"] = 2,
      		}
    	},
     	{   
      		Name = "Step",
      		Type = "stepper", 
      		Properties = 
      		{
      		    control_type = 1,   --// 0=dB 1=% 2=Integer 
      			num_steps = 100,    --// for 2=Integer
      			max_gain = 10,      --// for 0=dB 
      			min_gain = -90,		--// for 0=dB
      			gain_mode = 1,      --// for 0=dB  
      		}
    	},
   		{   
      		Name = "Sine",
      		Type = "sine", 
      		Properties = 
      		{

      		}
    	},
    	{
    		Name = "Router",
    		Type = "router",
      		Properties = 
      		{
      		 	n_inputs = 1,
      		 	n_outputs = 1,
      		}   		
    	},
    	{
    		Name = "control",
    		Type = "custom_controls",
      		Properties = 
      		{
				
      		}   		
    	},
    	{
      		Name = "meters",
      		Type = "meter2",
      		Properties = {
        		["meter_type"] = 1,     		
        		["multi_channel_type"] = "Multi-channel",
        		["multi_channel_count"] = 2,
    		},
      	},
    	{
      		Name = "FlipFlop",
      		Type = "flip_flop",
      	},
      	
 	}	
end

function GetControls(props)
    local ctrls = {}
    table.insert(ctrls, {
			Name = "period",
      		ControlType = "Text",
    })
    table.insert(ctrls, {
			Name = "MyLevel",
      		ControlType = "Knob",
  			ControlUnit = "Float",
  			Min = 1,
  			Max = 5,
    })
 	return ctrls

end

function GetControlLayout(props)	
	local graphics = {}
 	local layout = {}

    layout["period"] =	{
    	PrettyName = "Period",
    	Style = "Knob",
    	Color={255,0,0},
     	Position = { 0,0 },
    	Size = { 36,36 },
  	} 

    layout["MyLevel"] =	{
    	PrettyName = "Level",
    	Style = "Knob",
     	Position = { 48,0 },
    	Size = { 36,36 },
  	} 

  	return layout, graphics
end

if Controls or Reflect == nil then   
	do
	end	
	require(PluginInfo.Name)
end
