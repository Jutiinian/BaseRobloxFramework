-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Framework = require(ReplicatedStorage.Shared.Framework)

-- || Initializer || --
Framework.Start()
	:andThen(function()
		print("(Client) Framework Started!")
	end)
	:catch(warn)
