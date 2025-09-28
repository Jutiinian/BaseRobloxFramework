--!strict

-- || Public API || --
local TablesUtility = {}

--[[function TablesUtility:Find<K, V>(Key: K, Tbl: {[K]: V}): V
    
end]]

function TablesUtility:Find(Key: any, Tbl: { [any]: any }): any
	if Tbl[Key] then
		return Tbl[Key]
	end

	for thisKey, thisValue in Tbl do
		if Key == thisKey then
			return thisValue
		elseif typeof(thisValue) == "table" then
			local SearchResult = self:Find(Key, thisValue)
			if SearchResult ~= nil then
				return SearchResult
			end
		end
	end

	return nil
end

return TablesUtility
