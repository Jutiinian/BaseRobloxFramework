-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- || Variables || --
local Services = ServerScriptService.Services
local SharedServices = ReplicatedStorage.Shared.Services

local started = false
local startCompleted = false

local onCompleted = Signal.new()

-- || Public API || --
local FrameworkServer = {}

function FrameworkServer.Start(): Promise.Promise
	if started then
		return Promise.reject("(Server) Framework Already Started!")
	end

	started = true

	return Promise.new(function(resolve)
		local initPromises = {}

		for _, service in ipairs(Services:GetDescendants()) do
			if not service:IsA("ModuleScript") or not string.match(service.Name, "ServiceServer") then
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
	end)
		:andThen(function()
			local sharedInitPromises = {}

			for _, service in ipairs(SharedServices:GetDescendants()) do
				if not service:IsA("ModuleScript") or not string.match(service.Name, "Service") or string.match(service.Name, "ServiceClient") then
					continue
				end

				table.insert(
					sharedInitPromises,
					Promise.try(function()
						local module = require(service)
						debug.setmemorycategory(service.Name)
						return module:Init()
					end)
				)
			end

			return Promise.all(sharedInitPromises)
		end)
		:andThen(function()
			startCompleted = true
			onCompleted:FireDeferred()
		end)
end

function FrameworkServer.OnStart(): Promise.Promise
	if startCompleted then
		return Promise.resolve()
	else
		return Promise.new(function(resolve)
			onCompleted:Once(resolve)
		end)
	end
end

return FrameworkServer
