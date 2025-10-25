--!strict

-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local EmitParticles = require(ReplicatedStorage.Shared.Utils.EmitParticles)

-- || Variables || --
type effectArgs = {
	Position: Vector3,
	Radius: number,
}

-- || Public API || --
local Effect = {}

function Effect.Cast(args: effectArgs)
	print(args.Position, args.Radius)
end

return Effect
