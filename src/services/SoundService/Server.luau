-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local SoundEffects = require(ReplicatedStorage.Shared.Services.SoundService.SoundEffects)
local SoundRegistry = require(ReplicatedStorage.Shared.Modules.Registries.SoundRegistry)

local GetPlayersInRange = require(ReplicatedStorage.Shared.Utils.GetPlayersInRange)

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
	- Loads SoundService network on server
]]
function SoundServiceServer.Init(self: SoundServiceServer): ()
	self._network = require(ServerScriptService.ServerNetwork.SoundService)
end

--[[
	Plays a sound on the specified target(s)
	- If a single Player is given, sound is sent only to them
	- If a list of Players is given, sound is broadcast to that list
	- Should be used when the sound does not require positional audio
]]
function SoundServiceServer:PlaySound(target: Player | { Player }, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	if typeof(target) == "Player" then
		self._network.ReplicateSound.Fire(target, { SoundName = soundName, Properties = props })
	elseif typeof(target) == "table" then
		self._network.ReplicateSound.FireList(target, { SoundName = soundName, Properties = props })
	else
		warn("Target must be a Player or a list of Players")
	end
end

--[[
	Plays a sound for all players within a distance from the given position
	- Good for world events like explosions, interactables, etc.
	- Handles detecting nearby players automatically
]]
function SoundServiceServer.PlaySoundInRange(self: SoundServiceServer, position: Vector3 | CFrame, radius: number, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	local players = GetPlayersInRange(position, radius)
	self:PlaySound(players, soundName, props)
end

--[[
	Play a sound for EVERY player in the game
	- No position required (UI notifications, music stings, etc.)
]]
function SoundServiceServer:PlaySoundForAll(soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	self._network.ReplicateSound.FireAll({ SoundName = soundName, Properties = props })
end

--[[
	Plays a sound at a world position, but only for the specified target(s)
	- Good for personal-world sound replication like hit markers or interactions
	- Position-based playback only affects how clients hear it
]]
function SoundServiceServer:PlaySoundAt(target: Player | { Player }, position: Vector3 | CFrame, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	if typeof(target) == "Player" then
		self._network.ReplicateSound.Fire(target, { Position = position, SoundName = soundName, Properties = props })
	elseif typeof(target) == "table" then
		self._network.ReplicateSound.FireList(target, { Position = position, SoundName = soundName, Properties = props })
	else
		warn("Target must be a Player or a list of Players")
	end
end

--[[
	Plays a sound at a world position for all players within range
	- Combines distance-based filtering with positional audio
	- Best for realistic 3D world sound effects
]]
function SoundServiceServer.PlaySoundAtInRange(self: SoundServiceServer, position: Vector3 | CFrame, radius: number, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	local players = GetPlayersInRange(position, radius)
	self:PlaySoundAt(players, position, soundName, props)
end

--[[
	Play a 3D sound at a position for EVERY player
	- Useful for loud global events (boss landing, thunder strike, etc.)
]]
function SoundServiceServer:PlaySoundAtForAll(position: Vector3 | CFrame, soundName: string, props: soundProperties?): ()
	assert(SoundRegistry[soundName], (`%s is not a valid soundName`):format(soundName))

	self._network.ReplicateSound.FireAll({ Position = position, SoundName = soundName, Properties = props })
end

return SoundServiceServer
