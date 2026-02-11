-- || Services || --
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local ProductRegistry = require(script.Parent.ProductRegistry)
local Promise = require(ReplicatedStorage.Packages.promise)

-- || Types || --
type ProductInfo = {
	PriceInRobux: number?,
	[string]: any,
}

-- || Variables || --
local _priceCache: { [number]: number } = {}

-- || Public API || --
local MarketServiceUtils = {}

function MarketServiceUtils.PromptAsync(player: Player, productID: number, isGamepass: boolean?): Promise.TypedPromise<boolean>
	if not player or not player:IsDescendantOf(Players) then
		return Promise.reject("Player is not in the game")
	end
	
	local event = if isGamepass
		then MarketplaceService.PromptGamePassPurchaseFinished
		else MarketplaceService.PromptProductPurchaseFinished
	
	local eventConnection: RBXScriptConnection?
	
	return Promise.new(function(resolve, reject)
		eventConnection = event:Connect(function(purchaser, id, wasPurchased)
			if purchaser == player and id == productID then
				resolve(wasPurchased)
			end
		end)

		local success, err = pcall(function()
			if isGamepass then
				MarketplaceService:PromptGamePassPurchase(player, productID)
			else
				MarketplaceService:PromptProductPurchase(player, productID)
			end
		end)
		
		if not success then
			reject(`Failed to prompt purchase: {err}`)
		end
	end):finally(function()
		if eventConnection then
			eventConnection:Disconnect()
			eventConnection = nil
		end
	end)
end

function MarketServiceUtils.GetProductID(_self, productName: string): number?
	local gamepassData = ProductRegistry.GamePasses[productName]
	if gamepassData then
		return if typeof(gamepassData) == "table" then gamepassData.ID else gamepassData
	end

	local devProductData = ProductRegistry.DevProducts[productName]
	if devProductData then
		return if typeof(devProductData) == "table" then devProductData.ID else devProductData
	end
	
	return nil
end

function MarketServiceUtils.FetchProductPriceAsync(productId: number, infoType: Enum.InfoType): Promise.TypedPromise<number>
	return Promise.new(function(resolve, reject)
		local cached = _priceCache[productId]
		if cached then
			return resolve(cached)
		end

		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(productId, infoType)
		end)
		
		if not success then
			return reject(`Failed to fetch product info for ID {productId}: {result}`)
		end
		
		local info = result :: ProductInfo
		if not info then
			return reject(`No product info found for ID {productId}`)
		end
		
		local price = info.PriceInRobux
		if type(price) ~= "number" then
			return reject(`No price found for product ID {productId}`)
		end

		_priceCache[productId] = price

		return resolve(price)
	end)
end

return MarketServiceUtils