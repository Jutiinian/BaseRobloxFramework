-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- || Dependencies || --
local BaseProperties = require(script.Parent.BaseProperties)
local SoundGroups = require(script.Parent.SoundGroups)
local applySoundEffects = require(script.Parent.SoundEffects)

local SoundRegistry = require(ReplicatedStorage.Shared.Modules.Registries.SoundRegistry)

local CreateTween = require(ReplicatedStorage.Shared.Utils.CreateTween)
local ObjectPool = require(ReplicatedStorage.Shared.Classes.ObjectPool)

local SoundServiceNetwork = require(ReplicatedStorage.Shared.ClientNetwork.SoundService)

-- || Variables || --
local partTemplate = Instance.new("Part")
do
	partTemplate.Name = "Part"
	partTemplate.Size = Vector3.zero
	partTemplate.Transparency = 1
	partTemplate.CanCollide = false
	partTemplate.CanQuery = false
	partTemplate.CanTouch = false
	partTemplate.Anchored = true

	--[[local attachment = Instance.new("Attachment")
	attachment.Name = "SoundHolder"
	attachment.Parent = partTemplate]]
end

type soundProperties = {
	Group: string?,
	Parent: Instance?,
	Volume: number?,
	PlaybackSpeed: number?,
	PlaybackRegion: Vector2?,
	RollOff: Vector2?,
	Effects: {
		Chorus: applySoundEffects.Chorus?,
		Compressor: applySoundEffects.Compressor?,
		Distortion: applySoundEffects.Distortion?,
		Echo: applySoundEffects.Echo?,
		Equalizer: applySoundEffects.Equalizer?,
		Flange: applySoundEffects.Flange?,
		PitchShift: applySoundEffects.PitchShift?,
		Reverb: applySoundEffects.Reverb?,
		Tremolo: applySoundEffects.Tremolo?,
	}?,
	DenyBaseProperties: boolean?,
}

-- || Public API || --
local SoundServiceClient = {
	_container = nil :: Folder?,
	_soundPool = nil :: ObjectPool.ObjectPool<Sound>?,
	_partPool = nil :: ObjectPool.ObjectPool<typeof(partTemplate)>?,
	_soundGroups = {} :: { [string]: SoundGroup },
	_currentMusic = nil :: Sound?,
}

export type SoundServiceClient = typeof(SoundServiceClient)

--[[
	Start the SoundService on the client
	- Listens for events from the server
	- Initializes the object pools (sounds and parts)
	- Creates all the sound groups
]]
function SoundServiceClient.Init(self: SoundServiceClient)
	local groupsTable = {}
	for groupName, groupVolume in pairs(SoundGroups) do
		if SoundService:FindFirstChild(groupName) then
			continue
		end

		local soundGroup = Instance.new("SoundGroup")
		soundGroup.Name = groupName
		soundGroup.Volume = groupVolume
		soundGroup.Parent = SoundService

		groupsTable[groupName] = soundGroup
	end

	local container = Instance.new("Folder")
	container.Name = "SoundContainer"
	container.Parent = SoundService

	local soundPool = ObjectPool.new(function()
		local sound = Instance.new("Sound")
		sound.Name = "PooledSound"
		sound.Looped = false
		sound.PlayOnRemove = false
		sound.Volume = 0
		sound.Parent = container

		return sound
	end, 25)

	local partPool = ObjectPool.new(function()
		return partTemplate:Clone()
	end, 25)

	partPool.OnObjectReturned:Connect(function(part: BasePart)
		part.Parent = nil
	end)

	soundPool.OnObjectReturned:Connect(function(sound: Sound)
		self:_ResetSound(sound, container)
	end)

	self._container = container
	self._soundPool = soundPool
	self._partPool = partPool
	self._soundGroups = groupsTable

	SoundServiceNetwork.ReplicateSound.SetCallback(function(data)
		if data.Position ~= nil then
			self:PlaySoundAt(data.SoundName, data.Position, data.Properties)
		else
			self:PlaySound(data.SoundName, data.Properties)
		end
	end)
end

--[[
	Plays a one-shot sound
	- Sound automatically returns to the pool once finished
]]
function SoundServiceClient.PlaySound(self: SoundServiceClient, soundName: string, props: soundProperties?): ()
	local soundAsset = self:_GetSound(soundName, props)
	soundAsset.Parent = props and props.Parent or workspace.CurrentCamera
	soundAsset:Play()

	soundAsset.Ended:Once(function()
		self._soundPool:Return(soundAsset)
	end)
end

