-- || Services || --
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local MarketServiceUtils = require(script.Parent.MarketServiceUtils)
local ProductRegistry = require(script.Parent.ProductRegistry)

local Promise = require(ReplicatedStorage.Packages.promise)
local Signal = require(ReplicatedStorage.Packages.signal)

-- || Variables || --
local DEFAULT_OWNERSHIP_TIMEOUT = 10

local Player = Players.LocalPlayer

-- || Types || --
type MarketServiceNetwork = typeof(require(script.Parent.NetworkClient))

-- || Public API || --
local MarketServiceClient = {
	_network = nil :: MarketServiceNetwork?,
	_ownershipCache = {} :: { [string]: boolean },
	
	GamepassPurchased = nil :: Signal.Signal<string>?,      -- Fires when a gamepass is purchased
	DevProductPurchased = nil :: Signal.Signal<string>?,    -- Fires when a dev product is purchased
	GamepassOwnershipChanged = nil :: Signal.Signal<string, boolean>?, -- Fires when ownership status changes
	
	_initialized = false :: boolean,
	_initializedSignal = nil :: Signal.ClassicSignal<>?,
}

export type MarketServiceClient = typeof(MarketServiceClient)

-- || Initialization || --

--[[
	Initializes the MarketService on the client.
	
	This should be called once when the game starts. It sets up network communication,
	binds to marketplace events, and initializes ownership tracking.
	
	Example:
	```lua
	local MarketServiceClient = require(ReplicatedStorage.Services.MarketService.MarketServiceClient)
	MarketServiceClient:Init()
	
	-- Now you can use MarketServiceClient methods
	```
	
	Note: Must be called before using any other MarketServiceClient methods.
]]
function MarketServiceClient.Init(self: MarketServiceClient)
	if self._initialized then
		warn("MarketServiceClient already initialized")
		return
	end
	
	self._network = require(script.Parent.NetworkClient)
	self._initializedSignal = Signal.new()
	
	self.GamepassPurchased = Signal.new()
	self.DevProductPurchased = Signal.new()
	self.GamepassOwnershipChanged = Signal.new()
	
	self:_BindNetworkEvents()
	self:_BindMarketEvents()
end

-- || Gamepass Ownership Methods || --

--[[
	Checks if the local player owns a specific gamepass (synchronous).
	
	Uses cached data when available, otherwise queries the Roblox API.
	The result is cached for future calls.
	
	@param passID number - The gamepass ID to check
	@return boolean - True if the player owns the gamepass
	
	Examples:
	```lua
	if MarketServiceClient:PlayerOwnsGamepass(123456789) then
		print("Player has VIP!")
	end
	```
	
	Note: This makes a web request on first check. For async with better error handling,
	use PlayerOwnsGamepassAsync() instead.
]]
function MarketServiceClient.PlayerOwnsGamepass(self: MarketServiceClient, passID: number): boolean
	local key = tostring(passID)
	
	local cached = self._ownershipCache[key]
	if cached ~= nil then
		return cached
	end
	
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, passID)
	end)
	
	if not success then
		warn(`Failed to check gamepass ownership: {owns}`)
		return false
	end
	
	self._ownershipCache[key] = owns
	return owns
end

--[[
	Returns a promise that resolves with the player's gamepass ownership status.
	
	Waits for the initial data sync from the server, then checks ownership.
	The promise will reject if it times out waiting for server data.
	
	@param passID number - The gamepass ID to check
	@param timeout number? - Timeout in seconds (default: 10)
	@return Promise<boolean> - Promise that resolves with true if owned, false if not
	
	Examples:
	```lua
	MarketServiceClient:PlayerOwnsGamepassAsync(123456789):andThen(function(owns)
		if owns then
			print("Player owns VIP pass!")
		else
			print("Player doesn't own VIP pass")
		end
	end):catch(function(err)
		warn("Failed to check ownership:", err)
	end)
	```
	
	Benefits over PlayerOwnsGamepass():
	- Waits for server data sync (more reliable)
	- Non-blocking with promise interface
	- Can specify custom timeout
	- Better error handling
]]
function MarketServiceClient.PlayerOwnsGamepassAsync(self: MarketServiceClient, passID: number, timeout: number?): Promise.TypedPromise<boolean>
	local key = tostring(passID)

	return Promise.try(function()
		if not self._initialized then
			return Promise.fromEvent(self._initializedSignal)
		end
		return true
	end):andThen(function()
		local cached = self._ownershipCache[key]
		if cached ~= nil then
			return Promise.resolve(cached)
		end
		
		return Promise.race({
			Promise.fromEvent(self.GamepassOwnershipChanged, function(id)
				return id == key
			end):andThen(function(_, owns)
				return owns
			end),
			
			Promise.delay(timeout or DEFAULT_OWNERSHIP_TIMEOUT):andThen(function()
				return Promise.reject("Timed out waiting for gamepass ownership")
			end),
		})
	end)
