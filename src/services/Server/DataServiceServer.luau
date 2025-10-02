-- || Services || --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)

local DataServiceNetwork = require(ServerScriptService.ServerNetwork.DataServiceNetwork)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local DataProfile = require(ReplicatedStorage.Shared.Services.DataService.DataProfile)
local DataTemplate = require(ReplicatedStorage.Shared.Services.DataService.DataTemplate)

-- || Variables || --
type IndexPath = DataProfile.IndexPath
type Profile = ProfileStore.Profile<DataTemplate.Data>

local playerStore = ProfileStore.New("TestDataV.001", DataTemplate)
if RunService:IsStudio() then
	local mockData = playerStore.Mock
	playerStore = mockData
end

-- || Public API || --
local DataServiceServer = {
	_dataProfiles = {} :: { [Player]: DataProfile.DataProfile<DataTemplate.Data> },
	_activeProfiles = {} :: { [Player]: Profile },
	_waitSignals = {} :: { [Player]: Signal.Signal<any> },
}

--[[
	Start the DataService on the server
	- Loads data of all players already in game
	- Listens for players added and removing
]]
function DataServiceServer.Init(self: DataServiceServer)
	for _, player in ipairs(Players:GetPlayers()) do
		Promise.try(function()
			self:_PlayerAdded(player)
		end):catch(function(err)
			warn(err)
			player:Kick("Critical Game Error!\nPlease rejoin")
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		self:_PlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_PlayerRemoving(player)
	end)
end

--[[
	Forcefully save a player's profile data without closing session.
	- If a specific player is provided, only that player's data is saved.
	- If no player is provided, saves all active players' data.
	- Generally used for critical moments (eg. Developer Product related purchases)
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
	Retrieves the loaded profile for a given player.
]]
function DataServiceServer.GetProfile(self: DataServiceServer, player: Player): Profile?
	return self._activeProfiles[player]
end

--[[
	Waits for the player's data to be initialized and returns it.
	- Returns immediately if the data is already available.
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
	Retrieves a value from the player's profile data.
	- indexPath examples: "Settings" or "Settings.Audio" or "Settings.Audio.Music"
	- indexPath can also be a table {"Settings", "Audio"}, which is "Settings.Audio"
]]
function DataServiceServer.GetValue(self: DataServiceServer, player: Player, indexPath: IndexPath?): any
	return self._dataProfiles[player]:GetValue(indexPath)
end

--[[
	Sets a value in the player's profile data.
	- indexPath examples: "Settings" or "Settings.Audio" or "Settings.Audio.Music"
	- indexPath can also be a table {"Settings", "Audio"}, which is "Settings.Audio"
]]
function DataServiceServer.SetValue(self: DataServiceServer, player: Player, indexPath: IndexPath, value: any): ()
	DataServiceNetwork.DataUpdate.Fire(player, {
		Key = {
			Type = type(indexPath) == "table" and "Table" or "String",
			value = indexPath,
		},
		Value = value,
	})

	self._dataProfiles[player]:SetValue(indexPath, value)
end

--[[
	Updates a value in the player's profile data using a callback function and returns the new value.
	- indexPath examples: "Settings" or "Settings.Audio" or "Settings.Audio.Music"
	- indexPath can also be a table {"Settings", "Audio"}, which is "Settings.Audio"
	- The callback receives the current value and should return the new value
]]
function DataServiceServer.UpdateValue(self: DataServiceServer, player: Player, indexPath: IndexPath, callback: (any) -> any): any
	local newValue = self._dataProfiles[player]:UpdateValue(indexPath, callback)

	DataServiceNetwork.DataUpdate.Fire(player, {
		Key = {
			Type = type(indexPath) == "table" and "Table" or "String",
			value = indexPath,
		},
		Value = newValue,
	})

	return newValue
end

--[[
	Retrieves a signal that fires whenever the value at the specified path changes in a player's profile.
	- indexPath examples: "Settings" or "Settings.Audio" or "Settings.Audio.Music"
	- indexPath can also be a table {"Settings", "Audio"}, which is "Settings.Audio"
	- The signal passes the new value when it changes
]]
function DataServiceServer.GetValueChangedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<any>
	return self._dataProfiles[player]:GetValueChangedSignal(indexPath)
end

--[[
	Retrieves a signal that fires whenever any index under the specified path changes.
	- indexPath examples: "Settings" or "Settings.Audio" or "Settings.Audio.Music"
	- indexPath can also be a table {"Settings", "Audio"}, which is "Settings.Audio"
	- Fires with two parameters: the index that changed, and its new value
]]
function DataServiceServer.GetChildChangedSignal(self: DataServiceServer, player: Player, indexPath: IndexPath): Signal.Signal<any>
	return self._dataProfiles[player]:GetChildChangedSignal(indexPath)
end

function DataServiceServer._PlayerAdded(self: DataServiceServer, player: Player): ()
	local profile = playerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return (player.Parent ~= Players)
		end,
	})

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
	self:_InitializePlayer(player, profile.Data)
end

function DataServiceServer._PlayerRemoving(self: DataServiceServer, player: Player): ()
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

function DataServiceServer._InitializePlayer(self: DataServiceServer, player: Player, data: any): ()
	self._dataProfiles[player] = DataProfile.new(data)
	DataServiceNetwork.InitialDataSync.Fire(player, data)

	local waitSignal = self._waitSignals[player]
	if waitSignal then
		waitSignal:Fire()

		waitSignal:Destroy()
		self._waitSignals[player] = nil
	end
end

export type DataServiceServer = typeof(DataServiceServer)

return DataServiceServer
