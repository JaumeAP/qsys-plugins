
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

	end
