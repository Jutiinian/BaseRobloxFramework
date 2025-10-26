-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Signal = require(ReplicatedStorage.Packages.Signal)

-- || Variables || --
local AUTO_CLEAN_INTERVAL = 30
local pathCache = {} :: { [string]: { string } }

local strFind = string.find
local strSplit = string.split

export type IndexPath = string | { string }

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
		_autoCleanThread: thread?,
		_signals: {
			ValueChanged: { [string]: Signal.Signal<any> },
			ChildChanged: { [string]: Signal.Signal<string, any> },
		},
	},
	DataProfile
))

function DataProfile.new<T>(data: T): DataProfile<T>
	local self = {
		_data = data,
		_autoCleanThread = nil,
		_signals = {
			ValueChanged = {},
			ChildChanged = {},
		},
	}

	setmetatable(self, DataProfile)

	self._autoCleanThread = task.spawn(function()
		while true do
			task.wait(AUTO_CLEAN_INTERVAL)
			self:_CleanSignals()
		end
	end)

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

function DataProfile.GetValueChangedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<any>
	return self:_RetrieveSignal(indexPath, "ValueChanged")
end

function DataProfile.GetChildChangedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<string, any>
	return self:_RetrieveSignal(indexPath, "ChildChanged")
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

function DataProfile._FireChildChangedSignal<T>(self: DataProfile<T>, indexPath: string, index: string | number, value: any): ()
	local signal = self._signals.ChildChanged[indexPath]
	if signal then
		signal:Fire(index, value)
	end
end

function DataProfile._RetrieveSignal<T>(self: DataProfile<T>, indexPath: IndexPath, signalType: string): Signal.Signal<any, any>
	indexPath = stringifyPath(indexPath)
	if not self._signals[signalType][indexPath] then
		self._signals[signalType][indexPath] = Signal.new()
	end

	return self._signals[signalType][indexPath]
end

function DataProfile._CleanSignals<T>(self: DataProfile<T>): ()
	for _, signals in self._signals do
		for i, signal: Signal.Signal<any> in signals do
			if #signal:GetConnections() > 0 then
				continue
			end

			signal:Destroy()
			signals[i] = nil
		end
	end
end

-- Destroy Function
function DataProfile.Destroy<T>(self: DataProfile<T>): ()
	if self._autoCleanThread then
		task.cancel(self._autoCleanThread)
		self._autoCleanThread = nil
	end

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
