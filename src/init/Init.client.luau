-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local FrameworkClient = ReplicatedStorage:WaitForChild("FrameworkClient")

-- || Initializer || --
require(FrameworkClient)
	.Start()
	:andThen(function()
		print("(Client) Framework Started!")
	end)
	:catch(warn)
