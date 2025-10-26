--!strict

-- || Services ||
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- || Dependencies ||
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- || Variables ||
local isServer = RunService:IsServer()
local ServicesFolder = if isServer then game:GetService("ServerScriptService").Services else ReplicatedStorage.Shared.Services
local SharedServicesFolder = ReplicatedStorage.Shared.Services

local started = false
local startCompleted = false
local onCompleted = Signal.new()

-- || Private Helper ||
local function initModules(container: Instance, filterPattern: string)
	local promises = {}

	for _, moduleScript in ipairs(container:GetDescendants()) do
		if not moduleScript:IsA("ModuleScript") then
			continue
		end

		-- server excludes ServiceClient modules
		if isServer then
			if not string.match(moduleScript.Name, filterPattern) or string.match(moduleScript.Name, "ServiceClient") then
				continue
			end
		else
			-- client: must match filterPattern
			if not string.match(moduleScript.Name, filterPattern) then
				continue
			end
		end

		table.insert(
			promises,
			Promise.new(function(resolve)
				local success, module = pcall(require, moduleScript)
				if not success then
					warn(("Failed to require %s: %s"):format(moduleScript:GetFullName(), module))
					resolve()
					return
				end

				if debug and debug.setmemorycategory then
					debug.setmemorycategory(moduleScript.Name)
				end

				if type(module.Init) == "function" then
					module:Init()
				end

				resolve()
			end):catch(warn)
		)
	end

	return Promise.all(promises)
end

-- || Public API ||
local Framework = {}

function Framework.Start(): Promise.Promise
	if started then
		return Promise.reject(`({isServer and "Server" or "Client"}) Framework Already Started!`)
	end

	started = true

	if isServer then
		return initModules(ServicesFolder, "ServiceServer")
			:andThen(function()
				return initModules(SharedServicesFolder, "Service")
			end)
			:andThen(function()
				startCompleted = true
				onCompleted:FireDeferred()
			end)
	else
		return initModules(ServicesFolder, "Service"):andThen(function()
			startCompleted = true
			onCompleted:FireDeferred()
		end)
	end
end

function Framework.OnStart(): Promise.Promise
	if startCompleted then
		return Promise.resolve()
	else
		return Promise.new(function(resolve)
			onCompleted:Once(resolve)
		end)
	end
end

return Framework
