
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

		CPProtocol = {}

		-- Python repr layout of `digits` x 10^(exp10 - #digits + 1): scientific
		-- form when the decimal exponent is < -4 or >= 16.
		local function layoutrepr(digits,exp10)
			digits = digits:gsub("0+$","")
			if digits == "" then digits = "0" end
			if exp10 < -4 or exp10 >= 16 then
				local mant = digits:sub(1,1)
				if #digits > 1 then mant = mant.."."..digits:sub(2) end
				return string.format("%se%s%02d",mant,exp10 < 0 and "-" or "+",math.abs(exp10))
			elseif exp10 >= 0 then
				local intlen = exp10 + 1
				if #digits <= intlen then return digits..string.rep("0",intlen - #digits) end
				return digits:sub(1,intlen).."."..digits:sub(intlen + 1)
			end
			return "0."..string.rep("0",-exp10 - 1)..digits
		end

		-- Wire text of a float, as the CPSeries toolkit prints it
		-- (cpx50.comms.protocol._fmt_value): whole floats as integers with
		-- every digit (70.0 -> "70", 1e20 -> "100000000000000000000"), others
		-- as the shortest digit string that round-trips (0.1 -> "0.1", 1e-5
		-- -> "1e-05"; tostring keeps only 14 digits). The correctly rounded
		-- n-digit string can fail to round-trip where a neighbouring n-digit
		-- string does (2^-24 is "5.960464477539063e-08"), so the neighbours
		-- are tried before n + 1 digits. nan / inf print as "nan" / "inf".
		local function fmtfloat(v)
			if v ~= v then return "nan" end
			if v == math.huge then return "inf" end
			if v == -math.huge then return "-inf" end
			if v == math.floor(v) then
				if v == 0 then return "0" end
				return string.format("%.0f",v)
			end
			local sign = v < 0 and "-" or ""
			local a = math.abs(v)
			for n = 1,17 do
				local mstr,estr = string.format("%."..(n - 1).."e",a):match("^([%d.]+)e([+-]%d+)$")
				local e = tonumber(estr)
				local m = math.tointeger(tonumber((mstr:gsub("%.",""))))
				for _,cand in ipairs({m,m + 1,m - 1}) do
					if cand > 0 and tonumber(string.format("%de%d",cand,e - (n - 1))) == a then
						local digits = tostring(cand)
						return sign..layoutrepr(digits,e - (n - 1) + #digits - 1)
					end
				end
			end
			return string.format("%.17g",v)
		end

		local function fmtvalue(v)
			if type(v) == "boolean" then return v and "1" or "0" end
			if type(v) == "number" then
				if math.type(v) == "integer" then return tostring(v) end
				return fmtfloat(v)
			end
			return tostring(v)
		end

		CPProtocol.FormatValue = fmtvalue

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
