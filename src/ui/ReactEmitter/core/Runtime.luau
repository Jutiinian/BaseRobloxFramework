--!optimize 2
--!native

local EmitterType = require(script.Parent.EmitterType)
local Particle = require(script.Parent.Particle)

local runtime = {}

local actor = script:GetActor()

local evt: BindableEvent = script.Parent:WaitForChild("Completed")
local complete = evt.Fire

local emitters: { [number]: EmitterType._Emitter } = {}
local particles: { [number]: { EmitterType.Particle } } = {}

local actorIndex: number
function runtime.init(index: number)
	actorIndex = index
end

function runtime.register(emitter: EmitterType._Emitter)
	emitters[emitter._seed] = emitter
	particles[emitter._seed] = {}
end

function runtime.unregister(seed: number)
	particles[seed] = nil
	emitters[seed] = nil
end

function runtime.setProperty(seed: number, property: string, value: any)
	local emitter = emitters[seed]
	if emitter then
		-- We need to keep the old emitter for the existing particles
		local new = table.clone(emitter)
		new[property] = value
		emitters[seed] = new :: EmitterType._Emitter
	end
end

function runtime.emit(seed: number)
	local emitter = emitters[seed]
	if emitter then
		local particle = Particle.new(emitter)
		if actor then task.synchronize() end
		table.insert(particles[seed], particle)
	end
end

function runtime.dispatch(dt: number, frame: number)
	for seed in emitters do
		local emitterParticles = particles[seed]

		local count = #emitterParticles

		-- Reverse iteration with fast removal
		for i = count, 1, -1 do
			local particle = emitterParticles[i]
			local alive = Particle.Update(particle, dt)

			if not alive then
				-- Fast removal: swap last into current and shrink
				local lastIndex = #emitterParticles
				emitterParticles[i] = emitterParticles[lastIndex]
				emitterParticles[lastIndex] = nil
			end
		end
	end

	-- Copy out all required information
	local out = {}
	for seed, emitterParticles in particles do
		local outSeed = {}
		out[seed] = outSeed
		for i, p in emitterParticles do
			outSeed[i] = {
				Direction = p.Direction,
				FlipbookFrame = p.FlipbookFrame,
				FlipbookFrameAlpha = p.FlipbookFrameAlpha,
				FlipbookFrameTarget = p.FlipbookFrameTarget,
				Lifetime = p.Lifetime,
				Position = p.Position,
				Rotation = p.Rotation,
				Color = p.Color,
				Size = p.Size,
				Squash = p.Squash,
				Transparency = p.Transparency,
				_id = actorIndex * 536870912 + p._id, -- Shift left 29 bits
				-- TECHNICAL LIMITATION: This gives us ~31 days of runtime per emitter at a rate of 200. Should be enough
			}
		end
	end

	complete(evt, out, frame)
end

return runtime