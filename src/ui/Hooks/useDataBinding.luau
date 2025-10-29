-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local DataServiceClient = require(ReplicatedStorage.Shared.Services.DataService.DataServiceClient)
local React = require(ReplicatedStorage.Packages.React)

-- || Hook || --
return function(key: string | { string }, initialValue: any?)
	local dataBinding, setData = React.useBinding(DataServiceClient:GetValue(key) or initialValue)

	React.useEffect(function()
		local signalConnection = DataServiceClient:GetValueChangedSignal(key):Connect(setData)

		return function()
			signalConnection:Disconnect()
		end
	end)

	return dataBinding
end
