   -- ##############################################################
   --			CPSeries Class
  -- ##############################################################

  function setmeta(table) 
    local function searchelem(table,index) local m = getmetatable(table)
    local list = m.__table or table for count,elem in pairs(list) do
      for key,value in pairs(elem)  do if elem == table then if index=="index" then return count end 
        if index=="key" then return key end if index=="value" then return value end end 
        if key == index then if index~="state" then return elem end return nil end end end 
    error("variable '"..index.."' is not declared", 2) end
    local m = getmetatable(table) or {} setmetatable(table,m)
    m.__index = searchelem m = {}  m.__index = searchelem  m.__table = table
	for _,elem in pairs(table) do setmetatable(elem,m)  end end

	do

		local POLLTIME = 0.02
		local setValue,getValue,setState,getState,Poll,readData, request,received
		local privates = setmetatable({}, {__mode = "k"}) -- set 'privates' as private field
		
		local CP750 ={ { dig_1='digital 1' }, { dig_2='digital 2' }, { dig_3='digital 3' }, { dig_4='digital 4' },
					   { analog='Analog Input' },{ non_sync='Non Sync' },{ mic='Microphone' } }	
		
		local Actions = { {fader=false}, {mute=false}, {format=false}, 
						  {formname=false}, {formlist=false}, {reset=false} }		
  		
  		local SEP = 7	 	--	- CP650 -	     - CP750 -			    - CP850 -   
 		local CPServices ={  {'fader_level',  'cp750.sys.fader',      'sys.fader'       },    -- FADER
 							 {'mute',         'cp750.sys.mute',       'sys.mute'        },	-- MUTE	
 						     {'format_button','cp750.sys.input_mode', 'sys.macro_preset'},	-- FORMAT
 							 { nil,			  nil,                    'sys.macro_name'  },	-- FORMNAME
 							 {'format_list',  nil,                    'sys.macros'      },	-- FORMLIST
 							 {'fader_level',  'cp750.sysinfo.version','sys.fader' 		},	-- QUERY
							 { '=',' ',' ' } }												-- SEP
		  	 	 	 
 		-- assign metadata to tables
 
		setmeta(CP750)
		setmeta(Actions)
		
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
 						time=nil, npoll=0, model=Model.CP850.index, sock=nil, ready=false, cache ={}, waiting=0,tmplist={} }
 			local private = privates[self]
 			setmeta(private.value)
			for _,elem in pairs(Model) do
				if elem.value == model then private.model = elem end 
			end
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
 			private.sock = Sock				
 		    private.sock.Data = function(sock,data) readData(self) end		
  			private.time.EventHandler = function(timer) Poll(self) end
   			private.time:Start(POLLTIME) 
			private.waiting=0
  	 		private.npoll = 0
    	    private.ready=false
    		for _,elem in pairs(Actions) do 
    		 	setState(self,elem,false)
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
			local action
  			for _,elem in pairs(Actions) do 
  				if elem.key == control then action = elem end 
  			end
			assert(action,"CPSeries:Action -> Invalid control='".. control .."' param")
			-- *** FOR DEBUG ONLY ***
			--print("Action: control="..action.key.."  value=",value)
			if not private.ready then return end
 		    if action == Actions.formname then
		    	if private.model ~= Model.CP850 then
					action = Actions.format
					for t,elem in ipairs(getValue(self,Actions.formlist)) do
						if value == elem then value = t break end
					end
					if self.EventHandler then
						-- *** FOR DEBUG ONLY ***
						--print("Send Event1",action.key,value)
						self.EventHandler(action.key,value)
			end end end
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
		getValue = function(self,action) assert(self,"self is null") assert(action,"action is null") return privates[self].value[action.index][action.key] end
		getState = function(self,action) return privates[self].value[action.index]["state"] end
		setState = function(self,action,state)  privates[self].value[action.index]["state"] = state end
										
		local function isEqual(a,b)
 			if type(a)=='table' and type(b) == "table" then
				return comparetables( a, b) 
			elseif type(a)~='table' and type(b) ~= "table" then
				return a == b end return false
		end

	 	Print = function(show,...)     --    show=false      show=true     show=nil
	 		local tcp = Properties["TCP Log"] 	 
	 		if Properties.plugin_show_debug.Value == 0 then return end
			if ( tcp.Value == 'Command' and show ~= false ) or (tcp.Value == 'All' and show ~= nil) then
			print(...) end
	 	end
		
		local function doClose(self)
			local private = privates[self]
			if self.EventHandler then 
				self.EventHandler("close", private.model.value) 
			end 
		end

		
		local function getButtonName(model,btnNum)
			local action = {
				[Model.CP650] = function() btnNum = tostring(btnNum - 1)  end,    --is CP650
        		[Model.CP750] = function() btnNum = CP750[btnNum].key 	end,    --is CP750
        		[Model.CP850] = function() btnNum = tostring(btnNum)      end  }  --is CP850
			action[model]() 
			return btnNum
		 end

		 local function getButtonNum(model,btnName)
		 	local function index(btnName) 
		 		for _,btn in pairs(CP750) do 
		 			if btn.key == btnName then return btn.index end 
		 	end end			
			local action = { 
				[Model.CP650] =  function() btnName = tonumber(btnName)+1 	end,  --is CP650
        		[Model.CP750] =  function() btnName = index(btnName) 		end,  --is CP750
        		[Model.CP850] =  function() btnName = tonumber(btnName)	   	end } --is CP850
			action[model]()		 
		 	return btnName
		 end

		setValue = function(self,action,value,isevent)
			local private = privates[self]	
   	 		isevent = isevent or false
   	 		assert(action,"setValue->action is null)")
  	 		if isEqual(getValue(self,action),value) then
				return
			end	
			-- ***FOR DEBUG ONLY!!!****
			--print("setValue","action="..action.key,"value="..tostring(value),"isevent="..tostring(isevent))
 			if action == Actions.format and value==0 then
 				if self.EventHandler then
						-- *** FOR DEBUG ONLY ***
					--print("Send Event0",Actions.reset.key,getValue(self,Actions.format))
 					self.EventHandler(Actions.reset.key,getValue(self,Actions.format))
 				end
 			end
 			if getState(self,action) == false or isevent then
		    	private.value[action.index][action.key] = value
			end			
			if isevent then 
				setState(self,action,true)
			elseif self.EventHandler and (action~=Actions.format or value >0 ) then
			-- *** FOR DEBUG ONLY ***
				--print("Send Event3",action.key,getValue(self,action))
					self.EventHandler(action.key,getValue(self,action))
 			end
			 if (action == Actions.format or action == Actions.formname ) 
 			  and getValue(self,Actions.reset) == true then
 				setValue(self,Actions.reset,false,true)	
 			end	  			
 			if private.model ~= Model.CP850 then
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
					setValue(self,Actions.formname,s) 
					if self.EventHandler then
						self.EventHandler(Actions.formname.key,s)
					end
				end	
	  		elseif action == Actions.format and self.EventHandler then
	  			self.EventHandler(Actions.formname.key,getValue(self,Actions.formname))
	  	end end

		local function writeSocket(self,msg,updated)		
 			local private = privates[self]
			if not private.sock.IsConnected then doClose(self)	end 
     		local function write()
     			private.sock:Write(msg..'\r\n')
     		end
     		pcall(write)      -- write to socket
			Print(updated,'TX',msg)
		end

		request = function(self,model)
			local private = privates[self]			
			local msg = CPServices[Actions.reset.index][model.index]
							.. CPServices[SEP][model.index] .. '?'
			table.insert(private.cache,msg)
		end
			
		readData = function(self)
 			local private = privates[self]
 			local watchdog = false	
 			repeat 
    			local str = trimstr(private.sock:ReadLine(TcpSocket.EOL.Any));	    		
    			if str and str ~='' then watchdog = true received(self,str)  end	
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
 			--if #private.cache == 0 then
 				private.npoll = ( private.npoll + 1 ) % 0x2000 or 0
			--end
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
    		if private.waiting > 30 then
  				doClose(self) return end
  			if private.waiting ==0 then	
  			  	local updated = false
  		    	if #private.cache == 0 then
  					local result = '?'
					local action = pollAction(self)  			
  					msg = CPServices[action.index][private.model.index]
  		 			if msg == nil then return end
  		 			msg = msg .. CPServices [SEP][private.model.index]
  					if ( action ~= Actions.format or getValue(self,Actions.reset)==false ) and
  						getState(self,action) and action ~= Actions.formlist then
  						result = getValue(self,action)
  			    		if action == Actions.format then
  			    			result = getButtonName(private.model,result)
  			   		 	end
  			    		if action == Actions.fader then
  			    			result = string.format('%.0f',result * 10)
  			    		end
  			    		if action == Actions.mute then
  			    			result = string.format('%.0f',result)
  			    		end
  			    		updated = getState(self,action) 
  			    	end
					msg = msg .. result
				else msg = table.remove(private.cache) end	
  				writeSocket(self, msg, updated )
  			end
  			private.waiting = private.waiting + 1  		
  		end		
  	
  		-- -------------------------------------------

		-- 		TCP Packet received from processor
		-- -------------------------------------------
		
	    received = function(self,msg)  
      	 	local private = privates[self]	
     		local result,pattern,action
    	    Print(false,"RX",string.sub(msg,1,30))  
      	 	for t, actiontype in ipairs(CPServices) do
      			pattern = actiontype[private.model.index]  
      			if pattern ~= nil then
      				result = string.match(msg,'^'..pattern..CPServices[SEP][private.model.index]..'?(.*)')
    				if result ~= nil then 
    				 	for _,elem in pairs(Actions) do 
  							if elem.index == t then action = elem end 
  			end break end end end		
    	 		if action==nil then      -- unreconigzed action
				if private.model == Model.CP850 then -- Element List for CP850
 					result = string.match(msg,'%d+:(.*)')
   					table.insert(private.tmplist,result)	
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
				else   -- is CP850
					private.tmplist = {}
					readData(self,true)
					result = private.tmplist
			end	end		    
    		if  action == Actions.format then
      			result = getButtonNum(private.model,result) 	 
				setState(self,action,false) 
      		end			
  	   		if action == Actions.fader or action ==  Actions.mute then
      		  result = tonumber(string.format('%.f',result)) 
  	   			if action == Actions.fader then
      		  		result = result / 10 
				end      		
      		end  
   			if isEqual(getValue(self,action),result) then
				setState(self,action,false) 
				return
			end
			Print(nil,"RX",string.sub(msg,1,30))  	
      		setValue(self,action,result)	 	
  		end  

	end  -- end do
