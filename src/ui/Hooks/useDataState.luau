-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local DataServiceClient = require(ReplicatedStorage.Services.DataService.DataServiceClient)
local React = require(ReplicatedStorage.Packages.react)

-- || Hook || --
return function(key: string | { string }, initialValue: any?)
	local data, setData = React.useState(DataServiceClient:Get(key) or initialValue)

	React.useEffect(function()
		local signalConnection = DataServiceClient:GetValueChangedSignal(key):Connect(setData)

		return function()
			signalConnection:Disconnect()
		end
	end, {})

	return data
end
