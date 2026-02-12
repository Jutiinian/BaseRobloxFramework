--!optimize 2
--!strict

-- || Services || --
local GuiService = game:GetService("GuiService")

-- || Dependencies || --
local useViewportSize = require(script.Parent.useViewportSize)

-- || Constants / Variables || --
local TOP_INSET, BOTTOM_INSET = GuiService:GetGuiInset()

-- || Hook || --

-- NOTE: Vector3 is faster than Vec2
local function useScale(scale: number, goalSize: Vector2 | Vector3)
    return useViewportSize():map(function(viewportSize: Vector2)
        local size = viewportSize - TOP_INSET + BOTTOM_INSET
        return 1 / math.max(goalSize.X / size.X, goalSize.Y / size.Y) * scale
    end)
end

return useScale