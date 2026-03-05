--!strict

-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local StateProfile = require(ReplicatedStorage.Services.StateService.StateProfile)
local StateServiceTypes = require(ReplicatedStorage.Services.StateService.StateServiceTypes)

-- || Types || --
type profile = StateProfile.StateProfile

-- || Constants/Variables || --
type Networker = typeof(require(script.Parent.NetworkClient))

-- || Public API || --
local StateServiceClient = {
	_network = (nil :: Networker?) :: Networker,
	_profiles = {} :: { [StateServiceTypes.Object]: profile? },
}

type StateServiceClient = typeof(StateServiceClient)

function StateServiceClient.Init(self: StateServiceClient)
	self._network = require(script.Parent.NetworkClient)

	self._network.AddState.SetCallback(function(value)
		if value.type == "Single" then
			self:Add(value.object, value.stateKey)
		elseif value.type == "Many" then
			self:AddMany(value.object, value.map)
		end
	end)

	self._network.RemoveState.SetCallback(function(value)
		if value.Type == "Single" then
			self:Remove(value.object, value.stateKey)
		elseif value.Type == "Many" then
			self:RemoveMany(value.object, value.keys)
		end
	end)
end

function StateServiceClient.Add(self: StateServiceClient, object: StateServiceTypes.Object, stateKey: string, duration: number?)
	self:_retrieveProfile(object):Add(stateKey, duration)
end

function StateServiceClient.AddMany(self: StateServiceClient, object: StateServiceTypes.Object, map: { [string]: number | boolean })
	self:_retrieveProfile(object):AddMany(map)
end

function StateServiceClient.Remove(self: StateServiceClient, object: StateServiceTypes.Object, stateKey: string)
	self:_retrieveProfile(object):Remove(stateKey)
end

function StateServiceClient.RemoveMany(self: StateServiceClient, object: StateServiceTypes.Object, keys: { string })
	self:_retrieveProfile(object):RemoveMany(keys)
end

function StateServiceClient.IsActive(self: StateServiceClient, object: StateServiceTypes.Object, stateKey: string): boolean
	local profile = self._profiles[object]
	return profile ~= nil and profile:IsActive(stateKey)
end

function StateServiceClient.IsAnyActive(self: StateServiceClient, object: StateServiceTypes.Object, ...: string): boolean
	local profile = self._profiles[object]
	return profile ~= nil and profile:IsAnyActive(...)
end

function StateServiceClient.IsAllActive(self: StateServiceClient, object: StateServiceTypes.Object, ...: string): boolean
	local profile = self._profiles[object]
	return profile ~= nil and profile:IsAllActive(...)
end

function StateServiceClient.NoneActive(self: StateServiceClient, object: StateServiceTypes.Object, ...: string): boolean
	local profile = self._profiles[object]
	return profile ~= nil and profile:IsNoneActive(...)
end

function StateServiceClient.GetRemaining(self: StateServiceClient, object: StateServiceTypes.Object, stateKey: string): number?
	local profile = self._profiles[object]
	return if profile ~= nil then profile:GetRemaining(stateKey) else nil
end

function StateServiceClient.GetActive(self: StateServiceClient, object: StateServiceTypes.Object): { string }
	local profile = self._profiles[object]
	return if profile then profile:GetActive() else {}
end

function StateServiceClient.OnActivated(
	self: StateServiceClient,
	object: StateServiceTypes.Object,
	stateKey: string
): StateServiceTypes.OnActivatedSignal
	return self:_retrieveProfile(object):OnActivated(stateKey)
end

function StateServiceClient.OnDeactivated(
	self: StateServiceClient,
	object: StateServiceTypes.Object,
	stateKey: string
): StateServiceTypes.OnDeactivatedSignal
	return self:_retrieveProfile(object):OnDeactivated(stateKey)
end

function StateServiceClient.Observe(
	self: StateServiceClient,
	object: StateServiceTypes.Object,
	stateKey: string,
	callback: StateServiceTypes.ObserveCallback
): StateServiceTypes.Disconnect
	return self:_retrieveProfile(object):Observe(stateKey, callback)
end

function StateServiceClient.ObserveMany(
	self: StateServiceClient,
	object: StateServiceTypes.Object,
	stateKeys: { string },
	callback: StateServiceTypes.ObserveManyCallback
): StateServiceTypes.Disconnect
	return self:_retrieveProfile(object):ObserveMany(stateKeys, callback)
end

function StateServiceClient._retrieveProfile(self: StateServiceClient, object: StateServiceTypes.Object): profile
	if self._profiles[object] ~= nil then
		return self._profiles[object] :: profile
	end

	local profile = StateProfile.new()
	self._profiles[object] = profile

	profile._janitor:Add(
		object.Destroying:Connect(function()
			profile:Destroy()
			self._profiles[object] = nil
		end),
		"Disconnect",
		"DestroyingConn"
	)

	return profile
end

return StateServiceClient
