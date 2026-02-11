-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- || Dependencies || --
local Promise = require(ReplicatedStorage.Packages.promise)
local Signal = require(ReplicatedStorage.Packages.signal)

local DataProfile = require(script.Parent.DataProfile)
local DataServiceTypes = require(script.Parent.DataServiceTypes)

-- || Variables || --
type Disconnect = DataServiceTypes.Disconnect
type IndexPath = DataServiceTypes.IndexPath

local initializationSignal = Signal.new()

-- || Public API || --
type DataServiceNetwork = typeof(require(script.Parent.NetworkClient))

local DataServiceClient = {
	_network = nil :: DataServiceNetwork?,
	_data = nil :: DataProfile.DataProfile<any>?,
}

export type DataServiceClient = typeof(DataServiceClient)

--[[
	Initializes the DataService on the client.
	
	This should be called once when the game starts, typically in a client-side initialization script.
	It sets up network listeners to receive data updates from the server.
	
	@return void
	
	Example:
	```lua
	local DataServiceClient = require(ReplicatedStorage.Services.DataService.DataServiceClient)
	DataServiceClient:Init()
	```
	
	Note: This must be called before attempting to access any player data.
]]
function DataServiceClient.Init(self: DataServiceClient)
	self._network = require(script.Parent.NetworkClient)

	-- Listen for initial data sync from server
	self._network.InitialDataSync.SetCallback(function(data)
		if not data then
			return
		end

		self:_initializeData(data)
	end)

	-- Listen for data updates from server
	self._network.DataUpdate.SetCallback(function(key, value)
		self:WaitForDataAsync():andThen(function()
			self._data:Set(key.value, value)
		end)
	end)

	-- Listen for array insertions from server
	self._network.ArrayInsert.SetCallback(function(key, value, index)
		self:WaitForDataAsync():andThen(function()
			self._data:ArrayInsert(key.value, value, index)
		end)
	end)

	-- Listen for array removals from server
	self._network.ArrayRemove.SetCallback(function(key, index)
		self:WaitForDataAsync():andThen(function()
			self._data:ArrayRemove(key.value, index)
		end)
	end)
end

--[[
	Gets a value from the player's profile data.
	
	@param indexPath string | {string} - Path to the data. Can be a dot-separated string like "Settings.Audio.Volume"
	                                      or a table like {"Settings", "Audio", "Volume"}
	@return any - The value at the specified path, or nil if not found
	
	Examples:
	```lua
	-- Get entire settings object
	local settings = DataServiceClient:Get("Settings")
	
	-- Get nested value using string path
	local volume = DataServiceClient:Get("Settings.Audio.Volume")
	
	-- Get nested value using table path
	local volume = DataServiceClient:Get({"Settings", "Audio", "Volume"})
	
	-- Get root data (entire profile)
	local allData = DataServiceClient:Get()
	```
	
	Note: This is a synchronous read from the local cache. Make sure data is loaded first using WaitForData() or WaitForDataAsync().
]]
function DataServiceClient.Get(self: DataServiceClient, indexPath: IndexPath?): any
	return self._data:Get(indexPath)
end

