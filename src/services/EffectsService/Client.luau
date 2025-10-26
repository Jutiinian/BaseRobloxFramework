-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --

-- || Variables || --
local EffectsFolder = script.Parent.Effects

-- || Public API || --
type EffectsServiceNetwork = typeof(require(ReplicatedStorage.Shared.ClientNetwork.EffectsService))

local EffectsServiceClient = {
	_network = nil :: EffectsServiceNetwork?,
	_effectModules = {} :: { [string]: any },
}

export type EffectServiceClient = typeof(EffectsServiceClient)

--[[
	Start the EffectService on the client
	- Loads all effect module scripts from Effects folder
	- Loads the EffectService network on the client
	- Registers network callbacks for both reliable and unreliable replication events
]]
function EffectsServiceClient.Init(self: EffectServiceClient): ()
	for _, v in ipairs(EffectsFolder:GetChildren()) do
		if v:IsA("ModuleScript") then
			self._effectModules[v.Name] = require(v)
		end
	end

	self._network = require(ReplicatedStorage.Shared.ClientNetwork.EffectsService)

	local function Callback(data)
		self:CastEffect(data.Effect, data.Arguments.value)
	end

	self._network.ReplicateEffectReliable.SetCallback(Callback)
	self._network.ReplicateEffectUnreliable.SetCallback(Callback)
end

--[[
	Casts (executes) a visual effect by name.
	- Calls the module's Cast() function, passing in replicated arguments
	- Effect modules are responsible for handling their own visuals and cleanup
]]
function EffectsServiceClient.CastEffect(self: EffectServiceClient, effectName: string, args: any): ()
	local effectModule = self._effectModules[effectName]
	assert(effectModule, (`%s is not a valid effectName`):format(effectName))

	if effectModule.Cast and typeof(effectModule.Cast) == "function" then
		effectModule.Cast(args)
	end
end

return EffectsServiceClient
