--!strict

-- || Public API || --
local TablesUtility = {}

--[[
    Recursively searches tbl for key and returns the value, or nil if not found.
]]
function TablesUtility:Find(key: any, tbl: { [any]: any }): any
	-- Direct index if key exists at this level
	if tbl[key] then
		return tbl[key]
	end

	-- Recursive search through nested tables
	for _, thisValue in tbl do
		if typeof(thisValue) == "table" then
			local searchResult = self:Find(key, thisValue)
			if searchResult ~= nil then
				return searchResult
			end
		end
	end

	return nil
end

--[[
    Recursively searches tbl for key and replaces its value with value.
    Returns true if replacement happened, false otherwise.
    enforceType = optional; if true, makes sure the incoming value has the same type as the current value
]]
function TablesUtility:Replace(key: any, value: any, tbl: { [any]: any }, enforceType: boolean?): boolean
	enforceType = enforceType or false

	-- Direct replacement if key exists at this level
	if tbl[key] ~= nil then
		if enforceType and typeof(tbl[key]) ~= typeof(value) then
			warn(
				`TablesUtility:Replace - Type mismatch for key '{tostring(key)}': {typeof(tbl[key])} ~= {typeof(value)}`
			)
			return false
		end

		tbl[key] = value
		return true
	end

	-- Recursive search through nested tables
	for _, thisValue in pairs(tbl) do
		if typeof(thisValue) == "table" then
			local replaced = self:Replace(key, value, thisValue, enforceType)
			if replaced then
				return true
			end
		end
	end

	return false
end

--[[
    Returns true if the table has no entries
]]
function TablesUtility:IsEmpty(tbl: { [any]: any }): boolean
	return next(tbl) == nil
end

--[[
    Returns the number of entries in the table.
    Works for both arrays and dictionaries.
]]
function TablesUtility:Length(tbl: { [any]: any }): number
	local count = 0
	for _ in pairs(tbl) do
		count += 1
	end
	return count
end

return TablesUtility
