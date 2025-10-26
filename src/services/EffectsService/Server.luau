-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local GetPlayersInRange = require(ReplicatedStorage.Shared.Utils.GetPlayersInRange)

-- || Public API || --
type EffectsServiceNetwork = typeof(require(ServerScriptService.ServerNetwork.EffectsService))

local EffectsServiceServer = {
	_network = nil :: EffectsServiceNetwork?,
}

export type EffectsServiceServer = typeof(EffectsServiceServer)

function EffectsServiceServer.Init(self: EffectsServiceServer): ()
	self._network = require(ServerScriptService.ServerNetwork.EffectsService)
end

--[[
	Cast an effect on specified target(s)
	- Uses Unreliable replication (fast, real-time, okay to drop)
	- Great for short-lived VFX (slashes, spark hits, particles)
	- Accepts a single Player or a list of Players
]]
function EffectsServiceServer.CastEffect(self: EffectsServiceServer, target: Player | { Player }, effectName: string, effectArgs: { [string]: any }): ()
	self:_FireEvent("Unreliable", target, effectName, effectArgs)
end

--[[
	Cast an effect for all players within a radius of a position
	- Automatically filters nearby players
	- Good for explosions, impact effects, aura bursts, etc.
	- Unreliable by default (transient visuals)
]]
function EffectsServiceServer.CastEffectInRange(
	self: EffectsServiceServer,
	position: Vector3 | CFrame,
	radius: number,
	effectName: string,
	effectArgs: { [string]: any }
): ()
	local players = GetPlayersInRange(position, radius)

	if #players > 0 then
		self:_FireEvent("Unreliable", players, effectName, effectArgs)
	end
end

--[[
	Cast an effect for EVERY player in the game
	- Unreliable replication (best for transient global visuals)
	- Perfect for boss roars, atmospheric FX, shockwaves, etc.
]]
function EffectsServiceServer.CastEffectForAll(self: EffectsServiceServer, effectName: string, effectArgs: { [string]: any }): ()
	self._network.ReplicateEffectUnreliable.FireAll({
		Effect = effectName,
		Arguments = {
			Effect = effectName,
			value = effectArgs,
		},
	})
end

--[[
	Cast an effect on target(s) using Reliable replication
	- Guaranteed delivery at the cost of possible delay
	- Use for important visual feedback (quest rewards, confirms)
	- Most effects should use Unreliable
]]
function EffectsServiceServer.CastEffectReliable(self: EffectsServiceServer, target: Player | { Player }, effectName: string, effectArgs: { [string]: any }): ()
	self:_FireEvent("Reliable", target, effectName, effectArgs)
end

--[[
	Cast a reliable effect for players within range
	- Ensures players don't miss critical world effects
	- Useful for important environmental events
	- Most effects should use Unreliable
]]
function EffectsServiceServer.CastEffectInRangeReliable(
	self: EffectsServiceServer,
	position: Vector3 | CFrame,
	radius: number,
	effectName: string,
	effectArgs: { [string]: any }
): ()
	local players = GetPlayersInRange(position, radius)

	if #players > 0 then
		self:_FireEvent("Reliable", players, effectName, effectArgs)
	end
end

--[[
	Reliable version of CastEffectForAll
	- Guarantees delivery to every player
	- Use for critical visual moments (quest finishers, cutscene FX)
	- Most effects should use Unreliable
]]
function EffectsServiceServer.CastEffectForAllReliable(self: EffectsServiceServer, effectName: string, effectArgs: { [string]: any }): ()
	self._network.ReplicateEffectReliable.FireAll({
		Effect = effectName,
		Arguments = {
			Effect = effectName,
			value = effectArgs,
		},
	})
end

-- || Private Functions || --
function EffectsServiceServer._FireEvent(
	self: EffectsServiceServer,
	eventType: "Reliable" | "Unreliable",
	target: Player | { Player },
	effectName: string,
	effectArgs: { [string]: any }
): ()
	local event = eventType == "Reliable" and self._network.ReplicateEffectReliable or self._network.ReplicateEffectUnreliable

	if typeof(target) == "Player" then
		event.Fire(target, {
			Effect = effectName,
			Arguments = {
				Effect = effectName,
				value = effectArgs,
			},
		})
	elseif typeof(target) == "table" then
		event.FireList(target, {
			Effect = effectName,
			Arguments = {
				Effect = effectName,
				value = effectArgs,
			},
		})
	else
		warn("Target must be a Player or a list of Players")
	end
end

return EffectsServiceServer
