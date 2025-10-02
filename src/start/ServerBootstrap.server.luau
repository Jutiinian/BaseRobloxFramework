-- || Services || --
local ServerScriptService = game:GetService("ServerScriptService")

-- || Initializer || --
require(ServerScriptService.FrameworkServer)
	.Start()
	:andThen(function()
		print("(Server) Framework Started!")
	end)
	:catch(warn)
