  -------- STRICT -----------------------
  --  Verify strict variables
  --  Error if variable is not declared 	
  ---------------------------------------

  do 

    local mt = getmetatable(_G)

    if mt == nil then 
      mt = {} 
      setmetatable(_G, mt) 
    end   
    mt.__declared = {}

    function Global(...) 
      for _, key in ipairs{...} do 
        mt.__declared[key] = true 
      end 
    end

    mt.__newindex = function (table, key, value) 
      if not mt.__declared[key] then
        if  debug.getinfo(2, "S").what ~= "C" then 
          error("assign to undeclared variable '"..key.."'", 2)
        end 
        mt.__declared[key] = true 
      end 
      rawset(table, key, value) 
    end

    mt.__index = function (table, key) 
      if not mt.__declared[key] and debug.getinfo(2, "S").what ~= "C" then
        error("variable '"..key.."' is not declared", 2) 
      end 
      return rawget(table, key) 
    end 

  end
