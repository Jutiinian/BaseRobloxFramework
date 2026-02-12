-- Credits to isoopod
-- https://github.com/isoopod/React-Emitter

local Emitter = require(script.core.Emitter)

--[=[
	@class ReactEmitter
]=]

return {
	useEmitter = require(script.hooks.useEmitter),
	useEmitters = require(script.hooks.useEmitters),
	ParticleRenderer = require(script.components.ParticleRenderer),
	NormalId2D = Emitter.NormalId2D,
	ParticleEmitterShape2D = Emitter.ParticleEmitterShape2D,
	ParticleEmitterShapeStyle2D = Emitter.ParticleEmitterShapeStyle2D,
}