-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local packages = ReplicatedStorage.Packages

local Signal = require(packages.Signal)

local DataServiceNetwork = require(ReplicatedStorage.Shared.ClientNetwork.DataServiceNetwork)

local DataTemplate = require(script.Parent.DataTemplate)
local DataProfile = require(script.Parent.DataProfile)

-- || Types || --
type Signal<T> = Signal.Signal<T>

-- || Variables || --
type IndexPath = DataProfile.IndexPath

local initializationSignal = Signal.new()

-- || Public API || --
local DataServiceClient = {
	_Data = nil :: DataProfile.DataProfile<any>?,
}

--[[
	Start the DataService on the client
	- Listens for data to be sent from the server
	- Syncs data from server to client
	- Returns a function that disconnects the listener
]]
function DataServiceClient.Init(self: DataServiceClient): () -> ()
	local Disconnect = DataServiceNetwork.InitialDataSync.SetCallback(function(data)
		if not data then
			return
		end
		self:_InitializeData(data)
	end)

	return Disconnect
end

--[[
	Waits for the player's data to be initialized and returns it.
	- Returns immediately if the data is already available.
]]
function DataServiceClient.WaitForData(self: DataServiceClient): DataProfile.DataProfile<any>
	local data = self._Data
	if data then
		return data
	end

	initializationSignal:Wait()
	return self._Data
end

function DataServiceClient._InitializeData(self: DataServiceClient, data: any)
	assert(self._Data == nil, "Data already initialized on the client")
	self._Data = DataProfile.new(data)
	initializationSignal:Fire()
end

export type DataServiceClient = typeof(DataServiceClient)

return DataServiceClient
