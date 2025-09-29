-- || Services || --
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --

-- || Variables || --
local Services = ServerScriptService.Services

-- || Initializer || --
for _, Service in ipairs(Services:GetDescendants()) do
	if not Service:IsA("ModuleScript") or not string.match(Service.Name, "ServiceServer") then
		continue
	end

	local Module = require(Service)
	Module:init()
end
