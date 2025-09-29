-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Packages = ReplicatedStorage.Packages

local Signal = require(Packages.Signal)

local DataProfile = require(script.Parent.DataProfile)

-- || Variables || --
type Signal<T> = Signal.Signal<T>

local InitializationSignal = Signal.new()

-- || Public API || --
local DataServiceClient = {}

function DataServiceClient:init() end

return DataServiceClient
