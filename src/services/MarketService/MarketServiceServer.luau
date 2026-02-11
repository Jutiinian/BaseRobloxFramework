-- || Services || --
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local ProfileStore = require(ServerScriptService.ServerPackages.profilestore)
local Observers = require(ReplicatedStorage.Packages.observers)
local Promise = require(ReplicatedStorage.Packages.promise)
local Signal = require(ReplicatedStorage.Packages.signal)

local MarketServiceUtils = require(ReplicatedStorage.Services.MarketService.MarketServiceUtils)
local ProductRegistry = require(ReplicatedStorage.Services.MarketService.ProductRegistry)

-- || Constants || --
local DEFAULT_RECEIPT_STORE_KEY = "ProcessedReceipts"
local DEFAULT_PROFILE_STORE_INDEX = "DefaultMarketStore"

-- || Types || --
type Profile = ProfileStore.Profile<{ [string]: boolean }>

type InitOptions = {
	receiptStoreKey: string?,      -- DataStore key for tracking processed receipts
	profileStoreIndex: string?,    -- ProfileStore index for gamepass ownership
	useMock: boolean?,             -- Use mock ProfileStore (for testing)
	dontSave: boolean?,            -- Don't save data (read-only mode)
	overridenUserId: number?,      -- Override UserId for testing
}

type ReceiptInfo = { 
	PlayerId: number,         -- UserId who made the purchase
	ProductId: number,        -- The product ID purchased
	PurchaseId: string,       -- Unique ID for this transaction
	[string]: any             -- Additional Roblox receipt data
}

type ReceiptFunction = (player: Player, key: string, receiptInfo: ReceiptInfo, purchaser: Player) -> boolean

type GiftData = {
	PurchaserID: number,      -- Who is buying the gift
	RecipientID: number,      -- Who receives it
	ProductID: number,        -- What product is being gifted
	IsGamepassGift: boolean?, -- True if it's a gamepass gift
}

-- || Private Functions || --
local function getPassIDKey(passID: number): string
	return tostring(passID)
end

-- || Public API || --
type MarketServiceNetwork = typeof(require(script.Parent.NetworkServer))

local MarketServiceServer = {
	marketStore = nil :: ProfileStore.ProfileStore<{ [number]: boolean }>?,
	
	GamepassPurchased = nil :: Signal.Signal<Player, string>?,    -- Fires when a player purchases a gamepass
	DevProductPurchased = nil :: Signal.Signal<Player, string>?,  -- Fires when a player purchases a dev product
	
	_network = nil :: MarketServiceNetwork?,
	_receiptFunction = nil :: ReceiptFunction?,
	_receiptStore = nil :: DataStore?,
	
	_activeGifts = {} :: { [number]: GiftData },
	_activeProfiles = {} :: { [Player]: Profile },
	_waitSignals = {} :: { [Player]: Signal.Signal<any> },
}

export type MarketServiceServer = typeof(MarketServiceServer)

--[[
	Initializes the MarketService on the server.
	
	This should be called once when the server starts. It sets up ProfileStore for gamepass
	ownership tracking, initializes the receipt DataStore, and begins observing players.
	
	@param options InitOptions? - Optional configuration table
	
	Options:
	- receiptStoreKey: DataStore key for tracking processed receipts (default: "ProcessedReceipts")
	- profileStoreIndex: ProfileStore index for ownership data (default: "DefaultMarketStore")
	- useMock: Use mock ProfileStore for testing (no real data store access)
	- dontSave: Load data but don't save changes (read-only mode)
	- overridenUserId: Use different UserId for testing
	
	Examples:
	```lua
	local MarketServiceServer = require(ServerScriptService.Services.MarketService.MarketServiceServer)

	MarketServiceServer:Init({
		receiptStoreKey = "ProductionReceipts_V2",
		profileStoreIndex = "ProductionMarket_V2"
		useMock = true,
		dontSave = true
	})
	```
	
	Note: Must bind a receipt function with BindReceiptFunction() to handle dev product purchases.
]]
function MarketServiceServer.Init(self: MarketServiceServer, options: InitOptions?)
	self._network = require(script.Parent.NetworkServer)
	
	self.GamepassPurchased = Signal.new()
	self.DevProductPurchased = Signal.new()
	
	self.marketStore = ProfileStore.New(
		options and options.profileStoreIndex or DEFAULT_PROFILE_STORE_INDEX
	)
	self._receiptStore = DataStoreService:GetDataStore(
		options and options.receiptStoreKey or DEFAULT_RECEIPT_STORE_KEY
	)
	
	self:_BindMarketEvents()
	self:_BindNetworkEvents()
	
	Observers.observePlayer(function(player: Player)
		task.spawn(function()
			self:_OnPlayerAdded(player, options)
			
			if not player:IsDescendantOf(Players) then
				return
			end
			
			-- Fire signals for owned gamepasses
			for key, passData in pairs(ProductRegistry.GamePasses) do
				local passID = passData.ID
				if passID and self:PlayerOwnsGamepass(player, passID) then
					self.GamepassPurchased:FireDeferred(player, key)
				end
			end
		end)
		
		return function()
			self:_OnPlayerRemoved(player)
		end
	end)
