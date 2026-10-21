--!strict
-- Check allocation failure paths with property-write errors, without Roblox.
return function(loadGuiFactory: any)
	local created = {}
	local instance = { new = function(className)
		local fields = { DestroyCalls = 0 }
		local object = setmetatable({}, {
			__index = function(_, key)
				if key == "IsA" then return function(_, expected) return className == expected end end
				if key == "Destroy" then return function() fields.DestroyCalls += 1 end end
				return fields[key]
			end,
			__newindex = function(_, key, value)
				if key == "InvalidProperty" or (key == "Parent" and value == "invalid") then error("Invalid property assignment") end
				fields[key] = value
			end,
		})
		table.insert(created, object)
		return object
	end }
	local factory = loadGuiFactory(instance, {
		AutomaticSize = { None = "None" }, Font = { SourceSans = "SourceSans" },
		TextXAlignment = { Left = "Left" }, TextYAlignment = { Top = "Top" },
	}, { fromEnum = function(font) return font end })
	local root = factory.create("ScrollingFrame", nil, {})
	local label = factory.create("TextLabel", root, { Text = "word" })
	assert(root.ScrollingEnabled and not root.Active and not root.Selectable)
	assert(label.Parent == root and label.Text == "word" and not label.TextWrapped and not label.Active and not label.Selectable)
	for _, case in { { "Frame", { Active = true } }, { "Frame", { Selectable = true } }, { "ScrollingFrame", { ScrollingEnabled = false } } } do
		assert(not pcall(factory.create, case[1], nil, case[2]))
	end
	assert(#created == 2, "Invalid invariant overrides must be rejected before allocation")
	assert(not pcall(factory.create, "Frame", nil, { InvalidProperty = true }))
	assert(created[3].DestroyCalls == 1, "Invalid properties cannot leak an unparented instance")
	assert(not pcall(factory.create, "Frame", "invalid", {}))
	assert(created[4].DestroyCalls == 1, "Parent assignment failure must also release the instance")
	local stroke = factory.modifier("UIStroke", root, {Thickness = 2})
	local scale = factory.modifier("UIScale", root, {Scale = 1.2})
	assert(scale.Parent == root and scale.Scale == 1.2)
	local corner = factory.modifier("UICorner", root, {CornerRadius = 8})
	assert(stroke.Parent == root and stroke.Thickness == 2 and stroke.Active == nil and corner.Selectable == nil)
	assert(not pcall(factory.modifier, "Frame", root, {}))
	assert(not pcall(factory.modifier, "UIStroke", root, {Parent = root}))
	assert(#created == 7)
	assert(not pcall(factory.modifier, "UICorner", root, {InvalidProperty = true}))
	assert(created[8].DestroyCalls == 1, "Modifier configuration errors release the new instance")
	assert(not pcall(factory.modifier, "UIStroke", "invalid", {}))
	assert(created[9].DestroyCalls == 1)
	local image = factory.create("ImageLabel", root, {Name = "DecorationPattern"})
	assert(image.Parent == root and not image.Active and not image.Selectable and image.BackgroundTransparency == 1 and image.BorderSizePixel == 0)
	local shadow = factory.modifier("UIShadow", root, {Enabled = true, ZIndex = -1})
	assert(shadow.Parent == root and shadow.Enabled and shadow.ZIndex == -1)
	local gradient = factory.modifier("UIGradient", root, {Rotation = 90})
	assert(gradient.Parent == root and gradient.Rotation == 90)
	local before = #created
	assert(not pcall(factory.modifier, "UIShadow", root, {InvalidProperty = true}))
	assert(created[before + 1].DestroyCalls == 1, "Shadow configuration failure releases the modifier")
	local group = factory.create("CanvasGroup", root, {ClipsDescendants = true})
	assert(group.Parent == root and group.ClipsDescendants and not group.Active and not group.Selectable and group.BackgroundTransparency == 1)
	local editor = factory.create("TextBox", root, {Text="",ClearTextOnFocus=false,TextEditable=true})
	assert(not editor.Active and not editor.Selectable and not editor.RichText and not editor.TextScaled and not editor.ClearTextOnFocus)
	local video = factory.create("VideoFrame", root, {Video="rbxassetid://1"})
	assert(video.Parent == root and video.Video == "rbxassetid://1" and not video.Active and not video.Selectable)
	local display = factory.create("VideoDisplay", root, {})
	assert(display.Parent == root and not display.Active and not display.Selectable)
	local marker = factory.create("TextButton", root, {Text="",AutoButtonColor=false})
	assert(marker.Parent == root and marker.Active and not marker.Selectable and marker.Text == "" and not marker.AutoButtonColor)
	assert(not pcall(factory.create, "TextButton", root, {Active=false}))
	local textLimit = factory.modifier("UITextSizeConstraint", label, {MinTextSize=10, MaxTextSize=16})
	assert(textLimit.Parent == label and textLimit.MinTextSize == 10 and textLimit.MaxTextSize == 16)
	print("GUI factory: passive page objects, interactive marker buttons, native scrolling, video surfaces and cleanup passed")
end
