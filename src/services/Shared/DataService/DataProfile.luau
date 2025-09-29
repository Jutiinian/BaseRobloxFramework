--!nocheck
-- Got annoying having some things underlines red so I set to no check

-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Signal = require(ReplicatedStorage.Packages.Signal)

-- || Variables || --
local AUTO_CLEAN_INTERVAL = 30

local PathCache = {} :: { [string]: { string } }

export type IndexPath = string | { string }

-- || Private Functions || --
local function NormalizePath(IndexPath: IndexPath): { string } | string
	if type(IndexPath) == "string" then
		if PathCache[IndexPath] or string.find(IndexPath, ".", 1, true) then
			local Path = PathCache[IndexPath]

			if not Path then
				Path = string.split(IndexPath, ".")
				PathCache[IndexPath] = Path
			end

			return Path
		else
			return IndexPath
		end
	end

	return IndexPath
end

local function StringifyPath(IndexPath: IndexPath): string
	if type(IndexPath) == "string" then
		return IndexPath
	end

	return table.concat(IndexPath, ".")
end

-- || Public API || --
local DataProfile = {}
DataProfile.__index = DataProfile

function DataProfile.new<T>(Data: T): DataProfile<T>
	local self = {
		_Data = Data,
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
function DataProfile.GetValue<T>(self: DataProfile<T>, IndexPath: IndexPath?): T & any
	if IndexPath == nil then
		return self._Data
	end

	local Data = self._Data
	IndexPath = NormalizePath(IndexPath)

	if type(IndexPath) == "string" then
		return Data[IndexPath]
	end

	for _, key in ipairs(IndexPath :: { string }) do
		Data = Data[key]
	end

	return Data
end

function DataProfile.SetValue<T>(self: DataProfile<T>, IndexPath: IndexPath, Value: any): ()
	local Data = self._Data
	IndexPath = NormalizePath(IndexPath)

	if type(IndexPath) == "string" then
		Data[IndexPath] = Value
		self:_FireChangedSignals(IndexPath)
		return
	end

	for i = 1, #IndexPath - 1 do
		Data = Data[IndexPath[i]]
	end

	Data[IndexPath[#IndexPath]] = Value
	self:_FireChangedSignals(IndexPath)
end

function DataProfile.UpdateValue<T>(self: DataProfile<T>, IndexPath: IndexPath, Callback: (any) -> any): any
	local OldValue = self:GetValue(IndexPath)
	local NewValue = Callback(OldValue)

	self:SetValue(IndexPath, NewValue)

	return NewValue
end

function DataProfile.GetValueChangedSignal<T>(self: DataProfile<T>, IndexPath: IndexPath): Signal.Signal<any>
	return self:_RetrieveSignal(IndexPath, "ValueChanged")
end

function DataProfile.GetChildChangedSignal<T>(self: DataProfile<T>, IndexPath: IndexPath): Signal.Signal<any>
	return self:_RetrieveSignal(IndexPath, "ChildChanged")
end

-- Signal Functions
function DataProfile._FireChangedSignals<T>(self: DataProfile<T>, IndexPath: IndexPath): string
	if type(IndexPath) == "string" then
		self:_FireValueChangedSignal(IndexPath, self:GetValue(IndexPath))
		return IndexPath
	end

	local Value = self._Data
	local indexString = ""

	for i, Key in ipairs(IndexPath) do
		Value = Value[Key]

		if i > 1 then
			local ParentPath = indexString
			indexString ..= "."
			self:_FireChildChangedSignal(ParentPath, Key, Value)
		end

		indexString ..= Key

		self:_FireValueChangedSignal(indexString, Value)
	end

	return indexString
end

function DataProfile._FireValueChangedSignal<T>(self: DataProfile<T>, IndexPath: string, Value: any): ()
	local signal = self._Signals.ValueChanged[IndexPath]
	if signal then
		signal:Fire(Value)
	end
end

function DataProfile._FireChildChangedSignal<T>(
	self: DataProfile<T>,
	IndexPath: string,
	Index: string | number,
	Value: any
): ()
	local signal = self._Signals.ChildChanged[IndexPath]
	if signal then
		signal:Fire(Index, Value)
	end
end

function DataProfile._RetrieveSignal<T>(self: DataProfile<T>, IndexPath: IndexPath, SignalType: string): Signal.Signal<any>
	IndexPath = StringifyPath(IndexPath)
	if not self._Signals[SignalType][IndexPath] then
		self._Signals[SignalType][IndexPath] = Signal.new()
	end

	return self._Signals[SignalType][IndexPath]
end

function DataProfile._CleanSignals<T>(self: DataProfile<T>): ()
	for _, Signals in self._Signals do
		for i, signal: Signal.Signal<any> in Signals do
			if #signal:GetConnections() > 0 then
				continue
			end

			signal:Destroy()
			Signals[i] = nil
		end
	end
end

-- Destroy Function
function DataProfile.Destroy<T>(self: DataProfile<T>): ()
	if self._AutoCleanThread then
		task.cancel(self._AutoCleanThread)
		self._AutoCleanThread = nil
	end

	for _, Signals in self._Signals do
		for _, signal in Signals do
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