end

-- || Gamepass Methods || --

--[[
	Checks if a player owns a specific gamepass.
	
	Checks cached ownership data first, then queries Roblox API if not cached.
	The result is cached for future checks.
	
	@param player Player - The player to check
	@param passID number - The gamepass ID
	@return boolean - True if the player owns the gamepass
	
	Examples:
	```lua
	local VIP_PASS_ID = MarketServiceServer:GetProductID("VIP_Pass")
	
	if MarketServiceServer:PlayerOwnsGamepass(player, VIP_PASS_ID) then
		grantVIPPerks(player)
	end
	```
	
	Note: Makes a web request on first check. Use PlayerOwnsGamepassAsync() for
	promise-based async checking with better error handling.
]]
function MarketServiceServer.PlayerOwnsGamepass(self: MarketServiceServer, player: Player, passID: number): boolean
	local passIDKey = getPassIDKey(passID)
	
	-- Check cached data first
	local profile = self._activeProfiles[player]
	if profile and profile.Data and profile.Data[passIDKey] == true then
		return true
	end
	
	-- Query Roblox API
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passID)
	end)
	
	if not success then
		warn(`Failed to check gamepass ownership for {player.Name}: {owns}`)
		return false
	end
	
	-- Cache the result if owned
	if owns and profile and profile.Data then
		profile.Data[passIDKey] = true
		if self._network then
			self._network.SetMarketData.Fire(player, passIDKey, true)
		end
	end
	
	return owns
end

--[[
	Returns a promise that resolves with the player's gamepass ownership status.
	
	Waits for the player's market data to load, then checks ownership.
	
	@param player Player - The player to check
	@param passID number - The gamepass ID
	@return Promise<boolean> - Promise that resolves with true if owned, false if not
	
	Examples:
	```lua
	MarketServiceServer:PlayerOwnsGamepassAsync(player, VIP_PASS):andThen(function(owns)
		print("Owns VIP:", owns)
	end)
	```
	
	Benefits:
	- Non-blocking promise interface
	- Waits for data to load automatically
	- Rejects if player leaves
	- Better error handling
]]
function MarketServiceServer.PlayerOwnsGamepassAsync(self: MarketServiceServer, player: Player, passID: number): Promise.TypedPromise<boolean>
	return self:WaitForDataAsync(player):andThen(function()
		return self:PlayerOwnsGamepass(player, passID)
	end)
end

-- || Product Methods || --

--[[
	Gets the price of a product or gamepass.
	
	@param productId number - The product or gamepass ID
	@param isGamepass boolean - True if it's a gamepass, false if dev product
	@return Promise<number> - Promise that resolves with the price in Robux
	
	Examples:
	```lua
	MarketServiceServer:GetProductPriceAsync(VIP_PASS_ID, true):andThen(function(price)
		print("VIP costs", price, "Robux")
	end)
	```
]]
function MarketServiceServer.GetProductPriceAsync(_self: MarketServiceServer, productId: number, isGamepass: boolean): Promise.TypedPromise<number>
	local infoType = isGamepass and Enum.InfoType.GamePass or Enum.InfoType.Product
	return MarketServiceUtils.FetchProductPriceAsync(productId, infoType)
