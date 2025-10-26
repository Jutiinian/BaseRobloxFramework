-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local GetPlayersInRange = require(ReplicatedStorage.Shared.Utils.GetPlayersInRange)

-- || Public API || --
type EffectsServiceNetwork = typeof(require(ServerScriptService.ServerNetwork.EffectsService))

local EffectsServiceServer = {
	_network = nil :: EffectsServiceNetwork?,
}

export type EffectsServiceServer = typeof(EffectsServiceServer)

function EffectsServiceServer.Init(self: EffectsServiceServer): ()
	self._network = require(ServerScriptService.ServerNetwork.EffectsService)
end
