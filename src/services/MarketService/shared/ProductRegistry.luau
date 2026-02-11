-- || Public API || --
local ProductRegistry = {
	GamePasses = {
		-- Example:
		-- TEMPLATE = {
		--     ID = 123123123,      -- Normal Gamepass ID
		--     GiftID = 456456456,  -- Dev Product for gifting
		-- }
	},

	DevProducts = {
		-- Example:
		-- TEMPLATE = 789789789,
	},
}

-- Lookup tables
local lookups = {
	GamePassesByID = {}, -- ID -> key
	GamePassesByGiftID = {}, -- GiftID -> key
	DevProductsByID = {}, -- DevProduct ID -> key
}

for key, data in pairs(ProductRegistry.GamePasses) do
	lookups.GamePassesByID[data.ID] = key
	if data.GiftID then
		lookups.GamePassesByGiftID[data.GiftID] = key
	end
end

for key, id in pairs(ProductRegistry.DevProducts) do
	lookups.DevProductsByID[id] = key
end

function ProductRegistry:GetGamePassKeyFromId(id: number): string?
	return lookups.GamePassesByID[id]
end

function ProductRegistry:GetGamePassKeyFromGiftId(giftId: number): string?
	return lookups.GamePassesByGiftID[giftId]
end

function ProductRegistry:GetDevProductKeyFromId(id: number): string?
	return lookups.DevProductsByID[id]
end

return ProductRegistry
