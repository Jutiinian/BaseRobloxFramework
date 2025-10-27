-- Credit to leif

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useViewportSize = require(ReplicatedStorage.UI.hooks.useViewportSize)

local STUDIO_SIZE = Vector2.new(1500, 803)

export type AutoScaledFrameProps = {
	ScaleFactor: number?,
	MinSize: Vector2?,
	Size: UDim2,
	Position: UDim2?,
	Rotation: number?,
	AnchorPoint: Vector2?,
	BackgroundTransparency: number?,
	ZIndex: number?,
	children: React.ReactNode?,
}

return React.forwardRef(function(props: AutoScaledFrameProps, ref: React.Ref<any>)
	local screenSize = useViewportSize() -- This uses React.useState internally
	local minSize = props.MinSize or Vector2.zero
	local scaleFactor = props.ScaleFactor or 1
	local scaleBinding, setScale = React.useBinding(scaleFactor)
	local minScale = React.useMemo(function()
		return math.max(minSize.X / props.Size.X.Offset, minSize.Y / props.Size.Y.Offset)
	end, { screenSize, minSize, props.Size })

	React.useEffect(function()
		local newScale = scaleFactor * math.min(screenSize.X / STUDIO_SIZE.X, screenSize.Y / STUDIO_SIZE.Y)
		setScale(math.max(newScale, minScale))
	end, { screenSize, minSize, scaleFactor })

	return React.createElement("Frame", {
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Rotation = props.Rotation,
		ZIndex = props.ZIndex,
		BackgroundTransparency = props.BackgroundTransparency or 1,
		ref = ref,
	}, {
		React.createElement("UIScale", {
			Scale = scaleBinding,
		}),
		props.children,
	})
end)
