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

local PlayerStore = ProfileStore.New("TestDataV.001", DataTemplate)
if RunService:IsStudio() == true then
	local MockData = PlayerStore.Mock
	PlayerStore = MockData
end

-- || Public API || --
local DataServiceServer = {
	_DataProfiles = {} :: { [Player]: DataProfile.DataProfile<DataTemplate.Data> },
	_ActiveProfiles = {} :: { [Player]: Profile },
	_WaitSignals = {} :: { [Player]: Signal.Signal<any> },
}

--[[
	Start the DataService on the Server
	- Loads data of all players already in game
	- Listens for players added and removing
]]
function DataServiceServer.init(self: DataServiceServer)
	for _, Player in ipairs(Players:GetPlayers()) do
		Promise.try(function()
			self:_PlayerAdded(Player)
		end):catch(function(Err)
			warn(Err)
			Player:Kick("Critical Game Error!\nPlease rejoin")
		end)
	end

	Players.PlayerAdded:Connect(function(Player)
		self:_PlayerAdded(Player)
	end)

	Players.PlayerRemoving:Connect(function(Player)
		self:_PlayerRemoving(Player)
	end)
end

function DataServiceServer._PlayerAdded(self: DataServiceServer, Player: Player): ()
	local Profile = PlayerStore:StartSessionAsync(`{Player.UserId}`, {
		Cancel = function()
			return (Player.Parent ~= Players)
		end,
	})

	if not Profile then
		warn(`{Player.Name}'s profile failed to load!`)
		return
	end

	Profile:AddUserId(Player.UserId)
	Profile:Reconcile()

	Profile.OnSessionEnd:Connect(function()
		self._ActiveProfiles[Player] = nil
		Player:Kick("Session closed.\nPlease rejoin!")
	end)

	Profile.OnSave:Connect(function()
		print(`{Player.Name}'s data has been saved`)
	end)

	if not Player:IsDescendantOf(Players) then
		Player:Kick(`Data failed to load.\nPlease rejoin`)
		return
	end

	self._ActiveProfiles[Player] = Profile
	self:_InitializePlayer(Player, Profile.Data)
end

function DataServiceServer._PlayerRemoving(self: DataServiceServer, Player: Player): ()
	local Profile = self._ActiveProfiles[Player]

	if not Profile then
		return
	end

	Profile:EndSession()
	self._ActiveProfiles[Player] = nil

	local WaitSignal = self._WaitSignals[Player]
	if WaitSignal then
		WaitSignal:Destroy()
		self._WaitSignals[Player] = nil
	end

	local dataProfile = self._DataProfiles[Player]
	if dataProfile then
		dataProfile:Destroy()
		self._DataProfiles[Player] = nil
	end
end

function DataServiceServer._InitializePlayer(self: DataServiceServer, Player: Player, Data: any): ()
	self._DataProfiles[Player] = DataProfile.new(Data)
	-- TODO: Fire to the client to update their data

	local WaitSignal = self._WaitSignals[Player]
	if WaitSignal then
		WaitSignal:Fire()

		WaitSignal:Destroy()
		self._WaitSignals[Player] = nil
	end
end

--[[
	Forcefully save a player's profile data without closing session.
	- If a specific Player is provided, only that player's data is saved.
	- If no Player is provided, saves all active players' data.
	- Generally used for more criticle moments (eg. Developer Product related purchases)
]]
function DataServiceServer.SaveData(self: DataServiceServer, Player: Player?)
	local function SaveProfile(p: Player): ()
		local Profile = self._ActiveProfiles[p]
		if Profile then
			Profile:Save()
		end
	end

	if Player then
		SaveProfile(Player)
	else
		for _, p in ipairs(Players:GetPlayers()) do
			SaveProfile(p)
		end
	end
end

--[[
	Retrieves the loaded profile for a given player.
]]
function DataServiceServer.GetProfile(self: DataServiceServer, Player: Player): Profile?
	return self._ActiveProfiles[Player]
end

--[[
	Waits for the player's data to be initialized and returns it.
	- Returns immediately if the data is already available.
]]
function DataServiceServer.WaitForData(
	self: DataServiceServer,
	Player: Player
): DataProfile.DataProfile<DataTemplate.Data>
	local Data = self._DataProfiles[Player]
	if Data then
		return Data
	end

	local WaitSignal = self._WaitSignals[Player]
	if not WaitSignal then
		WaitSignal = Signal.new()
		self._WaitSignals[Player] = WaitSignal
	end

	WaitSignal:Wait()
	return self._DataProfiles[Player]
end

--[[
	Retrieves a value from the player's profile data.
	- Path can be "Settings.Audio" or "Settings.Audio.Music"
	- Path can also be a table {"Settings", "Audio"}
]]
function DataServiceServer.GetValue(self: DataServiceServer, Player: Player, IndexPath: IndexPath?): any
	return self._DataProfiles[Player]:GetValue(IndexPath)
end

--[[
	Sets a value in the player's profile data.
	- Path can be a string: "Settings.Audio" or "Settings.Audio.Music"
	- Path can also be a table: {"Settings", "Audio"}
]]
function DataServiceServer.SetValue(self: DataServiceServer, Player: Player, IndexPath: IndexPath, Value: any): ()
	self._DataProfiles[Player]:SetValue(IndexPath, Value)
end

--[[
	Updates a value in the player's profile data using a callback function and returns the new value.
	- Path can be a string: "Settings.Audio" or "Settings.Audio.Music"
	- Path can also be a table: {"Settings", "Audio"}
	- The callback receives the current value and should return the new value
]]
function DataServiceServer.UpdateValue(
	self: DataServiceServer,
	Player: Player,
	IndexPath: IndexPath,
	Callback: (any) -> any
): any
	return self._DataProfiles[Player]:UpdateValue(IndexPath, Callback)
end

--[[
	Retrieves a signal that fires whenever the value at the specified path changes in a player's profile.
	- Path can be a string: "Settings.Audio" or "Settings.Audio.Music"
	- Path can also be a table: {"Settings", "Audio"}
	- The signal passes the new value when it changes
]]
function DataServiceServer.GetValueChangedSignal(
	self: DataServiceServer,
	Player: Player,
	IndexPath: IndexPath
): Signal.Signal<any>
	return self._DataProfiles[Player]:GetValueChangedSignal(IndexPath)
end

--[[
	Retrieves a signal that fires whenever any index under the specified path changes.
	- Path can be a string: "Settings"
	- Path can also be a table: {"Settings"}
	- Fires with two parameters: the index that changed, and its new value
]]
function DataServiceServer.GetChildChangedSignal(
	self: DataServiceServer,
	Player: Player,
	IndexPath: IndexPath
): Signal.Signal<any>
	return self._DataProfiles[Player]:GetChildChangedSignal(IndexPath)
end

export type DataServiceServer = typeof(DataServiceServer)

return DataServiceServer
