--!strict

--[[
    Modules that allows "base properties" for certain sound names found within the SoundRegistry
]]

-- || Dependencies || --
local SoundEffects = require(script.Parent.SoundEffects)

-- || Variables || --
type soundProperties = {
	Group: string?,
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
}

return {
	["Test"] = {},
} :: { [string]: soundProperties }
