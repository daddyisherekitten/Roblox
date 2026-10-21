--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadBlockLayout: any)
 local fixtureElement=require('DOM/Node').element
	local function resolve(css, author)
		return Style.resolve(fixtureElement("div",{style = css}), {FontSize = 20}, error, false, author)
	end
	for _, mode in {"visible", "hidden", "auto", "scroll"} do
		local s = resolve("overflow: " .. mode)
		assert(s.OverflowX == mode and s.OverflowY == mode)
	end
	local s = resolve("overflow: hidden; overflow-x: auto")
	assert(s.OverflowX == "auto" and s.OverflowY == "hidden")
	s = resolve("overflow-y: scroll; overflow: auto hidden")
	assert(s.OverflowX == "auto" and s.OverflowY == "hidden")
	s = resolve("overflow-x: visible; overflow-y: hidden")
	assert(s.OverflowX == "auto" and s.OverflowY == "hidden")
	s = resolve("overflow: auto; overflow-x: visible; overflow-y: visible")
	assert(s.OverflowX == "visible" and s.OverflowY == "visible", "Compute the axis coupling after the complete cascade")
	s = resolve("overflow: auto", "overflow-y: hidden !important")
	assert(s.OverflowX == "auto" and s.OverflowY == "hidden")
	local inherited = Style.resolve(fixtureElement("div",{}), s, error)
	assert(inherited.OverflowX == "visible" and inherited.OverflowY == "visible")
	local requests, objects = 0, 0
	local renderer = loadRenderTree({create = function(class, parent, props)
		objects += 1
		local gui = table.clone(props); gui.ClassName, gui.Parent = class, parent
		return gui
	end})
	local words = loadWordLayout({["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			requests += 1
			return {X = if text == " " then 5 else 20, Y = size}
		end}})
	local layout = loadBlockLayout({["Layout/WordLayout"] = words})
	local function build(html) return renderer.build(Parser.parse(html), {}, error) end
	local function arrange(tree, width) return layout.arrange(tree, width or 200, 0, 0, function() return true end) end
	local tree = build('<div style="height: 40px; overflow: auto"><div style="height: 120px"></div></div><div style="height: 10px"></div>')
	local h, w = arrange(tree, 100)
	local box = tree.Children[1]
	assert(h == 50 and w == 100 and tree.Children[2].LayoutY == 40)
	assert(box.ScrollGui.ClassName == "ScrollingFrame" and box.ScrollGui.Parent == box.Gui)
	assert(box.Children[1].Gui.Parent == box.ScrollContent and box.ScrollContent.Parent == box.ScrollGui)
	assert(box.ContentWidth == 90 and box.ScrollX == 0 and box.ScrollY == 10)
	assert(box.ScrollGui.CanvasSize[1] == 0 and box.ScrollGui.CanvasSize[2] == 120)
	box.ScrollGui.CanvasPosition = Vector2.new(0, 70)
	local count, allocated = requests, objects
	arrange(tree, 160)
	assert(box.ScrollGui.CanvasPosition.Y == 70 and requests == count and objects == allocated)
	box.Style.Height.Value = 100
	arrange(tree, 160)
	assert(box.ScrollGui.CanvasPosition.Y == 20, "Clamp after a larger viewport")
	box.Style.Height.Value = 150
	arrange(tree, 160)
	assert(box.ScrollY == 0 and box.ScrollGui.CanvasPosition.Y == 0 and box.ScrollGui.CanvasSize[2] == 0)
	local axes = build('<div style="width: 60px; height: 30px; overflow-x: auto; overflow-y: hidden"><div style="width: 150px; height: 80px"></div></div>')
	assert(arrange(axes, 80) == 30)
	box = axes.Children[1]
	assert(box.ScrollX == 10 and box.ScrollY == 0 and box.ContentHeight == 20)
	assert(box.ScrollGui.ScrollingDirection == Enum.ScrollingDirection.X and box.ScrollGui.CanvasSize[1] == 150 and box.ScrollGui.CanvasSize[2] == 0)
	local two = build('<div style="width: 100px; height: 50px; overflow: auto"><div style="width: 95px; height: 100px"></div></div>')
	arrange(two)
	box = two.Children[1]
	assert(box.ScrollX == 10 and box.ScrollY == 10 and box.ContentWidth == 90 and box.ContentHeight == 40, "Vertical gutter can create horizontal overflow")
	local autoHeight = build('<div style="width: 100px; overflow: auto"><div style="width: 200px; height: 20px"></div></div>')
	assert(arrange(autoHeight) == 30)
	box = autoHeight.Children[1]
	assert(box.ScrollX == 10 and box.ScrollY == 0, "Automatic height grows for a horizontal bar without a spurious vertical bar")
	local forced = build('<div style="width: 100px; height: 50px; overflow: scroll"></div>')
	arrange(forced)
	box = forced.Children[1]
	assert(box.ScrollX == 10 and box.ScrollY == 10 and box.ScrollTrackX.Visible and box.ScrollTrackY.Visible)
	assert(box.ScrollGui.CanvasSize[1] == 0 and box.ScrollGui.CanvasSize[2] == 0, "Idle scrollbars must not create fake scroll range")
	local tiny = build('<div style="width: 0; height: 0; overflow: scroll"></div>')
	assert(arrange(tiny) == 0 and tiny.Children[1].OuterWidth == 0)
	local padded = build('<div style="width: 100px; height: 60px; box-sizing: border-box; padding: 5px; border: 2px solid; overflow-y: auto; overflow-x: hidden"><div style="height: 100px"></div></div>')
	arrange(padded)
	box = padded.Children[1]
	assert(box.OuterWidth == 100 and box.OuterHeight == 60 and box.ContentWidth == 76)
	assert(box.ScrollGui.Position[1] == 2 and box.ScrollGui.Size[1] == 96 and box.ScrollContent.Position[1] == -2)
	assert(box.Children[1].LayoutX == 7 and box.ScrollGui.CanvasSize[2] == 110, "Border stays fixed; content canvas includes padding")
	local nested = build('<div style="height: 60px; overflow: auto"><div style="height: 40px; overflow: auto"><div style="height: 200px"></div></div></div>')
	arrange(nested)
	assert(nested.Children[1].ScrollY == 0 and nested.Children[1].Children[1].ScrollY == 10, "Inner overflow cannot expand the ancestor canvas")
	local positioned = build('<div style="position: relative; width: 100px; height: 40px; overflow: auto"><div style="position: absolute; top: 80px; height: 20px; width: 20px"></div></div>')
	assert(arrange(positioned) == 40)
	box = positioned.Children[1]
	assert(box.ScrollY == 10 and box.ScrollGui.CanvasSize[2] == 100, "Positioned descendants extend only their scroll container")
	local anchored = build('<div style="position: relative; width: 100px; height: 40px; overflow: auto"><div style="height: 100px"></div><div style="position: absolute; right: 0; top: 0; width: 20px; height: 10px"></div></div>')
	arrange(anchored)
	box = anchored.Children[1]
	assert(box.Children[2].Gui.Position[1] == 70, "Positioned right edge excludes the scrollbar gutter")
	local reflow = build('<div style="height: 25px; line-height: 10px; overflow: auto">AA BB CC DD EE FF</div>')
	arrange(reflow, 100)
	box = reflow.Children[1]
	assert(box.ScrollY == 0)
	count, allocated = requests, objects
	arrange(reflow, 50)
	assert(box.ScrollY == 10 and box.ScrollGui.CanvasSize[2] == 60 and requests == count and objects == allocated)
	arrange(reflow, 100)
	assert(box.ScrollY == 0 and requests == count and objects == allocated)
	local flex = build('<div style="display: flex; width: 100px"><div style="overflow: auto; white-space: nowrap; height: 30px">AA BB CC DD EE FF</div></div>')
	arrange(flex)
	box = flex.Children[1].Children[1]
	assert(box.OuterWidth == 100 and box.ScrollX == 10, "Scrollable flex items have a zero automatic minimum")
	print("Scrolling: axis cascade, native hierarchy, gutters, forced tracks, padding/borders, nested/positioned overflow, flex and resize reuse passed")
end
