
   -- ##############################################################
   --			CPSeries Protocol
   -- ##############################################################
   --
   -- Per-model wire formatting.
   --   CP650                        -> KEY=VALUE   ("MASTER=100")
   --   CP750 / CP850 / CP950 / 950A -> "param value" ("sys.mute 0")
   -- The GET framing ("KEY=?" / "param ?") is this plugin's own
   -- Dolby-verified convention.

	do

		require("cpseries_models")

		CPProtocol = {}

		local function fmtvalue(v)
			if type(v) == "boolean" then return v and "1" or "0" end
			if type(v) == "number" then
				if v == math.floor(v) then return tostring(math.floor(v)) end -- whole numbers as ints: 70.0 -> "70"
				return tostring(v)
			end
			return tostring(v)
		end

		-- Reject a param/value with an embedded newline/CR: commands are framed
		-- one per line, so it would split into two commands or corrupt the stream.
		local function rejectcontrol(s,what)
			if s:find("[\r\n]") then
				error(what.." contains a newline/CR ("..s.."); would corrupt the wire framing")
			end
		end

		function CPProtocol.FormatMessage(model,param,value)
			local val = fmtvalue(value)
			rejectcontrol(param,"param")
			rejectcontrol(val,"value")
			if CPModels.UsesKeyValue(model) then
				return param.."="..val
			end
			return param.." "..val
		end

		function CPProtocol.FormatQuery(model,param)
			rejectcontrol(param,"param")
			if CPModels.UsesKeyValue(model) then
				return param.."=?"
			end
			return param.." ?"
		end

	end
