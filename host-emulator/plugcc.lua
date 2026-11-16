-- Source assembler standing in for QSC's PLUGCC.exe `#include` expansion, so a
-- plugin can be loaded straight from Developer/plugins/<Name>/plugin.lua. The
-- test harness also uses it to assemble the distributables into build/ (the
-- real PLUGCC output only exists in the build-qplug release assets).
--
-- A directive is a Lua comment on its own line:  --[[ #include "x.lua" ]]
-- Rules, as qsys-plugin-development.md records them for PLUGCC: a relative
-- path always resolves against the directory of the ORIGINAL plugin.lua, and
-- the directive is replaced by the file's text. Nested includes are expanded
-- too (the real tool only honours them when they are that file's first line;
-- this expander is more lenient, so it cannot prove a layout PLUGCC accepts).

local M = {}

local function read(path)
	local f = assert(io.open(path, "rb"), "cannot open " .. path)
	local text = f:read("a")
	f:close()
	return text
end

-- Returns the assembled source of `plugin_lua` (path to a plugin.lua).
function M.assemble(plugin_lua)
	local dir = plugin_lua:match("^(.*)[/\\][^/\\]*$") or "."
	local function expand(text, depth)
		assert(depth < 8, "include nesting too deep")
		return (text:gsub('%-%-%[%[%s*#include%s+"([^"]+)"%s*%]%]', function(rel)
			return expand(read(dir .. "/" .. rel), depth + 1)
		end))
	end
	return expand(read(plugin_lua), 0)
end

-- Load the assembled plugin as a chunk named after the plugin.
function M.load(plugin_lua)
	return assert(load(M.assemble(plugin_lua), "@" .. plugin_lua, "t"))
end

return M
