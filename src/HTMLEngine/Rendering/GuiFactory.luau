--!strict
-- All visual objects are created here, before being attached to the page.
local GuiFactory = {}
local WorkContext=require(script.Parent.Parent.WorkContext)

local function configure(object: Instance, parent: Instance?, properties: {[string]: any})
	local success, message = pcall(function()
		WorkContext.checkpoint()
		for key, value in properties do (object :: any)[key] = value end
		object.Parent = parent
	end)
	if not success then object:Destroy(); error(message) end
end

function GuiFactory.modifier(className: string, parent: Instance, properties: {[string]: any}): Instance
	assert(className == "UIStroke" or className == "UICorner" or className == "UIShadow" or className == "UIScale" or className == "UIGradient" or className == "UITextSizeConstraint", "GuiFactory: unsupported modifier " .. className)
	assert(properties.Parent == nil, "Pass the parent separately")
	local object = Instance.new(className)
	configure(object, parent, properties)
	return object
end

function GuiFactory.create(className: string, parent: Instance?, properties: { [string]: any }): GuiObject
	assert(className == "Frame" or className == "TextLabel" or className == "TextButton" or className == "ScrollingFrame" or className == "ImageLabel" or className == "CanvasGroup" or className == "TextBox" or className == "VideoFrame" or className == "VideoDisplay",
		"GuiFactory: unsupported class " .. className)
	local interactive = className == "TextButton"
	assert(properties.Active == nil or properties.Active == interactive, if interactive then "TextButton must remain active" else "Active must remain false")
	assert(properties.Selectable == nil or properties.Selectable == false, "Selectable must remain false")
	assert(className ~= "ScrollingFrame" or properties.ScrollingEnabled == nil or properties.ScrollingEnabled == true,
		"Native scrolling must remain enabled")
	assert(properties.Parent == nil, "Pass the parent separately")
	local object = Instance.new(className) :: GuiObject
	object.Active = interactive
	object.Selectable = false
	object.BorderSizePixel = 0
	object.AutomaticSize = Enum.AutomaticSize.None
	object.BackgroundTransparency = 1
	if object:IsA("TextLabel") or object:IsA("TextBox") or object:IsA("TextButton") then
		object.AutoLocalize = false
		object.RichText = false
		object.TextScaled = false
		object.TextWrapped = false
		if properties.FontFace == nil then object.FontFace = Font.fromEnum(Enum.Font.SourceSans) end
		object.TextSize = 18
		object.TextColor3 = Color3.fromRGB(224, 231, 241)
		object.TextXAlignment = Enum.TextXAlignment.Left
		object.TextYAlignment = Enum.TextYAlignment.Top
	end
	if object:IsA("ScrollingFrame") then
		object.ScrollingEnabled = true
		object.AutomaticCanvasSize = Enum.AutomaticSize.None
		object.ClipsDescendants = true
		object.ScrollBarThickness = 10
		object.ScrollBarImageColor3 = Color3.fromRGB(139, 139, 139)
	end
	configure(object, parent, properties)
	return object
end

return GuiFactory
