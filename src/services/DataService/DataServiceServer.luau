-- || Services || --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local Observers = require(ReplicatedStorage.Packages.observers)
local Promise = require(ReplicatedStorage.Packages.promise)
local Sift = require(ReplicatedStorage.Packages.sift)
local Signal = require(ReplicatedStorage.Packages.signal)

local ProfileStore = require(ServerScriptService.ServerPackages.profilestore)

local DataProfile = require(ReplicatedStorage.Services.DataService.DataProfile)
local DataServiceTypes = require(ReplicatedStorage.Services.DataService.DataServiceTypes)
local DataTemplate = require(ReplicatedStorage.Services.DataService.DataTemplate)

-- || Variables || --
local DATA_PREFIX = "PLAYER_"
local DEFAULT_PROFILE_STORE_INDEX = "Default"

type IndexPath = DataServiceTypes.IndexPath
type Disconnect = DataServiceTypes.Disconnect
type Profile = ProfileStore.Profile<DataTemplate.Data>

-- || Public API || --
type DataServiceNetwork = typeof(require(script.Parent.NetworkServer))

local DataServiceServer = {
	_network = nil :: DataServiceNetwork?,
	_dataProfiles = {} :: { [Player]: DataProfile.DataProfile<DataTemplate.Data> },
	_activeProfiles = {} :: { [Player]: Profile },
	_waitSignals = {} :: { [Player]: Signal.Signal<any> },

	options = {} :: dataOptions?,
	playerStore = nil :: ProfileStore.ProfileStore<DataTemplate.Data>?,
}

export type DataServiceServer = typeof(DataServiceServer)

type dataOptions = {
	useMock: boolean?,              -- Use mock data store (for testing)
	overridenUserId: number?,       -- Override the UserId for data keys (for testing)
	dontSave: boolean?,             -- Don't save data (read-only mode)
	profileStoreIndex: string?,     -- Custom ProfileStore index name
	profileStoreDataPrefix: string?,-- Custom prefix for data keys
	replicationIgnoreList: { string }?, -- List of data keys to not replicate to clients
}

--[[
	Initializes the DataService on the server.
	
	This should be called once when the server starts. It sets up the ProfileStore, network replication,
	and begins observing player joins/leaves.
	
	@param options dataOptions - Configuration table to control behavior
	
	Options:
	- useMock: Use mock ProfileStore for testing (no real data store access)
	- overridenUserId: Use a different UserId for data keys (useful for testing)
	- dontSave: Load data but don't save changes (read-only mode)
	- profileStoreIndex: Custom name for the ProfileStore (default: "Default")
	- profileStoreDataPrefix: Custom prefix for player data keys (default: "PLAYER_")
	- replicationIgnoreList: Array of top-level keys to exclude from client replication
	
	Examples:
	```lua
	-- Production setup
	local DataServiceServer = require(ServerScriptService.Services.DataService.DataServiceServer)
	DataServiceServer:Init({
		profileStoreIndex = "Production_V1",
		replicationIgnoreList = {"AdminFlags", "BannedUntil"} -- Don't send to client
	})
	
	-- Testing setup with mock data
	DataServiceServer:Init({
		useMock = true,
		dontSave = true
	})
	
	-- Development setup with custom prefix
	DataServiceServer:Init({
		profileStoreIndex = "Development",
		profileStoreDataPrefix = "DEV_PLAYER_"
	})
	```
	
	Note: Must be called before any player data operations.
]]
function DataServiceServer.Init(self: DataServiceServer, options: dataOptions)
	self._network = require(script.Parent.NetworkServer)

	self.options = options
	self.playerStore = ProfileStore.New(options.profileStoreIndex or DEFAULT_PROFILE_STORE_INDEX, DataTemplate)

	Observers.observePlayer(function(player: Player)
		self:_playerAdded(player)
		return function()
			task.defer(self._playerRemoving, self, player)
		end
	end)
end

