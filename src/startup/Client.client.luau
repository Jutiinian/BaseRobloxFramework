-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServiceClient = require(ReplicatedStorage.Services.DataService.DataServiceClient)

-- || Dependencies || --

-- || Initializer || --
DataServiceClient:Init()
