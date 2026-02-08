-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Signal = require(ReplicatedStorage.Packages.Signal)

-- || Variables || --
local pathCache = {} :: { [string]: { string } }

local strFind = string.find
local strSplit = string.split

export type IndexPath = string | { string }
type WeakValueTable<T> = typeof(setmetatable({} :: { [string]: T }, { __mode = "v" }))

-- || Private Functions || --
local function normalizePath(indexPath: IndexPath): { string } | string
	if typeof(indexPath) == "string" then
		local cached = pathCache[indexPath]
		if cached then
			return cached
		end

		if strFind(indexPath, ".", 1, true) then
			local splitPath = strSplit(indexPath, ".")
			pathCache[indexPath] = splitPath
			return splitPath
		end
	end

	return indexPath
end

local function stringifyPath(indexPath: IndexPath): string
	if type(indexPath) == "string" then
		return indexPath
	end

	return table.concat(indexPath, ".")
end

-- || Public API || --
local DataProfile = {}
DataProfile.__index = DataProfile

export type DataProfile<T> = typeof(setmetatable(
	{} :: {
		_data: T,
		_signals: {
			ValueChanged: { [string]: Signal.Signal<any, any?> },
			IndexChanged: { [string]: Signal.Signal<any, any?> },
			ArrayInserted: { [string]: Signal.Signal<any> },
			ArrayRemoved: { [string]: Signal.Signal<any> },
		},
		_weakSignals: {
			ValueChanged: WeakValueTable<Signal.Signal<any, any?>>,
			IndexChanged: WeakValueTable<Signal.Signal<any, any?>>,
			ArrayInserted: WeakValueTable<Signal.Signal<any>>,
			ArrayRemoved: WeakValueTable<Signal.Signal<any>>,
		},
	},
	DataProfile
))

function DataProfile.new<T>(data: T): DataProfile<T>
	local self = {
		_data = data,
		_signals = {
			ValueChanged = {},
			IndexChanged = {},
			ArrayInserted = {},
			ArrayRemoved = {},
		},
		_weakSignals = {
			ValueChanged = setmetatable({}, { __mode = "v" }),
			IndexChanged = setmetatable({}, { __mode = "v" }),
			ArrayInserted = setmetatable({}, { __mode = "v" }),
			ArrayRemoved = setmetatable({}, { __mode = "v" }),
		},
	}

	setmetatable(self, DataProfile)

	return self
end

-- Usable Functions
function DataProfile.GetValue<T>(self: DataProfile<T>, indexPath: IndexPath?): T & any
	if indexPath == nil then
		return self._data
	end

	local data = self._data
	indexPath = normalizePath(indexPath)

	if type(indexPath) == "string" then
		return data[indexPath]
	end

	for _, key in ipairs(indexPath :: { string }) do
		data = data[key]
	end

	return data
end

