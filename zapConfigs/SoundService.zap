opt server_output = "../src/network/Server/SoundService.luau"
opt client_output = "../src/network/Client/SoundService.luau"

opt remote_scope = "SoundService"
opt casing = "PascalCase"

opt yield_type = "promise"
opt async_lib = "require(game:GetService('ReplicatedStorage').Packages.Promise)"

type Chorus = struct {
    Depth: f32(0..1)?,
    Mix: f32(0..1)?,
    Priority: u8?,
    Rate: f32(0..20)?
}

type Compressor = struct {
	Attack: f32(0..1)?,
	GainMakeup: f32(0..20)?,
	Priority: u8?,
	Ratio: f32(..20)?,
	Release: f32(0..5)?,
	Threshold: f32(-80..0)?
}

type Distortion = struct {
	Level: f32(..1)?,
	Priority: u8?
}

type Echo = struct {
	Delay: f32(0..5)?,
	DryLevel: f32(0..1)?,
	Feedback: f32(0..1)?,
	Priority: u8?,
	WetLevel: f32(0..1)?
}

type Equalizer = struct {
	HighGain: f32(-80..10)?,
	LowGain: f32(-80..10)?,
	MidGain: f32(-80..10)?,
	Priority: u8?
}

type Flange = struct {
	Depth: f32(0..1)?,
	Mix: f32(0..1)?,
	Priority: u8?,
	Rate: f32(0..20)?
}

type PitchShift = struct {
	Octave: f32(-1..1)?,
	Priority: u8?
}

type Reverb = struct {
	DecayTime: f32(0..20)?,
	Density: f32(0..1)?,
	Diffusion: f32(0..1)?,
	DryLevel: f32(-80..0)?,
	Priority: u8?,
	WetLevel: f32(-80..0)?
}

type Tremolo = struct {
	Depth: f32(0..1)?,
	Duty: f32(0..1)?,
	Frequency: f32(0..20)?,
	Priority: u8?
}

type soundProperties = struct {
    Group: string.utf8(..20)?,
	Parent: Instance?,
	Volume: f32(0..1)?,
	PlaybackSpeed: f32(0..15)?,
	PlaybackRegion: vector(f32, f32)?,
	RollOff: vector(f32, f32)?,
	Effects: struct {
		Chorus: Chorus?,
		Compressor: Compressor?,
		Distortion: Distortion?,
		Echo: Echo?,
		Equalizer: Equalizer?,
		Flange: Flange?,
		PitchShift: PitchShift?,
		Reverb: Reverb?,
		Tremolo: Tremolo?,
	}?,
	DenyBaseProperties: boolean?,
}

type position = (
    vector(f32, f32, f32)
    | CFrame
)

event ReplicateSoundUnreliable = {
    from: Server,
    type: Unreliable,
    call: SingleAsync,
    data: struct {
        SoundName: string.utf8(..20),
        Position: position?,
        Properties: soundProperties?,
    }
}

event ReplicateSoundReliable = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct {
        SoundName: string.utf8(..20),
        Position: position?,
        Properties: soundProperties?,
    } 
}