--[[
	Saves profile data for a specific player, or all players if none is provided.
	
	Useful for forcing a save during critical events (purchases, major achievements, etc.)
	Note: ProfileStore automatically saves periodically, so manual saves are usually optional.
	
	@param player Player? - The Player to save. If nil, saves all players.
	
	Examples:
	```lua
	-- Save a specific player's data after a purchase
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		-- ... grant items ...
		DataServiceServer:SaveData(player) -- Force save
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	-- Save all players before shutdown
	game:BindToClose(function()
		DataServiceServer:SaveData() -- Saves everyone
		wait(3) -- Give time for saves to complete
	end)
	
	-- Save after critical state changes
	local function grantRareItem(player, itemId)
		DataServiceServer:ArrayInsert(player, "Inventory.Items", itemId)
		DataServiceServer:SaveData(player) -- Force save to prevent loss
	end
	```
]]
function DataServiceServer.SaveData(self: DataServiceServer, player: Player?)
	local function saveProfile(p: Player): ()
		local profile = self._activeProfiles[p]
		if profile then
			profile:Save()
		end
	end

	if player then
		saveProfile(player)
	else
		for _, p in ipairs(Players:GetPlayers()) do
			saveProfile(p)
		end
	end
end

--[[
	Gets the currently loaded ProfileStore profile for a player.
	
	Returns the raw ProfileStore profile, which contains the data and additional metadata.
	Usually you'll want to use Get(), Set(), etc. instead of accessing the profile directly.
	
	@param player Player - The player whose profile to get
	@return Profile? - The ProfileStore profile, or nil if not loaded yet
	
	Example:
	```lua
	-- Check if profile is loaded
	local profile = DataServiceServer:GetProfile(player)
	if profile then
		print("Profile loaded for:", player.Name)
		print("Last save:", profile.LastSavedTime)
	end
	
	-- Access raw profile data (not recommended, use Get() instead)
	local profile = DataServiceServer:GetProfile(player)
	if profile then
		local coins = profile.Data.Currency.Coins
	end
	```
	
	Note: Prefer using Get() and other methods over directly accessing profile.Data
]]
function DataServiceServer.GetProfile(self: DataServiceServer, player: Player): Profile?
	return self._activeProfiles[player]
end

--[[
	Waits for the player's data to be ready and returns it (synchronous).
	
	⚠️ Warning: This yields the current thread. Consider using WaitForDataAsync() instead.
	
	@param player Player - The player whose data to wait for
	@return DataProfile - The player's data profile
	
	Example:
	```lua
	-- In a coroutine or thread that can yield
	Players.PlayerAdded:Connect(function(player)
		local data = DataServiceServer:WaitForData(player)
		
		print(DataServiceServer:Get(player, "isVip"))
	end)
	```
	
	Note: Generally prefer WaitForDataAsync() for better async handling.
]]
function DataServiceServer.WaitForData(self: DataServiceServer, player: Player): DataProfile.DataProfile<DataTemplate.Data>
	local data = self._dataProfiles[player]
	if data then
		return data
	end

	local waitSignal = self._waitSignals[player]
	if not waitSignal then
		waitSignal = Signal.new()
		self._waitSignals[player] = waitSignal
	end

	waitSignal:Wait()
	return self._dataProfiles[player]
end

--[[
	Returns a promise that resolves with the player's profile data once ready.
	
	This is the preferred way to wait for data. The promise rejects if the player leaves before data loads.
	
	@param player Player - The player whose data to wait for
	@return Promise<DataProfile> - Promise that resolves with the data profile
	
	Examples:
	```lua
	-- Basic usage
	DataServiceServer:WaitForDataAsync(player):andThen(function(data)
		local coins = data:Get("Currency.Coins")
		print(player.Name, "has", coins, "coins")
	end):catch(function(err)
		warn("Failed to load data for", player.Name, ":", err)
	end)
	
	-- Chain multiple async operations
	DataServDataServiceServerice:WaitForDataAsync(player)
		:andThen(function(data)
			local level = data:Get("Stats.Level")
			return loadPlayerAssets(player, level)
		end)
		:andThen(function()
			return setupPlayerCharacter(player)
		end)
		:andThen(function()
			player:LoadCharacter()
		end)
		:catch(function(err)
			player:Kick("Failed to load data: " .. tostring(err))
		end)
	
	-- Handle player leaving during data load
	DataServiceServer:WaitForDataAsync(player)
		:andThen(function(data)
			-- This won't run if player left
			grantDailyReward(player, data)
		end)
		:catch(function(err)
			if err == "Player left before data loaded" then
				print(player.Name, "left before data could load")
			end
		end)
	
	-- Use in an async function with await
	local function handlePlayerJoin(player)
		local data = DataServiceServer:WaitForDataAsync(player):await()
		local firstTime = data:Get("Stats.FirstJoin")
		if firstTime then
			showTutorial(player)
		end
	end
	
	Players.PlayerAdded:Connect(function(player)
		Promise.try(handlePlayerJoin, player):catch(warn)
	end)
	```
	
	Benefits:
	- Automatically rejects if player leaves (prevents errors)
	- Non-blocking, returns immediately
	- Can be chained with other operations
	- Better error handling
]]
function DataServiceServer.WaitForDataAsync(self: DataServiceServer, player: Player): Promise.TypedPromise<DataProfile.DataProfile<DataTemplate.Data>>
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
		Promise.fromEvent(waitSignal, function()
			return self._dataProfiles[player] ~= nil
		end):andThenReturn(self._dataProfiles[player]),

		Promise.fromEvent(Players.PlayerRemoving, function(leavingPlayer)
			return leavingPlayer == player
		end):andThen(function()
			error("Player left before data loaded")
		end),
	})