function DataProfile.SetValue<T>(self: DataProfile<T>, indexPath: IndexPath, value: any): ()
	local data = self._data
	indexPath = normalizePath(indexPath)

	if type(indexPath) == "string" then
		data[indexPath] = value
		self:_FireChangedSignals(indexPath)
		return
	end

	for i = 1, #indexPath - 1 do
		data = data[indexPath[i]]
	end

	data[indexPath[#indexPath]] = value
	self:_FireChangedSignals(indexPath)
end

function DataProfile.UpdateValue<T>(self: DataProfile<T>, indexPath: IndexPath, callback: (any) -> any): any
	local oldValue = self:GetValue(indexPath)
	local newValue = callback(oldValue)

	self:SetValue(indexPath, newValue)

	return newValue
end

function DataProfile.ArrayInsert<T>(self: DataProfile<T>, indexPath: IndexPath, value: any, index: number?): ()
	local data = self:GetValue(indexPath)
	assert(type(data) == "table", "Data at path is not a table")

	if index then
		table.insert(data, index, value)
	else
		table.insert(data, value)
	end

	local pathString = self:_FireChangedSignals(indexPath)

	local signal = self._signals.ArrayInserted[pathString]
	if signal then
		signal:Fire(index or #data, value)
	end
end

function DataProfile.ArrayRemove<T>(self: DataProfile<T>, indexPath: IndexPath, index: number): any
	local data = self:GetValue(indexPath)
	assert(type(data) == "table", "Data at path is not a table")

	local value = table.remove(data, index)
	local pathString = self:_firePathChangedSignals(indexPath)

	local signal = self._signals.ArrayRemoved[pathString]
	if signal then
		signal:Fire(index, value)
	end

	return value
end

function DataProfile.GetValueChangedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<any>
	return self:_RetrieveSignal(indexPath, "ValueChanged")
end

function DataProfile.GetIndexChangedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<string, any>
	return self:_RetrieveSignal(indexPath, "ChildChanged")
end

function DataProfile.GetArrayInsertedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<any>
	return self:_getSignal(indexPath, "ArrayInserted")
end

function DataProfile.GetArrayRemovedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<any>
	return self:_getSignal(indexPath, "ArrayRemoved")
end

-- Signal Functions
function DataProfile._FireChangedSignals<T>(self: DataProfile<T>, indexPath: IndexPath): string
	if type(indexPath) == "string" then
		self:_FireValueChangedSignal(indexPath, self:GetValue(indexPath))
		return indexPath
	end

	local value = self._data
	local indexString = ""

	for i, key in ipairs(indexPath) do
		value = value[key]

		if i > 1 then
			local parentPath = indexString
			indexString ..= "."
			self:_FireChildChangedSignal(parentPath, key, value)
		end

		indexString ..= key

		self:_FireValueChangedSignal(indexString, value)
	end

	return indexString
end

function DataProfile._FireValueChangedSignal<T>(self: DataProfile<T>, indexPath: string, value: any): ()
	local signal = self._signals.ValueChanged[indexPath]
	if signal then
		signal:Fire(value)
	end
end

function DataProfile._FireIndexChangedSignal<T>(self: DataProfile<T>, indexPath: string, index: string | number, value: any): ()
	local signal = self._signals.IndexChanged[indexPath]
	if signal then
		signal:Fire(index, value)
	end
end

function DataProfile._RetrieveSignal<T>(self: DataProfile<T>, indexPath: IndexPath, signalType: string): Signal.Signal<any, any>
	local pathString = stringifyPath(indexPath)

	--[[if not self._signals[signalType][indexPath] then
		self._signals[signalType][indexPath] = Signal.new()
	end

	return self._signals[signalType][indexPath]]

	local weakSignals = self._weakSignals[signalType]
	local signal = weakSignals[pathString]
	if signal then
		return signal
	end

	signal = Signal.new()
	weakSignals[pathString] = signal
	local connCreators = { Connect = signal.Connect, Once = signal.Once }
	local connCount = 0
	local strongSignals = self._signals[signalType]

	for funcName, originalFunc in connCreators do
		signal[funcName] = function(_, handler: (...any?) -> ())
			local conn = originalFunc(signal, handler)
			connCount += 1
			strongSignals[pathString] = signal

			local originalDisconnect = conn.Disconnect
			conn.Disconnect = function()
				if conn.Connected then
					connCount -= 1
					if connCount <= 0 then
						strongSignals[pathString] = nil
					end
				end
				originalDisconnect(conn)
			end

			conn.Destroy = conn.Disconnect
			return conn
		end
	end

	local originalDestroy = signal.Destroy
	signal.Destroy = function()
		connCount = 0
		strongSignals[pathString] = nil
		weakSignals[pathString] = nil
		originalDestroy(signal)
	end

	local originalDisconnectAll = signal.DisconnectAll
	signal.DisconnectAll = function()
		connCount = 0
		strongSignals[pathString] = nil
		originalDisconnectAll(signal)
	end

	return signal
end

-- Destroy Function
function DataProfile.Destroy<T>(self: DataProfile<T>): ()
	for _, signals in self._signals do
		for _, signal in signals do
			signal:Destroy()
		end
	end

	self._signals = nil :: any

	table.clear(self :: any)
	setmetatable(self :: any, nil)
end

return DataProfile
