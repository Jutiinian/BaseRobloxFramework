-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Signal = require(ReplicatedStorage.Packages.Signal)
local Promise = require(ReplicatedStorage.Packages.Promise)

-- || Variables || --
local started = false
local startedCompleted = false

local onCompleted = Signal.new()

-- || Public API || --
local FrameworkClient = {}

function FrameworkClient.Start(): Promise.Promise
	if started then
		return Promise.reject("(Client) Framework Already Started!")
	end

	started = true

	return Promise.new(function(resolve, reject)
		onCompleted:FireDeferred()
	end)
end

function FrameworkClient.OnStart(): Promise.Promise
	if startedCompleted then
		return Promise.resolve()
	else
		return Promise.new(function(resolve)
			onCompleted:Once(resolve)
		end)
	end
end

return FrameworkClient
