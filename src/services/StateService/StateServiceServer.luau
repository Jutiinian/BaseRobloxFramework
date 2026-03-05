--!strict

-- || Services || --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Observers = require(ReplicatedStorage.Packages.observers)
local Promise = require(ReplicatedStorage.Packages.promise)
local Signal = require(ReplicatedStorage.Packages.signal)

local StateProfile = require(ReplicatedStorage.Services.StateService.StateProfile)
local StateServiceTypes = require(ReplicatedStorage.Services.StateService.StateServiceTypes)

-- || Types || --
type profile = StateProfile.StateProfile
type Networker = typeof(require(script.Parent.NetworkServer))

export type ReplicationTarget = "All" | "Self" | { Player } | nil

-- || Constants/Variables || --
local errorMessages = {
	AlreadyCreated = "[StateServiceServer] Object '%s' is already initialized",
	NotInitialized = "[StateServiceServer] Object '%s' has not yet been initialized",
}

-- || Private Functions || --
local function getPlayerFromObject(object: StateServiceTypes.Object): Player?
	if typeof(object) == "Instance" then
		if object:IsA("Player") then
			return object
		end

		return Players:GetPlayerFromCharacter(object :: any)
	end

	return nil
end

-- || Public API || --
local StateServiceServer = {
	_network = (nil :: Networker?) :: Networker,
	_waitSignals = {} :: { [StateServiceTypes.Object]: Signal.ClassicSignal<> },
	_profiles = {} :: { [StateServiceTypes.Object]: profile? },
}

export type StateServiceServer = typeof(StateServiceServer)

function StateServiceServer.Init(self: StateServiceServer)
	self._network = require(script.Parent.NetworkServer)

	Observers.observePlayer(function(player: Player)
		self:InitializeObject(player)

		return function()
			self:DeinitializeObject(player)
		end
	end)
end

function StateServiceServer.InitializeObject(self: StateServiceServer, object: StateServiceTypes.Object)
	assert(self._profiles[object] == nil, errorMessages.AlreadyCreated:format(tostring(object)))

	local profile = StateProfile.new()
	self._profiles[object] = profile

	if self._waitSignals[object] then
		self._waitSignals[object]:Fire()
	end

	if not object:IsA("Player") then
		profile._janitor:Add(
			object.Destroying:Connect(function()
				self:DeinitializeObject(object)
			end),
			"Disconnect",
			"DestroyingConn"
		)
	end
end

function StateServiceServer.DeinitializeObject(self: StateServiceServer, object: StateServiceTypes.Object)
	local profile = self._profiles[object]
	if not profile then
		return
	end

	profile:Destroy()
	self._profiles[object] = nil
end

function StateServiceServer.Add(
	self: StateServiceServer,
	object: StateServiceTypes.Object,
	stateKey: string,
	duration: number?,
	replication: ReplicationTarget
)
	self:_requireProfile(object):Add(stateKey, duration)
	self:_fireReplication("Add", replication, object, {
		type = "Single",
		stateKey = stateKey,
		duration = duration,
		object = object :: Instance,
	})
end

function StateServiceServer.AddMany(
	self: StateServiceServer,
	object: StateServiceTypes.Object,
	map: { [string]: number | boolean },
	replication: ReplicationTarget
)
	self:_requireProfile(object):AddMany(map)
	self:_fireReplication("Add", replication, object, {
		type = "Many",
		map = map,
		object = object :: Instance,
	})
end

function StateServiceServer.Remove(
	self: StateServiceServer,
	object: StateServiceTypes.Object,
	stateKey: string,
	replication: ReplicationTarget
)
	self:_requireProfile(object):Remove(stateKey)
	self:_fireReplication("Remove", replication, object, {
		type = "Single",
		stateKey = stateKey,
	})
end

function StateServiceServer.RemoveMany(
	self: StateServiceServer,
	object: StateServiceTypes.Object,
	keys: { string },
	replication: ReplicationTarget
)
	self:_requireProfile(object):RemoveMany(keys)
	self:_fireReplication("Remove", replication, object, {
		type = "Many",
		keys = keys,
	})
end

