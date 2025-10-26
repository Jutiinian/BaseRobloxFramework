--[[
    Module that holds all the type definitions for Sound Effects and holds/returns applySoundEffects function
]]

export type Chorus = {
	Depth: number?,
	Mix: number?,
	Priority: number?,
	Rate: number?,
}

export type Compressor = {
	Attack: number?,
	GainMakeup: number?,
	Priority: number?,
	Ratio: number?,
	Release: number?,
	Threshold: number?,
}

export type Distortion = {
	Level: number?,
	Priority: number?,
}

export type Echo = {
	Delay: number?,
	DryLevel: number?,
	Feedback: number?,
	Priority: number?,
	WetLevel: number?,
}

export type Equalizer = {
	HighGain: number?,
	LowGain: number?,
	MidGain: number?,
	Priority: number?,
}

export type Flange = {
	Depth: number?,
	Mix: number?,
	Priority: number?,
	Rate: number?,
}

export type PitchShift = {
	Octave: number?,
	Priority: number?,
}

export type Reverb = {
	DecayTime: number?,
	Density: number?,
	Diffusion: number?,
	DryLevel: number?,
	Priority: number?,
	WetLevel: number?,
}

export type Tremolo = {
	Depth: number?,
	Duty: number?,
	Frequency: number?,
	Priority: number?,
}

--[[
	Applies sound properties effects list to sound
]]
local function applySoundEffects(
	sound: Sound,
	effects: {
		Chorus: Chorus?,
		Compressor: Compressor?,
		Distortion: Distortion?,
		Echo: Echo?,
		Equalizer: Equalizer?,
		Flange: Flange?,
		PitchShift: PitchShift?,
		Reverb: Reverb?,
		Tremolo: Tremolo?,
	}?
)
	if not effects then
		return
	end

	for name, props in pairs(effects) do
		local success, effect = pcall(Instance.new, `{name}SoundEffect`)
		if not success or not effect then
			warn(`Failed to create sound effect {name}`)
			continue
		end

		for property, value in pairs(props) do
			effect[property] = value
		end

		effect.Parent = sound
	end
end

return applySoundEffects
