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

-- || Private Helper || --
local function initModules(container, filterPattern: string)
	local promises = {}

	for _, moduleScript in ipairs(container:GetDescendants()) do
		if not moduleScript:IsA("ModuleScript") or not string.match(moduleScript.Name, filterPattern) then
			continue
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

-- || Public API || --
local FrameworkClient = {}

function FrameworkClient.Start(): Promise.Promise
	if started then
		return Promise.reject("(Client) Framework Already Started!")
	end

	started = true

	return initModules(Services, "Service"):andThen(function()
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