end

--[[
	Prompts a player to purchase a gamepass.
	
	@param player Player - The player to show the purchase prompt
	@param passID number - The gamepass ID to prompt
	@return Promise<boolean> - Promise that resolves with true if purchased, false if declined
	
	Examples:
	```lua
	local VIP_PASS_ID = MarketServiceServer:GetProductID("VIP_Pass")
	
	MarketServiceServer:PromptGamePassAsync(player, VIP_PASS_ID):andThen(function(purchased)
		if purchased then
			print(player.Name, "bought VIP!")
		end
	end):catch(warn)
	```
]]
function MarketServiceServer.PromptGamePassAsync(_self: MarketServiceServer, player: Player, passID: number): Promise.TypedPromise<boolean>
	return MarketServiceUtils.PromptAsync(player, passID, true)
end

--[[
	Prompts a player to purchase a developer product.
	
	@param player Player - The player to show the purchase prompt
	@param productID number - The developer product ID
	@return Promise<boolean> - Promise that resolves with true if purchased, false if declined
	
	Examples:
	```lua
	local COINS_100_ID = MarketServiceServer:GetProductID("100_Coins")
	
	MarketServiceServer:PromptDevProductAsync(player, COINS_100_ID):andThen(function(purchased)
		if purchased then
			print(player.Name, "bought 100 coins!")
		end
	end):catch(warn)
	```
	
	Note: The actual granting happens in your BindReceiptFunction callback.
]]
function MarketServiceServer.PromptDevProductAsync(_self: MarketServiceServer, player: Player, productID: number): Promise.TypedPromise<boolean>
	return MarketServiceUtils.PromptAsync(player, productID, false)
end

-- || Gift Methods || --

--[[
	Prompts a player to purchase a developer product as a gift for another player.
	
	The purchaser pays, but the recipient receives the product. The gift data is
	tracked so ProcessReceipt knows to grant to the recipient instead of purchaser.
	
	@param purchaser Player - The player who will pay for the gift
	@param recipient Player - The player who will receive the gift
	@param productID number - The developer product ID to gift
	@return Promise<boolean> - Promise that resolves with true if purchased
	
	Examples:
	```lua
	MarketServiceServer:PromptGiftDevProductAsync(purchaser, recipient, productId)
		:andThen(function(success)
			if success then
				print(purchaser.Name, "gifted item to", recipient.Name)
			end
		end)
		:catch(function(err)
			warn("Gift failed:", err)
		end)
	```
	
	How it works:
	1. Validates recipient is in-game
	2. Stores gift data (purchaser → recipient)
	3. Prompts purchaser for payment
	4. On success, ProcessReceipt sees gift data and grants to recipient
	5. Clears gift data after processing
	
	Note: Your BindReceiptFunction callback receives BOTH the recipient (as player)
	and purchaser (as the purchaser parameter).
]]
function MarketServiceServer.PromptGiftDevProductAsync(
	self: MarketServiceServer,
	purchaser: Player,
	recipient: Player,
	productID: number
): Promise.TypedPromise<boolean>
	if not recipient or not recipient:IsDescendantOf(Players) then
		return Promise.reject("Recipient is not in the game")
	end
	
	self._activeGifts[purchaser.UserId] = {
		PurchaserID = purchaser.UserId,
		RecipientID = recipient.UserId,
		ProductID = productID,
	}
	
	return MarketServiceUtils.PromptAsync(purchaser, productID, false):catch(function(err)
		self._activeGifts[purchaser.UserId] = nil
		return Promise.reject(err)
	end)
end

