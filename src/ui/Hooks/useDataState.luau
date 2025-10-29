-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local DataServiceClient = require(ReplicatedStorage.Shared.Services.DataService.DataServiceClient)
local React = require(ReplicatedStorage.Packages.React)

-- || Hook || --
return function(key: string | { string }, initialValue: any?)
	local data, setData = React.useState(DataServiceClient:GetValue(key) or initialValue)

	React.useEffect(function()
		local signalConnection = DataServiceClient:GetValueChangedSignal(key):Connect(setData)

		return function()
			signalConnection:Disconnect()
		end
	end, {})

	--[[React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				setData(function(oldValue)
					return oldValue + math.random(0, 30000)
				end)
				task.wait(0.4)
			end
		end)
		return function()
			running = false
		end
	end, {})]]

	return data
end