end

-- || Product Methods || --

--[[
	Gets the price of a product or gamepass.
	
	@param productId number - The product or gamepass ID
	@param isGamepass boolean - True if it's a gamepass, false if it's a dev product
	@return Promise<number> - Promise that resolves with the price in Robux
	
	Examples:
	```lua
	-- Get gamepass price
	MarketServiceClient:GetProductPriceAsync(123456789, true):andThen(function(price)
		print("VIP Pass costs", price, "Robux")
	end)
	
	-- Get dev product price
	MarketServiceClient:GetProductPriceAsync(987654321, false):andThen(function(price)
		print("Coin Pack costs", price, "Robux")
	end)
	```
]]
function MarketServiceClient.GetProductPriceAsync(_self: MarketServiceClient, productId: number, isGamepass: boolean): Promise.TypedPromise<number>
	local infoType = isGamepass and Enum.InfoType.GamePass or Enum.InfoType.Product
	return MarketServiceUtils.FetchProductPriceAsync(productId, infoType)
end

--[[
	Prompts the player to purchase a gamepass.
	
	@param passID number - The gamepass ID to prompt
	@return Promise<boolean> - Promise that resolves with true if purchased, false if declined
	
	Examples:
	```lua
	local VIP_PASS_ID = MarketServiceClient:GetProductID("VIP")
	
	MarketServiceClient:PromptGamePassAsync(VIP_PASS_ID):andThen(function(purchased)
		if purchased then
			print("Thanks for purchasing VIP!")
		else
			print("Purchase was declined or failed")
		end
	end):catch(function(err)
		warn("Error prompting gamepass:", err)
	end)
	```
	
	Note: The promise resolves true ONLY if the purchase completed successfully.
	It resolves false if declined, and rejects if there's an error.
]]
function MarketServiceClient.PromptGamePassAsync(_self: MarketServiceClient, passID: number): Promise.TypedPromise<boolean>
	return MarketServiceUtils.PromptAsync(Player, passID, true)
end

--[[
	Prompts the player to purchase a developer product.
	
	@param productID number - The developer product ID to prompt
	@return Promise<boolean> - Promise that resolves with true if purchased, false if declined
	
	Examples:
	```lua
	-- Prompt coin purchase
	local COINS_100_ID = MarketServiceClient:GetProductID("100_Coins")

	MarketServiceClient:PromptDevProductAsync(COINS_100_ID):andThen(function(purchased)
		if purchased then
			print("Thanks for purchasing 100 coins!")
			-- Actual grant happens server-side in ProcessReceipt
		end
	end)
	```
	
	Note: The server's ProcessReceipt callback handles actually granting the product.
	This just initiates the purchase flow.
]]
function MarketServiceClient.PromptDevProductAsync(_self: MarketServiceClient, productID: number): Promise.TypedPromise<boolean>
	return MarketServiceUtils.PromptAsync(Player, productID, false)
end

-- || Gift Methods || --

--[[
	Prompts the local player to gift a developer product to another player.
	
	The purchaser pays for the product, but the recipient receives it.
	Requires server validation before the purchase prompt appears.
	
	@param recipient Player - The player who will receive the gift
	@param productID number - The developer product ID to gift
	@return Promise<boolean> - Promise that resolves with true if purchase completed
	
	Examples:
	```lua
	local COINS_100_ID = MarketServiceClient:GetProductID("100_Coins")
		
	MarketServiceClient:PromptGiftDevProductAsync(targetPlayer, COINS_GIFT_ID)
		:andThen(function(success)
			if success then
				print("Gift sent to", targetPlayer.Name)
			end
		end)
		:catch(function(err)
			print("Gift failed:", err)
		end)
	```
	
	How it works:
	1. Validates recipient is in-game
	2. Asks server to authorize the gift
	3. If authorized, prompts purchaser for payment
	4. Server's ProcessReceipt grants the product to the recipient
	
	Note: The server must have gift handling set up in ProcessReceipt.
]]
function MarketServiceClient.PromptGiftDevProductAsync(self: MarketServiceClient, recipient: Player, productID: number): Promise.TypedPromise<boolean>
	if not recipient or not recipient:IsDescendantOf(Players) then
		return Promise.reject("Recipient is not in the game")
	end
	
	if not self._network then
		return Promise.reject("MarketService not initialized")
	end
	
	return self._network.RequestGiftPurchase.Call(tostring(recipient.UserId), tostring(productID))
		:andThen(function(accepted)
			if not accepted then
				return Promise.reject("Server rejected gift request")
			end
			return MarketServiceUtils.PromptAsync(Player, productID, false)
		end)
end

