-- || Services || --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local Signal = require(ReplicatedStorage.Packages.Signal)
local Promise = require(ReplicatedStorage.Packages.Promise)
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
	_DataProfiles = {} :: { [Player]: DataProfile.DataProfile<DataTemplate.Data> },
	_ActiveProfiles = {} :: { [Player]: Profile },
	_WaitSignals = {} :: { [Player]: Signal.Signal<any> },
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
		self._ActiveProfiles[player] = nil
		player:Kick("Session closed.\nPlease rejoin!")
	end)

	profile.OnSave:Connect(function()
		print(`{player.Name}'s data has been saved`)
	end)

	if not player:IsDescendantOf(Players) then
		player:Kick(`Data failed to load.\nPlease rejoin`)
		return
	end

	self._ActiveProfiles[player] = profile
	self:_InitializePlayer(player, profile.Data)
end

function DataServiceServer._PlayerRemoving(self: DataServiceServer, player: Player): ()
	local profile = self._ActiveProfiles[player]

	if not profile then
		return
	end

	profile:EndSession()
	self._ActiveProfiles[player] = nil

	local waitSignal = self._WaitSignals[player]
	if waitSignal then
		waitSignal:Destroy()
		self._WaitSignals[player] = nil
	end

	local dataProfile = self._DataProfiles[player]
	if dataProfile then
		dataProfile:Destroy()
		self._DataProfiles[player] = nil
	end
end

function DataServiceServer._InitializePlayer(self: DataServiceServer, player: Player, data: any): ()
	self._DataProfiles[player] = DataProfile.new(data)
	-- TODO: Fire to the client to update their data

	local waitSignal = self._WaitSignals[player]
	if waitSignal then
		waitSignal:Fire()

		waitSignal:Destroy()
		self._WaitSignals[player] = nil
	end
end

--[[
	Forcefully save a player's profile data without closing session.
	- If a specific player is provided, only that player's data is saved.
	- If no player is provided, saves all active players' data.
	- Generally used for critical moments (eg. Developer Product related purchases)
]]
function DataServiceServer.SaveData(self: DataServiceServer, player: Player?)
	local function saveProfile(p: Player): ()
		local profile = self._ActiveProfiles[p]
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
	return self._ActiveProfiles[player]
end

--[[
	Waits for the player's data to be initialized and returns it.
	- Returns immediately if the data is already available.
]]
function DataServiceServer.WaitForData(
	self: DataServiceServer,
	player: Player
): DataProfile.DataProfile<DataTemplate.Data>
	local data = self._DataProfiles[player]
	if data then
		return data
	end

	local waitSignal = self._WaitSignals[player]
	if not waitSignal then
		waitSignal = Signal.new()
		self._WaitSignals[player] = waitSignal
	end

	waitSignal:Wait()
	return self._DataProfiles[player]
end

--[[
	Retrieves a value from the player's profile data.
	- Path can be "Settings.Audio" or "Settings.Audio.Music"
	- Path can also be a table {"Settings", "Audio"}
]]
function DataServiceServer.GetValue(self: DataServiceServer, player: Player, indexPath: IndexPath?): any
	return self._DataProfiles[player]:GetValue(indexPath)
end

--[[
	Sets a value in the player's profile data.
	- Path can be a string: "Settings.Audio" or "Settings.Audio.Music"
	- Path can also be a table: {"Settings", "Audio"}
]]
function DataServiceServer.SetValue(self: DataServiceServer, player: Player, indexPath: IndexPath, value: any): ()
	self._DataProfiles[player]:SetValue(indexPath, value)
end

--[[
	Updates a value in the player's profile data using a callback function and returns the new value.
	- Path can be a string: "Settings.Audio" or "Settings.Audio.Music"
	- Path can also be a table: {"Settings", "Audio"}
	- The callback receives the current value and should return the new value
]]
function DataServiceServer.UpdateValue(
	self: DataServiceServer,
	player: Player,
	indexPath: IndexPath,
	callback: (any) -> any
): any
	return self._DataProfiles[player]:UpdateValue(indexPath, callback)
end

--[[
	Retrieves a signal that fires whenever the value at the specified path changes in a player's profile.
	- Path can be a string: "Settings.Audio" or "Settings.Audio.Music"
	- Path can also be a table: {"Settings", "Audio"}
	- The signal passes the new value when it changes
]]
function DataServiceServer.GetValueChangedSignal(
	self: DataServiceServer,
	player: Player,
	indexPath: IndexPath
): Signal.Signal<any>
	return self._DataProfiles[player]:GetValueChangedSignal(indexPath)
end

--[[
	Retrieves a signal that fires whenever any index under the specified path changes.
	- Path can be a string: "Settings"
	- Path can also be a table: {"Settings"}
	- Fires with two parameters: the index that changed, and its new value
]]
function DataServiceServer.GetChildChangedSignal(
	self: DataServiceServer,
	player: Player,
	indexPath: IndexPath
): Signal.Signal<any>
	return self._DataProfiles[player]:GetChildChangedSignal(indexPath)
end

export type DataServiceServer = typeof(DataServiceServer)

return DataServiceServer
