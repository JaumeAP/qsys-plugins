-- Minimal Lua OOP base: class(), Class:set(name, propDef), Class:new(...), Class:init(...).
-- Vendored replacement for the removed "class/class" git submodule (see CLAUDE.md).
-- Declares a global `class` function, matching how qknob.lua calls it after
-- `require("class/class")` without capturing a return value.

function class(parent)
	local Class = {}
	Class.__properties = {}
	Class.__parent = parent

	function Class:set(name, propDef)
		self.__properties[name] = propDef
	end

	local function lookupProperty(c, key)
		while c do
			local propDef = c.__properties[key]
			if propDef then return propDef end
			c = c.__parent
		end
		return nil
	end

	local function lookupMethod(c, key)
		while c do
			local method = rawget(c, key)
			if method then return method end
			c = c.__parent
		end
		return nil
	end

	function Class:new(...)
		local raw = {}
		local instance = {}

		setmetatable(instance, {
			__index = function(_, key)
				local propDef = lookupProperty(Class, key)
				if propDef then
					local value = raw[key]
					if propDef.get then return propDef.get(instance, value) end
					return value
				end
				return lookupMethod(Class, key)
			end,
			__newindex = function(_, key, val)
				local propDef = lookupProperty(Class, key)
				if propDef then
					local oldVal = raw[key]
					if propDef.set then val = propDef.set(instance, val, oldVal) end
					raw[key] = val
				else
					rawset(instance, key, val)
				end
			end,
		})

		local c = Class
		while c do
			for key, propDef in pairs(c.__properties) do
				if raw[key] == nil then raw[key] = propDef.value end
			end
			c = c.__parent
		end

		if instance.init then instance:init(...) end
		return instance
	end

	return Class
end
