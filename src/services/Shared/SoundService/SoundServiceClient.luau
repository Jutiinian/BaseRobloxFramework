-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- || Dependencies || --
local SoundGroups = require(script.Parent.SoundGroups)
local applySoundEffects = require(script.Parent.SoundEffects)

local SoundRegistry = require(ReplicatedStorage.Shared.Assets.SoundRegistry)

local ObjectPool = require(ReplicatedStorage.Shared.Classes.ObjectPool)

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

	local attachment = Instance.new("Attachment")
	attachment.Name = "SoundHolder"
	attachment.Parent = partTemplate
end

type soundProperties = {
	Group: string,
	Parent: Instance?,
	Volume: number?,
	StartAt: number?,
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
}

-- || Public API || --
local SoundServiceClient = {
	_container = nil :: Folder?,
	_soundPool = nil :: ObjectPool.ObjectPool<Sound>?,
	_partPool = nil :: ObjectPool.ObjectPool<typeof(partTemplate)>?,
}

export type SoundServiceClient = typeof(SoundServiceClient)

function SoundServiceClient.Init(self: SoundServiceClient)
	for groupName, groupVolume in pairs(SoundGroups) do
		if SoundService:FindFirstChild(groupName) then
			continue
		end

		local soundGroup = Instance.new("SoundGroup")
		soundGroup.Name = groupName
		soundGroup.Volume = groupVolume
		soundGroup.Parent = SoundService
	end

	local container = Instance.new("Folder")
	container.Name = "SoundContainer"
	container.Parent = SoundService

	local soundPool = ObjectPool.new(function()
		local sound = Instance.new("Sound")
		sound.Name = "PooledSound"
		sound.PlayOnRemove = false
		sound.Volume = 0
		sound.Parent = container

		return sound
	end, 25)

	local partPool = ObjectPool.new(function()
		return partTemplate:Clone()
	end, 25)

	soundPool.OnObjectReturned:Connect(function(sound: Sound)
		sound.Volume = 0
		sound.SoundId = ""
		sound.SoundGroup = nil
	end)

	self._container = container
	self._soundPool = soundPool
	self._partPool = partPool
end

function SoundServiceClient.PlaySound(self: SoundServiceClient, soundName: string, props: soundProperties?) end

function SoundServiceClient.PlaySoundAtPosition(self: SoundServiceClient, soundName: string, props: soundProperties?) end

return SoundServiceClient
