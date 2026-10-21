--!strict
return function(Parser, loadRenderTree, loadWordLayout, loadBlockLayout)
	local created, measured, objects = 0, 0, {}
	local function create(class, parent, props)
		created += 1
		local gui = table.clone(props); gui.ClassName = class; gui.Parent = parent; gui.Destroy = function() end
		table.insert(objects, gui)
		return gui
	end
	local renderer = loadRenderTree({create = create, modifier = create})
	local overrides = {['Layout/FontProfiles'] = {face = function(font) return font end}, ['Layout/TextMeasure'] = {measure = function(text, _, size) measured += 1; return {X = #text * 6, Y = size} end}}
	overrides['Layout/WordLayout'] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	local html = '<style>a{color:black}a:hover{color:red}#native{display:block;border:2px solid black}#native:hover{border-color:red}#dotted{display:block;border:2px dotted black}#dotted:hover{border-color:red}#edge{display:block;border-bottom:1px solid transparent}#edge:hover{border-bottom-color:red}#inline{box-decoration-break:clone;border-bottom:1px solid transparent}#inline:hover{border-bottom-color:red}#resize{display:block;border-bottom:1px solid black}#resize:hover{border-bottom-width:5px}</style><a id="native" href="#">Native</a><a id="dotted" href="#">Dotted</a><a id="edge" href="#">Edge</a><p><a id="inline" href="#">Inline label</a></p><a id="resize" href="#">Resize</a>'
	local tree = renderer.build(Parser.parse(html), {}, error)
	layout.arrange(tree, 400, 0, 0, function() return true end)
	local byId = {}
	for _, node in tree.Links do byId[node.Attributes.id] = node end
	for _, id in {'native', 'dotted', 'edge', 'inline'} do
		local node = byId[id]
		local beforeCreated, beforeMeasured = created, measured
		local changed, needed = tree:SetCSSState('hover', node)
		assert(changed and not needed, id .. ' border color must not request layout')
		assert(created == beforeCreated and measured == beforeMeasured, id .. ' hover must reuse paint and measurements')
		local box = tree.NodeBoxes[node]
		if id == 'native' then
			local stroke
			for _, gui in objects do if gui.ClassName == 'UIStroke' and gui.Parent == box.Gui then stroke = gui end end
			assert(stroke and stroke.Color == Color3.fromRGB(255, 0, 0), 'Native stroke receives the hover color')
		elseif id == 'dotted' or id == 'edge' then
			assert(box.InsetEdges[3].BackgroundColor3 == Color3.fromRGB(255, 0, 0), 'Retained border strips receive the hover color')
		elseif id == 'inline' then
			local painted = false
			local function visit(current)
				for _, slot in current.FragmentPool or {} do
					if slot.OwnerStyle.Node == node then
						assert(slot.Edges[3].BackgroundColor3 == Color3.fromRGB(255, 0, 0), 'Inline underline repaints without wrapping')
						painted = true
					end
				end
				for _, child in current.Children or {} do visit(child) end
			end
			visit(tree); assert(painted)
		end
		local left, leftNeeded = tree:SetCSSState('hover', nil)
		assert(left and not leftNeeded, 'Leaving retains the paint-only path')
	end
	local changed, needed = tree:SetCSSState('hover', byId.resize)
	assert(changed and needed, 'A true border width change still requests layout')
	assert(tree.NodeStyles[byId.resize].BorderSizes[3] == 5, 'Derived border geometry updates with the width')
	print('Hover borders: native, dotted, transparent underlines and inline fragments repaint without layout; width changes still reflow')
end
