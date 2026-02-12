-- || Services || --
local ServerScriptService = game:GetService("ServerScriptService")

-- || Dependencies || --
local DataServiceServer = require(ServerScriptService.Services.DataService.DataServiceServer)
local MarketServiceServer = require(ServerScriptService.Services.MarketService.MarketServiceServer)

-- || Initializer || --
DataServiceServer:Init({})
MarketServiceServer:Init({})
