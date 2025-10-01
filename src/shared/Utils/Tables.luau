--!strict

-- || Variables || --
local RNG = Random.new()

-- || Public API || --
local TablesUtility = {}

--[[
    Recursively searches through a dictionary for the given key and returns its value.
    - Returns nil if the key is not found.
    - Only supports dictionaries (arrays are not supported).
]]
function TablesUtility.SimpleFind(key: any, tbl: { [any]: any }): any
	-- Direct index if key exists at this level
	if tbl[key] then
		return tbl[key]
	end

	-- Recursive search through nested tables
	for _, thisValue in tbl do
		if typeof(thisValue) == "table" then
			local searchResult = TablesUtility.SimpleFind(key, thisValue)
			if searchResult ~= nil then
				return searchResult
			end
		end
	end

	return nil
end

--[[
    Returns the first value and key in the table that satisfies the callback.
    - Iterates through each element and calls the callback with (value, index, tbl).
    - If the callback returns true, the current value and key are returned.
    - Works with both arrays and dictionaries, but dictionary order is not guaranteed.
]]
function TablesUtility.Find<K, V>(tbl: { [K]: V }, callback: (V, K, { [K]: V }) -> boolean): (V?, K?)
	for k, v in tbl do
		if callback(v, k, tbl) then
			return v, k
		end
	end

	return nil, nil
end

--[[
	Locks the table using `table.freeze`.
	- Locks nested tables as well.
]]
function TablesUtility.Lock<T>(tbl: T): T
	local function Freeze(t: { [any]: any })
		for k, v in pairs(t) do
			if type(v) == "table" then
				t[k] = Freeze(v)
			end
		end

		return table.freeze(t)
	end

	return Freeze(tbl :: any)
end

--[[
    Returns a new shuffled copy of the given array.
    - `rngOverride` can be provided for deterministic/randomized control, otherwise defaults to `RNG`.
    - Original table is not modified.
]]
function TablesUtility.Shuffle<T>(tbl: { T }, rngOverride: Random?): { T }
	assert(typeof(tbl) == "table", "Shuffle: First argument must be a table")

	local shuffled = table.clone(tbl)
	local rng = if typeof(rngOverride) == "Random" then rngOverride else RNG

	for i = #shuffled, 2, -1 do
		local j = rng:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	return shuffled
end

--[[
    Recursively searches tbl for key and replaces its value with value.
    - Returns true if replacement happened, false otherwise.
    - enforceType = optional; if true, makes sure the incoming value has the same type as the current value.
]]
function TablesUtility.Replace(key: any, value: any, tbl: { [any]: any }, enforceType: boolean?): boolean
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
			local replaced = TablesUtility.Replace(key, value, thisValue, enforceType)
			if replaced then
				return true
			end
		end
	end

	return false
end

--[[
    Returns true if the table has no entries.
]]
function TablesUtility.IsEmpty(tbl: { [any]: any }): boolean
	return next(tbl) == nil
end

--[[
    Returns the number of entries in the table.
    - Works for both arrays and dictionaries.
]]
function TablesUtility.Length(tbl: { [any]: any }): number
	local count = 0
	for _ in pairs(tbl) do
		count += 1
	end
	return count
end

return TablesUtility
