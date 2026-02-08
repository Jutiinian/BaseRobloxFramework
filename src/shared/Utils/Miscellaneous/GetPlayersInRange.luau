--!strict

-- || Services || --
local Players = game:GetService("Players")

-- || Public API || --
--[[
	Returns a list of players within `range` studs of `origin`
    - Origin can be either Vector3 or CFrame
]]
local function GetPlayersInRange(origin: Vector3 | CFrame, range: number): { Player }
	local position: Vector3 = typeof(origin) == "CFrame" and origin.Position :: Vector3 or origin :: Vector3

	local nearbyPlayers = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and (humanoidRootPart.Position - position).Magnitude <= range then
			table.insert(nearbyPlayers, player)
		end
	end

	return nearbyPlayers
end

return GetPlayersInRange