end

--[[
	Gets a value from a player's profile data.
	
	@param player Player - The player whose data to read
	@param indexPath string | {string}? - Path to the data (nil returns entire profile)
	@return any - The value at the specified path
	
	Examples:
	```lua
	-- Get entire data
	local allData = DataServiceServer:Get(player)
	
	-- Get nested value with string path
	local volume = DataServiceServer:Get(player, "Settings.Audio.Volume")
	
	-- Get nested value with table path
	local volume = DataServiceServer:Get(player, {"Settings", "Audio", "Volume"})
	
	-- Get object
	local inventory = DataServiceServer:Get(player, "Inventory")
	
	-- Get array
	local friends = DataServiceServer:Get(player, "Social.Friends")
	```
]]
function DataServiceServer.Get(self: DataServiceServer, player: Player, indexPath: IndexPath?): any
	return self._dataProfiles[player]:Get(indexPath)
end

--[[
	Sets a value in the player's profile data.
	
	The change is automatically saved to the data store and replicated to the client (unless NoReplication is true).
	
	@param player Player - The player whose data to modify
	@param indexPath string | {string} - Path to the value to set
	@param value any - The new value
	@param NoReplication boolean? - If true, don't send update to client (default: false)
	
	Examples:
	```lua
	-- Set simple values
	DataServiceServer:Set(player, "Stats.Level", 5)
	DataServiceServer:Set(player, "Settings.Audio.Volume", 0.8)
	
	-- Set entire objects
	DataServiceServer:Set(player, "Settings.Graphics", {
		Quality = "High",
		Shadows = true,
		ParticleEffects = true
	})
	
	-- Set without replicating to client (server-only data)
	DataServiceServer:Set(player, "AdminData.BannedUntil", os.time() + 86400, true)
	
	-- Use table path
	DataServiceServer:Set(player, {"Currency", "Coins"}, 100)
	
	-- Set nested value in table
	local inventory = DataServiceServer:Get(player, "Inventory")
	inventory.MaxSlots = 50
	DataServiceServer:Set(player, "Inventory", inventory)
	```
	
	Note: For arrays, use ArrayInsert() and ArrayRemove() instead.
]]
function DataServiceServer.Set(self: DataServiceServer, player: Player, indexPath: IndexPath, value: any, NoReplication: boolean?): ()
	if not NoReplication then
		self._network.DataUpdate.Fire(player, {
			Type = type(indexPath) == "table" and "Table" or "String",
			value = indexPath,
		}, value)
	end

	self._dataProfiles[player]:Set(indexPath, value)
end

