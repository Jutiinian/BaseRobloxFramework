-- || Services || --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages:FindFirstChild("React-Roblox"))

-- || Variables || --

-- || Loader || --
return function()
	local handle = Instance.new("ScreenGui")
	do
		handle.IgnoreGuiInset = true
		handle.Parent = Players.LocalPlayer.PlayerGui
	end

	local root = ReactRoblox.createRoot(handle)

	return function()
		root:unmount()
	end
end
