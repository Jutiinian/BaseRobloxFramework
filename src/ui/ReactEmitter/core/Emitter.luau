
--!optimize 2

-- Services
local RunService = game:GetService("RunService")
-- Modules
local EmitterType = require(script.Parent.EmitterType)
local Runtime

local Emitter = {}

local isEdit = not RunService:IsRunning()

local ACTOR_COUNT = 4

local completedExisting = script.Parent:FindFirstChild("Completed")
if completedExisting then completedExisting:Destroy() end

local _completed = Instance.new("BindableEvent")
_completed.Name = "Completed"
_completed.Archivable = false
_completed.Parent = script.Parent
local completed = _completed.Event

if isEdit then
	Runtime = require(script.Parent.Runtime)
	Runtime.init(1)
	ACTOR_COUNT = 1
end

local actorIndex = 1
local actors = { script.Parent.actor1 }

for i = 2, ACTOR_COUNT do
	local name = `actor{i}`
	local actor = script.Parent:FindFirstChild(name) or actors[1]:Clone()
	actor.Name = name
	actor.Archivable = false
	actor.Parent = script.Parent
	actors[i] = actor
end

for i, v in actors do
	v:SendMessage("init", i)
end

local seed = 0
local function nextSeed(): number
	seed += 1
	return seed
end

local emitters = {} :: { [number]: EmitterType._Emitter } -- Emitter seed -> emitter
Emitter.Particles = {} :: { [number]: { EmitterType.Particle } } -- Emitter seed -> particles

local IncludedProperties = {
	Acceleration = true,
	Brightness = true,
	Color = true,
	Drag = true,
	EmissionDirection = true,
	FlipbookLayout = true,
	FlipbookStartRandom = true,
	FlipbookMode = true,
	FlipbookFramerate = true,
	Lifetime = true,
	Rotation = true,
	RotSpeed = true,
	Shape = true,
	ShapeStyle = true,
	ShapeDimensions = true,
	ShapeInOut = true,
	ShapePartial = true,
	Size = true,
	Speed = true,
	SpreadAngle = true,
	Squash = true,
	Transparency = true,
	TimeScale = true,
	_seed = true,
	_center = true,
	_frames = true,
}

function Emitter.new(init: EmitterType._Emitter | any)
	local emitter: EmitterType._Emitter = {
		Acceleration = init.Acceleration or Vector2.zero,
		Brightness = init.Brightness or 1,
		Color = init.Color or ColorSequence.new(Color3.new(1, 1, 1)),
		Drag = init.Drag or 0,
		EmissionDirection = init.EmissionDirection or Emitter.NormalId2D.Top,
		Enabled = if init.Enabled ~= nil then init.Enabled else true,
		FlipbookFramerate = init.FlipbookFramerate or NumberRange.new(1),
		FlipbookImageSize = init.FlipbookImageSize or Vector2.new(1024, 1024),
		FlipbookLayout = init.FlipbookLayout or Enum.ParticleFlipbookLayout.None,
		FlipbookMode = init.FlipbookMode or Enum.ParticleFlipbookMode.Loop,
		FlipbookSizeX = init.FlipbookSizeX or 1,
		FlipbookSizeY = init.FlipbookSizeY or 1,
		FlipbookStartRandom = init.FlipbookStartRandom or false,
		Lifetime = init.Lifetime or NumberRange.new(5, 10),
		Rate = init.Rate or 20,
		Rotation = init.Rotation or NumberRange.new(0),
		RotSpeed = init.RotSpeed or NumberRange.new(0),
		Shape = init.Shape or 1,
		ShapeDimensions = init.ShapeDimensions or Vector2.one,
		ShapeInOut = init.ShapeInOut or Enum.ParticleEmitterShapeInOut.Outward,
		ShapePartial = init.ShapePartial or 1,
		ShapeStyle = init.ShapeStyle or 1,
		Size = init.Size or NumberSequence.new(1),
		Speed = init.Speed or NumberRange.new(5),
		SpreadAngle = init.SpreadAngle or 0,
		Squash = init.Squash or NumberSequence.new(0),
		Texture = init.Texture or Content.fromUri("rbxasset://textures/particles/sparkles_main.dds"),
		TimeScale = init.TimeScale or 1,
		Transparency = init.Transparency or NumberSequence.new(0),

		_seed = nextSeed(),
		_emitAcc = 0,
		_center = (init.ShapeDimensions or Vector2.one) * 0.5,
		_frames = (function(): number?
			if init.FlipbookLayout == Enum.ParticleFlipbookLayout.Grid2x2 then return 4 end
			if init.FlipbookLayout == Enum.ParticleFlipbookLayout.Grid4x4 then return 16 end
			if init.FlipbookLayout == Enum.ParticleFlipbookLayout.Grid8x8 then return 64 end
			if init.FlipbookLayout == Enum.ParticleFlipbookLayout.Custom then return (init.FlipbookSizeX or 1) * (init.FlipbookSizeY or 1) end
			return
		end)() :: any,
	} :: any

	local filtered = {}
	for property, value in emitter :: any do
		if IncludedProperties[property] then filtered[property] = value end
	end

	if Runtime then
		Runtime.register(filtered)
	else
		for _, v in actors do
			v:SendMessage("register", filtered)
		end
	end

	emitters[emitter._seed] = emitter

	return emitter