--[[
	Gets a signal that fires whenever a value changes at the specified path.
	
	@param indexPath string | {string} - Path to observe for changes
	@return Signal<any> - Signal that fires with the new value when it changes
	
	Examples:
	```lua
	-- Listen for volume changes
	local volumeSignal = DataServiceClient:GetValueChangedSignal("Settings.Audio.Volume")
	volumeSignal:Connect(function(newVolume)
		print("Volume changed to:", newVolume)
		SoundService.Volume = newVolume
	end)
	
	-- Listen for currency changes
	local coinConnection = DataServiceClient:GetValueChangedSignal("Currency.Coins"):Connect(function(newCoins)
		updateCoinsUI(newCoins)
	end)

	coinConnection:Disconnect()
	```
	
	Note: The signal will only fire when the server updates this value. Local changes are not possible on the client.
]]
function DataServiceClient.GetValueChangedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.ClassicSignal<any>
	return self._data:GetValueChangedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever a value is inserted into an array at the specified path.
	
	@param indexPath string | {string} - Path to the array to observe
	@return Signal<number, any> - Signal that fires with (index, value) when an item is inserted
	
	Examples:
	```lua
	-- Listen for new inventory items
	local insertSignal = DataServiceClient:GetArrayInsertedSignal("Inventory.Items")
	insertSignal:Connect(function(index, item)
		print("New item added at position", index, ":", item)
		addItemToUI(item)
	end)
	
	-- Listen for friend additions
	local friendsConnection = DataServiceClient:GetArrayInsertedSignal("Social.Friends"):Connect(function(index, friendUserId)
		notifyNewFriend(friendUserId)
	end)

	friendsConnection:Disconnect()
	```
]]
function DataServiceClient.GetArrayInsertedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.ClassicSignal<number, any>
	return self._data:GetArrayInsertedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever a value is removed from an array at the specified path.
	
	@param indexPath string | {string} - Path to the array to observe
	@return Signal<number, any> - Signal that fires with (index, removedValue) when an item is removed
	
	Examples:
	```lua
	-- Listen for removed inventory items
	local removeSignal = DataServiceClient:GetArrayRemovedSignal("Inventory.Items")
	removeSignal:Connect(function(index, removedItem)
		print("Item removed from position", index, ":", removedItem)
		removeItemFromUI(removedItem)
	end)
	```
]]
function DataServiceClient.GetArrayRemovedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.ClassicSignal<number, any>
	return self._data:GetArrayRemovedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever any child index under the specified path changes.
	
	Useful for observing changes to multiple fields within an object without creating separate signals.
	
	@param indexPath string | {string} - Path to the parent object to observe
	@return Signal<string, any> - Signal that fires with (childKey, newValue) when any child changes
	
	Examples:
	```lua
	-- Listen for any settings changes
	local settingsSignal = DataServiceClient:GetIndexChangedSignal("Settings")
	settingsSignal:Connect(function(key, value)
		print("Setting changed:", key, "=", value)
		if key == "Audio" then
			updateAudioSettings(value)
		elseif key == "Graphics" then
			updateGraphicsSettings(value)
		end
	end)
	
	-- Listen for any stat changes
	local statsConnection = DataServiceClient:GetIndexChangedSignal("Stats"):Connect(function(statName, newValue)
		updateStatUI(statName, newValue)
	end)
	```
]]
function DataServiceClient.GetIndexChangedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.ClassicSignal<string, any>
	return self._data:GetChildChangedSignal(indexPath)
end

--[[
	Observes a single value at a path for a specific player.
	
	Calls the factory function whenever the value changes. The factory should return a cleanup function.
	This is useful for setting up reactive behavior based on data changes.

	@param indexPath string | {string} - Path to observe
	@param factory (value: any) -> Disconnect - Function called with value, returns cleanup function
	@return Disconnect - Function to stop observing
	
	Examples:
	```lua
	-- Observe VIP status and grant/remove perks
	local disconnect = DataServiceClient:ObserveData("Subscriptions.VIP", function(isVIP)
		if isVIP then
			local perkTag = Instance.new("StringValue")
			perkTag.Name = "VIPPerks"
			perkTag.Parent = player
			
			-- Return cleanup function
			return function()
				perkTag:Destroy()
			end
		end
		
		return function() 
			print("IsVIP has changed")
		end
	end)
	
	-- Later: stop observing
	disconnect()
	```
]]
function DataServiceClient.ObserveData(self: DataServiceClient, indexPath: IndexPath, factory: (value: any) -> Disconnect): Disconnect
	return self._data:ObserveData(indexPath, factory)
end

