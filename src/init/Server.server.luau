-- || Services || --
local ServerScriptService = game:GetService("ServerScriptService")

-- || Variables || --
local servicesFolder = ServerScriptService.Services

-- || Initializer || --
for _, service in ipairs(servicesFolder:GetDescendants()) do
	if not service:IsA("ModuleScript") or not string.match(service.Name, "ServiceServer") then
		continue
	end

	local module = require(service)
	module:Init()
end