end

local function emit(emitter: EmitterType._Emitter)
	if Runtime then
		Runtime.emit(emitter._seed)
		return
	end

	actors[actorIndex]:SendMessage("emit", emitter._seed)

	actorIndex += 1
	if actorIndex > ACTOR_COUNT then actorIndex = 1 end
end
Emitter.Emit = emit

function Emitter.Set(emitter: EmitterType._Emitter, property: string, value: any)
	emitter[property] = value
	if IncludedProperties[property] then
		if Runtime then
			Runtime.setProperty(emitter._seed, property, value)
			return
		end

		for _, v in actors do
			v:SendMessage("setProperty", emitter._seed, property, value)
		end
	end
end

function Emitter.Destroy(emitter: EmitterType._Emitter)
	if Runtime then
		Runtime.unregister(emitter._seed)
	else
		for _, v in actors do
			v:SendMessage("unregister", emitter._seed)
		end
	end
	Emitter.Particles[emitter._seed] = nil
	emitters[emitter._seed] = nil
end

-- Enums
--[=[
	@type NormalId2D "Top" | "Right" | "Bottom" | "Left"
	@within ReactEmitter

	Used for Emission Direction on the Rectangle shape. 
	Functions like the regular NormalId, but without the Z-axis (Front, Back)
]=]
Emitter.NormalId2D = {
	Top = 1,
	Right = 2,
	Bottom = 3,
	Left = 4,
}

--[=[
	@type ParticleEmitterShape2D "Rectangle" | "Annulus"
	@within ReactEmitter

	Controls the shape of the emitter, where Rectangle is the 2D equivalent of Box and Annulus is the 2D equivalent of Disc.  
	Annulus also functions like a 2D version of Cylinder or Sphere when ShapePartial is set to 1.
]=]
Emitter.ParticleEmitterShape2D = {
	-- Deviation: 2D Equivalent of Box
	Rectangle = 1,
	-- Deviation: 2D Equivalent of Disc
	-- Also covers Cylinder/Sphere when ShapePartial is 1
	Annulus = 2,
}

--[=[
	@type ParticleEmitterShapeStyle2D "Area" | "Perimeter"
	@within ReactEmitter

	Controls where particles will be emitted within the emitter's shape.  
	Area is the 2D equivalent of Volume, and Perimeter is the 2D equivalent of Surface.

	For an Annulus shape, a ShapePartial of 0 is equivalent to the perimeter.
]=]
Emitter.ParticleEmitterShapeStyle2D = {
	-- Deviation: 2D Equivalent of Volume
	Area = 1,
	-- Deviation: 2D Equivalent of Surface
	Perimeter = 2,
}

local _frame = 0
local function nextFrame()
	_frame += 1
	return _frame
end

local frameQueue: { [number]: { assembled: { [number]: { EmitterType.Particle } }, completedCount: number } } = {}

local function step(dt: number)
	local frame = nextFrame()
	frameQueue[frame] = {
		assembled = {},
		completedCount = 0,
	}

	for _, emitter in emitters do
		frameQueue[frame].assembled[emitter._seed] = {}
	end

	-- Emit particles
	for _, emitter in emitters do
		if emitter.Enabled then
			local accumulated = emitter._emitAcc + emitter.Rate * dt * emitter.TimeScale
			local emitCount = accumulated // 1
			emitter._emitAcc = accumulated - emitCount

			for _ = 1, emitCount do
				emit(emitter)
			end
		end
	end

	if Runtime then
		Runtime.dispatch(dt, frame)
		return
	end

	for _, v in actors do
		v:SendMessage("dispatch", dt, frame)
	end
end

local latestFrame = 0
completed:Connect(function(allParticles, f)
	local frameData = frameQueue[f]

	-- ignore unknown or old frames
	if not frameData then return end
	if f < latestFrame then
		frameQueue[f] = nil
		return
	end

	local assembled = frameData.assembled
	for s, particleList in allParticles do
		local emitter = emitters[s]
		if emitter then
			local target = assembled[emitter._seed]
			if not target then
				target = {}
				assembled[emitter._seed] = target
			end
			for _, p in particleList do
				table.insert(target, p)
			end
		end
	end

	frameData.completedCount += 1
	if frameData.completedCount >= ACTOR_COUNT then
		Emitter.Particles = frameData.assembled
		latestFrame = f
		frameQueue[f] = nil -- remove completed frame
	end
end)

-- Avoid multiple bindings in case of tools like UI_Labs
RunService:UnbindFromRenderStep("ReactEmitterCore")
RunService:BindToRenderStep("ReactEmitterCore", Enum.RenderPriority.Last.Value - 1, function(dt)
	if isEdit then
		local success, err = pcall(step :: any, dt)
		if not success then
			RunService:UnbindFromRenderStep("ReactEmitterCore")
			error(err)
		end
	else
		step(dt)
	end
end)

return Emitter
