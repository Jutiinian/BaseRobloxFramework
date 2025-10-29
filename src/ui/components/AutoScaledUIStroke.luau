-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local React = require(ReplicatedStorage.Packages.React)
local useViewportSize = require(script.Parent.Parent.hooks.useViewportSize)

-- || Variables || --
local STUDIO_SIZE = Vector2.new(1924, 939)

export type AutoScaledStrokeProps = {
	Thickness: number?,
	Transparency: number?,
	Color: Color3?,
	ApplyStrokeMode: Enum.ApplyStrokeMode?,
	LineJoinMode: Enum.LineJoinMode?,
	ScaleFactor: number?,
}

-- || Private Functions || --
local function getBox(vector2: Vector2): number
	return math.min(vector2.X, vector2.Y)
end

-- || Public API || --
return function(props: AutoScaledStrokeProps)
	local screenSize = useViewportSize() -- This uses React.useState internally
	local scaleFactor = props.ScaleFactor or 1
	local baseThickness = props.Thickness or 1
	local scaleBinding, setScale = React.useBinding(scaleFactor)

	React.useEffect(function()
		local newScale = getBox(screenSize) / getBox(STUDIO_SIZE)
		--scaleFactor * (screenSize.X / STUDIO_SIZE.X) --math.min(screenSize.X / STUDIO_SIZE.X, screenSize.Y / STUDIO_SIZE.Y)
		setScale(newScale)
	end, { screenSize, scaleFactor })

	return React.createElement("UIStroke", {
		Color = props.Color or Color3.fromRGB(0, 0, 0),
		Transparency = props.Transparency,
		ApplyStrokeMode = props.ApplyStrokeMode,
		LineJoinMode = props.LineJoinMode,

		Thickness = scaleBinding:map(function(value)
			return baseThickness * value
		end),
	})
end