--[[
	Prompts a player to purchase a gamepass as a gift for another player.
	
	Uses the gamepass's associated gift developer product. When purchased, the server
	grants the actual gamepass to the recipient.
	
	@param purchaser Player - The player who will pay for the gift
	@param recipient Player - The player who will receive the gamepass
	@param passID number - The gamepass ID to gift
	@return Promise<boolean> - Promise that resolves with true if purchased
	
	Examples:
	```lua
	local VIP_PASS_ID = MarketServiceServer:GetProductID("VIP_Pass")
	
	MarketServiceServer:PromptGiftGamepassAsync(purchaser, recipient, VIP_PASS_ID)
		:andThen(function(success)
			if success then
				print(purchaser.Name, "gifted VIP to", recipient.Name)
			end
		end)
		:catch(function(err)
			sendError(purchaser, "Gift failed: " .. tostring(err))
		end)
	```
	
	Requirements:
	- The gamepass must have a GiftID field in ProductRegistry
	- The GiftID must point to a valid developer product
	- ProcessReceipt must handle the IsGamepassGift flag
	
	Errors:
	- "Recipient is not in the game" - Player left
	- "Invalid gamepass ID" - Pass not in ProductRegistry
	- "No gift Dev Product associated with this gamepass" - No GiftID configured
	
	How it works:
	1. Looks up the gamepass's GiftID from ProductRegistry
	2. Stores gift data with IsGamepassGift flag
	3. Prompts the gift dev product purchase
	4. ProcessReceipt sees IsGamepassGift and grants the actual gamepass to recipient
]]
function MarketServiceServer.PromptGiftGamepassAsync(self: MarketServiceServer, purchaser: Player, recipient: Player, passID: number): Promise.TypedPromise<boolean>
	if not recipient or not recipient:IsDescendantOf(Players) then
		return Promise.reject("Recipient is not in the game")
	end
	
	local gamepassKey = ProductRegistry:GetGamePassKeyFromId(passID)
	if not gamepassKey then
		return Promise.reject("Invalid gamepass ID")
	end
	
	local giftDevProductID = ProductRegistry.GamePasses[gamepassKey].GiftID
	if not giftDevProductID then
		return Promise.reject("No gift Dev Product associated with this gamepass")
	end
	
	self._activeGifts[purchaser.UserId] = {
		PurchaserID = purchaser.UserId,
		RecipientID = recipient.UserId,
		ProductID = giftDevProductID,
		IsGamepassGift = true,
	}
	
	return MarketServiceUtils.PromptAsync(purchaser, giftDevProductID, false):catch(function(err)
		self._activeGifts[purchaser.UserId] = nil
		return Promise.reject(err)
	end)
end

-- || Data Methods || --

--[[
	Returns a promise that resolves when a player's market data is loaded.
	
	@param player Player - The player whose data to wait for
	@return Promise<Profile> - Promise that resolves with the ProfileStore profile
	
	Examples:
	```lua
	MarketServiceServer:WaitForDataAsync(player):andThen(function(profile)
		local hasVIP = MarketServiceServer:PlayerOwnsGamepass(player, VIP_PASS_ID)
		print(hasVIP)
	end):catch(function(err)
		player:Kick("Failed to load market data")
	end)
	```
]]
function MarketServiceServer.WaitForDataAsync(self: MarketServiceServer, player: Player): Promise.TypedPromise<Profile>
	local profile = self._activeProfiles[player]
	if profile then
		return Promise.resolve(profile)
	end
	
	local waitSignal = self._waitSignals[player]
	if not waitSignal then
		waitSignal = Signal.new()
		self._waitSignals[player] = waitSignal
	end
	
	return Promise.race({
		Promise.fromEvent(waitSignal, function(receivedProfile)
			return receivedProfile ~= nil
		end),
		
		Promise.fromEvent(Players.PlayerRemoving, function(leavingPlayer)
			return leavingPlayer == player
		end):andThen(function()
			return Promise.reject("Player left before data loaded")
		end),
	})
end

-- || Receipt Handling || --