--[[
	Updates a value in a player's profile data using a callback function and returns the new value.
	
	The callback receives the current value and must return the new value. This is useful for
	incrementing, decrementing, or transforming values based on their current state.
	
	@param player Player - The player whose data to modify
	@param indexPath string | {string} - Path to the value to update
	@param callback (currentValue: any) -> any - Function that transforms the current value
	@param NoReplication boolean? - If true, don't send update to client (default: false)
	@return any - The new value after the update
	
	Examples:
	```lua
	-- Increment coins
	local newCoins = DataServiceServer:Update(player, "Currency.Coins", function(coins)
		return coins + 100
	end)
	print("Player now has", newCoins, "coins")
	
	-- Increment with maximum
	DataServiceServer:Update(player, "Stats.Experience", function(exp)
		return math.min(exp + 50, 1000) -- Cap at 1000
	end)
	
	-- Toggle boolean
	DataServiceServer:Update(player, "Settings.MusicEnabled", function(enabled)
		return not enabled
	end)
	
	-- Modify table properties
	DataServiceServer:Update(player, "Stats", function(stats)
		stats.Kills = stats.Kills + 1
		stats.KDR = stats.Kills / math.max(stats.Deaths, 1)
		return stats
	end)
	
	-- Add to a count without replication
	DataServiceServer:Update(player, "Analytics.SessionsPlayed", function(count)
		return count + 1
	end, true) -- No replication
	
	-- Conditional update
	local success = DataServiceServer:Update(player, "Currency.Coins", function(coins)
		if coins >= 500 then
			return coins - 500 -- Deduct cost
		end
		return coins -- Not enough, no change
	end)
	
	if success < coins then
		-- Purchase failed, not enough coins
	end
	```
	
	Benefits over Get() + Set():
	- Atomic operation (no race conditions)
	- Cleaner code for transformations
	- Returns the new value immediately
]]
function DataServiceServer.Update(self: DataServiceServer, player: Player, indexPath: IndexPath, callback: (any) -> any, NoReplication: boolean?): any
	local newValue = self._dataProfiles[player]:Update(indexPath, callback)

	if not NoReplication then
		self._network.DataUpdate.Fire(player, {
			Type = type(indexPath) == "table" and "Table" or "String",
			value = indexPath,
		}, newValue)
	end

	return newValue
end

--[[
	Inserts a value into an array in a player's profile data.
	
	@param player Player - The player whose data to modify
	@param indexPath string | {string} - Path to the array
	@param value any - The value to insert
	@param index number? - Position to insert at (nil = append to end)
	@param NoReplication boolean? - If true, don't send update to client (default: false)
	
	Examples:
	```lua
	-- Append to array
	DataServiceServer:ArrayInsert(player, "Inventory.Items", {
		Id = "sword_legendary",
		Damage = 50
	})
	
	-- Insert at specific position
	DataServiceServer:ArrayInsert(player, "Inventory.Items", newItem, 1) -- Insert at start
	
	-- Add friend to list
	DataServiceServer:ArrayInsert(player, "Social.Friends", friendUserId)
	
	-- Add quest to active quests
	DataServiceServer:ArrayInsert(player, "Quests.Active", {
		QuestId = "main_001",
		Progress = 0,
		StartTime = os.time()
	})
	
	-- Insert without client notification
	DataServiceServer:ArrayInsert(player, "ServerData.LoginHistory", os.time(), nil, true)
	```
	
	Note: The array must already exist at the specified path.
]]
function DataServiceServer.ArrayInsert(self: DataServiceServer, player: Player, indexPath: IndexPath, value: any, index: number?, NoReplication: boolean?)
	if not NoReplication then
		self._network.ArrayInsert.Fire(player, {
			Type = type(indexPath) == "table" and "Table" or "String",
			value = indexPath,
		}, value, index)
	end

	self._dataProfiles[player]:ArrayInsert(indexPath, value, index)
end

--[[
	Removes an element from an array in a player's profile data.
	
	@param player Player - The player whose data to modify
	@param indexPath string | {string} - Path to the array
	@param index number - Position of the element to remove (1-indexed)
	@param NoReplication boolean? - If true, don't send update to client (default: false)
	@return any - The value that was removed
	
	Examples:
	```lua
	-- Remove item by index
	local removedItem = DataService:ArrayRemove(player, "Inventory.Items", 3)
	print("Removed:", removedItem.Id)
	
	-- Remove first element
	DataService:ArrayRemove(player, "Notifications", 1)
	
	-- Remove friend from list
	local friends = DataService:Get(player, "Social.Friends")
	for i, friendId in ipairs(friends) do
		if friendId == targetFriendId then
			DataService:ArrayRemove(player, "Social.Friends", i)
			break
		end
	end
	
	-- Remove completed quest
	local activeQuests = DataService:Get(player, "Quests.Active")
	for i, quest in ipairs(activeQuests) do
		if quest.QuestId == completedQuestId then
			local removed = DataService:ArrayRemove(player, "Quests.Active", i)
			-- Add to completed quests
			DataService:ArrayInsert(player, "Quests.Completed", removed)
			break
		end
	end
	```
	
	Returns: The removed value, useful for moving items between arrays.
]]
function DataServiceServer.ArrayRemove(self: DataServiceServer, player: Player, indexPath: IndexPath, index: number, NoReplication: boolean?): any
	if not NoReplication then
		self._network.ArrayRemove.Fire(player, {
			Type = type(indexPath) == "table" and "Table" or "String",
			value = indexPath,
		}, index)
	end

	return self._dataProfiles[player]:ArrayRemove(indexPath, index)
