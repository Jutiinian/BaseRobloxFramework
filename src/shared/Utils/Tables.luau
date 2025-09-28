--!strict

-- || Public API || --
local TablesUtility = {}

--[[
    Recursively searches Tbl for Key and returns the value, or nil if not found.
]]
function TablesUtility:Find(Key: any, Tbl: { [any]: any }): any
	-- Direct index if key exists at this level
	if Tbl[Key] then
		return Tbl[Key]
	end

	-- Recursive search through nested tables
	for _, thisValue in Tbl do
		if typeof(thisValue) == "table" then
			local SearchResult = self:Find(Key, thisValue)
			if SearchResult ~= nil then
				return SearchResult
			end
		end
	end

	return nil
end

--[[
    Recursively searches Tbl for Key and replaces its value with Value.
    Returns true if replacement happened, false otherwise.
	EnforceType = optional; Makes sure incoming value is of the same type as current value
]]
function TablesUtility:Replace(Key: any, Value: any, Tbl: { [any]: any }, EnforceType: boolean?): boolean
	EnforceType = EnforceType or false

	-- Direct replacement if key exists at this level
	if Tbl[Key] ~= nil then
		if EnforceType and typeof(Tbl[Key]) ~= typeof(Value) then
			warn(
				`TablesUtility:Replace - Type mismatch for key '{tostring(Key)}': {typeof(Tbl[Key])} ~= {typeof(Value)}`
			)
			return false
		end

		Tbl[Key] = Value
		return true
	end

	-- Recursive search through nested tables
	for _, thisValue in pairs(Tbl) do
		if typeof(thisValue) == "table" then
			local replaced = self:Replace(Key, Value, thisValue)
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
function TablesUtility:IsEmpty(Tbl: { [any]: any }): boolean
	return next(Tbl) == nil
end

--[[
	Returns the number of entries in the table.
    Works for both arrays and dictionaries.
]]
function TablesUtility:Length(Tbl: { [any]: any }): number
	local count = 0

	for _ in pairs(Tbl) do
		count += 1
	end

	return count
end

return TablesUtility
