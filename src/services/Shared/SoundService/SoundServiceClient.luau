-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-- || Dependencies || --
local SoundRegistry = require(ReplicatedStorage.Shared.Assets.SoundRegistry)

-- || Variables || --
type soundProperties = {}

-- || Public API || --
local SoundServiceClient = {}

export type SoundServiceClient = typeof(SoundServiceClient)

function SoundServiceClient.Init(self: SoundServiceClient) end

function SoundServiceClient.PlaySound(self: SoundServiceClient, soundName: string, soundProperties) end

function SoundServiceClient.PlaySoundAtPosition(self: SoundServiceClient, soundName: string, soundProperties) end

return SoundServiceClient
