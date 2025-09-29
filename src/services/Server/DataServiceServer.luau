-- || Services || --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local Promise = require(ReplicatedStorage.Packages.Promise)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local TablesUtilities = require(ReplicatedStorage.Shared.Utils.Tables)

local DataTemplate = require(ReplicatedStorage.Shared.Services.DataService.DataTemplate)

-- || Variables || --
type Profile = ProfileStore.Profile<DataTemplate.Data>

local PlayerStore = ProfileStore.New("TestDataV.001", DataTemplate)
if RunService:IsStudio() == true then
	local MockData = PlayerStore.Mock
	PlayerStore = MockData
end

local ActiveProfiles: { [Player]: Profile } = {}

-- || Public API || --
local DataServiceServer = {}

--[[
	Attempts to load the player's profile synchronously.
	- Loads data if it isn't already loaded.
	- Adds the player's UserId to the profile.
	- Connects OnSessionEnd and OnSave events.
	- Returns the loaded profile, or nil if loading fails.
]]
function DataServiceServer:LoadPlayer(Player: Player): Profile?
	if ActiveProfiles[Player] then
		warn(`{Player.Name}'s profile already loaded`)
		return ActiveProfiles[Player]
	end

	local Profile = PlayerStore:StartSessionAsync(`{Player.UserId}`, {
		Cancel = function()
			return (Player.Parent ~= Players)
		end,
	})

	if not Profile then
		warn(`{Player.Name}'s profile failed to load!`)
		return nil
	end

	Profile:AddUserId(Player.UserId)
	Profile:Reconcile()

	Profile.OnSessionEnd:Connect(function()
		Player:Kick("Session closed.\nPlease rejoin!")
	end)

	Profile.OnSave:Connect(function()
		print(`{Player.Name}'s data has been saved`)
	end)

	ActiveProfiles[Player] = Profile
	return Profile
end

--[[
	Promise-based async wrapper around LoadPlayer.
	- Resolves with the Profile if successful.
	- Rejects with an error string if loading fails.
]]
function DataServiceServer:LoadPlayerAsync(Player: Player): Promise.TypedPromise<Profile>
	return Promise.new(function(resolve, reject)
		local Profile = self:LoadPlayer(Player)
		if Profile then
			resolve(Profile)
		else
			reject(`Failed to load profile`)
		end
	end)
end

--[[
	Forcefully save a player's profile data without closing session.
	- If a specific Player is provided, only that player's data is saved.
	- If no Player is provided, saves all active players' data.
	- Generally used for more criticle moments (eg. Developer Product related purchases)
]]
function DataServiceServer:SaveData(Player: Player?)
	local function SaveProfile(p: Player): ()
		local Profile = ActiveProfiles[p]
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
	Forcefully end a player's data session.
	- Data will automatically save.
	- Player is automatically kicked.
]]
function DataServiceServer:EndSession(Player: Player)
	local Profile = ActiveProfiles[Player]
	if Profile then
		Profile:EndSession()
	end
end

--[[
	Retrieves the loaded profile for a given player.
]]
function DataServiceServer:GetProfile(Player: Player): Profile?
	return ActiveProfiles[Player]
end

--[[
	Updates a specific value in the player's profile data.
	- Uses TablesUtilities:Replace with enforceType enabled by default.
	- Returns true if the update succeeded, false otherwise.
]]
function DataServiceServer:UpdateValue(Key: string, Value: any, Player: Player): boolean?
	local Profile = ActiveProfiles[Player]
	if not Profile or not Profile.Data then
		return false
	end

	local Success = TablesUtilities:Replace(Key, Value, Profile.Data, true)
	return Success
end

--[[
	Retrieves a value from the player's profile data.
	- Searches recursively using TablesUtilities:Find.
]]
function DataServiceServer:GetValue(Key: string, Player: Player): any
	local Profile = ActiveProfiles[Player]
	if not Profile or not Profile.Data then
		return nil
	end

	return TablesUtilities:Find(Key, Profile.Data)
end

--[[
	Increments a numeric value in the player's data by the specified amount.
	- Fails if the value does not exist or is not a number.
	- Updates the value and returns the new number if successful.
]]
function DataServiceServer:IncrementValue(Key: string, Amount: number, Player: Player): number?
	local Profile = ActiveProfiles[Player]
	if not Profile or not Profile.Data then
		return
	end

	local Current = self:GetValue(Key, Player)
	if not Current or typeof(Current) ~= "number" then
		return warn(`Failed to increment {Key} as no value exists or is not a number`)
	end

	Current += Amount
	local Success = self:UpdateValue(Key, Current, Player)
	if Success then
		return Current
	else
		return warn(`Failed to increment {Key} due to update error`)
	end
end

return DataServiceServer
