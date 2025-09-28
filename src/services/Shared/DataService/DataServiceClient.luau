-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Packages = ReplicatedStorage.Packages

local Signal = require(Packages.Signal)

local Data = require(script.Parent.Data)

-- || Variables || --
type Signal<T> = Signal.Signal<T>

local InitializationSignal = Signal.new()

-- || Public API || --
local DataServiceClient = {}

function DataServiceClient:init() end

return DataServiceClient
