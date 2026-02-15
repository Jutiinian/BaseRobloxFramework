--!strict

-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local React = require(ReplicatedStorage.Packages.react)
local getDependencies = require(ReplicatedStorage.UI.utils.getDependencies)
local useScale = require(ReplicatedStorage.UI.hooks.useScale)

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
	local minSize = props.MinSize or Vector2.zero
	local scaleFactor = props.ScaleFactor or 1

	local minScale = React.useMemo(function()
		return math.max(minSize.X / props.Size.X.Offset, minSize.Y / props.Size.Y.Offset)
	end, getDependencies(minSize, props.Size))

	local scaleBinding = useScale(scaleFactor, STUDIO_SIZE)

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
			Scale = scaleBinding:map(function(scaleNumber)
				return math.max(scaleNumber, minScale)
			end),
		}),
		props.children :: any,
	})
end)
