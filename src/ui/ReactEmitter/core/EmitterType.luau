--[=[
	@class Emitter
	An Emitter created through useEmitter or useEmitters. Can be used in multiple ParticleRenderers.
]=]
export type Emitter = {
	Acceleration: Vector2, -- Deviation: Vector2 instead of Vector3
	Brightness: number, -- Deviation: ImageLabels are clamped to 255, 255, 255 and will not get brighter, it is recommended to avoid this.
	Color: ColorSequence,
	Drag: number,
	EmissionDirection: number, -- Deviation: NormalId2D
	Enabled: boolean,
	FlipbookFramerate: NumberRange,
	FlipbookImageSize: Vector2, -- Deviation: Need to provide the resolution of the entire image, dft 1024,1024
	-- Deviation: Not handling FlipbookIncompatible error string
	FlipbookLayout: Enum.ParticleFlipbookLayout,
	FlipbookMode: Enum.ParticleFlipbookMode,
	FlipbookSizeX: number,
	FlipbookSizeY: number,
	FlipbookStartRandom: boolean,
	Lifetime: NumberRange,
	-- Deviation: LightEmission is not applicable, particle will behave as if both emission and influence are 0
	-- Deviation: LightInfluence is not applicable
	-- Deviation: LocalTransparencyModifier is handled on ParticleRenderer
	-- Deviation: Will always be "LockedToPart" (the ParticleRenderer component)
	-- Deviation: Orientation is not applicable in 2D
	Rate: number,
	Rotation: NumberRange,
	RotSpeed: NumberRange,
	Shape: number, -- Deviation: ParticleEmitterShape2D
	ShapeDimensions: Vector2, -- Deviation: For Shape support, dimensions need to be specified to the emitter
	ShapeInOut: Enum.ParticleEmitterShapeInOut,
	ShapePartial: number,
	ShapeStyle: number, -- Deviation: ParticleEmitterShapeStyle2D
	Size: NumberSequence,
	Speed: NumberRange,
	SpreadAngle: number, -- Deviation: Single number instead of Vector2
	Squash: NumberSequence,
	Texture: Content, -- Deviation: Dropped support for strings
	TimeScale: number,
	Transparency: NumberSequence,
	-- Deviation: VelocityInheritance not supported
	-- Deviation: WindAffectsDrag not applicable
	-- Deviation: ZOffset is handled by the ParticleRenderer component
}

export type _Emitter = Emitter & {
	-- INTERNAL
	_seed: number,
	_emitAcc: number,
	_center: Vector2,
	-- Only exist when flipbook layout is not None
	_frames: number,
	_frameCache: { Vector2 },
	_frameSize: Vector2,
}

