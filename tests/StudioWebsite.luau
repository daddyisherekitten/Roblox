--!strict
-- Integration: the replacement pages mount at narrow, medium and wide widths.
return function(mainHTML, mainCSS, testHTML, testCSS, Parser, loadRenderTree, loadWordLayout, loadBlockLayout)
	local creations, measurements, hoverPairs, hoverSeconds = 0, 0, 0, 0
	local function create(class, parent, props)
		creations += 1
		local gui = table.clone(props)
		gui.ClassName = class
		gui.Parent = parent
		gui.Destroy = function() end
		return gui
	end
	local renderer = loadRenderTree({create = create, modifier = create})
	local overrides = {
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size) measurements += 1; return {X = #text * size * .5, Y = size} end},
	}
	overrides["Layout/WordLayout"] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	for _, source in {{HTML = mainHTML, CSS = mainCSS, Project = false}, {HTML = testHTML, CSS = testCSS, Project = true}} do
		for _, width in {360, 800, 1280} do
			local document = Parser.parse(source.HTML)
			assert(#document.Diagnostics == 0, "Replacement page must parse without errors")
			local warnings = {}
			local tree = renderer.build(document, {AbsoluteSize = {X = width, Y = 800}}, function(message) table.insert(warnings, message) end, nil, nil, nil, function() return "rbxassetid://1" end, nil, nil, nil, nil, nil, {["styles.css"] = source.CSS})
			assert(#warnings == 0, table.concat(warnings, "\n"))
			layout.arrange(tree, width, 0, 0, function() return true end)
			assert(tree.OuterHeight > 2000 and tree.OuterHeight < 50000, "Long page must have a finite document height")
			local boxes, pending = {}, {tree}
			while #pending > 0 do
				local box = table.remove(pending)
				if box.Node and box.Node.Attributes and box.Node.Attributes.id then boxes[box.Node.Attributes.id] = box end
				for _, child in box.Children or {} do table.insert(pending, child) end
			end
			assert(boxes.inhalt and boxes.top)
			local disclosureCount = 0
			for _ in tree.Disclosures do disclosureCount += 1 end
			assert(disclosureCount == 4, "Both pages expose four native disclosures")
			for _, link in tree.Links do
				local ancestor = link.Parent
				while ancestor and ancestor.Name ~= "header" do ancestor = ancestor.Parent end
				if not ancestor then continue end
				local beforeCreations, beforeMeasurements = creations, measurements
				local started = os.clock()
				local changed, needsLayout = tree:SetCSSState("hover", link)
				assert(not changed or needsLayout == false, "Header link hover must not request page layout: " .. (link.Attributes.href or ""))
				local linkBox = tree.NodeBoxes[link]
				if linkBox and linkBox.InsetEdges and linkBox.Style.BorderSizes and linkBox.Style.BorderSizes[3] > 0 then
					assert(linkBox.InsetEdges[3].BackgroundColor3 == linkBox.Style.BorderSides[3].Color, "Hover paints the existing underline")
				end
				local leftChanged, leftNeedsLayout = tree:SetCSSState("hover", nil)
				assert(not leftChanged or leftNeedsLayout == false, "Leaving a header link must not request page layout")
				hoverSeconds += os.clock() - started; hoverPairs += 1
				assert(measurements == beforeMeasurements and creations == beforeCreations, "Header hover must reuse all text measurements and GUI objects")
			end
			if source.Project then
				assert(boxes.idee and boxes.raeume and boxes.material and boxes.planung and boxes.anfrage)
				local types = {}
				for _, control in tree.Controls do types[control.Type] = (types[control.Type] or 0) + 1 end
				assert(types.text == 1 and types.email == 1 and types.select == 1 and types.textarea == 1)
				assert(types.radio == 3 and types.checkbox == 1 and types.submit == 1 and types.reset == 1)
			else
				assert(boxes.projekte and boxes.studio and boxes.arbeitsweise and boxes.kontakt)
			end
		end
	end
	-- Roblox GUI sizes can be zero while the document is first constructed.
	-- The caption must leave normal flow when the real viewport becomes wide.
	local responsive = renderer.build(Parser.parse(mainHTML), {AbsoluteSize = {X = 0, Y = 0}}, error, nil, nil, nil, function() return "rbxassetid://1" end, nil, nil, nil, nil, nil, {["styles.css"] = mainCSS})
	local caption, figure, material, materialFigure, materialCopy
	for node, box in responsive.NodeBoxes do
		if node.Name == "figcaption" and node.Parent.Attributes.class == "hero-figure" then
			caption, figure = box, responsive.NodeBoxes[node.Parent]
		end
		local class = node.Attributes and node.Attributes.class
		if class == "material-section container" then material = box end
		if class == "material-figure" then materialFigure = box end
		if class == "material-copy" then materialCopy = box end
	end
	assert(caption and figure)
	for _, width in {1100, 360, 800, 1280, 680, 681, 480, 360, 1100} do
		responsive:SetMediaEnvironment(width, 800)
		layout.arrange(responsive, width, 0, 0, function() return true end)
		local materialImage = materialFigure.Children[1]
		assert(materialFigure.OuterWidth <= material.ContentWidth + .001, "Material figure must fit its responsive grid: " .. width .. " px; figure " .. materialFigure.OuterWidth .. ", available " .. material.ContentWidth)
		assert(materialImage.OuterWidth <= materialFigure.ContentWidth + .001, "Material image scales with its containing figure")
		assert(math.abs(materialImage.OuterHeight / materialImage.OuterWidth - .8) < .001, "Material image keeps its natural aspect ratio")
		if width > 680 then
			assert(math.abs(materialFigure.OuterWidth - (material.ContentWidth - material.Style.Gap[2]) / 2) < .001, "Wide material grid uses two equal responsive columns")
			assert(materialCopy.LayoutX > materialFigure.LayoutX, "Wide material section places text beside the image")
			assert(caption.Style.Position == "absolute", "Wide viewport must restore the caption overlay")
			assert(math.abs(caption.Gui.Position[1] - 24) < .001, "Caption left inset")
			assert(math.abs(caption.Gui.Position[2] + caption.OuterHeight - (figure.OuterHeight - 24)) < .001, "Caption bottom inset")
			assert(caption.Gui.ZIndex > figure.Children[1].Gui.ZIndex, "Caption paints above the image")
		else
			assert(math.abs(materialFigure.OuterWidth - material.ContentWidth) < .001, "Narrow material figure fills its single column")
			assert(materialCopy.LayoutY >= materialFigure.LayoutY + materialFigure.OuterHeight, "Narrow material section places text below the image")
			assert(caption.Style.Position == "static", "Mobile viewport keeps the browser's caption below the image")
			assert(caption.LayoutY >= figure.Children[1].OuterHeight, "Mobile caption follows the image")
		end
	end
	print("Studio website: both browser-native pages parse and mount at 360, 800 and 1280 px")
	print("Studio responsive layout: nine live resizes preserve hero overlays, material image sizing/aspect ratio and text stacking at the 680px breakpoint")
	print(string.format("Studio header hover: %d enter/leave pairs, %.2f ms average, zero page layouts, text measurements or GUI creations", hoverPairs, hoverSeconds * 1000 / hoverPairs))
end
