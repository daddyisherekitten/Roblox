--!strict
local Factory = require(script.Parent.Parent.Parent).GuiFactory
local GuideControls = {}

function GuideControls.create(row: GuiObject, router: any, definition: any, index: number, changed: (string, number) -> ())
	local offset = definition.Offset
	local line = Factory.create("Frame", row, {
		Name = definition.Key .. "Guide", Size = UDim2.fromOffset(450, 1),
		BackgroundTransparency = 0.8, BackgroundColor3 = definition.Color, ZIndex = 3,
	})
	local y = 38 + (index - 1) * 35
	local caption = Factory.create("TextLabel", row, {
		Name = definition.Key .. "Value", Position = UDim2.fromOffset(480, y),
		Size = UDim2.fromOffset(230, 30), TextColor3 = definition.Color,
		TextYAlignment = Enum.TextYAlignment.Center,
	}) :: TextLabel
	local function update()
		line.Position = UDim2.fromOffset(12, 44 + offset)
		caption.Text = string.format("%s: %d px", definition.Label, offset)
		changed(definition.Key, offset)
	end
	local function button(text: string, x: number, delta: number)
		local object = Factory.create("TextLabel", row, {
			Name = definition.Key .. (if delta < 0 then "Up" else "Down"), Text = text,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(56, 30),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(48, 65, 87),
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
		})
		router:Register(object, function()
			local nextOffset = math.clamp(offset + delta, 0, 100)
			if nextOffset == offset then return end
			offset = nextOffset
			update()
		end)
	end
	button("−1", 724, -1)
	button("+1", 788, 1)
	update()
end

return GuideControls
