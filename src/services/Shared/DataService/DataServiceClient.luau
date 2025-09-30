-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local packages = ReplicatedStorage.Packages

local Signal = require(packages.Signal)
local DataProfile = require(script.Parent.DataProfile)

-- || Types || --
type Signal<T> = Signal.Signal<T>

-- || Variables || --
local initializationSignal = Signal.new()

-- || Public API || --
local DataServiceClient = {}

function DataServiceClient:Init()
	-- TODO: Add initialization logic here
end

return DataServiceClient
