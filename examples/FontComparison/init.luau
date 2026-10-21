--!strict
-- Plain, separate font comparison. All labels stay allocated while scrolling.
local Engine = require(script.Parent.Parent)
local Catalog = require(script.Catalog)
local Config = require(script.Config)
local Factory = Engine.GuiFactory
local Comparison = {}

function Comparison.mount(target: GuiObject)
	local rowHeight = Config.Size + 50
	local canvasWidth = 500
	local root = Factory.create("ScrollingFrame", target, {
		Name = "FontComparison", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		CanvasSize = UDim2.fromOffset(canvasWidth, #Catalog * rowHeight + 16),
		ScrollingDirection = Enum.ScrollingDirection.XY,
	}) :: ScrollingFrame
	local page = Engine.PageSession.new(root)
	local nextIndex = 1
	local function loadRows()
		while page.Alive and nextIndex <= #Catalog do
			local index = nextIndex
			nextIndex += 1
			local entry = Catalog[index]
			local row = Factory.create("Frame", root, {
				Name = entry.Key, Position = UDim2.fromOffset(8, 8 + (index - 1) * rowHeight),
				Size = UDim2.new(1, -16, 0, rowHeight),
			})
			local name = Factory.create("TextLabel", row, {
				Name = "FontName", Text = string.format("%03d %s", index, entry.Name),
				TextSize = 16, TextColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0, 20),
			}) :: TextLabel
			local font = Font.new(entry.Family, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
			local sample = Factory.create("TextLabel", row, {
				Name = "Sample", Text = Config.Text, FontFace = font, TextSize = Config.Size,
				TextColor3 = Color3.new(0, 0, 0), LineHeight = 1, Visible = false,
				Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(canvasWidth - 16, rowHeight - 20),
			}) :: TextLabel
			local bounds, message = Engine.TextMeasure.measure(Config.Text, font, Config.Size, 0)
			if not page.Alive then return end
			if bounds then
				sample.Size = UDim2.fromOffset(math.max(1, bounds.X), rowHeight - 20)
				sample.Visible = true
				if bounds.X + 16 > canvasWidth then
					canvasWidth = bounds.X + 16
					root.CanvasSize = UDim2.fromOffset(canvasWidth, #Catalog * rowHeight + 16)
				end
			else
				name.Text ..= " (Ladefehler)"
				warn(entry.Name .. ": " .. tostring(message))
			end
			task.wait() -- Yield only while initially loading the list.
		end
	end
	task.spawn(loadRows)
	task.spawn(loadRows)
	return page
end

return Comparison
