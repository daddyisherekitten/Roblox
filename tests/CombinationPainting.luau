--!strict
return function(Parser, loadRenderTree, loadWordLayout, loadBlockLayout, ViewportLayer)
	local cropGroups = 0
	local function create(class, parent, props)
		local gui = table.clone(props); gui.Parent = parent; gui.ClassName = class
		gui.Destroy = function(self) self.Parent = nil; self.Destroyed = true end
		if class == "CanvasGroup" and props.Name == "ImageContent" then cropGroups += 1 end
		return gui
	end
	local factory = {create = create, modifier = create}
	local renderer = loadRenderTree(factory)
	local overrides = {['Layout/FontProfiles'] = {face = function(font) return font end}, ['Layout/TextMeasure'] = {measure = function(text, _, size) return Vector2.new(#text * 5, size) end}}
	overrides['Layout/WordLayout'] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	local root = {Parent = {}, AbsoluteSize = Vector2.new(400, 400), AbsoluteWindowSize = Vector2.new(400, 400), CanvasPosition = Vector2.new(0, 0)}
	local tree = renderer.build(Parser.parse('<style>#photo{display:block;box-sizing:border-box;width:120px;height:80px;border:2px solid blue;padding:3px;object-fit:none;object-position:center}#photo:hover{object-fit:cover;object-position:right bottom;border-radius:8px;opacity:.6}</style><img id="photo" src="photo" alt="" width="200" height="100">'), root, error, nil, nil, nil, function() return "rbxassetid://1" end)
	local photo; for node, box in tree.NodeBoxes do if node.Attributes and node.Attributes.id == "photo" then photo = box end end
	layout.arrange(tree, 400, 0, 0, function() return true end)
	local item, originalClip = photo.ImageItem, photo.ImageItem.ImageClip
	assert(originalClip.ClassName == "Frame")
	for _ = 1, 5 do
		tree:SetCSSState("hover", photo.Node); layout.arrange(tree, 400, 0, 0, function() return true end)
		assert(item.ImageClip.ClassName == "CanvasGroup" and item.ImageGui.Parent == item.ImageClip, "Late rounded custom fit must clip the image itself")
		assert(item.ImageCorner.CornerRadius.Offset == 3, "Inner image corner subtracts border and padding")
		assert(item.ImageGui.Position[1] == -30 and item.ImageGui.Position[2] == 0, "Cover and right/bottom positioning use the image content box")
		assert(photo.OpacityGroup and math.abs(photo.OpacityGroup.Gui.GroupTransparency - .4) < .001)
		tree:SetCSSState("hover", nil); layout.arrange(tree, 400, 0, 0, function() return true end)
		assert(item.ImageCorner.CornerRadius.Offset == 0 and item.BoxCorner.CornerRadius.Offset == 0, "Leaving restores square corners")
		assert(item.ImageGui.Position[1] == -45 and item.ImageGui.Position[2] == -15, "Leaving restores the natural-size centered crop")
		assert(photo.OpacityGroup.Gui.GroupTransparency == 0, "Late opacity group restores full opacity")
	end
	assert(cropGroups == 1 and originalClip.Destroyed, "Rounded crop surface is upgraded once and retained")
	for _, display in {"block", "flex", "grid"} do
		local css = '#parent{display:' .. display .. ';flex-direction:column;grid-template-columns:80px}#card{width:80px;height:40px}#other{width:80px;height:20px}#parent:hover #card{display:none}#fixed{position:fixed;top:5px;left:5px;width:10px;height:10px}'
		local hiddenTree = renderer.build(Parser.parse('<style>' .. css .. '</style><div id="parent"><div id="card"><div id="fixed"></div></div><div id="other"></div></div>'), root, error)
		local ids = {}; for node, box in hiddenTree.NodeBoxes do if node.Attributes and node.Attributes.id then ids[node.Attributes.id] = box end end
		local home = ids.fixed.Gui.Parent
		for _ = 1, 4 do
			layout.arrange(hiddenTree, 400, 0, 0, function() return true end); ViewportLayer.attach(hiddenTree, root, factory)
			assert(ids.parent.OuterHeight == 60 and ids.fixed.Gui.Parent == hiddenTree.ViewportLayer)
			local changed, needed = hiddenTree:SetCSSState("hover", ids.parent.Node)
			assert(changed and needed); layout.arrange(hiddenTree, 400, 0, 0, function() return true end); ViewportLayer.attach(hiddenTree, root, factory)
			assert(ids.parent.OuterHeight == 20 and ids.card.Gui.Visible == false, "Display:none removes the existing block from layout: " .. display)
			assert(ids.fixed.Gui.Parent == home and ids.fixed.HiddenByAncestor, "Fixed child cannot escape a hidden ancestor")
			hiddenTree:SetCSSState("hover", nil)
		end
		ViewportLayer.destroy(hiddenTree)
		root.AbsoluteSize = Vector2.new(300, 400); root.AbsoluteWindowSize = root.AbsoluteSize
		local initialCSS = '#parent{display:' .. display .. ';flex-direction:column;grid-template-columns:80px}#card{display:none;width:80px;height:40px}#other{width:80px;height:20px}#fixed{position:fixed;top:5px;left:5px;width:10px;height:10px}@media(min-width:350px){#card{display:block}}'
		local initiallyHidden = renderer.build(Parser.parse('<style>' .. initialCSS .. '</style><div id="parent"><div id="card"><div id="fixed"></div></div><div id="other"></div></div>'), root, error)
		local initialIds = {}; for node, box in initiallyHidden.NodeBoxes do if node.Attributes and node.Attributes.id then initialIds[node.Attributes.id] = box end end
		assert(initialIds.card, "Initially hidden block is retained")
		for _, width in {300, 600, 300, 800, 340} do
			root.AbsoluteSize = Vector2.new(width, 400); root.AbsoluteWindowSize = root.AbsoluteSize
			initiallyHidden:SetMediaEnvironment(width, 400)
			layout.arrange(initiallyHidden, width, 0, 0, function() return true end); ViewportLayer.attach(initiallyHidden, root, factory)
			local shown = width >= 350
			assert(initialIds.parent.OuterHeight == (if shown then 60 else 20) and initialIds.card.Gui.Visible == shown, "Initially hidden block follows media queries in " .. display)
			assert(initialIds.fixed.HiddenByAncestor == not shown, "Initial hiding/reveal propagates through fixed descendants")
		end
		ViewportLayer.destroy(initiallyHidden)
	end
	print("Painting combinations: five rounded object-fit/opacity round trips, one retained crop upgrade, twelve block/flex/grid display:none round trips with fixed descendants")
	print("Initially hidden combinations: fifteen block/flex/grid media-query states retain, reveal and hide block subtrees without fixed-child escape")
end
