-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local GetPlayersInRange = require(ReplicatedStorage.Shared.Utils.GetPlayersInRange)
local SoundEffects = require(ReplicatedStorage.Shared.Services.SoundService.SoundEffects)
local SoundRegistry = require(ReplicatedStorage.Shared.Modules.Registries.SoundRegistry)

-- || Variables || --
type soundProperties = {
	Group: string?,
	Parent: Instance?,
	Volume: number?,
	PlaybackSpeed: number?,
	PlaybackRegion: Vector2?,
	RollOff: Vector2?,
	Effects: {
		Chorus: SoundEffects.Chorus?,
		Compressor: SoundEffects.Compressor?,
		Distortion: SoundEffects.Distortion?,
		Echo: SoundEffects.Echo?,
		Equalizer: SoundEffects.Equalizer?,
		Flange: SoundEffects.Flange?,
		PitchShift: SoundEffects.PitchShift?,
		Reverb: SoundEffects.Reverb?,
		Tremolo: SoundEffects.Tremolo?,
	}?,
	DenyBaseProperties: boolean?,
}

-- || Public API || --
type SoundServiceNetwork = typeof(require(ServerScriptService.ServerNetwork.SoundService))

local SoundServiceServer = {
	_network = nil :: SoundServiceNetwork?,
}

export type SoundServiceServer = typeof(SoundServiceServer)

--[[
	Start SoundService on the server
	- Loads the sound network endpoints
]]
function SoundServiceServer.Init(self: SoundServiceServer): ()
	self._network = require(ServerScriptService.ServerNetwork.SoundService)
end

--[[
	Plays a sound on the specified target(s)
	- Most gameplay sounds should use this (unreliable)
	- Slight packet loss is usually fine
]]
function SoundServiceServer.PlaySound(self: SoundServiceServer, target: Player | { Player }, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))
	self:_FireEvent("Unreliable", target, { SoundName = soundName, Properties = props })
end

--[[
	Plays a sound for all players in a radius around the given position
	- Good for footsteps, explosions, ambient interactions
	- Unreliable by default (transient)
]]
function SoundServiceServer.PlaySoundInRange(self: SoundServiceServer, position: Vector3 | CFrame, radius: number, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	local players = GetPlayersInRange(position, radius)
	if #players > 0 then
		self:PlaySound(players, soundName, props)
	end
end

--[[
	Play a sound for EVERY player (unreliable)
	- Great for global alerts, ambience, UI stings
]]
function SoundServiceServer.PlaySoundForAll(self: SoundServiceServer, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))
	self._network.ReplicateSoundUnreliable.FireAll({ SoundName = soundName, Properties = props })
end

--[[
	Plays a 3D positional sound for the specified target(s)
	- Clients will hear the sound spatially relative to position
	- UNRELIABLE by default
]]
function SoundServiceServer.PlaySoundAt(self: SoundServiceServer, target: Player | { Player }, position: Vector3 | CFrame, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))
	self:_FireEvent("Unreliable", target, { Position = position, SoundName = soundName, Properties = props })
end

--[[
	Plays a 3D sound at a position for all players in a given radius
	- Combines distance-based filtering with spatial audio
]]
function SoundServiceServer.PlaySoundAtInRange(self: SoundServiceServer, position: Vector3 | CFrame, radius: number, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	local players = GetPlayersInRange(position, radius)
	if #players > 0 then
		self:PlaySoundAt(players, position, soundName, props)
	end
end

--[[
	Play a positional sound for EVERY player in the game
	- Useful for global cinematic audio moments
]]
function SoundServiceServer.PlaySoundAtForAll(self: SoundServiceServer, position: Vector3 | CFrame, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))
	self._network.ReplicateSoundUnreliable.FireAll({ Position = position, SoundName = soundName, Properties = props })
end

--[[
	Plays a sound using a reliable event
	- Guaranteed delivery (at the cost of possible delay)
	- Use for confirmation sounds, rewards, error messages, etc.
	- Most sounds should use Unreliable
]]
function SoundServiceServer.PlaySoundReliable(self: SoundServiceServer, target: Player | { Player }, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))
	self:_FireEvent("Reliable", target, { SoundName = soundName, Properties = props })
end

--[[
	Reliable version of PlaySoundInRange
	- Use when the positional event is important to hear
	- Most sounds should use Unreliable
]]
function SoundServiceServer.PlaySoundInRangeReliable(self: SoundServiceServer, position: Vector3 | CFrame, radius: number, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	local players = GetPlayersInRange(position, radius)
	if #players > 0 then
		self:PlaySoundReliable(players, soundName, props)
	end
end

--[[
	Reliable version of PlaySoundForAll
	- Ensures all players hear it (reward chimes, announcements)
	- Most sounds should use Unreliable
]]
function SoundServiceServer.PlaySoundForAllReliable(self: SoundServiceServer, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))
	self._network.ReplicateSoundReliable.FireAll({ SoundName = soundName, Properties = props })
end

--[[
	Reliable version of PlaySoundAt
	- Recommended for impactful or rare positional events
	- Most sounds should use Unreliable
]]
function SoundServiceServer.PlaySoundAtReliable(
	self: SoundServiceServer,
	target: Player | { Player },
	position: Vector3 | CFrame,
	soundName: string,
	props: soundProperties?
): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))
	self:_FireEvent("Reliable", target, { Position = position, SoundName = soundName, Properties = props })
end

--[[
	Reliable version of PlaySoundAtInRange
	- Ensures positional world events are heard by everyone present
	- Most sounds should use Unreliable
]]
function SoundServiceServer.PlaySoundAtInRangeReliable(
	self: SoundServiceServer,
	position: Vector3 | CFrame,
	radius: number,
	soundName: string,
	props: soundProperties?
): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	local players = GetPlayersInRange(position, radius)
	if #players > 0 then
		self:PlaySoundAtReliable(players, position, soundName, props)
	end
end

--[[
	Reliable version of PlaySoundAtForAll
	- Guarantees delivery of major audio events
	- Most sounds should use Unreliable
]]
function SoundServiceServer.PlaySoundAtForAllReliable(self: SoundServiceServer, position: Vector3 | CFrame, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))
	self._network.ReplicateSoundReliable.FireAll({ Position = position, SoundName = soundName, Properties = props })
end

-- || Private Helpers || --
function SoundServiceServer._FireEvent(self: SoundServiceServer, eventType: "Reliable" | "Unreliable", target: Player | { Player }, args: any): ()
	local event = eventType == "Reliable" and self._network.ReplicateSoundReliable or self._network.ReplicateSoundUnreliable

	if typeof(target) == "Player" then
		event.Fire(target, args)
	elseif typeof(target) == "table" then
		event.FireList(target, args)
	else
		warn("Target must be a Player or a list of Players")
	end
end

return SoundServiceServer
