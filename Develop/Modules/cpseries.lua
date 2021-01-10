

   -- ##############################################################
   --			CPSeries Class
  -- ##############################################################
	
	do

		require("cpseries_class")
        require("dolbyfader")

        local DolbyCP = CPSeries.New(Properties.Model.Value)
 
 		DolbyFaderEventHandler = function(ctrl)
        	if ctrl  ~= DolbyCP then    
            	DolbyCP:Action("fader",DKNob.Value)
 			end
		end 

        local sock = TcpSocket:New()
        sock.WriteTimeout = 2

        -- Local functions

        local function SetStatus(state,msg)
            if Controls.status.Value ~= state then
            	Print(true,'Set Status '..state)
            	Controls.status.Value = state
            end
            Controls["status.led"].Value = state
            --if Controls.status.Value == 5 then Controls["status.led"].Color = 'blue'
            if Controls.status.Value == 0 then Controls["status.led"].Color = 'lightgreen'
            --if Controls.status.Value == 2 then Controls["status.led"].Color = 'red'
            end
            if msg ~= nil then Controls.status.String =  string.sub(msg,1,30)
            else Controls.status.String = '' end
        end

        local function validateAddress(ip)
            local chunks = {string.match(ip,"^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
            if #chunks < 4 then
                return false
            end
            for _,v in pairs(chunks) do
                if tonumber(v) > 255 then
                    return false
                end
            end
            return true
        end

		local function connect()
			Controls.refresh.IsDisabled = false
			if validateAddress(Controls.address.String) then
				SetStatus(5,'')
				local CPPort
				local assign = {
				  [Model.CP650.value] = function() CPPort = 61412 end,
				  [Model.CP750.value] = function() CPPort = 61408 end,
				  [Model.CP850.value] = function() CPPort = 61408 end
				} assign[Properties.Model.Value]()
				
				sock:Connect(Controls.address.String,CPPort)
			else
				if System.IsEmulating then
					SetStatus(0,"Emulation")
				else
					SetStatus(2,"Invalid Address")
				end
			end
		end

    local function disconnect(recon)
		DolbyCP:Stop()
        sock:Disconnect()
        if recon then SetStatus(5,'Connect')
        else SetStatus(2,'Offline') end
    end
    
    local function refreshCNX()
        disconnect(true)
        Controls.refresh.IsDisabled = true
        Timer.CallAfter(connect,1)
    end

	local function sockError(msg)
		if sock.IsConnected then
			sock:Disconnect()
			Print(true,'SOCK',msg)
			Print(true,'SOCK',"Closed")
			SetStatus(2,msg)
			DolbyCP:Stop()
			Timer.CallAfter(refreshCNX,2)
		end
	end

		--- sock Events --

		sock.Connected = function()
			Print(true,'SOCK',"Connected")
			DolbyCP:Start(sock)
		end

		sock.Closed = function()  
			Print(true,'SOCK','Closed') 
			SetStatus(4,"Offline") 
		end
		
		sock.Timeout = function() 
			Print(true,'SOCK','Timeout') 
			SetStatus(2,"Timeout") 
		end
		
		sock.Error = function(_,err)
			Print(true,'SOCK',"Remote Server Error "..err)
			SetStatus(2,err)
		end

		sock.Reconnect = function()
			Print(true,'SOCK',"Reconnecting")
			SetStatus(5,"Attempt Reconnect")
		end

		-- Events ---

		Controls.address.EventHandler = refreshCNX
		Controls.refresh.EventHandler = refreshCNX

		DolbyCP.EventHandler = function(service,result)
			local action = {
				["close"] = function() local msg ='unknown Dolby ' ..result sockError(msg) end,
				["ready"] = function()  Print(true,'found "Dolby '..result..'"') SetStatus(0) end,
				["formlist"] = function() Controls.select.Choices = result  end,
				["formname"] = function() Controls.select.String = result end,
				["mute"] = function()   Controls.mute.Value = result end,
				["fader"] = function()  DKNob.Value = result
										DKNob.EventHandler(DolbyCP)
										end,
				["format"] = function() assert(result~=0,"Plugin Event Error: format=0")
										Controls.selector[tonumber(result)].Value = 1
										Controls.selector[tonumber(result)].EventHandler(DolbyCP) end,
				["reset"] = function()  assert(result~=0,"Plugin Event Error: reset=0")
										Controls.selector[result].Value = 0 end,
			}
			-- *** FOR DEBUG ****
			--print("Event Triggered:",service,result)
			assert( service, "Plugin Event Error: service=nil" )
			assert( result, "Plugin Event Error: result=nil" )
			assert( action[service], "Plugin Event Error: service" )
			action[service]()
		end

		Controls.mute.EventHandler = function(ctrl)
			DolbyCP:Action("mute",Controls.mute.Value)
		end

		Controls.select.EventHandler = function(ctrl)
			DolbyCP:Action("formname",Controls.select.String)
		end

		for numBtn,ctl in ipairs(Controls.selector) do
			ctl.EventHandler = function(ctrl)
				if ctl.Value == 1 then
					for _,ctrl in ipairs(Controls.selector) do
						if ctrl ~= ctl then ctrl.Value = 0 end
					end
					if ctrl ~= DolbyCP then DolbyCP:Action("format",numBtn)  end
				else
					for _,ctl in ipairs(Controls.selector) do
						if ctl.Value == 1 then return end
					end
					DolbyCP:Action("reset")
				end
		end end



	 -- init plugin--

		-- hidden components

		if Controls.start.Value == false then
			Controls.start.Value = true
			dolby.Value = 7.0
			dolby.EventHandler(DolbyCP)
			Controls.mute.Value = 0
			Controls.selector[1].Value = 1
			Controls.selector[1].EventHandler(DolbyCP)
		end

		refreshCNX()

	end