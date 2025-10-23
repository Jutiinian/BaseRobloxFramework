-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local packages = ReplicatedStorage.Packages

local Signal = require(packages.Signal)

local DataServiceNetwork = require(ReplicatedStorage.Shared.ClientNetwork.DataServiceNetwork)

local DataProfile = require(script.Parent.DataProfile)

-- || Types || --
type Signal<T> = Signal.Signal<T>

-- || Variables || --
type IndexPath = DataProfile.IndexPath

local initializationSignal = Signal.new()

-- || Public API || --
local DataServiceClient = {
	_data = nil :: DataProfile.DataProfile<any>?,
}

export type DataServiceClient = typeof(DataServiceClient)

--[[
	Start the DataService on the client
	- Listens for data to be sent from the server
	- Syncs data from server to client
	- Returns a function that disconnects the listeners
]]
function DataServiceClient.Init(self: DataServiceClient): () -> ()
	local initialDisconnector = DataServiceNetwork.InitialDataSync.SetCallback(function(data)
		if not data then
			return
		end

		print(data)

		self:_InitializeData(data)
	end)

	local updaterDisconnector = DataServiceNetwork.DataUpdate.SetCallback(function(data)
		if not data or not data.Key then
			return
		end

		self:WaitForData()
		self._data:SetValue(data.Key.value, data.Value)
	end)

	return function()
		initialDisconnector()
		updaterDisconnector()
	end
end

--[[
	Retrieves a value from the player's profile data.
	- indexPath examples: "Settings" or "Settings.Audio" or "Settings.Audio.Music"
	- indexPath can also be a table {"Settings", "Audio"}, which is "Settings.Audio"
]]
function DataServiceClient.GetValue(self: DataServiceClient, indexPath: IndexPath?): any
	self:WaitForData()
	return self._data:GetValue(indexPath)
end

-- TODO: Maybe add set and update functions

--[[
	Retrieves a signal that fires whenever the value at the specified path changes in the player's data.
	- indexPath examples: "Settings" or "Settings.Audio" or "Settings.Audio.Music"
	- indexPath can also be a table {"Settings", "Audio"}, which is "Settings.Audio"
	- The signal passes the new value when it changes
]]
function DataServiceClient.GetValueChangedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.Signal<any>
	return self._data:GetValueChangedSignal(indexPath)
end

--[[
	Retrieves a signal that fires whenever any index under the specified path changes.
	- indexPath examples: "Settings" or "Settings.Audio" or "Settings.Audio.Music"
	- indexPath can also be a table {"Settings", "Audio"}, which is "Settings.Audio"
	- Fires with two parameters: the index that changed, and its new value
]]
function DataServiceClient.GetChildChangedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.Signal<string, any>
	return self._data:GetChildChangedSignal(indexPath)
end

--[[
	Waits for the player's data to be initialized and returns it.
	- Returns immediately if the data is already available.
]]
function DataServiceClient.WaitForData(self: DataServiceClient): DataProfile.DataProfile<any>
	local data = self._data
	if data then
		return data
	end

	initializationSignal:Wait()
	return self._data
end

function DataServiceClient._InitializeData(self: DataServiceClient, data: any)
	assert(self._data == nil, "Data already initialized on the client")
	self._Data = DataProfile.new(data)
	initializationSignal:Fire()
end

return DataServiceClient
