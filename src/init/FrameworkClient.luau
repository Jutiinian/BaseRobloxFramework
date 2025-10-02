-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- || Variables || --
local Services = ReplicatedStorage.Shared.Services

local started = false
local startCompleted = false

local onCompleted = Signal.new()

-- || Public API || --
local FrameworkClient = {}

function FrameworkClient.Start(): Promise.Promise
	if started then
		return Promise.reject("(Client) Framework Already Started!")
	end

	started = true

	return Promise.new(function(resolve)
		local initPromises = {}

		for _, service in ipairs(Services:GetDescendants()) do
			if not service:IsA("ModuleScript") or not string.match(service.Name, "Service") then
				continue
			end

			table.insert(
				initPromises,
				Promise.try(function()
					local module = require(service)
					debug.setmemorycategory(service.Name)
					return module:Init()
				end)
			)
		end

		resolve(Promise.all(initPromises))
	end):andThen(function()
		startCompleted = true
		onCompleted:FireDeferred()
	end)
end

function FrameworkClient.OnStart(): Promise.Promise
	if startCompleted then
		return Promise.resolve()
	else
		return Promise.new(function(resolve)
			onCompleted:Once(resolve)
		end)
	end
end

return FrameworkClient
