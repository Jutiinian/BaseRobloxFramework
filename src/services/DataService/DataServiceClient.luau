-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- || Dependencies || --
local Promise = require(ReplicatedStorage.Packages.promise)
local Signal = require(ReplicatedStorage.Packages.signal)

local DataProfile = require(script.Parent.DataProfile)
local DataServiceTypes = require(script.Parent.DataServiceTypes)

-- || Variables || --
type IndexPath = DataServiceTypes.IndexPath

local initializationSignal = Signal.new()

-- || Public API || --
type DataServiceNetwork = typeof(require(script.Parent.NetworkClient))

local DataServiceClient = {
	_network = nil :: DataServiceNetwork?,
	_data = nil :: DataProfile.DataProfile<any>?,
}

export type DataServiceClient = typeof(DataServiceClient)

--[[
	Start the DataService on the client
	- Loads DataService network on client and listens for data to be sent from the server
	- Syncs data from server to client
	- Returns a function that disconnects the listeners
]]
function DataServiceClient.Init(self: DataServiceClient)
	self._network = require(script.Parent.NetworkClient)

	self._network.InitialDataSync.SetCallback(function(data)
		if not data then
			return
		end

		self:_initializeData(data)
	end)

	self._network.DataUpdate.SetCallback(function(key, value)
		self:WaitForDataAsync():andThen(function()
			self._data:Set(key.value, value)
		end)
	end)

	self._network.ArrayInsert.SetCallback(function(key, value, index)
		self:WaitForDataAsync():andThen(function()
			self._data:ArrayInsert(key.value, value, index)
		end)
	end)

	self._network.ArrayRemove.SetCallback(function(key, index)
		self:WaitForDataAsync():andThen(function()
			self._data:ArrayRemove(key.value, index)
		end)
	end)
end

--[[
	Gets a value from a player's profile data.
	- indexPath can be string "Settings.Audio" or table {"Settings", "Audio"}
]]
function DataServiceClient.Get(self: DataServiceClient, indexPath: IndexPath?): any
	return self._data:Get(indexPath)
end

-- TODO: Maybe add set and update functions

--[[
	Gets a signal that fires whenever a value changes at the specified path.
	- Passes the new value as parameter
]]
function DataServiceClient.GetValueChangedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.ClassicSignal<any>
	return self._data:GetValueChangedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever a value is inserted into an array at the specified path.
	- Passes the inserted value as parameter
]]
function DataServiceClient.GetArrayInsertedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.ClassicSignal<number, any>
	return self._data:GetArrayInsertedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever a value is removed from an array at the specified path.
	- Passes the removed value as parameter
]]
function DataServiceClient.GetArrayRemovedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.ClassicSignal<number, any>
	return self._data:GetArrayRemovedSignal(indexPath)
end

--[[
	Gets a signal that fires whenever any index under the specified path changes.
	- Fires with two parameters: the index that changed and its new value
]]
function DataServiceClient.GetIndexChangedSignal(self: DataServiceClient, indexPath: IndexPath): Signal.ClassicSignal<string, any>
	return self._data:GetChildChangedSignal(indexPath)
end

--[[
	Waits for the player's data to be initialized and returns it.
	- Returns immediately if the data is already available.
	- Generally, use WaitForDataAsync instead
]]
function DataServiceClient.WaitForData(self: DataServiceClient): DataProfile.DataProfile<any>
	if not RunService:IsEdit() and not self._data then
		self:_initializeData(require(script.Parent.DataTemplate))
	end

	local data = self._data
	if data then
		return data
	end

	initializationSignal:Wait()
	return self._data
end

--[[
	Returns a promise that waits for the player's data to be initialized and resolves with it.
	- Resolves immediately if the data is already available.
]]
function DataServiceClient.WaitForDataAsync(self: DataServiceClient): Promise.TypedPromise<DataProfile.DataProfile<any>>
	local data = self._data
	if data then
		return Promise.resolve(data)
	end

	return Promise.fromEvent(initializationSignal, function()
		return self._data ~= nil
	end):andThenReturn(self._data)
end

function DataServiceClient._initializeData(self: DataServiceClient, data: any)
	assert(self._data == nil, "Data already initialized on the client")
	self._data = DataProfile.new(data)
	initializationSignal:Fire()
end

return DataServiceClient