--[[
	Observes a table at a path for a specific player.
	
	Calls the factory function for each key/value pair in the table, and whenever they change.
	The factory should return a cleanup function for each entry.
	
	@param indexPath string | {string} - Path to the table
	@param factory (key: K, value: V) -> Disconnect? - Function called for each entry
	@param monitorLastValue boolean? - If true, factory is called when values change (not just keys)
	@return Disconnect - Function to stop observing
	
	Examples:
	```lua
	-- Observe all active quests
	local disconnect = DataServiceClient:ObserveTableData("Quests.Active", function(questId, questData)
		print("Tracking quest:", questId, questData)
		
		-- Set up quest tracking UI
		local questUI = createQuestUI(questId, questData)
		
		-- Return cleanup
		return function()
			questUI:Destroy()
		end
	end, true) -- Monitor value changes too
	
	-- Observe equipped items
	DataServiceClient:ObserveTableData("Character.Equipped", function(slot, itemId)
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
function DataServiceClient.ObserveTableData<K, V>(self: DataServiceClient, indexPath: IndexPath, factory: (key: K, value: V) -> Disconnect?, monitorLastValue: boolean?): Disconnect
	return self._data:ObserveTableData(indexPath, factory, monitorLastValue)
end

--[[
	Waits for the player's data to be initialized and returns it (synchronous).
	
	⚠️ Warning: This yields the current thread. Consider using WaitForDataAsync() instead for better control.
	
	@return DataProfile - The player's data profile
	
	Example:
	```lua
	-- In a script that can yield
	local data = DataServiceClient:WaitForData()
	local coins = data:Get("Currency.Coins")
	print("Player has", coins, "coins")
	```
	
	Note: Generally prefer WaitForDataAsync() for more robust async handling.
]]
function DataServiceClient.WaitForData(self: DataServiceClient): DataProfile.DataProfile<any>
	if not RunService:IsEdit() and not self._data then
		self:_initializeData(require(script.Parent.DataTemplate))
	end

	local data = self._data
	if data then
		return data
	end

	initializationSignal:Wait()
	return self._data
end

--[[
	Returns a promise that waits for the player's data to be initialized and resolves with it.
	
	This is the preferred way to wait for data as it integrates well with promise chains and doesn't yield.
	
	@return Promise<DataProfile> - Promise that resolves with the player's data profile
	
	Examples:
	```lua
	-- Basic usage
	DataServiceClient:WaitForDataAsync():andThen(function(data)
		local coins = data:Get("Currency.Coins")
		print("Player has", coins, "coins")
	end):catch(function(err)
		warn("Failed to load data:", err)
	end)
	
	-- Chain multiple operations
	DataServiceClient:WaitForDataAsync()
		:andThen(function(data)
			local level = data:Get("Stats.Level")
			return loadLevelAssets(level)
		end)
		:andThen(function()
			print("Level assets loaded!")
		end)
	
	-- Use with await in async context
	local function setupPlayer()
		local data = DataServiceClient:WaitForDataAsync():await()
		local characterData = data:Get("Character")
		applyCharacterCustomization(characterData)
	end
	
	Promise.try(setupPlayer):catch(warn)
	```
	
	Benefits over WaitForData():
	- Non-blocking, returns immediately with a promise
	- Can be chained with other async operations
	- Better error handling with catch()
	- Can be canceled or timed out
]]
function DataServiceClient.WaitForDataAsync(self: DataServiceClient): Promise.TypedPromise<DataProfile.DataProfile<any>>
	local data = self._data
	if data then
		return Promise.resolve(data)
	end

	return Promise.fromEvent(initializationSignal, function()
		return self._data ~= nil
	end):andThenReturn(self._data)
end

function DataServiceClient._initializeData(self: DataServiceClient, data: any)
	assert(self._data == nil, "Data already initialized on the client")
	self._data = DataProfile.new(data)
	initializationSignal:Fire()
end

return DataServiceClient