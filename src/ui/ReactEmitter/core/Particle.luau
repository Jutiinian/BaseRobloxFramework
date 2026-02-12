--!optimize 2
--!native

-- Modules
local EmitterType = require(script.Parent.EmitterType)

local RANDOM = Random.new()

local normalToDir = {
	-Vector2.yAxis,
	Vector2.xAxis,
	Vector2.yAxis,
	-Vector2.xAxis,
}

local function unitDirection(fromPos: Vector2, toPos: Vector2): Vector2
	local delta = toPos - fromPos
	local mag = delta.Magnitude
	if mag == 0 then return Vector2.zero end
	return delta / mag
end

-- 2x2 rotation transform
local function rotateDirection(dir: Vector2, angleDeg: number): Vector2
	local rad = math.rad(angleDeg)

	local c = math.cos(rad)
	local s = math.sin(rad)

	local x = dir.X * c - dir.Y * s
	local y = dir.X * s + dir.Y * c

	return Vector2.new(x, y)
end

local function getColorAtTime(seq: ColorSequence, t: number): Color3
	local keypoints = seq.Keypoints
	if #keypoints == 0 then
		return Color3.new(1, 1, 1) -- fallback
	end

	t = math.clamp(t, 0, 1)

	-- If t is before the first key or after the last, return edge colour
	if t <= keypoints[1].Time then
		return keypoints[1].Value
	elseif t >= keypoints[#keypoints].Time then
		return keypoints[#keypoints].Value
	end

	-- Find the segment t is in
	for i = 1, #keypoints - 1 do
		local k0, k1 = keypoints[i], keypoints[i + 1]
		if t >= k0.Time and t <= k1.Time then
			local min = k0.Time
			local segmentT = (t - min) / (k1.Time - min)
			return k0.Value:Lerp(k1.Value, segmentT)
		end
	end

	-- Should never reach here
	return keypoints[#keypoints].Value
end

local function colorMul(color: Color3, scalar: number): Color3
	local v = vector.create(color.R, color.G, color.B) * scalar
	return Color3.new(v.x, v.y, v.z)
end

local function getValueAtTime(seq: NumberSequence, t: number): number
	local keypoints = seq.Keypoints
	if #keypoints == 0 then
		return 1 -- fallback
	end

	t = math.clamp(t, 0, 1)

	-- If t is before the first key or after the last, return edge colour
	if t <= keypoints[1].Time then
		return keypoints[1].Value
	elseif t >= keypoints[#keypoints].Time then
		return keypoints[#keypoints].Value
	end

	-- Find the segment t is in
	for i = 1, #keypoints - 1 do
		local k0, k1 = keypoints[i], keypoints[i + 1]
		if t >= k0.Time and t <= k1.Time then
			local min = k0.Time
			local segmentT = (t - min) / (k1.Time - min)
			return math.lerp(k0.Value, k1.Value, segmentT)
		end
	end

	-- Should never reach here
	return keypoints[#keypoints].Value
end

local Particle = {}

local _seed = 0
local function nextSeed(): number
	_seed += 1
	return _seed
end

-- Emit a particle
function Particle.new(emitter: EmitterType._Emitter): EmitterType.Particle
	-- If emitter is updated, a new reference is made and existing particles use the old emitter
	-- Determine Position and Direction from Shape settings
	local direction, position
	local dimensions = emitter.ShapeDimensions

	local function computeDirFromInOut(baseDir: Vector2)
		local dir = baseDir
		if (emitter.ShapeInOut == Enum.ParticleEmitterShapeInOut.Inward) or (emitter.ShapeInOut == Enum.ParticleEmitterShapeInOut.InAndOut and RANDOM:NextNumber() >= 0.5) then
			dir = -baseDir
		end

		local spread = math.abs(emitter.SpreadAngle)
		if spread ~= 0 then dir = rotateDirection(dir, RANDOM:NextNumber(-spread, spread)) end

		return dir
	end

	if emitter.Shape == 1 then
		-- Rectangle
		if emitter.ShapeStyle == 1 then
			-- Area
			position = Vector2.new(RANDOM:NextNumber(0, dimensions.X), RANDOM:NextNumber(0, dimensions.Y))
		else
			-- Perimeter
			local edge = emitter.EmissionDirection
			local t = RANDOM:NextNumber()

			if edge == 1 then
				position = Vector2.new(t * dimensions.X, 0)
			elseif edge == 2 then
				position = Vector2.new(dimensions.X, t * dimensions.Y)
			elseif edge == 3 then
				position = Vector2.new(t * dimensions.X, dimensions.Y)
			else
				position = Vector2.new(0, t * dimensions.Y)
			end
		end

		direction = computeDirFromInOut(normalToDir[emitter.EmissionDirection])
	else
		-- Annulus
		local half = dimensions * 0.5
		local outerX, outerY = half.X, half.Y

		local partial = math.clamp(emitter.ShapePartial, 0, 1)
		if emitter.ShapeStyle == 2 then partial = 0 end
		local innerFactor = 1 - partial -- 0..1 where 0 means inner radius is 0 and 1 means inner == outer

		-- Sample angle uniformly
		local theta = RANDOM:NextNumber(0, math.pi * 2)

		-- Sample radial factor for uniform area between innerFactor and 1
		-- For circle r = sqrt(u*(R^2 - r0^2) + r0^2) -> factor s = sqrt(u*(1 - innerFactor^2) + innerFactor^2)
		local u = RANDOM:NextNumber()
		local innerFactorSq = innerFactor * innerFactor
		local s = math.sqrt(u * (1 - innerFactorSq) + innerFactorSq)

		-- Position in local shape coords (center mapepd to half)
		position = Vector2.new(math.cos(theta) * s * outerX, math.sin(theta) * s * outerY) + half

		local offsetFromCenter = position - half
		local center = emitter._center
		local worldPos = center + offsetFromCenter
		local dir = unitDirection(center, worldPos)

		-- Fallback if the particle falls dead center
		if dir == Vector2.zero then
			local theta2 = RANDOM:NextNumber(0, math.pi * 2)
			dir = Vector2.new(math.cos(theta2), math.sin(theta2))
		end

		direction = computeDirFromInOut(dir)
	end

	-- Determine frame, or leave unset
	local frame
	if emitter.FlipbookLayout ~= Enum.ParticleFlipbookLayout.None then frame = emitter.FlipbookStartRandom and RANDOM:NextInteger(0, emitter._frames) or 0 end

	-- Size normalisation factor (Longest side)
	local sizeScale = math.max(dimensions.X, dimensions.Y) * 0.1

	local speed = RANDOM:NextNumber(emitter.Speed.Min, emitter.Speed.Max) * sizeScale

	return {
		Emitter = emitter,

		Direction = direction,
		FlipbookFrame = frame :: number,
		FlipbookFrameAlpha = emitter.FlipbookMode == Enum.ParticleFlipbookMode.Random and 0 or nil :: any,
		FlipbookFramerate = RANDOM:NextInteger(emitter.FlipbookFramerate.Min, emitter.FlipbookFramerate.Max),
		FlipbookFrameTarget = emitter.FlipbookMode == Enum.ParticleFlipbookMode.Random and frame or nil :: any,
		Speed = speed,
		Lifetime = RANDOM:NextNumber(emitter.Lifetime.Min, emitter.Lifetime.Max),
		Position = position,
		Rotation = RANDOM:NextNumber(emitter.Rotation.Min, emitter.Rotation.Max) % 360,
		RotSpeed = RANDOM:NextNumber(emitter.RotSpeed.Min, emitter.RotSpeed.Max),

		Color = colorMul(getColorAtTime(emitter.Color, 0), emitter.Brightness),
		Size = getValueAtTime(emitter.Size, 0),
		Squash = getValueAtTime(emitter.Squash, 0),
		Transparency = getValueAtTime(emitter.Transparency, 0),

		Age = 0,
		_id = nextSeed(),
	}
end

function Particle.Update(particle: EmitterType.Particle, dt: number): boolean
	local emitter = particle.Emitter

	local dtAdjusted = dt * emitter.TimeScale
	local t = particle.Age + dtAdjusted
	if t >= particle.Lifetime then return false end
	particle.Age = t

	-- Integrate acceleration
	local vx = particle.Direction.X * particle.Speed + emitter.Acceleration.X * dtAdjusted
	local vy = particle.Direction.Y * particle.Speed + emitter.Acceleration.Y * dtAdjusted

	-- Apply exponential drag (Drag = time in seconds to halve velocity)
	local drag = emitter.Drag
	if math.abs(drag) > 0 then
		local decay = 0.5 ^ (dtAdjusted / drag)
		vx *= decay
		vy *= decay
	end

	-- Integrate position (semi-implicit Euler)
	particle.Position += Vector2.new(vx * dtAdjusted, vy * dtAdjusted)

	-- Recompute speed and direction
	local newSpeed = math.sqrt(vx * vx + vy * vy)
	if newSpeed > 0 then
		local newSpeedI = 1 / newSpeed
		particle.Direction = Vector2.new(vx * newSpeedI, vy * newSpeedI)
		particle.Speed = newSpeed
	else
		particle.Speed = newSpeed
	end

	-- Integrate rotation
	local rotspeed = particle.RotSpeed
	if rotspeed ~= 0 then particle.Rotation = (particle.Rotation + particle.RotSpeed * dtAdjusted) % 360 end

	-- Flipbook
	local frame = particle.FlipbookFrame
	if frame then
		local frames = emitter._frames
		local mode = emitter.FlipbookMode

		if mode == Enum.ParticleFlipbookMode.Loop then
			frame = (t * particle.FlipbookFramerate) % frames
		elseif mode == Enum.ParticleFlipbookMode.OneShot then
			local a = t / particle.Lifetime

			if a >= 1 then
				frame = frames - 1
			else
				frame = a * (frames - 1)
			end
		elseif mode == Enum.ParticleFlipbookMode.PingPong then
			local a = t / particle.Lifetime

			if a <= 0.5 then
				local k = a * 2
				frame = k * (frames - 1)
			else
				local k = (a - 0.5) * 2
				frame = (frames - 1) * (1 - k)
			end
		else
			local a = particle.FlipbookFrameAlpha + particle.FlipbookFramerate * dtAdjusted

			if a >= 1 then
				a = 0
				frame = particle.FlipbookFrameTarget
				particle.FlipbookFrameTarget = RANDOM:NextInteger(0, frames - 1)
			end

			particle.FlipbookFrameAlpha = a
		end

		particle.FlipbookFrame = frame // 1
	end

	-- Read properties on sequences
	local tNorm = t / particle.Lifetime
	particle.Color = colorMul(getColorAtTime(emitter.Color, tNorm), emitter.Brightness)
	particle.Size = getValueAtTime(emitter.Size, tNorm)
	particle.Squash = getValueAtTime(emitter.Squash, tNorm)
	particle.Transparency = getValueAtTime(emitter.Transparency, tNorm)

	return true
end

return Particle