--[[
	Plays a 3D sound at a world position / CFrame
	- Automatically cleans up and returns pooled instances when done
]]
function SoundServiceClient.PlaySoundAt(self: SoundServiceClient, soundName: string, pos: Vector3 | CFrame, props: soundProperties?): ()
	local soundAsset = self:_GetSound(soundName, props)
	local partAsset = self._partPool:Get()

	if typeof(pos) == "CFrame" then
		partAsset.CFrame = pos
	else
		partAsset.Position = pos
	end

	soundAsset.Parent = partAsset
	partAsset.Parent = props and props.Parent or workspace

	soundAsset:Play()

	soundAsset.Ended:Once(function()
		self._soundPool:Return(soundAsset)
		self._partPool:Return(partAsset)
	end)
end

--[[
	Plays a sound and loops it
	- Returns a function used to stop and clean up the looped sound
]]
function SoundServiceClient.PlayLoopedSound(self: SoundServiceClient, soundName: string, props: soundProperties?): ()
	local soundAsset = self:_GetSound(soundName, props)
	soundAsset.Looped = true
	soundAsset.Parent = props and props.Parent or workspace.CurrentCamera

	soundAsset:Play()

	return function()
		soundAsset:Stop()
		soundAsset.Looped = false
		self._soundPool:Return(soundAsset)
	end
end

--[[
	Plays background music
	- Fades currently playing into new music
]]
function SoundServiceClient.PlayMusic(self: SoundServiceClient, songName: string, props: soundProperties?, fadeTime: number?): ()
	local fade = fadeTime or 0.2
	if self._currentMusic ~= nil then
		local music = self._currentMusic

		local fadeTween = self:_FadeVolume(music, 0, fade)
		fadeTween.Completed:Once(function()
			self._soundPool:Return(music)
		end)
	end

	local newMusic = self:_GetSound(songName, props)
	newMusic.Looped = true
	newMusic.Volume = 0
	newMusic.Parent = SoundService

	if newMusic.SoundGroup == nil and self._soundGroups["Music"] ~= nil then
		newMusic.SoundGroup = self._soundGroups["Music"]
	end

	self._currentMusic = newMusic

	newMusic:Play()
	self:_FadeVolume(newMusic, props and props.Volume or 0.5, fade)
end

--[[
	Updates a sound group's master volume
	- Volume automaitcally clamped
]]
function SoundServiceClient.SetGroupVolume(self: SoundServiceClient, groupName: string, volume: number): ()
	local group = self._soundGroups[groupName]
	if group then
		group.Volume = math.clamp(volume, 0, 1)
	end
end

-- Internal / Private Functions
function SoundServiceClient:_FadeVolume(sound: Sound, targetVolume: number, duration: number): Tween?
	if duration <= 0 then
		sound.Volume = 0
		return
	end

	local tween = CreateTween(sound, TweenInfo.new(duration), { Volume = math.clamp(targetVolume, 0, 1) })

	tween:Play()

	return tween
end

function SoundServiceClient:_ResetSound(sound: Sound, parent: Instance?): ()
	if sound.IsPlaying then
		sound:Stop()
	end

	sound.Volume = 0
	sound.SoundId = ""

	sound.SoundGroup = nil

	sound.PlaybackRegionsEnabled = false

	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 10000

	sound.PlaybackSpeed = 1

	sound.Parent = parent or nil
end

function SoundServiceClient._GetSound(self: SoundServiceClient, soundName: string, props: soundProperties?): Sound
	local soundId = SoundRegistry[soundName]
	assert(soundId, (`%s is not a valid soundName`):format(soundName))

	local soundAsset = self._soundPool:Get()

	local baseProps = (not props or props.DenyBaseProperties ~= true) and BaseProperties[soundName] or nil

	local volume = (props and props.Volume) or (baseProps and baseProps.Volume) or 0.5
	local groupName = (props and props.Group) or (baseProps and baseProps.Group)
	local playbackSpeed = (props and props.PlaybackSpeed) or (baseProps and baseProps.PlaybackSpeed) or 1
	local playbackRegion = (props and props.PlaybackRegion) or (baseProps and baseProps.PlaybackRegion)
	local rollOff = (props and props.RollOff) or (baseProps and baseProps.RollOff)
	local effects = (props and props.Effects) or (baseProps and baseProps.Effects)

	soundAsset.Volume = volume
	soundAsset.SoundGroup = groupName and self._soundGroups[groupName] or nil
	soundAsset.PlaybackSpeed = playbackSpeed

	if playbackRegion then
		soundAsset.PlaybackRegionsEnabled = true
		soundAsset.PlaybackRegion = NumberRange.new(playbackRegion.X, playbackRegion.Y)
	else
		soundAsset.PlaybackRegionsEnabled = false
	end

	if rollOff then
		soundAsset.RollOffMinDistance = rollOff.X
		soundAsset.RollOffMaxDistance = rollOff.Y
	end

	if effects then
		applySoundEffects(soundAsset, effects)
	end

	if soundAsset.SoundGroup == nil then
		warn((`%s has not been assigned to a SoundGroup (not suggested)`):format(soundName))
	end

	soundAsset.SoundId = soundId
	return soundAsset
end

return SoundServiceClient
