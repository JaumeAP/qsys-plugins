
   -- ##############################################################
   --			CPSeries Class
   -- ##############################################################
   --
   -- v3.0: adds CP950 / CP950A. Wire formatting/framing now goes through the
   -- cpseries_models / cpseries_protocol modules -- CPProtocol.FormatMessage /
   -- CPProtocol.FormatQuery and CPModels.CONFIG replace the old per-model
   -- string concatenation, so all five processors share one code path instead
   -- of a growing branch tree. The old setmeta/searchelem reflection hack on
   -- Model/CP750/Actions is gone too: those are now plain tables carrying
   -- their own index/key fields.
   --
   -- Bug fixes: a format/reset index read off the wire is now bounds-checked
   -- before it's used to look up CP750/Actions (an out-of-range value used to
   -- index a nil entry and crash); Action() ignores an unknown control or a
   -- write to the device-populated formlist instead of corrupting state; the
   -- macro-list accumulator is capped at 512 entries so a stream of orphan/
   -- garbage "n:name" lines can't grow it without bound.

	do

		local POLLTIME = 0.02

		-- Minimum gap between two sent commands, and the no-response
		-- watchdog, both in seconds. These are the "Protocol Guarantees" of
		-- the Dolby CP Cinema Control spec: the CP650 needs more headroom
		-- than the general case (250ms minimum, not 100ms), and a link that
		-- stops answering is declared dead after 3s rather than polled
		-- forever.
		local GAP_CP650 = 0.25
		local GAP_DEFAULT = 0.10
		local WATCHDOG = 3.0

		-- Poll runs off a POLLTIME timer and counts ticks, so both live here
		-- as tick counts. Rounded up: rounding down would sit just under the
		-- documented minimum, which is the one direction that matters.
		local GAP_TICKS_CP650 = math.ceil(GAP_CP650 / POLLTIME)
		local GAP_TICKS_DEFAULT = math.ceil(GAP_DEFAULT / POLLTIME)
		local WATCHDOG_TICKS = math.ceil(WATCHDOG / POLLTIME)

		-- private.cache's own guarantee, per the same spec: a single FIFO
		-- queue of pending outbound messages ahead of the regular poll
		-- cycle, capped at QMAX -- past capacity the OLDEST entry is
		-- dropped first, so the most recent request always survives.
		-- request() (below) is currently this queue's only producer, and it
		-- is only ever called once per Start() (the readiness handshake),
		-- so today the queue never actually holds more than one entry --
		-- this exists so a future second caller doesn't inherit a queue
		-- that silently reordered or grew without bound.
		local QMAX = 10

		local setValue,getValue,setState,getState,Poll,readData,request,received
		local privates = setmetatable({}, {__mode = "k"}) -- set 'privates' as private field

		local CP750 ={ { key='dig_1',value='digital 1' }, { key='dig_2',value='digital 2' },
					   { key='dig_3',value='digital 3' }, { key='dig_4',value='digital 4' },
					   { key='analog',value='Analog Input' },{ key='non_sync',value='Non Sync' },
					   { key='mic',value='Microphone' } }
		for i,elem in ipairs(CP750) do elem.index = i end

		local Actions = {}
		for i,name in ipairs({'fader','mute','format','formname','formlist','reset'}) do
			local a = { index=i, key=name }
			Actions[i] = a
			Actions[name] = a
		end

  		local SEP = 7	 	--	- CP650 -	     - CP750 -			    - CP850 -          - CP950 -          - CP950A -
 		local CPServices ={  {'fader_level',  'cp750.sys.fader',      'sys.fader',        'sys.fader',        'sys.fader'        },    -- FADER
 							 {'mute',         'cp750.sys.mute',       'sys.mute',         'sys.mute',         'sys.mute'         },	-- MUTE
 						     {'format_button','cp750.sys.input_mode', 'sys.macro_preset', 'sys.macro_preset', 'sys.macro_preset' },	-- FORMAT
 							 { nil,			  nil,                    'sys.macro_name',   'sys.macro_name',   'sys.macro_name'   },	-- FORMNAME
 							 {'format_list',  nil,                    'sys.macros',       'sys.macros',       'sys.macros'       },	-- FORMLIST
 							 {'fader_level',  'cp750.sysinfo.version','sys.fader',        'sys.fader',        'sys.fader' 		},	-- QUERY
							 { '=',' ',' ',' ',' ' } }												-- SEP

		-- A "macro model" drives formats as named macros (sys.macro_*): CP850/CP950/CP950A.
		local function isMacro(model)
			return CPServices[Actions.formname.index][model.index] ~= nil
		end

		--- Creating the Class itself ---

		CPSeries = { EventHandler = nil }
		CPSeries.__index = CPSeries

	--	------------------------------------
	--		public function .New(processorType)
	--			param: processor
	--			return: object
	--	------------------------------------

 		function CPSeries.New(model)
 		 	-- private variables --
 			local self = {}
 			privates[self] = { value={	{ fader=0,state=false }, { mute=0,state=false }, { format=0,state=false },
 						{ formname="",state=false }, { formlist={},state=false }, { reset=false,state=false } },
 						npoll=0, model=Model.CP850, sock=nil, ready=false, cache ={}, waiting=0,tmplist={} }
 			local private = privates[self]
			for _,elem in ipairs(Model) do
				if elem.value == model then private.model = elem end
			end
			-- resolve per-connection model facts once (used on every Poll/received)
			private.libmodel = (private.model.value):gsub("%s","")
			private.isMacro = isMacro(private.model)
			private.gapticks = (private.model == Model.CP650) and GAP_TICKS_CP650 or GAP_TICKS_DEFAULT
			private.echopending = nil
			private.time = Timer.New()
			return setmetatable( self, CPSeries)
 		end


	--	------------------------------------
	--		public function :Start(socket)
	--			param: socket connected to processor
	--	------------------------------------

 		function CPSeries:Start(Sock)
			local private = privates[self]
			private.cache = {}
			private.echopending = nil   -- no outbound message sent yet on this connection
 			private.sock = Sock
 		    private.sock.Data = function(sock,data) readData(self) end
  			private.time.EventHandler = function(timer) Poll(self) end
   			private.time:Start(POLLTIME)
			private.waiting=0
			-- Start with the gap already elapsed, so the first poll after a
			-- connect puts the handshake query on the wire immediately
			-- instead of idling for one gap period.
			private.sincesend = private.gapticks
  	 		private.npoll = 0
    	    private.ready=false
    		for _,elem in pairs(Actions) do
    		 	setState(self,elem,false)
    		end
			-- precompile the per-model response patterns once (skip absent
			-- columns and the SEP row, which never maps to an action)
			local sep = CPServices[SEP][private.model.index]
			private.recv = {}
			for t=1,6 do
				local param = CPServices[t][private.model.index]
				if param then
					local pat = '^'..param:gsub('%p','%%%0')..sep..'?(.*)'
					table.insert(private.recv,{pat=pat,action=Actions[t]})
				end
			end
     		if private.model == Model.CP750 then
				local tmplist = {}
				for _,v in pairs(CP750) do
					table.insert(tmplist,v.value)
				end
				setValue(self,Actions.formlist,tmplist)
			end
	 		request(self,private.model)
  	  	end

	--	------------------------------------
	--		public function :Stop()
	--	------------------------------------

 		function CPSeries:Stop()
 			local private = privates[self]
			private.time:Stop()
 		end

	--	------------------------------------
	--		public function :Action( control, value )
	--			param: control, value to send to processor
	--	------------------------------------

		function CPSeries:Action(control,value)
			local private = privates[self]
			local action = Actions[control]
			-- unknown control or a write to the device-populated formlist:
			-- ignore rather than corrupting state (a formlist write used to
			-- overwrite the list with a non-table and crash the next ipairs)
			if not action or action == Actions.formlist then return end
			if not private.ready then return end
 		    if action == Actions.formname and not private.isMacro then
		    	-- map the chosen name to its list index; ignore if it isn't a
		    	-- current list entry (storing a string into the numeric format
		    	-- mirror would crash the next format poll)
		    	local idx
				for t,elem in ipairs(getValue(self,Actions.formlist)) do
					if value == elem then idx = t break end
				end
				if idx == nil then return end
				action, value = Actions.format, idx
				if self.EventHandler then
					self.EventHandler(action.key,value)
			end end
			if action == Actions.reset then
				value = value or true
				if self.EventHandler then
					self.EventHandler(Actions.formname.key,"")
				end
			end
      		setValue(self,action,value,true)
		end

	 	-- ------------ internal local utility functions  -----------------

  		local function trimstr(str) if(str) then str = str:match("^(.-)%s*$") end return str end
		local function comparetables(t1, t2) if #t1 ~= #t2 then return false end for i=1,#t1 do if t1[i] ~= t2[i] then return false end end return true end
		getValue = function(self,action) return privates[self].value[action.index][action.key] end
		getState = function(self,action) return privates[self].value[action.index]["state"] end
		setState = function(self,action,state)  privates[self].value[action.index]["state"] = state end

		-- A stored value can be a Lua boolean (Actions.reset's `value or true`,
		-- Mute's Controls.Mute.Boolean) or a number (everything arriving off
		-- the wire, via tonumber() in received() below) for the exact same
		-- logical action -- `false == 0` is never true in Lua (no boolean/
		-- number coercion), so without this, an incoming wire echo of a value
		-- just set locally as a boolean failed the "already equal" check and
		-- re-fired the EventHandler redundantly. Normalize booleans to 0/1
		-- before comparing so both representations of the same value compare
		-- equal.
		local function normalize(v) if type(v) == 'boolean' then return v and 1 or 0 end return v end

		local function isEqual(a,b)
 			if type(a)=='table' and type(b) == "table" then
				return comparetables( a, b)
			elseif type(a)~='table' and type(b) ~= "table" then
				return normalize(a) == normalize(b) end return false
		end

	 	Print = function(show,...)     --    show=false      show=true     show=nil
	 		if Properties.plugin_show_debug.Value == 0 then return end
	 		local tcp = Properties["TCP Log"]
			if ( tcp.Value == 'Command' and show ~= false ) or (tcp.Value == 'All' and show ~= nil) then
			print(...) end
	 	end

		local function doClose(self)
			local private = privates[self]
			if self.EventHandler then
				self.EventHandler("close", private.model.value)
			end
		end

		-- Format button number <-> wire token, per model. Returns nil for an
		-- out-of-range button (the caller then falls back to a query instead
		-- of sending garbage / indexing a nil entry).
		local function getButtonName(model,btnNum)
			if type(btnNum) ~= "number" then return nil end
			if model == Model.CP650 then return tostring(btnNum - 1) end     --is CP650
			if model == Model.CP750 then local b = CP750[btnNum] return b and b.key or nil end  --is CP750
			return tostring(btnNum)                                          --is macro model
		 end

		 local function getButtonNum(model,btnName)
		 	local function index(btnName)
		 		for _,btn in pairs(CP750) do
		 			if btn.key == btnName then return btn.index end
		 	end end
			if model == Model.CP650 then local n = tonumber(btnName) return n and n+1 or nil end  --is CP650
			if model == Model.CP750 then return index(btnName) end                                --is CP750
			return tonumber(btnName)                                                               --is macro model
		 end

		setValue = function(self,action,value,isevent)
			local private = privates[self]
   	 		isevent = isevent or false
  	 		if isEqual(getValue(self,action),value) then
				return
			end
 			if action == Actions.format and value==0 then
 				if self.EventHandler then
 					self.EventHandler(Actions.reset.key,getValue(self,Actions.format))
 				end
 			end
 			if getState(self,action) == false or isevent then
		    	private.value[action.index][action.key] = value
			end
			if isevent then
				setState(self,action,true)
			elseif self.EventHandler and (action~=Actions.format or value >0 ) then
					self.EventHandler(action.key,getValue(self,action))
 			end
			 if (action == Actions.format or action == Actions.formname )
 			  and getValue(self,Actions.reset) == true then
 				setValue(self,Actions.reset,false,true)
 			end
 			if private.isMacro then
				if action == Actions.format and self.EventHandler then
					local s = getValue(self,Actions.formname)
					if s ~= nil then self.EventHandler(Actions.formname.key,s) end
				end
			else
				if action == Actions.formlist then
					for t,v in ipairs(getValue(self,Actions.formlist)) do
						if t == getValue(self,Actions.format) then
							setValue(self,Actions.format,t)
					end end
				elseif action == Actions.format then
					local s
					for t,v in ipairs(getValue(self,Actions.formlist)) do
						if t == getValue(self,Actions.format) then s = v end
					end
					-- The format index has no entry in the list yet: the device
					-- has not reported its format list, or reported a shorter
					-- one. Leave the name mirror alone and stay quiet instead of
					-- publishing a nil formname -- the plugin's event handler
					-- asserts on a nil result, so pressing a format button
					-- before the list arrived used to crash the component.
					-- Same rule Action() already applies to the reverse
					-- direction, where an unresolvable name is ignored.
					if s ~= nil then
						setValue(self,Actions.formname,s)
						if self.EventHandler then
							self.EventHandler(Actions.formname.key,s)
						end
					end
				end
	  		end
		end

		local function writeSocket(self,msg,updated)
 			local private = privates[self]
			if not private.sock.IsConnected then doClose(self) return end -- don't write to a dead socket
     		local function write()
     			private.sock:Write(msg..'\r\n')
     		end
     		pcall(write)      -- write to socket
			private.sincesend = 0   -- the gap is measured from the last send
			-- CP650 raw-echoes the sent line before its real response
			-- ("Protocol Guarantees": expect RESPONSE, not echo). Arm the
			-- expectation for readData() below; other models never set
			-- this, so their read path is unchanged.
			private.echopending = (private.model == Model.CP650) and msg or nil
			Print(updated,'TX',msg)
		end

		request = function(self,model)
			local private = privates[self]
			local param = CPServices[Actions.reset.index][model.index]
			table.insert(private.cache, CPProtocol.FormatQuery(private.libmodel,param))
			if #private.cache > QMAX then
				table.remove(private.cache, 1)   -- saturation: drop the oldest first
			end
		end

		readData = function(self)
 			local private = privates[self]
 			local watchdog = false
 			repeat
    			local str = trimstr(private.sock:ReadLine(TcpSocket.EOL.Any));
    			if str and str ~='' then
    				if private.echopending and str == private.echopending then
    					-- The mechanical CP650 echo of what we just sent, not a
    					-- real reply: discard it without touching the watchdog
    					-- or calling received() on it, so it can neither be
    					-- misread as the answer (e.g. a query's echoed "?" is
    					-- not a value) nor prematurely satisfy the busy/one-
    					-- in-flight wait for the real response. Cleared after
    					-- one match: only the first identical line is the
    					-- mechanical echo -- a second one is a genuine (if
    					-- repetitive) reply and must be processed normally.
    					private.echopending = nil
    				else
    					watchdog = true received(self,str)
    				end
    			end
			until str==nil or private.sock.IsConnected == false
 			if not private.sock.IsConnected then doClose(self) end
 			if (watchdog) then private.waiting = 0 end
 		end

		local function pollAction(self)
			local private = privates[self]
  			local action = nil
			local num = 1
 			num = private.npoll %  2 == 1 and 2 or num
 			num = private.npoll %  4 == 3 and 3 or num
 			num = private.npoll %  8 == 7 and 4 or num
 			num = private.npoll % 0x2000 == 0 and 5 or num
 			private.npoll = ( private.npoll + 1 ) % 0x2000
  			for _,elem in pairs(Actions) do
  				if elem.index == num then action = elem end
  			end
			return action
 		end

		-- --------------------------------------------
		--  	Poll : send TCP Packet to Processor
		-- -------------------------------------------

 		Poll = function(self)
			local msg
  			local private = privates[self]
    		if private.waiting > WATCHDOG_TICKS then
  				doClose(self) return end
			private.sincesend = private.sincesend + 1
  			if private.waiting ==0 then
				-- Hold the wire until the model's minimum gap has passed.
				-- Returning before the waiting counter is bumped is what
				-- keeps this a hold and not a deadlock: waiting only starts
				-- counting once a command is actually in flight, so the next
				-- tick gets to try again instead of waiting forever for a
				-- response to a command that was never sent.
				if private.sincesend < private.gapticks then return end
  			  	local updated = false
  		    	if #private.cache == 0 then
  					local result = '?'
					local action = pollAction(self)
  					local param = CPServices[action.index][private.model.index]
  		 			if param == nil then return end
  					if ( action ~= Actions.format or getValue(self,Actions.reset)==false ) and
  						getState(self,action) and action ~= Actions.formlist then
  						result = getValue(self,action)
  			    		if action == Actions.format then
  			    			result = getButtonName(private.model,result)
  			    			if result == nil then result = '?' end -- invalid format value: query instead of a bad SET
  			   		 	end
  			    		if action == Actions.fader then
  			    			result = string.format('%.0f',result * 10)
  			    		end
  			    		if action == Actions.mute then
  			    			result = string.format('%.0f',result)
  			    		end
  			    		updated = getState(self,action)
  			    	end
					if result == '?' then
						msg = CPProtocol.FormatQuery(private.libmodel,param)
					else
						msg = CPProtocol.FormatMessage(private.libmodel,param,result)
					end
				else msg = table.remove(private.cache, 1) end   -- FIFO: oldest queued message first
  				writeSocket(self, msg, updated )
  			end
  			private.waiting = private.waiting + 1
  		end

  		-- -------------------------------------------

		-- 		TCP Packet received from processor
		-- -------------------------------------------

	    received = function(self,msg)
      	 	local private = privates[self]
     		local result,action
    	    Print(false,"RX",string.sub(msg,1,30))
      	 	for _,r in ipairs(private.recv) do
      	 		result = string.match(msg,r.pat)
      	 		if result ~= nil then action = r.action break end
      	 	end
    	 		if action==nil then      -- unreconigzed action
				if private.isMacro then -- Element List for CP850/CP950/CP950A
					-- bound the accumulator: real macro lists are well under
					-- this, so orphan/garbage "n:name" lines can't grow it
					-- without limit
					if #private.tmplist < 512 then
 						table.insert(private.tmplist,string.match(msg,'%d+:(.*)'))
 					end
      				return
      			end
      			Print(true,string.sub(msg,1,30))
      			return --ignore action
      		end
			if not private.ready then
				if CPServices[action.index][private.model.index] == CPServices[Actions.reset.index][private.model.index] then
   	 				private.ready = true
   	 				if self.EventHandler then
    					self.EventHandler('ready',private.model.value)
    				end
    			end
    			return
   		    end
   			if action == Actions.formlist then
				if private.model == Model.CP650 then
					local tmp = {} 	local pos = 1
                   	while pos do
        				local v = result:match('(%d+)',pos)
						if v == nil then break end
        				table.insert(tmp,'Format '.. v)
						pos = result:find(',',pos)
						if pos then pos = pos + 1 end
					end result = tmp
				else   -- macro list (CP850/CP950/CP950A)
					private.tmplist = {}
					readData(self) -- FIX: was readData(self,true) -- readData only takes
					               -- self, the second argument was silently ignored
					result = private.tmplist
			end	end
    		if  action == Actions.format then
      			result = getButtonNum(private.model,result)
      			if result == nil then return end -- unparseable format token: ignore, don't crash
				setState(self,action,false)
      		end
  	   		if action == Actions.fader or action ==  Actions.mute then
      		  local n = tonumber(result)
      		  if n == nil then return end -- non-numeric value (nan/garbage): ignore, don't crash
      		  n = tonumber(string.format('%.f',n))
      		  if n == nil then return end -- an overflowed value (e.g. 1e400 -> inf) formats to a string
      		                               -- tonumber can't parse back ("inf"/"nan"), ignore rather than crash
  	   			if action == Actions.fader then
      		  		n = n / 10
				end
      		  result = n
      		end
   			if isEqual(getValue(self,action),result) then
				setState(self,action,false)
				return
			end
			Print(nil,"RX",string.sub(msg,1,30))
      		setValue(self,action,result)
  		end

	end  -- end do
