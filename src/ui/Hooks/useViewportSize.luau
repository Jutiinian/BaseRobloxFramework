-- Credit to leif

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

return function()
	local value, setValue = React.useState(workspace.CurrentCamera.ViewportSize)

	React.useEffect(function()
		local conn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setValue(workspace.CurrentCamera.ViewportSize)
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	return value
end