--[=[
	@interface EmitterProps
	@within ReactEmitter
	.Acceleration Vector2 -- [0, 0] Acceleration along the X and Y axes.
	.Brightness number -- [1] How bright this particle appears. Note that since ImageLabels do not get brighter at RGB values above 255, this has limited use.
	.Color ColorSequence -- [255, 255, 255] The Color of each particle over its lifetime. Use `ColorSequence.new(Color3.new(r, g, b))` for a solid color.
	.Drag number -- [0] Determines the rate in seconds particles lose half their speed through exponential decay. Setting to negative will cause particles' velocity to grow exponentially.
	.EmissionDirection NormalId2D -- [Top] Face of the emitter to emit from when Shape is Rectangle.
	.Enabled boolean -- [true] Will emit particles at `Rate` * `TimeScale` per second when enabled. Particles can be manually emitted on a disbled emitter with the imperative API.
	.FlipbookFramerate NumberRange -- [1] Determines how fast the flipbook texture animates in frames per second. Applies to FlipbookModes Loop and Random.
	.FlipbookImageSize Vector2 -- [1024, 1024] The dimensions of the actual image.
	.FlipbookLayout ParticleFlipbookLayout -- [None] Determines the layout of the flipbook texture.
	.FlipbookMode ParticleFlipbookMode -- [Loop] Determines the type of the flipbook animation.
	.FlipbookSizeX number -- [1] The number of cells in the flipbook texture when using FlipbookMode Custom.
	.FlipbookSizeY number -- [1] the number of rows in the flipbook texture when using FlipbookMode Custom.
	.FlipbookStartRandom boolean -- [false] Determines whether to start at a random frame chosen per particle instead of starting at frame zero. Can be used with Framerate zero for a random texture.
	.Lifetime NumberRange -- [5, 10] Defines a random range of ages for newly emitted particles. Particles will despawn after their age passes their lifetime.
	.Rate number -- [20] How many particles to emit per second (at TimeScale 1) when the Emitter is enabled. Goes to 200, but be careful because UI particles are a lot more expensive than ParticleEmitters.
	.Rotation NumberRange -- [0] Defines a random range of rotations in degrees for the particle to start at.
	.RotSpeed NumberRange -- [0] Determines the range of angular speeds of emitted particles, measured in degrees per second.
	.Shape ParticleEmitterShape2D -- [Rectangle] 2D Shape of the emitter, either Rectangle (like Box) or Annulus (like Cylinder, Disc, or Sphere).
	.ShapeDimensions Vector2 -- [1, 1] Absolute size of the emitter. A React State can be helpful for this.
	.ShapeInOut Enum.ParticleEmitterShapeInOut -- [Outward] Selects whether particles emit outward only, inward only, or in both dimensions.
	.ShapePartial number -- [1] For Annulus shapes, a multiplier between [0, 1] for the inner radius relative to the outer radius, where 1 is a full circle and 0 is the perimeter.
	.ShapeStyle ParticleEmitterShapeStyle2D -- [Area] If particles should spawn in the whole area of the shape or just on the perimeter of the shape.
	.Size NumberSequence -- [1] Determines the relative size over individual particles' lifetimes. Use `NumberSequence.new(n)` for a single size. Size is relative to the ParticleRenderer (relative to the larger of the two dimensions).
	.Speed NumberRange -- [5] A range of speeds for the particle to start at. Can be set negative to have the particle go backwards.
	.SpreadAngle number -- [0] A number determining the degrees either side of the emission direction to randomly offset the starting direction of particles by.
	.Squash NumberSequence -- [0] Allows for non-uniform scaling of particles over their lifetimes. >0 elongates it vertically, and <0 elongates it horizontally.
	.Texture Content -- [sparkles] The texture of each particle, given as a Content (e.g. `Content.fromAssetId(xxxx)` or `Content.fromUri("rbxassetid://xxxx")`).
	.TimeScale number -- [1] Multiplier to how fast particles are simulated. Allows for values outside the range [0, 1]. Applies to rate as well.
	.Transparency NumberRange -- [0] Determines the transparency of individual particles over their lifetimes. Use `NumberSequence.new(n)` for a single transparency. 
	These are the props used by useEmitter / useEmitters to create an Emitter. Every field is optional and has a default if not given.
]=]
export type EmitterPublic = {
	Acceleration: Vector2?,
	Brightness: number?,
	Color: ColorSequence?,
	Drag: number?,
	EmissionDirection: number?,
	Enabled: boolean?,
	FlipbookFramerate: NumberRange?,
	FlipbookImageSize: Vector2?,
	FlipbookLayout: Enum.ParticleFlipbookLayout?,
	FlipbookMode: Enum.ParticleFlipbookMode?,
	FlipbookSizeX: number?,
	FlipbookSizeY: number?,
	FlipbookStartRandom: boolean?,
	Lifetime: NumberRange?,
	Rate: number?,
	Rotation: NumberRange?,
	RotSpeed: NumberRange?,
	Shape: number?,
	ShapeDimensions: Vector2?,
	ShapeInOut: Enum.ParticleEmitterShapeInOut?,
	ShapePartial: number?,
	ShapeStyle: number?,
	Size: NumberSequence?,
	Speed: NumberRange?,
	SpreadAngle: number?,
	Squash: NumberSequence?,
	Texture: Content?,
	TimeScale: number?,
	Transparency: NumberSequence?,
}

export type Particle = {
	Emitter: _Emitter, -- Internal and only exists for runtime use

	-- Derived from emitter properties
	Direction: Vector2, -- Only for runtime
	FlipbookFrame: number, -- Only present if flipbook enabled
	FlipbookFrameAlpha: number, -- 0..1 Only in Random Mode
	FlipbookFramerate: number, -- Only for runtime
	FlipbookFrameTarget: number, -- Only in Random mode
	Speed: number, -- Only for runtime
	Lifetime: number,
	Position: Vector2, -- Only for runtime
	Rotation: number,
	RotSpeed: number, -- Only for runtime

	Color: Color3,
	Size: number,
	Squash: number,
	Transparency: number,

	Age: number, -- Only for runtime

	_id: number,
}

return nil