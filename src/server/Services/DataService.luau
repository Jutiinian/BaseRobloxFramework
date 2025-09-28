--!strict

-- || Services || --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local Promise = require(ReplicatedStorage.Packages.Promise)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

-- || Variables || --
local DataProfile = ProfileStore.New("TestDataV.001", {})

type Profile = ProfileStore.Profile<typeof({})>

local ActiveProfiles: { [Player]: Profile } = {}

-- || Public API || --
local DataService = {}

function DataService:LoadPlayer(Player: Player): Profile?
	if ActiveProfiles[Player] then
		warn(`{Player.Name}'s profile already loaded`)
		return ActiveProfiles[Player]
	end

	local Profile = DataProfile:StartSessionAsync(`{Player.UserId}`, {
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
		Player:Kick("Data released.\nPlease rejoin!")
	end)

	Profile.OnSave:Connect(function()
		print(`{Player.Name}'s data has been saved`)
	end)

	ActiveProfiles[Player] = Profile
	return Profile
end

function DataService:LoadPlayerAsync(Player: Player): Promise.TypedPromise<Profile>
	return Promise.new(function(resolve, reject)
		local Profile = self:LoadPlayer(Player)
		if Profile then
			resolve(Profile)
		else
			reject(`Failed to load profile`)
		end
	end)
end

function DataService:GetProfile(Player: Player): Profile?
	return ActiveProfiles[Player]
end

function DataService:UpdateValue(Key: string, Value: any, Player: Player): boolean?
	local Profile = self:GetProfile(Player)
	if not Profile or not Profile.Data then
		return false
	end

	local function recursiveReplace(tbl: { [any]: any }): boolean
		for key, value in pairs(tbl) do
			if key == Key then
				if typeof(value) == typeof(Value) then
					tbl[key] = Value
					return true
				else
					warn(`Type mismatch for Key: {Key}\nExpected {typeof(value)}, got {typeof(Value)}`)
					return false
				end
			elseif typeof(value) == "table" then
				if recursiveReplace(value) then
					return true
				end
			end
		end
		return false
	end

	local success = recursiveReplace(Profile.Data)
	return success
end

function DataService:GetValue(Key: string, Player: Player): any
	local Profile = self:GetProfile(Player)
	if not Profile or not Profile.Data then
		return
	end

	-- TODO: Make "deep search"
	if Profile then
		return Profile.Data[Key]
	end

	return nil
end

return DataService
