--!strict
return function(Parser: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any, Popover: any)
	local renderer = loadRenderTree({
		create = function(_, parent, props)
			local gui = table.clone(props)
			gui.Parent = parent
			function gui:Destroy() self.Parent = nil; self.Destroyed = true end
			return gui
		end,
		modifier = function(_, _, props) return table.clone(props) end,
	})
	local document = Parser.parse('<div style="height:20px;overflow:hidden"><button id="toggle" type="button" popovertarget="a">Toggle</button></div><p id="a" popover>Alpha</p><div id="b" popover="manual">Beta</div><div id="c" popover>Gamma</div><div id="hint" popover="hint">Hint</div><div id="invalid" popover="unknown">Manual fallback</div><button id="show" popovertarget="a" popovertargetaction="show">Show</button><button id="hide" popovertarget="a" popovertargetaction="hide">Hide</button>')
	local viewport = {AbsolutePosition = Vector2.new(7, 11)}
	local root = {Parent = viewport, AbsolutePosition = Vector2.new(17, 26)}
	local tree = renderer.build(document, root, error, nil, nil, nil, nil, 'p{margin:0 0 14px} #a:popover-open{background:#123456}')
	Popover.attachViewport(tree, root)
	assert(#tree.Popovers == 5 and tree.PopoverHost and not tree.PopoverHost.Layer.Visible)
	local a, b, c, hint, invalid = tree.Popovers[1], tree.Popovers[2], tree.Popovers[3], tree.Popovers[4], tree.Popovers[5]
	assert(hint.Mode == 'hint' and invalid.Mode == 'manual', 'hint and invalid-value fallback follow HTML popover states')
	assert(not a.Open and not a.Box.Gui.Visible and Popover.hidden(tree, a.Node))
	local controls = {}
	for _, control in tree.Controls do controls[control.Node.Attributes.id or ''] = control end
	assert(Popover.command(tree, controls.toggle) == a and a.Open and a.Box.Gui.Visible)
	local openStyles = {[a.Node] = true}
	assert(tree.CSSStates['popover-open'][a.Node], 'The native command synchronizes :popover-open with the matching style')
	assert(tree.NodeStyles[a.Node].Background == Color3.fromRGB(18, 52, 86))
	assert(tree:SetCSSState('popover-open', {}), 'Closing removes :popover-open styles')
	assert(a.Box.Gui.Parent == tree.PopoverHost.Layer and tree.PopoverHost.Layer.Visible)
	assert(not Popover.hidden(tree, a.Node))
	assert(Popover.command(tree, controls.toggle) == a and not a.Open, 'The invoker toggles its popover')
	assert(Popover.command(tree, controls.show) == a and a.Open)
	assert(Popover.command(tree, controls.show) == a and a.Open, 'show on an open popover is idempotent')
	assert(Popover.command(tree, controls.hide) == a and not a.Open)
	assert(Popover.show(tree, b.Node) == b and b.Open)
	assert(Popover.cancel(tree) == nil and b.Open, 'Manual popovers ignore Escape')
	assert(Popover.show(tree, a.Node) == a and a.Open and b.Open)
	assert(Popover.show(tree, c.Node) == c and c.Open and not a.Open and b.Open, 'Opening another auto popover closes its peer, not manual popovers')
	assert(Popover.show(tree, hint.Node) == hint and hint.Open and c.Open, 'Hint popovers leave auto popovers open')
	assert(Popover.cancel(tree) == hint and not hint.Open and c.Open, 'Escape closes the most recently opened light-dismissible popover')
	c.Box.Gui.AbsolutePosition = Vector2.new(100, 80)
	c.Box.Gui.AbsoluteSize = Vector2.new(60, 30)
	assert(Popover.dismissAt(tree, Vector2.new(110, 90), nil) == nil and c.Open)
	assert(Popover.dismissAt(tree, Vector2.new(5, 5), nil) == c and not c.Open and b.Open)
	assert(Popover.show(tree, a.Node) == a)
	assert(Popover.dismissAt(tree, Vector2.new(5, 5), controls.toggle.Node) == nil and a.Open, 'A press on the invoker must reach toggle instead of first light-dismissing')
	assert(Popover.cancel(tree) == a and not a.Open)
	local words = loadWordLayout({
		['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(text, _, size) return {X = if text == ' ' then 4 else #text * 8, Y = size} end},
	})
	local block = loadBlockLayout({['Layout/WordLayout'] = words})
	tree.ViewportHeight = 300
	local height = block.arrange(tree, 500, 0, 0, function() return true end)
	assert(height > 20 and height < 200, 'Closed popovers must not enlarge the document flow')
	root.AbsoluteSize = Vector2.new(500, 300)
	root.AbsoluteWindowSize = Vector2.new(500, 300)
	root.CanvasPosition = Vector2.new(0, 40)
	Popover.arrange(tree, root)
	assert(tree.PopoverHost.Layer.Position[1] == 10 and tree.PopoverHost.Layer.Position[2] == 15)
	assert(a.Box.Gui.Position[1] == 0 and a.Box.Gui.Position[2] == 0, 'Authored p margins place this popover at the viewport origin')
	assert(b.Box.Gui.Position[1] == (500 - b.Box.OuterWidth) / 2 and b.Box.Gui.Position[2] == (300 - b.Box.OuterHeight) / 2, 'Unstyled popovers use auto margins and center in the viewport')
	Popover.destroyHost(tree)
	assert(tree.PopoverHost == nil)
	local retained=renderer.build(Parser.parse('<div id="owner"><div id="retained" popover>Retained</div></div>'),root,error)
	Popover.attachViewport(retained,root)
	local state=retained.Popovers[1];local owner=state.Node.Parent
	Popover.show(retained,state.Node)
	state.Box.Gui.AbsolutePosition=Vector2.new(100,80);state.Box.Gui.AbsoluteSize=Vector2.new(140,80)
	owner.Attributes.style='content-visibility:hidden';retained:RefreshDOMStyles({[owner]=true})
	assert(state.Open and retained.CSSStates['popover-open'][state.Node]and state.Box.TopLayerActive,'Skipping preserves popover membership without returning it to flow')
	assert(not state.Box.Gui.Visible and not retained.PopoverHost.Layer.Visible and Popover.hidden(retained,state.Node),'A skipped open popover generates no surface or focus target')
	assert(Popover.dismissAt(retained,Vector2.new(120,100))==state and not state.Open,'Stale retained popover geometry does not suppress light dismissal while skipped')
	Popover.show(retained,state.Node)
	assert(Popover.cancel(retained)==state and not state.Open,'A hidden auto popover still responds to its close watcher')
	Popover.destroyHost(retained)
	print('Popover: hidden flow, top layer, target actions, auto/manual, light dismissal, Escape and viewport placement passed')
end