--[[
	Prompts the local player to gift a gamepass to another player.
	
	Uses a special "gift dev product" associated with the gamepass. When purchased,
	the server grants the gamepass to the recipient instead of the purchaser.
	
	@param recipient Player - The player who will receive the gamepass
	@param passID number - The gamepass ID to gift
	@return Promise<boolean> - Promise that resolves with true if purchase completed
	
	Examples:
	```lua
	local VIP_PASS_ID = MarketServiceClient:GetProductID("VIP_Pass")
	
	MarketServiceClient:PromptGiftGamepassAsync(targetPlayer, VIP_PASS_ID)
		:andThen(function(success)
			if success then
				print("VIP gifted to", selectedPlayer.Name)
			end
		end)
		:catch(function(err)
			warn("Gift failed:", err)
		end)
	```
	
	Requirements:
	- The gamepass must have a GiftID field in ProductRegistry
	- The GiftID must be a valid developer product ID
	- Server must handle gifting in ProcessReceipt
	
	Errors:
	- "Recipient is not in the game" - Player left
	- "Invalid gamepass ID" - Gamepass doesn't exist in registry
	- "Gamepass has no gift Dev Product" - No GiftID configured
	- "Server rejected gift request" - Server validation failed
]]
function MarketServiceClient.PromptGiftGamepassAsync(self: MarketServiceClient, recipient: Player, passID: number): Promise.TypedPromise<boolean>
	if not recipient or not recipient:IsDescendantOf(Players) then
		return Promise.reject("Recipient is not in the game")
	end
	
	local passKey = ProductRegistry:GetGamePassKeyFromId(passID)
	if not passKey then
		return Promise.reject("Invalid gamepass ID")
	end
	
	local giftProductID = ProductRegistry.GamePasses[passKey].GiftID
	if not giftProductID then
		return Promise.reject("Gamepass has no gift Dev Product")
	end
	
	if not self._network then
		return Promise.reject("MarketService not initialized")
	end
	
	return self._network.RequestGiftPurchase.Call(tostring(recipient.UserId), tostring(passID))
		:andThen(function(accepted)
			if not accepted then
				return Promise.reject("Server rejected gift request")
			end
			return MarketServiceUtils.PromptAsync(Player, giftProductID, false)
		end)
end

-- || Utility Methods || --

--[[
	Gets the product ID from a product name.
	
	Looks up the product in ProductRegistry by its key name.
	
	@param productName string - The product key name from ProductRegistry
	@return number - The Roblox product/gamepass ID
	
	Examples:
	```lua
	local productName = "SpeedBoost"
	local productId = MarketServiceClient:GetProductID(productName)
	MarketServiceClient:PromptGamePassAsync(productId)
	```
]]
MarketServiceClient.GetProductID = MarketServiceUtils.GetProductID :: (
	self: MarketServiceClient,
	productName: string
) -> number

-------------------------------------------------------------------------------------------------------------------------------
-- Private Methods

function MarketServiceClient._SetOwnership(self: MarketServiceClient, passKey: string, owns: boolean)
	local current = self._ownershipCache[passKey]
	if current == owns then
		return
	end
	
	self._ownershipCache[passKey] = owns
	
	if self.GamepassOwnershipChanged then
		self.GamepassOwnershipChanged:Fire(passKey, owns)
	end
	
	if owns and self.GamepassPurchased then
		self.GamepassPurchased:FireDeferred(passKey)
	end
end

function MarketServiceClient._BindNetworkEvents(self: MarketServiceClient)
	if not self._network then
		warn("Network not initialized")
		return
	end
	
	-- Initial ownership data from server
	self._network.InitializeMarketData.SetCallback(function(data)
		for passKey, owns in pairs(data) do
			self:_SetOwnership(passKey, owns)
		end
		
		if not self._initialized then
			self._initialized = true
			if self._initializedSignal then
				self._initializedSignal:Fire()
			end
		end
	end)
	
	-- Ownership updates from server
	self._network.SetMarketData.SetCallback(function(passKey, owns)
		self:_SetOwnership(passKey, owns)
	end)
end

function MarketServiceClient._BindMarketEvents(self: MarketServiceClient)
	-- Listen for gamepass purchases
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passID: number, wasPurchased: boolean)
		if player ~= Player then
			return
		end
		
		if wasPurchased then
			self:_SetOwnership(tostring(passID), true)
		end
	end)
	
	-- Listen for dev product purchases
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userID: number, productID: number, wasPurchased: boolean)
		if userID ~= Player.UserId then
			return
		end
		
		if wasPurchased then
			local key = ProductRegistry:GetDevProductKeyFromId(productID)
			if key and self.DevProductPurchased then
				self.DevProductPurchased:FireDeferred(key)
			end
		end
	end)
end

return MarketServiceClient