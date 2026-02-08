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
	useMock: boolean?,
	overridenUserId: number?,
	dontSave: boolean?,
	profileStoreIndex: string?,
	profileStoreDataPrefix: string?,
	replicationIgnoreList: { string }?,
}

--[[
	Initializes the DataService server.
	- Loads data for all players currently in the game.
	- Sets up network replication module.
	- Observes player joins and leaves.
	Parameters:
	- options: Configuration table to control behavior
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
	- Useful for critical events like purchases.
	Parameters:
	- player (optional): The Player to save. Saves all if nil.
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
	Gets the currently loaded profile for a player.
	Returns nil if the profile isn't loaded yet.
]]
function DataServiceServer.GetProfile(self: DataServiceServer, player: Player): Profile?
	return self._activeProfiles[player]
end

--[[
	Waits for the player's data to be ready and returns it.
	- Returns immediately if data is already available.
	- Can be used synchronously in scripts.
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
	- Resolves immediately if data is already available.
	- Rejects if the player leaves before data is loaded.
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
			return self._activeProfiles[player] ~= nil
		end):andThenReturn(self._activeProfiles[player]),

		Promise.fromEvent(Players.PlayerRemoving, function(leavingPlayer)
			return leavingPlayer == player
		end):andThen(function()
			error("Player left before data loaded")
		end),
	})
end

--[[
	Gets a value from a player's profile data.
	- indexPath can be string "Settings.Audio" or table {"Settings", "Audio"}
]]
function DataServiceServer.Get(self: DataServiceServer, player: Player, indexPath: IndexPath?): any
	return self._dataProfiles[player]:Get(indexPath)
end

--[[
	Sets a value in the player's profile data.
	- indexPath examples: "Settings" or "Settings.Audio" or "Settings.Audio.Music"
	- indexPath can also be a table {"Settings", "Audio"}, which is "Settings.Audio"
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
	Updates a value in a player's profile data using a callback and returns the new value.
	- indexPath can be string or table
	- NoReplication disables client replication
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
	- indexPath can be string or table
	- index is optional, otherwise value is appended
	- NoReplication disables client replication
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
	- indexPath can be string or table
	- Returns the removed value
	- NoReplication disables client replication
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
	- Passes the new value as parameter
]]
function DataServiceServer.GetValueChangedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<any>
	return self._dataProfiles[player]:GetValueChangedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever a value is inserted into an array at the specified path.
	- Passes the inserted value as parameter
]]
function DataServiceServer.GetArrayInsertedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<any>
	return self._dataProfiles[player]:GetArrayInsertedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever a value is removed from an array at the specified path.
	- Passes the removed value as parameter
]]
function DataServiceServer.GetArrayRemovedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<number, any>
	return self._dataProfiles[player]:GetArrayRemovedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever any index under the specified path changes.
	- Fires with two parameters: the index that changed and its new value
]]
function DataServiceServer.GetIndexChangedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<any>
	return self._dataProfiles[player]:GetChildChangedSignal(indexPath)
end

--[[
	Observes a single value at a path for a specific player.
	- Calls factory whenever the value changes
	- Returns a disconnect function to stop observing
]]
function DataServiceServer.ObserveData(self: DataServiceServer, player: Player, indexPath: IndexPath, factory: (value: any) -> Disconnect): Disconnect
	return self._dataProfiles[player]:ObserveData(indexPath, factory)
end

--[[
	Observes a table at a path for a specific player.
	- Calls factory for each key/value whenever it changes
	- monitorLastValue: optional, triggers factory if value changes
	- Returns a disconnect function to stop observing
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
