-- || Services || --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages:FindFirstChild("React-Roblox"))

-- || Variables || --
local Handle = Instance.new("ScreenGui", Players.LocalPlayer.PlayerGui)

-- || Loader || --
