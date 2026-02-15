--!strict

-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local React = require(ReplicatedStorage.Packages.react)
local useStrokeScale = require(ReplicatedStorage.UI.hooks.useStrokeScale)

-- || Variables || --
local STUDIO_SIZE = Vector2.new(1924, 939)

export type ScaledStrokeProps = {
	Thickness: number | React.Binding<number>,
	Transparency: number | React.Binding<number> | nil,
	Color: Color3 | React.Binding<Color3> | nil,
	BorderOffset: UDim | React.Binding<UDim> | nil,
	ZIndex: number?,
	ApplyStrokeMode: Enum.ApplyStrokeMode?,
	LineJoinMode: Enum.LineJoinMode?,
	BorderStrokePosition: Enum.BorderStrokePosition?,
	Enabled: boolean | React.Binding<boolean> | nil,

	children: React.ReactNode?,
}

-- || Public API || --
return function(props: ScaledStrokeProps)
	local trueEnabled = props.Enabled or true
	local scaledThickness = useStrokeScale(props.Thickness, STUDIO_SIZE.X)

	return React.createElement("UIStroke", {
		Color = props.Color or Color3.fromRGB(0, 0, 0),
		Transparency = props.Transparency,
		ApplyStrokeMode = props.ApplyStrokeMode,
		LineJoinMode = props.LineJoinMode,
		BorderStrokePosition = props.BorderStrokePosition,
		BorderOffset = props.BorderOffset,
		ZIndex = props.ZIndex,
		Enabled = trueEnabled,

		Thickness = scaledThickness,
	}, props.children)
end
