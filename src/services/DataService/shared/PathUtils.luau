-- || Variables || --
local pathCache = {} :: { [string]: { string } }
local stringCache = {} :: { [any]: string }
setmetatable(pathCache, { __mode = "k" })
setmetatable(stringCache, { __mode = "k" })

local strFind = string.find

-- || Private Functions || --
local function hasDot(str: string): boolean
	return strFind(str, ".", 1, true) ~= nil
end

local function fastSplit(str: string, delimiter: string): { string }
	local result = table.create(8)
	local pattern = "[^" .. delimiter .. "]+"
	
	for match in string.gmatch(str, pattern) do
		table.insert(result, match)
	end
	
	return result
end

-- || Public API || --
local PathUtils = {}

--[[
	Normalizes an index path into a consistent format
	Returns: normalized path, isSplit (boolean indicating if it's an array)
	
	Performance optimizations:
	1. Single-key strings avoid splitting entirely
	2. Caching prevents redundant splits
	3. Tables are passed through unchanged
	4. Pre-allocated table for splits
]]
function PathUtils.normalizePath(indexPath: string | { string }): ({ string } | string, boolean)
	-- Fast path: already a table, return as-is
	if type(indexPath) == "table" then
		return indexPath, true
	end
	
	-- Fast path: single key (no dots)
	if not hasDot(indexPath) then
		return indexPath, false
	end
	
	-- Check cache before splitting
	local cached = pathCache[indexPath]
	if cached then
		return cached, true
	end
	
	-- Split and cache the result
	local splitPath = fastSplit(indexPath, ".")
	pathCache[indexPath] = splitPath
	
	return splitPath, true
end

--[[
	Converts any index path into a string representation
	Performance optimizations:
	1. Strings returned immediately
	2. Results cached by reference
	3. Uses table.concat (C-level optimization)
]]
function PathUtils.stringifyPath(indexPath: string | { string }): string
	if type(indexPath) == "string" then
		return indexPath
	end
	
	-- Check cache
	local cached = stringCache[indexPath]
	if cached then
		return cached
	end
	
	-- Create and cache string representation
	local result = table.concat(indexPath, ".")
	stringCache[indexPath] = result
	
	return result
end

--[[
	Clears the path caches (useful for testing or memory management)
]]
function PathUtils.clearCache()
	table.clear(pathCache)
	table.clear(stringCache)
end

--[[
	Gets the parent path and the final key
	Returns: parentPath, finalKey
	
	Examples:
	"Settings.Audio.Volume" -> "Settings.Audio", "Volume"
	{"Settings", "Audio", "Volume"} -> {"Settings", "Audio"}, "Volume"
	"Volume" -> nil, "Volume"
]]
function PathUtils.splitParentAndKey(indexPath: string | { string }): (string | { string } | nil, string)
	local normalized, isSplit = PathUtils.normalizePath(indexPath)
	
	if not isSplit then
		-- Single key, no parent
		return nil, normalized :: string
	end
	
	local path = normalized :: { string }
	local finalKey = path[#path]
	
	if #path == 1 then
		return nil, finalKey
	end
	
	-- Create parent path
	local parentPath = table.create(#path - 1)
	for i = 1, #path - 1 do
		parentPath[i] = path[i]
	end
	
	return parentPath, finalKey
end

--[[
	Validates that a path exists in a data structure
	Returns: true if path exists, false otherwise
]]
function PathUtils.pathExists(data: any, indexPath: string | { string }): boolean
	if indexPath == nil then
		return true
	end
	
	local normalized, isSplit = PathUtils.normalizePath(indexPath)
	
	if not isSplit then
		return data[normalized] ~= nil
	end
	
	local current = data
	for _, key in ipairs(normalized :: { string }) do
		if type(current) ~= "table" then
			return false
		end
		
		current = current[key]
		if current == nil then
			return false
		end
	end
	
	return true
end

return PathUtils