--[[
	Binds a function to process developer product purchases.
	
	This is REQUIRED for developer products to work. Your function receives the purchase
	details and must grant the product, returning true on success or false to retry.
	
	@param func (player: Player, key: string, receiptInfo: ReceiptInfo, purchaser: Player) -> boolean
	
	Parameters your function receives:
	- player: The player who receives the product (might be different from purchaser in gifts)
	- key: The product key from ProductRegistry (e.g. "Coins100", "GemPack")
	- receiptInfo: Full receipt data from Roblox (PlayerId, ProductId, PurchaseId, etc.)
	- purchaser: The player who paid (same as player unless it's a gift)
	
	Your function should:
	- Grant the product to the player
	- Return true if successful
	- Return false to retry later (if DataStore fails, etc.)
	
	Examples:
	```lua
	MarketServiceServer:BindReceiptFunction(function(player, productKey, receiptInfo, purchaser)
		if productKey == "Coins100" then
			DataService:Update(player, "Currency.Coins", function(coins)
				return coins + 100
			end)
			return true
		elseif productKey == "Coins500" then
			DataService:Update(player, "Currency.Coins", function(coins)
				return coins + 500
			end)
			return true
		elseif productKey == "Gems50" then
			DataService:Update(player, "Currency.Gems", function(gems)
				return gems + 50
			end)
			return true
		end
		
		warn("Unknown product:", productKey)
		return false
	end)
	```
	
	Important notes:
	- Must return true for purchase to be marked as processed
	- Return false to retry later (don't worry, won't double-grant)
	- Each PurchaseId is only processed once (stored in DataStore)
	- For gifts, player and purchaser will be different
	- For gamepass gifts, the gamepass is granted automatically (just return true)
	- Errors in your function are caught and treated as return false
	- Always wrap DataStore operations in pcall and return false on failure
]]
function MarketServiceServer.BindReceiptFunction(self: MarketServiceServer, func: ReceiptFunction)
	self._receiptFunction = func
end

--[[
	Gets the product ID from a product name.
	
	Looks up the product in ProductRegistry by its key name.
	
	@param productName string - The product key from ProductRegistry
	@return number - The Roblox product/gamepass ID
	
	Examples:
	```lua
	local productName = "SpeedBoost"
	local productId = MarketServiceServer:GetProductID(productName)
	MarketServiceServer:PromptGamePassAsync(player, productId)
	```
]]
MarketServiceServer.GetProductID = MarketServiceUtils.GetProductID :: (
	self: MarketServiceServer,
	productName: string
) -> number

-------------------------------------------------------------------------------------------------------------------------------
-- Private Service Functions

function MarketServiceServer._ProcessReceipt(
	self: MarketServiceServer,
	receiptInfo: ReceiptInfo
): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key = ProductRegistry:GetDevProductKeyFromId(receiptInfo.ProductId)
		or ProductRegistry:GetGamePassKeyFromGiftId(receiptInfo.ProductId)
	
	if not key then
		warn(`Unknown product: {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local giftData = self._activeGifts[player.UserId]
	local recipient: Player = player
	local isGamepassGift = false
	
	if giftData and giftData.ProductID == receiptInfo.ProductId then
		recipient = Players:GetPlayerByUserId(giftData.RecipientID) or player
		isGamepassGift = giftData.IsGamepassGift or false
		self._activeGifts[player.UserId] = nil
	end

	local success, result = pcall(function()
		return self._receiptStore:UpdateAsync(receiptInfo.PurchaseId, function(isPurchased)
			if isPurchased then
				return true
			end
			
			if self._receiptFunction then
				local receiptFunctionSuccess, receiptFunctionResult = pcall(
					self._receiptFunction,
					recipient,
					key,
					receiptInfo,
					player
				)
				
				if not receiptFunctionSuccess then
					warn(`Receipt function errored for {player.Name} product {receiptInfo.ProductId}: {receiptFunctionResult}`)
					return nil
				end
				
				if receiptFunctionResult ~= true then
					return nil
				end
			end

			if isGamepassGift then
				local gamepassID = ProductRegistry.GamePasses[key].ID
				self:_GrantGamepass(recipient, gamepassID)
			end
			
			return true
		end)
	end)
	
	if not success then
		warn(`Failed to process receipt due to data store error: {result}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	if result == true and self.DevProductPurchased then
		self.DevProductPurchased:Fire(player, key)
	end
	
	return if result == true
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

function MarketServiceServer._GrantGamepass(self: MarketServiceServer, player: Player, passID: number)
	local profile = self._activeProfiles[player]
	if profile and profile.Data then
		local passIDKey = getPassIDKey(passID)
		profile.Data[passIDKey] = true
		
		if self._network then
			self._network.SetMarketData.Fire(player, passIDKey, true)
		end
	end
	
	local key = ProductRegistry:GetGamePassKeyFromId(passID)
	if key and self.GamepassPurchased then
		self.GamepassPurchased:Fire(player, key)
	end
end

function MarketServiceServer._BindMarketEvents(self: MarketServiceServer)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passID: number, wasPurchased: boolean)
		if wasPurchased then
			self:_GrantGamepass(player, passID)
		end
	end)
	
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userID: number, productID: number, wasPurchased: boolean)
		if not wasPurchased then
			local giftData = self._activeGifts[userID]
			if giftData and giftData.ProductID == productID then
				self._activeGifts[userID] = nil
			end
		end
	end)
	
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:_ProcessReceipt(receiptInfo)
	end
