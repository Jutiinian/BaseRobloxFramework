--!strict

-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Janitor = require(ReplicatedStorage.Packages.janitor)
local Signal = require(ReplicatedStorage.Packages.signal)

local HeapManager = require(script.Parent.Utils.HeapManager)

local StateServiceTypes = require(script.Parent.StateServiceTypes)

-- || Constants/Variables || --
type StateData = StateServiceTypes.StateData
type HeapManager = HeapManager.HeapManager<StateProfile>

local sharedHeap: HeapManager.HeapManager<StateProfile> = HeapManager.new(function(rawEntry)
	local entry = rawEntry :: HeapManager.HeapEntry<StateProfile>
	local self = entry.Instance

	if not self._states then
		return
	end

	local state = self._states[entry.Key]
	if state ~= entry.StateRef then
		return
	end

	if state.Paused then
		return
	end

	self._states[entry.Key] = nil
	self:_fire(entry.Key, false)
end)

-- || Private Helper Functions || --
local function _getRemaining(state: StateData): number?
	if not state.ExpiresAt then
		return nil
	end
	local r = state.ExpiresAt - os.clock()
	return if r > 0 then r else 0
end

-- || Public API || --
local StateProfile = {}
StateProfile.__index = StateProfile

export type StateProfile = typeof(setmetatable(
	{} :: {
		_states: { [string]: StateData },
		_signals: { [string]: Signal.ClassicSignal<any> },
		_janitor: Janitor.Janitor,

		Changed: Signal.ClassicSignal<any>,
	},
	StateProfile
))

function StateProfile.new(): StateProfile
	local self = setmetatable({
		_states = {},
		_signals = {},
		_janitor = Janitor.new(),
	}, StateProfile)

	self.Changed = Signal.new(self._janitor)

	return self
end

function StateProfile.Add(self: StateProfile, stateKey: string, duration: number?)
	local state: StateData = {
		ExpiresAt = if duration then os.clock() + duration else nil,
		Duration = duration,
	}

	self._states[stateKey] = state

	if duration then
		sharedHeap:Push({
			ExpiresAt = state.ExpiresAt :: number,
			Instance = self,
			Key = stateKey,
			StateRef = state,
		})

		local root = sharedHeap:Peek()
		if root and (root :: any).StateRef == state then
			sharedHeap:ScheduleNext()
		end
	end

	-- TODO: FIre added
end

function StateProfile.AddMany(self: StateProfile, map: { [string]: number | boolean })
	for stateKey, value in map do
		if value == false then
			continue
		end
		self:Add(stateKey, if type(value) == "number" then value else nil)
	end
end

function StateProfile.Remove(self: StateProfile, stateKey: string)
	if not self._states[stateKey] then
		return
	end

	self._states[stateKey] = nil

	-- TODO: Fire remove
end

function StateProfile.RemoveMany(self: StateProfile, keys: { string })
	for _, key in keys do
		self:Remove(key)
	end
end

function StateProfile.IsActive(self: StateProfile, stateKey: string): boolean
	return self._states[stateKey] ~= nil
end

function StateProfile.IsAnyActive(self: StateProfile, ...: string): boolean
	local states = self._states
	for i = 1, select("#", ...) do
		if states[(select(i, ...))] then
			return true
		end
	end
	return false
end

function StateProfile.IsAllActive(self: StateProfile, ...: string): boolean
	local states = self._states
	for i = 1, select("#", ...) do
		if not states[(select(i, ...))] then
			return false
		end
	end
	return true
end

function StateProfile.IsNoneActive(self: StateProfile, ...: string): boolean
	local states = self._states
	for i = 1, select("#", ...) do
		if states[(select(i, ...))] then
			return false
		end
	end
	return true
end

function StateProfile.GetRemaining(self: StateProfile, stateKey: string): number?
	local status = self._states[stateKey]
	return if status then _getRemaining(status) else nil
end

function StateProfile.GetActive(self: StateProfile): { string }
	local active = {}
	for key in self._states do
		table.insert(active, key)
	end
	return active
end

function StateProfile.Pause(self: StateProfile, stateKey: string)
	local status = self._states[stateKey]
	if not status or not status.ExpiresAt or status.Paused then
		return
	end

	status.PausedRemaining = status.ExpiresAt - os.clock()
	status.ExpiresAt = nil
	status.Paused = true
end

--- Restores a paused status' frozen remaining time.
function StateProfile.Resume(self: StateProfile, stateKey: string)
	local state = self._states[stateKey]
	if not state or not state.Paused then
		return
	end

	local remaining = state.PausedRemaining or 0
	state.ExpiresAt = os.clock() + remaining
	state.PausedRemaining = nil
	state.Paused = false

	sharedHeap:Push({
		ExpiresAt = state.ExpiresAt :: number,
		Instance = self,
		Key = stateKey,
		StateRef = state,
	})
	sharedHeap:ScheduleNext()
end

function StateProfile.Destroy(self: StateProfile)
	self._states = nil :: any
	self._janitor:Destroy()

	table.clear(self :: any)
	setmetatable(self :: any, nil)
end

return StateProfile
