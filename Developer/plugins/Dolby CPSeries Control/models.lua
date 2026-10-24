
   -- ##############################################################
   --			CPSeries Models
   -- ##############################################################
   --
   -- Per-model wire config: TCP port and whether the model speaks the
   -- CP650 KEY=VALUE dialect or the "param value" dialect used by every
   -- other processor.

	do

		CPModels = {}

		CPModels.CONFIG = {
			CP650  = { port = 61412, namespace = "KEY=VALUE" },
			CP750  = { port = 61408, namespace = "cp750.*"   },
			CP850  = { port = 61408, namespace = "sys.*"     },
			CP950  = { port = 61408, namespace = "sys.*"     },
			CP950A = { port = 61408, namespace = "sys.*"     },
		}

		-- Documented connection limit per model (Dolby CP Cinema Control spec,
		-- "Models Supported"); not verified against hardware.
		CPModels.MAX_CONNECTIONS = { CP650 = 1, CP750 = 20, CP850 = 20, CP950 = 20, CP950A = 20 }

		function CPModels.DefaultPort(model)
			local c = CPModels.CONFIG[model]
			assert(c,"CPModels.DefaultPort: unknown model '"..tostring(model).."'")
			return c.port
		end

		function CPModels.UsesKeyValue(model)
			local c = CPModels.CONFIG[model]
			assert(c,"CPModels.UsesKeyValue: unknown model '"..tostring(model).."'")
			return c.namespace == "KEY=VALUE"
		end

		-- CP750 key parameter ranges (dB / ms / Hz), from the spec's "Key
		-- Parameters (CP750)" table via the CPSeries toolkit. The ch_level_*
		-- and eq_* families share one range each. Real hardware clips a SET to
		-- these silently.
		CPModels.CP750_PARAM_RANGES = {
			["cp750.sys.master_level"]       = { 0, 96 },
			["cp750.sys.ch_level"]           = { -96, 12 },
			["cp750.sys.mute"]               = { 0, 1 },
			["cp750.sys.surround_delay"]     = { 0, 150 },
			["cp750.sys.subwoofer_filter"]   = { 50, 100 },
			["cp750.sys.eq"]                 = { -60, 60 },
			["cp750.sys.mute_fade_out_time"] = { 200, 5000 },
		}

		function CPModels.RangeOf(param)
			local ranges = CPModels.CP750_PARAM_RANGES
			if ranges[param] then return ranges[param] end
			if param:find("cp750.sys.ch_level_",1,true) == 1 then return ranges["cp750.sys.ch_level"] end
			if param:find("cp750.sys.eq_",1,true) == 1 then return ranges["cp750.sys.eq"] end
			return nil
		end

		-- True when value is inside the documented range of param, or param has none.
		function CPModels.ValidateRange(param,value)
			local r = CPModels.RangeOf(param)
			if not r then return true end
			return value >= r[1] and value <= r[2]
		end

		-- value clipped to the documented range of param (unchanged when it has none).
		function CPModels.ClipToRange(param,value)
			local r = CPModels.RangeOf(param)
			if not r then return value end
			return math.max(r[1],math.min(r[2],value))
		end

	end
