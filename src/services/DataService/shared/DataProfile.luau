-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local DataServiceTypes = require(script.Parent.DataServiceTypes)
local Signal = require(ReplicatedStorage.Packages.signal)

-- || Variables || --
local pathCache = {} :: { [string]: { string } }

local strFind = string.find
local strSplit = string.split

type Disconnect = DataServiceTypes.Disconnect
type IndexPath = DataServiceTypes.IndexPath
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
			ValueChanged: { [string]: Signal.ClassicSignal<any, any?> },
			IndexChanged: { [string]: Signal.ClassicSignal<any, any?> },
			ArrayInserted: { [string]: Signal.ClassicSignal<any> },
			ArrayRemoved: { [string]: Signal.ClassicSignal<any> },
		},
		_weakSignals: {
			ValueChanged: WeakValueTable<Signal.ClassicSignal<any, any?>>,
			IndexChanged: WeakValueTable<Signal.ClassicSignal<any, any?>>,
			ArrayInserted: WeakValueTable<Signal.ClassicSignal<number, any>>,
			ArrayRemoved: WeakValueTable<Signal.ClassicSignal<number, any>>,
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
function DataProfile.Get<T>(self: DataProfile<T>, indexPath: IndexPath?): T & any
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

function DataProfile.Set<T>(self: DataProfile<T>, indexPath: IndexPath, value: any): ()
	local data = self._data
	indexPath = normalizePath(indexPath)

	if type(indexPath) == "string" then
		data[indexPath] = value
		self:_fireChangedSignals(indexPath)
		return
	end

	for i = 1, #indexPath - 1 do
		data = data[indexPath[i]]
	end

	data[indexPath[#indexPath]] = value
	self:_fireChangedSignals(indexPath)
end

function DataProfile.Update<T>(self: DataProfile<T>, indexPath: IndexPath, callback: (any) -> any): any
	local oldValue = self:Get(indexPath)
	local newValue = callback(oldValue)

	self:Set(indexPath, newValue)

	return newValue
end

function DataProfile.ArrayInsert<T>(self: DataProfile<T>, indexPath: IndexPath, value: any, index: number?): ()
	local data = self:Get(indexPath)
	assert(type(data) == "table", "Data at path is not a table")

	if index then
		table.insert(data, index, value)
	else
		table.insert(data, value)
	end

	local pathString = self:_fireChangedSignals(indexPath)

	local signal = self._signals.ArrayInserted[pathString]
	if signal then
		signal:Fire(index or #data, value)
	end
end

function DataProfile.ArrayRemove<T>(self: DataProfile<T>, indexPath: IndexPath, index: number): any
	local data = self:Get(indexPath)
	assert(type(data) == "table", "Data at path is not a table")

	local value = table.remove(data, index)
	local pathString = self:_fireChangedSignals(indexPath)

	local signal = self._signals.ArrayRemoved[pathString]
	if signal then
		signal:Fire(index, value)
	end

	return value
end

function DataProfile.GetValueChangedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<any>
	return self:_retrieveSignal(indexPath, "ValueChanged")
end

function DataProfile.GetIndexChangedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<string, any>
	return self:_retrieveSignal(indexPath, "ChildChanged")
end

function DataProfile.GetArrayInsertedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<number, any>
	return self:_retrieveSignal(indexPath, "ArrayInserted")
end

function DataProfile.GetArrayRemovedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<number, any>
	return self:_retrieveSignal(indexPath, "ArrayRemoved")
end

function DataProfile.ObserveData<T>(self: DataProfile<T>, indexPath: IndexPath, factory: (value: any) -> Disconnect?): Disconnect
	local cleanupFunction: (() -> ())? = nil

	local function listener(value: any)
		if cleanupFunction then
			task.spawn(cleanupFunction)
			cleanupFunction = nil
		end

		local clean = factory(value)
		cleanupFunction = typeof(clean) == "function" and clean or function() end
	end

	local conn = self:GetValueChangedSignal(indexPath):Connect(listener)

	task.defer(function()
		if not conn.Connected then
			return
		end

		listener(self:Get(indexPath))
	end)

	return function()
		conn:Disconnect()

		if cleanupFunction then
			cleanupFunction()
			cleanupFunction = nil
		end
	end
end

-- TODO: MAYBE make separate observe array function
function DataProfile.ObserveTableData<T, K, V>(self: DataProfile<T>, indexPath: IndexPath, factory: (key: K, value: V) -> Disconnect?, monitorLastValue: boolean?): Disconnect
	local connections: { [K]: {disconnect: Disconnect?, lastValue: V?} } = {}

	local function listener(state: {[K]: V})
		state = state or {}
		
		for key, data in next, connections do
			if state[key] == nil then
				connections[key] = nil
				task.spawn(data.disconnect)
			end
		end

		for key, value in next, state do
			local data = connections[key]

			if not data then
				local clean = factory(key, value)
				connections[key] = {
					disconnect = typeof(clean) == "function" and clean or function() end,
					lastValue = value
				}
			elseif monitorLastValue and data.lastValue ~= value then
				data.disconnect()
				local clean = factory(key, value)
				connections[key] = {
					disconnect = typeof(clean) == "function" and clean or function() end,
					lastValue = value
				}
			end
		end
	end

	local conn = self:GetValueChangedSignal(indexPath):Connect(listener)

	task.defer(function()
		if not conn.Connected then return end
		listener(self:Get(indexPath))
	end)

	return function()
		conn:Disconnect()
		for _, data in next, connections do
			data.disconnect()
		end
		table.clear(connections)
	end
end

-- Signal Functions
function DataProfile._fireChangedSignals<T>(self: DataProfile<T>, indexPath: IndexPath): string
	if type(indexPath) == "string" then
		self:_fireValueChangedSignal(indexPath, self:Get(indexPath))
		return indexPath
	end

	local value = self._data
	local indexString = ""

	for i, key in ipairs(indexPath) do
		value = value[key]

		if i > 1 then
			local parentPath = indexString
			indexString ..= "."
			self:_fireIndexChangedSignal(parentPath, key, value)
		end

		indexString ..= key

		self:_fireValueChangedSignal(indexString, value)
	end

	return indexString
end

function DataProfile._fireValueChangedSignal<T>(self: DataProfile<T>, indexPath: string, value: any): ()
	local signal = self._signals.ValueChanged[indexPath]
	if signal then
		signal:Fire(value)
	end
end

function DataProfile._fireIndexChangedSignal<T>(self: DataProfile<T>, indexPath: string, index: string | number, value: any): ()
	local signal = self._signals.IndexChanged[indexPath]
	if signal then
		signal:Fire(index, value)
	end
end

function DataProfile:_retrieveSignal<T>(indexPath: IndexPath, signalType: string): Signal.Signal<any, any?>
	local pathString = stringifyPath(indexPath)

	local weakSignals = self._weakSignals[signalType]
	local strongSignals = self._signals[signalType]

	if weakSignals[pathString] then
		return weakSignals[pathString]
	end
	local signal = Signal.new()
	weakSignals[pathString] = signal

	local activeConnCount = 0

	local function wrapConnect(originalFunc)
		return function(_, handler: (...any?) -> ())
			local conn = originalFunc(signal, handler)
			activeConnCount += 1
			strongSignals[pathString] = signal

			local origDisconnect = conn.Disconnect
			conn.Disconnect = function()
				if conn.Connected then
					activeConnCount -= 1
					if activeConnCount <= 0 then
						strongSignals[pathString] = nil
					end
				end
				origDisconnect(conn)
			end

			conn.Destroy = conn.Disconnect
			return conn
		end
	end

	signal.Connect = wrapConnect(signal.Connect)
	signal.Once = wrapConnect(signal.Once)

	local origDestroy = signal.Destroy
	signal.Destroy = function()
		activeConnCount = 0
		strongSignals[pathString] = nil
		weakSignals[pathString] = nil
		origDestroy(signal)
	end

	local origDisconnectAll = signal.DisconnectAll
	signal.DisconnectAll = function()
		activeConnCount = 0
		strongSignals[pathString] = nil
		origDisconnectAll(signal)
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
