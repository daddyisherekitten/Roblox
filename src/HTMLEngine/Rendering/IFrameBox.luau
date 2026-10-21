--!strict
local BorderGeometry = require(script.Parent.Parent.Layout.BorderGeometry)
local BorderBox = require(script.Parent.BorderBox)
local OutlineBox = require(script.Parent.OutlineBox)
local IFrameBox = {}

local function write(object: any, key: string, value: any)
	if object and object[key] ~= value then object[key] = value end
end

function IFrameBox.create(item: any, parent: any, factory: any, corners: any?)
	local style = item.Style
	local kind = item.EmbeddedKind or "iframe"
	local title = if kind == "object" then "HTMLObject" elseif kind == "embed" then "HTMLEmbed" else "HTMLIFrame"
	item.Gui = factory.create("Frame", parent, {Name = item.Node.Attributes.id or title})
	item.BoxGui = factory.create("Frame", item.Gui, {
		Name = title .. "Box",
		ClipsDescendants = true,
		BackgroundTransparency = if style.Background then 1 - (style.BackgroundAlpha or 1) else 0,
		BackgroundColor3 = style.Background or Color3.new(1, 1, 1),
	})
	if style.BorderRadius > 0 then
		item.BoxCorner = factory.modifier("UICorner", item.BoxGui, {CornerRadius = UDim.new(0, style.BorderRadius)})
	end
	item.BorderEdges = BorderBox.create(style, item.BoxGui, factory, corners)
	item.Outline = OutlineBox.create(style, item.BoxGui, factory, corners)
	item.ContentGui = factory.create("Frame", item.BoxGui, {
		Name = title .. "Content",
		ClipsDescendants = true,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	item.FallbackGui = factory.create("TextLabel", item.ContentGui, {
		Name = title .. "Status",
		Text = "Loading embedded page...",
		TextSize = 14,
		TextColor3 = Color3.fromRGB(80, 80, 80),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Visible = true,
	})
end

function IFrameBox.status(item: any, message: string?)
	if not item.FallbackGui then return end
	item.FallbackGui.Text = message or ""
	item.FallbackGui.Visible = message ~= nil
end

function IFrameBox.arrange(item: any)
	local style, padding = item.Style, item.Style.Padding
	local bt, br, bb, bl = BorderGeometry.sizes(style)
	write(item.BoxGui, "Visible", style.Visibility ~= "hidden")
	write(item.BoxGui, "Position", UDim2.fromOffset(style.Margin[4], style.Margin[1]))
	write(item.BoxGui, "Size", UDim2.fromOffset(item.BoxWidth, item.BoxHeight))
	local x, y = bl + padding[4], bt + padding[1]
	write(item.ContentGui, "Position", UDim2.fromOffset(x, y))
	write(item.ContentGui, "Size", UDim2.fromOffset(item.ContentWidth, item.ContentHeight))
	write(item.FallbackGui, "Position", UDim2.fromOffset(0, 0))
	write(item.FallbackGui, "Size", UDim2.fromScale(1, 1))
	if item.BorderEdges then BorderBox.arrange(item.BorderEdges, style, item.BoxWidth, item.BoxHeight) end
	if item.Outline then OutlineBox.arrange(item.Outline, item.BoxWidth, item.BoxHeight) end
end

return IFrameBox