end

--[[
	Gets a signal that fires whenever a value changes at the specified path.
	
	@param player Player - The player whose data to observe
	@param indexPath string | {string} - Path to observe
	@return Signal<any> - Signal that fires with the new value
	
	Examples:
	```lua
	-- Listen for level changes
	DataServiceServer:GetValueChangedSignal(player, "Stats.Level"):Connect(function(newLevel)
		print(player.Name, "reached level", newLevel)
		checkLevelAchievements(player, newLevel)
	end)
	
	-- Listen for VIP status changes
	DataServiceServer:GetValueChangedSignal(player, "Subscriptions.VIP"):Connect(function(isVIP)
		if isVIP then
			grantVIPPerks(player)
		else
			removeVIPPerks(player)
		end
	end)
	```
]]
function DataServiceServer.GetValueChangedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<any>
	return self._dataProfiles[player]:GetValueChangedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever a value is inserted into an array.
	
	@param player Player - The player whose data to observe
	@param indexPath string | {string} - Path to the array
	@return Signal<number, any> - Signal that fires with (index, value)
	
	Example:
	```lua
	-- Notify when new items are added
	DataServiceServer:GetArrayInsertedSignal(player, "Inventory.Items"):Connect(function(index, item)
		notifyPlayer(player, "New item acquired: " .. item.Name)
	end)
	```
]]
function DataServiceServer.GetArrayInsertedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<any>
	return self._dataProfiles[player]:GetArrayInsertedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever a value is removed from an array.
	
	@param player Player - The player whose data to observe
	@param indexPath string | {string} - Path to the array
	@return Signal<number, any> - Signal that fires with (index, removedValue)
	
	Example:
	```lua
	-- Track item removals
	DataServiceServer:GetArrayRemovedSignal(player, "Inventory.Items"):Connect(function(index, item)
		logItemRemoval(player, item)
	end)
	```
]]
function DataServiceServer.GetArrayRemovedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<number, any>
	return self._dataProfiles[player]:GetArrayRemovedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever any child index under the specified path changes.
	
	@param player Player - The player whose data to observe
	@param indexPath string | {string} - Path to the parent object
	@return Signal<string, any> - Signal that fires with (childKey, newValue)
	
	Example:
	```lua
	-- Listen for any currency changes
	DataService:GetIndexChangedSignal(player, "Currency"):Connect(function(currencyType, newAmount)
		updateCurrencyUI(player, currencyType, newAmount)
	end)
	```
]]
function DataServiceServer.GetIndexChangedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<any>
	return self._dataProfiles[player]:GetChildChangedSignal(indexPath)
end

--[[
	Observes a single value at a path for a specific player.
	
	Calls the factory function whenever the value changes. The factory should return a cleanup function.
	This is useful for setting up reactive behavior based on data changes.
	
	@param player Player - The player whose data to observe
	@param indexPath string | {string} - Path to observe
	@param factory (value: any) -> Disconnect - Function called with value, returns cleanup function
	@return Disconnect - Function to stop observing
	
	Examples:
	```lua
	-- Observe VIP status and grant/remove perks
	local disconnect = DataServiceServer:ObserveData(player, "Subscriptions.VIP", function(isVIP)
		if isVIP then
			local perkTag = Instance.new("StringValue")
			perkTag.Name = "VIPPerks"
			perkTag.Parent = player
			
			-- Return cleanup function
			return function()
				perkTag:Destroy()
			end
		end
		
		return function() end -- No cleanup needed
	end)
	
	-- Later: stop observing
	disconnect()
	
	-- Observe level and update character attributes
	DataServiceServer:ObserveData(player, "Stats.Level", function(level)
		player:SetAttribute("Level", level)
		
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = 100 + (level * 10)
			humanoid.Health = humanoid.MaxHealth
		end
		
		-- Cleanup when level changes again
		return function()
			print("Level changed, old value was:", level)
		end
	end)
	```
]]
function DataServiceServer.ObserveData(self: DataServiceServer, player: Player, indexPath: IndexPath, factory: (value: any) -> Disconnect): Disconnect
	return self._dataProfiles[player]:ObserveData(indexPath, factory)
