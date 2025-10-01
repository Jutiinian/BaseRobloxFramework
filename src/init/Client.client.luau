-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Wait for Stuff to Load || --
ReplicatedStorage:WaitForChild("Shared")

local servicesFolder = ReplicatedStorage.Shared:WaitForChild("Services")

-- || Initializer || --
for _, service in ipairs(servicesFolder:GetDescendants()) do
	if not service:IsA("ModuleScript") or not string.match(service.Name, "ServiceClient") then
		continue
	end

	local module = require(service)
	module:Init()
end
