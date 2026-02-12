-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local DataServiceClient = require(ReplicatedStorage.Services.DataService.DataServiceClient)
local MarketServiceClient = require(ReplicatedStorage.Services.MarketService.MarketServiceClient)

-- || Initializer || --
DataServiceClient:Init()
MarketServiceClient:Init()