end

function MarketServiceServer._BindNetworkEvents(self: MarketServiceServer)
	if not self._network then
		return
	end
	
	self._network.RequestGiftPurchase.SetCallback(function(player: Player, recipient: string, productID: string): boolean
		local recipientID = tonumber(recipient)
		local productIDNum = tonumber(productID)
		
		if not recipientID or not productIDNum then
			warn("Invalid recipient or productID:", recipient, productID)
			return false
		end
		
		local recipientPlayer = Players:GetPlayerByUserId(recipientID)
		if not recipientPlayer then
			warn("Recipient player not found:", recipientID)
			return false
		end
		
		local giftDevProductID
		local isGamepassGift = false
		local gamepassKey = ProductRegistry:GetGamePassKeyFromId(productIDNum)
		
		if gamepassKey then
			giftDevProductID = ProductRegistry.GamePasses[gamepassKey].GiftID
			if not giftDevProductID then
				warn("Gamepass does not have a gift Dev Product:", gamepassKey)
				return false
			end
			isGamepassGift = true
		else
			giftDevProductID = productIDNum
		end
		
		self._activeGifts[player.UserId] = {
			PurchaserID = player.UserId,
			RecipientID = recipientID,
			ProductID = giftDevProductID,
			IsGamepassGift = isGamepassGift,
		}
		
		return true
	end)
end

function MarketServiceServer._OnPlayerAdded(self: MarketServiceServer, player: Player, options: InitOptions?)
	self._waitSignals[player] = Signal.new()
	
	local key = `{options and options.overridenUserId or player.UserId}`
	
	local params = {
		Cancel = function()
			return player.Parent ~= Players
		end,
	}
	
	local profile: Profile
	if options and options.useMock then
		profile = self.marketStore.Mock:StartSessionAsync(key, params)
	elseif options and options.dontSave then
		profile = self.marketStore:GetAsync(key)
	else
		profile = self.marketStore:StartSessionAsync(key, params)
	end
	
	if not profile then
		warn(`{player.Name}'s market profile failed to load!`)
		player:Kick("Failed to load market data. Please rejoin.")
		return
	end
	
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	
	profile.OnSessionEnd:Connect(function()
		self._activeProfiles[player] = nil
		if player:IsDescendantOf(Players) then
			player:Kick("Market session closed.\nPlease rejoin!")
		end
	end)
	
	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end
	
	self._activeProfiles[player] = profile
	
	if self._network then
		self._network.InitializeMarketData.Fire(player, profile.Data)
	end

	local waitSignal = self._waitSignals[player]
	if waitSignal then
		waitSignal:Fire(profile)
		waitSignal:Destroy()
		self._waitSignals[player] = nil
	end
end

function MarketServiceServer._OnPlayerRemoved(self: MarketServiceServer, player: Player)
	self._activeGifts[player.UserId] = nil
	
	local waitSignal = self._waitSignals[player]
	if waitSignal then
		waitSignal:Destroy()
		self._waitSignals[player] = nil
	end
	
	local profile = self._activeProfiles[player]
	if profile then
		profile:EndSession()
		self._activeProfiles[player] = nil
	end
end

return MarketServiceServer