function StateServiceServer.IsActive(self: StateServiceServer, object: StateServiceTypes.Object, stateKey: string): boolean
	local profile = self._profiles[object]
	return profile ~= nil and profile:IsActive(stateKey)
end

function StateServiceServer.IsAnyActive(self: StateServiceServer, object: StateServiceTypes.Object, ...: string): boolean
	local profile = self._profiles[object]
	return profile ~= nil and profile:IsAnyActive(...)
end

function StateServiceServer.IsAllActive(self: StateServiceServer, object: StateServiceTypes.Object, ...: string): boolean
	local profile = self._profiles[object]
	return profile ~= nil and profile:IsAllActive(...)
end

function StateServiceServer.NoneActive(self: StateServiceServer, object: StateServiceTypes.Object, ...: string): boolean
	local profile = self._profiles[object]
	return profile ~= nil and profile:IsNoneActive(...)
end

function StateServiceServer.GetRemaining(self: StateServiceServer, object: StateServiceTypes.Object, stateKey: string): number?
	local profile = self._profiles[object]
	return if profile ~= nil then profile:GetRemaining(stateKey) else nil
end

function StateServiceServer.GetActive(self: StateServiceServer, object: StateServiceTypes.Object): { string }
	local profile = self._profiles[object]
	return if profile then profile:GetActive() else {}
end

function StateServiceServer.OnActivated(
	self: StateServiceServer,
	object: StateServiceTypes.Object,
	stateKey: string
): StateServiceTypes.OnActivatedSignal
	return self:_requireProfile(object):OnActivated(stateKey)
end

function StateServiceServer.OnDeactivated(
	self: StateServiceServer,
	object: StateServiceTypes.Object,
	stateKey: string
): StateServiceTypes.OnDeactivatedSignal
	return self:_requireProfile(object):OnDeactivated(stateKey)
end

function StateServiceServer.Observe(
	self: StateServiceServer,
	object: StateServiceTypes.Object,
	stateKey: string,
	callback: StateServiceTypes.ObserveCallback
): StateServiceTypes.Disconnect
	return self:_requireProfile(object):Observe(stateKey, callback)
end

function StateServiceServer.ObserveMany(
	self: StateServiceServer,
	object: StateServiceTypes.Object,
	stateKeys: { string },
	callback: StateServiceTypes.ObserveManyCallback
): StateServiceTypes.Disconnect
	return self:_requireProfile(object):ObserveMany(stateKeys, callback)
end

function StateServiceServer.AwaitObjectInitialization(self: StateServiceServer, object: StateServiceTypes.Object): Promise.Promise
	local profile = self._profiles[object]
	if profile then
		return Promise.resolve()
	end

	local waitSignal = self._waitSignals[object]
	if not waitSignal then
		waitSignal = Signal.new()
		self._waitSignals[object] = waitSignal
	end

	return Promise.race({
		Promise.fromEvent(waitSignal :: any, function()
			return self._profiles[object] ~= nil
		end),

		Promise.fromEvent(object.Destroying):andThen(function()
			return Promise.reject("Object destroyed before data loaded")
		end),
	}):finally(function()
		waitSignal:Destroy()
		self._waitSignals[object] = nil
	end)
end

function StateServiceServer._requireProfile(self: StateServiceServer, object: StateServiceTypes.Object): profile
	local profile = self._profiles[object]
	assert(profile, errorMessages.NotInitialized:format(tostring(object)))
	return profile
end

function StateServiceServer._fireReplication(
	self: StateServiceServer,
	actionType: "Add" | "Remove",
	replication: ReplicationTarget,
	object: StateServiceTypes.Object,
	payload: any
)
	if not replication then
		return
	end

	local networkEvent: typeof(self._network.AddState) | typeof(self._network.RemoveState) = if actionType == "Add"
		then self._network.AddState
		else self._network.RemoveState

	if replication == "All" then
		(networkEvent :: any).FireAll(payload)
	elseif replication == "Self" then
		local player = getPlayerFromObject(object)
		if player then
			(networkEvent :: any).Fire(player, payload)
		end
	else
		(networkEvent :: any).FireList(replication, payload)
	end
end

return StateServiceServer
