--!nocheck
-- Disabled type checking due to false positives in some areas

-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Signal = require(ReplicatedStorage.Packages.Signal)

-- || Variables || --
local AUTO_CLEAN_INTERVAL = 30
local pathCache = {} :: { [string]: { string } }

export type IndexPath = string | { string }

-- || Private Functions || --
local function normalizePath(indexPath: IndexPath): { string } | string
	if type(indexPath) == "string" then
		if pathCache[indexPath] or string.find(indexPath, ".", 1, true) then
			local path = pathCache[indexPath]

			if not path then
				path = string.split(indexPath, ".")
				pathCache[indexPath] = path
			end

			return path
		else
			return indexPath
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

function DataProfile.new<T>(data: T): DataProfile<T>
	local self = {
		_Data = data,
		_AutoCleanThread = nil,
		_Signals = {
			ValueChanged = {},
			ChildChanged = {},
		},
	}

	setmetatable(self, DataProfile)

	self._AutoCleanThread = task.spawn(function()
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
		return self._Data
	end

	local data = self._Data
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
	local data = self._Data
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

function DataProfile.GetChildChangedSignal<T>(self: DataProfile<T>, indexPath: IndexPath): Signal.Signal<any>
	return self:_RetrieveSignal(indexPath, "ChildChanged")
end

-- Signal Functions
function DataProfile._FireChangedSignals<T>(self: DataProfile<T>, indexPath: IndexPath): string
	if type(indexPath) == "string" then
		self:_FireValueChangedSignal(indexPath, self:GetValue(indexPath))
		return indexPath
	end

	local value = self._Data
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
	local signal = self._Signals.ValueChanged[indexPath]
	if signal then
		signal:Fire(value)
	end
end

function DataProfile._FireChildChangedSignal<T>(
	self: DataProfile<T>,
	indexPath: string,
	index: string | number,
	value: any
): ()
	local signal = self._Signals.ChildChanged[indexPath]
	if signal then
		signal:Fire(index, value)
	end
end

function DataProfile._RetrieveSignal<T>(self: DataProfile<T>, indexPath: IndexPath, signalType: string): Signal.Signal<any>
	indexPath = stringifyPath(indexPath)
	if not self._Signals[signalType][indexPath] then
		self._Signals[signalType][indexPath] = Signal.new()
	end

	return self._Signals[signalType][indexPath]
end

function DataProfile._CleanSignals<T>(self: DataProfile<T>): ()
	for _, signals in self._Signals do
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
	if self._AutoCleanThread then
		task.cancel(self._AutoCleanThread)
		self._AutoCleanThread = nil
	end

	for _, signals in self._Signals do
		for _, signal in signals do
			signal:Destroy()
		end
	end

	self._Signals = nil :: any

	table.clear(self)
	setmetatable(self, nil :: any)
end

export type DataProfile<T> = typeof(setmetatable(
	{} :: {
		_Data: T,
		_AutoCleanThread: thread?,
		_Signals: {
			ValueChanged: { [string]: Signal.Signal<any> },
			ChildChanged: { [string]: Signal.Signal<any> },
		},
	},
	DataProfile
))

return DataProfile
