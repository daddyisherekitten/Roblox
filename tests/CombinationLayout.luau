--!strict
-- A resized tree must agree with a freshly built document at the same width.
return function(Parser, loadRenderTree, loadWordLayout, loadBlockLayout)
	local function create(_, parent, props) local gui = table.clone(props); gui.Parent = parent; gui.Destroy = function() end; return gui end
	local renderer = loadRenderTree({create = create, modifier = create})
	local overrides = {['Layout/FontProfiles'] = {face = function(font) return font end}, ['Layout/TextMeasure'] = {measure = function(text, _, size) return Vector2.new(#text * size * .5, size) end}}
	overrides['Layout/WordLayout'] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	local function build(html, width)
		local tree = renderer.build(Parser.parse(html), {AbsoluteSize = Vector2.new(width, 600)}, error, nil, nil, nil, function() return "rbxassetid://1" end)
		local boxes = {}; for node, box in tree.NodeBoxes do if node.Attributes and node.Attributes.id then boxes[node.Attributes.id] = box end end
		return tree, boxes
	end
	local count = 0
	for _, outer in {"block", "flex", "grid"} do for _, inner in {"block", "flex", "grid"} do
		local css = '#outer{display:' .. outer .. ';grid-template-columns:repeat(2,minmax(0,1fr));flex-wrap:wrap;gap:12px;padding:8px;border:2px solid blue} .card{min-width:0;flex:1 1 180px}#inner{display:' .. inner .. ';grid-template-columns:minmax(0,1fr);flex-direction:column;gap:6px;padding:4px}#pic{display:block;width:100%;height:auto;aspect-ratio:16/9;box-sizing:border-box;border:2px solid red;padding:3px;min-width:0}#caption{font:400 14px/1.4 Arial} @media(max-width:520px){#outer{display:block}#inner{display:flex;flex-direction:column}} @media(min-width:900px){#outer{display:grid}#inner{display:grid}}'
		local html = '<style>' .. css .. '</style><div id="outer"><section id="one" class="card"><div id="inner"><img id="pic" src="photo" alt="" width="960" height="540"><p id="caption">A caption that wraps when space becomes narrow.</p></div></section><section id="two" class="card"><p>Another card with several words and a different intrinsic width.</p></section></div>'
		local persistent, persistentBoxes = build(html, 800)
		layout.arrange(persistent, 800, 0, 0, function() return true end)
		for _, width in {360, 1100, 500, 800, 420, 1280, 800} do
			persistent:SetMediaEnvironment(width, 600)
			layout.arrange(persistent, width, 0, 0, function() return true end)
			local fresh, freshBoxes = build(html, width)
			layout.arrange(fresh, width, 0, 0, function() return true end)
			for id, box in persistentBoxes do
				local expected = freshBoxes[id]
				assert(expected, "Both builds retain " .. id)
				for _, field in {"OuterWidth", "OuterHeight", "LayoutX", "LayoutY", "ContentWidth", "ContentHeight"} do
					assert(math.abs(box[field] - expected[field]) < .001, outer .. "/" .. inner .. " at " .. width .. "px: " .. id .. "." .. field .. " differs after resize: " .. box[field] .. " versus " .. expected[field])
				end
			end
			local pic = persistentBoxes.pic
			assert(math.abs(pic.OuterWidth / pic.OuterHeight - 16 / 9) < .001, "Border-box aspect ratio survives nested layouts and resizing")
			assert(pic.OuterWidth <= persistentBoxes.inner.ContentWidth + .001, "Percent image fits its nested container")
			count += 1
		end
	end end
	print("Layout combinations: " .. count .. " live-resize/fresh-build comparisons, nested block/flex/grid switches, intrinsic image sizes, borders, padding, aspect ratio and wrapped text")
end
