
	--///////////////////////  QKNob Class ////////////////////////////// 

  require("class/class")

  do

    -- declare local variables & functions
    local setposition,getposition,formatstr,formatval,todigits,compare
    local privates = setmetatable({}, {__mode = "k"}) 

    QKnob = class()

    QKnob:set("Value",{
        value = 0,	
        get = function(self,value) return value end, 
        set = function(self, newVal,oldVal) 
          newVal = formatval(self,newVal)
          privates[self].ctrl.Value = newVal 
          if not privates[self].nested then 
          	privates[self].nested = true
          	self.Position = setposition(self,newVal) 
          	self.String = newVal
          	privates[self].nested = false 		
          end
          return newVal 
        end,
        } ) 

    QKnob:set("String",{ 	
        value = "",
        get = function(self,value) return value end, 
        set = function(self, newVal,oldVal)	
          newVal = formatstr(self,newVal)
          privates[self].ctrl.String = newVal 
          if not privates[self].nested then
          	privates[self].nested = true
          	self.Value = newVal
          	self.Position = setposition(self,self.Value)
          	privates[self].nested = false 		
          end
          return newVal 
        end,
      })			

    QKnob:set("Position",{ 	
        value = 0,
        get = function(self,value) return value end, 
        set = function(self, newVal,oldVal)
          local val = getposition(self,newVal)
          newVal = setposition(self,val)	 
          privates[self].ctrl.Position = newVal 
          if not privates[self].nested then
          	privates[self].nested = true 		
          	self.Value = getposition(self,newVal) 
          	self.String = self.Value
          	privates[self].nested = false		
          end
          return newVal 
        end,
        } ) 			


    function QKnob:SetString(val) 
      return val 
    end	

    function QKnob:init(ctlName, Min, Max, numDecs )
      local ctrldef = nil
      for _,def in ipairs(GetControls(Properties)) do
        if def.Name == ctlName then	 ctrldef = def break end	
      end 
      assert(ctrldef,"GetComponents: "..ctlName.." not found")
      assert(ctrldef.ControlType=="Text","GetComponents: "..ctlName..".Type is not 'Text'")
      privates[self] = { ctrl = Controls[ctlName], nested = false, min=Min, max=Max, 
        numdecs = numDecs, tm = Timer.New() }
      self.EventHandler = nil		
      privates[self].ctrl.EventHandler = function() 
         local newVal = formatstr(self,privates[self].ctrl.String)
		 if self.String ~=newVal then 	
        	self.String =  newVal
    		if self.EventHandler then
            	self.EventHandler(privates[self].ctrl)
        	end
        end
      end
      self.String = privates[self].ctrl.String 
      privates[self].tm.EventHandler = function()
        compare(self)
      end
      privates[self].tm:Start(1/1000)
    end

    todigits = function (a) 
      local _
      a = tostring(a) or "" 
      a,_ = a:gsub("[^%d.-]", "") 
      return tonumber(a) or 0  
    end

    setposition = function(self,value)
      local p = (value-privates[self].min)/(privates[self].max-privates[self].min) 
      return p<0 and 1+p or p 
    end

    getposition = function(self,value)
      value = value * ( privates[self].max-privates[self].min ) + privates[self].min 
      return value
    end

    compare = function(self)
      if math.abs(privates[self].ctrl.Position - self.Position)>=1e-3 and not privates[self].nested then
        self.Position = privates[self].ctrl.Position 
    	if self.EventHandler then
            self.EventHandler(privates[self].ctrl)
        end
      end 				
    end

    formatval = function(self,val)
      val = todigits(val)
      val = val < privates[self].min and privates[self].min or val
      val = val > privates[self].max and privates[self].max or val 		
      if privates[self].numdecs then
        val = tonumber(string.format("%."..privates[self].numdecs.."f",val))
      end
      return val	
    end

    formatstr = function(self,val)
      val = todigits(val)
      val = val < privates[self].min and privates[self].min or val
      val = val > privates[self].max and privates[self].max or val 		
      local neg = val<0 and true or false
      val = math.abs(val)
      local num = 0 
      num = val<100 and 1 or num
      num = val<10  and 2 or num
      num = val< 1  and 3 or num
      if privates[self].numdecs then
        num = num>privates[self].numdecs and privates[self].numdecs or num 
      end
      val = string.format("%."..num.."f",val)	
      if not privates[self].numdecs then
        val = tonumber(val)<1 and val:sub(2) or val
        val = tonumber(val)==0 and 0 or val
      end
      if neg then val = '-'.. val end
      val = self:SetString(tostring(val))
      return tostring(val)
    end

  end
