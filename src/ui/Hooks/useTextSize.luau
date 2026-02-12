--!optimize 2
--!strict

-- || Services || --
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local React = require(ReplicatedStorage.Packages.react)
local getDependencies = require(ReplicatedStorage.UI.utils.getDependencies)

-- || Types || --
type Options = {
    size: number,
    font: Font,
    width: number?,
}

-- || Hook || --
local function useTextSize(text: string, options: Options): Vector2
    local textSize = options.size
    local fontFace = options.font
    local width = options.width or math.huge

    local frameSize = React.useMemo(function()
        local params = Instance.new("GetTextBoundsParams")

        params.Text = text
        params.Size = textSize
        params.Font = fontFace
        params.Width = width

        return TextService:GetTextBoundsAsync(params)
    end, getDependencies(text, textSize, fontFace, width))

    return frameSize
end

return useTextSize