end

--[[
	Observes a table at a path for a specific player.
	
	Calls the factory function for each key/value pair in the table, and whenever they change.
	The factory should return a cleanup function for each entry.
	
	@param player Player - The player whose data to observe
	@param indexPath string | {string} - Path to the table
	@param factory (key: K, value: V) -> Disconnect? - Function called for each entry
	@param monitorLastValue boolean? - If true, factory is called when values change (not just keys)
	@return Disconnect - Function to stop observing
	
	Examples:
	```lua
	-- Observe all active quests
	local disconnect = DataServiceServer:ObserveTableData(player, "Quests.Active", function(questId, questData)
		print("Tracking quest:", questId, questData)
		
		-- Set up quest tracking UI
		local questUI = createQuestUI(questId, questData)
		
		-- Return cleanup
		return function()
			questUI:Destroy()
		end
	end, true) -- Monitor value changes too
	
	-- Observe equipped items
	DataServiceServer:ObserveTableData(player, "Character.Equipped", function(slot, itemId)
		-- Equip the item visually
		local character = player.Character
		if character then
			equipItemToCharacter(character, slot, itemId)
		end
		
		-- Cleanup function
		return function()
			unequipItemFromCharacter(character, slot)
		end
	end)
	
	-- Later: stop observing
	disconnect()
	```
]]
function DataServiceServer.ObserveTableData<K, V>(self: DataServiceServer, player: Player, indexPath: IndexPath, factory: (key: K, value: V) -> Disconnect?, monitorLastValue: boolean?): Disconnect
	return self._dataProfiles[player]:ObserveTableData(indexPath, factory, monitorLastValue)
end

function DataServiceServer._playerAdded(self: DataServiceServer, player: Player): ()
	local userId = self.options.overridenUserId or player.UserId
	local key = self:_getProfileKey(userId)

	local params = {
		Cancel = function()
			return (player.Parent ~= Players)
		end,
	}

	local profile: Profile = if self.options.useMock
		then self.playerStore.Mock:StartSessionAsync(key, params)
		elseif self.options.dontSave then self.playerStore:GetAsync(key)
		else self.playerStore:StartSessionAsync(key, params)

	if not profile then
		warn(`{player.Name}'s profile failed to load!`)
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		self._activeProfiles[player] = nil
		player:Kick("Session closed.\nPlease rejoin!")
	end)

	profile.OnSave:Connect(function()
		print(`{player.Name}'s data has been saved`)
	end)

	if not player:IsDescendantOf(Players) then
		player:Kick(`Data failed to load.\nPlease rejoin`)
		return
	end

	self._activeProfiles[player] = profile
	self:_initializePlayer(player, profile.Data)
end

function DataServiceServer._playerRemoving(self: DataServiceServer, player: Player): ()
	local profile = self._activeProfiles[player]

	if not profile then
		return
	end

	profile:EndSession()
	self._activeProfiles[player] = nil

	local waitSignal = self._waitSignals[player]
	if waitSignal then
		waitSignal:Destroy()
		self._waitSignals[player] = nil
	end

	local dataProfile = self._dataProfiles[player]
	if dataProfile then
		dataProfile:Destroy()
		self._dataProfiles[player] = nil
	end
end

function DataServiceServer._initializePlayer(self: DataServiceServer, player: Player, data: any): ()
	self._dataProfiles[player] = DataProfile.new(data)

	local replicationData = self.options.replicationIgnoreList == nil and data or Sift.Dictionary.copyDeep(data)
	if self.options.replicationIgnoreList then
		for _, dataName in ipairs(self.options.replicationIgnoreList) do
			replicationData[dataName] = nil
		end
	end
	self._network.InitialDataSync.Fire(player, replicationData)

	local waitSignal = self._waitSignals[player]
	if waitSignal then
		waitSignal:Fire()

		waitSignal:Destroy()
		self._waitSignals[player] = nil
	end
end

function DataServiceServer._getProfileKey(self: DataServiceServer, userId: number | string): string
	return (self.options.profileStoreDataPrefix or DATA_PREFIX) .. tostring(userId)
end

return DataServiceServer