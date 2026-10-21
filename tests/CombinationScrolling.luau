--!strict
return function(Parser, loadRenderTree, loadWordLayout, loadBlockLayout)
	local function create(_, parent, props) local gui = table.clone(props); gui.Parent = parent; gui.Destroy = function() end; return gui end
	local renderer = loadRenderTree({create = create, modifier = create})
	local overrides = {['Layout/FontProfiles'] = {face = function(font) return font end}, ['Layout/TextMeasure'] = {measure = function(text, _, size) return Vector2.new(#text * 5, size) end}}
	overrides['Layout/WordLayout'] = loadWordLayout(overrides)
	local layout = loadBlockLayout(overrides)
	local function pixels(value) return if type(value) == "table" then value.Value else value end
	local count = 0
	for _, display in {"block", "flex", "grid"} do for _, writing in {"horizontal-tb", "vertical-lr", "vertical-rl"} do
		local css = '#port{display:' .. display .. ';writing-mode:' .. writing .. ';width:200px;height:100px;overflow:scroll;scrollbar-gutter:stable both-edges;scroll-snap-type:both mandatory}#body{min-width:430px;height:320px;scroll-snap-align:start}#port:hover{scrollbar-width:thin;scrollbar-color:red yellow;overscroll-behavior:contain;touch-action:pan-y;scroll-padding:20px;scroll-behavior:smooth}#port:hover #body{scroll-snap-align:end;scroll-margin:8px}#port:focus{scrollbar-width:none}'
		local tree = renderer.build(Parser.parse('<style>' .. css .. '</style><div id="port"><div id="body"></div></div>'), {AbsoluteSize = Vector2.new(500, 400)}, error)
		local port, body; for node, box in tree.NodeBoxes do if node.Attributes and node.Attributes.id == "port" then port = box elseif node.Attributes and node.Attributes.id == "body" then body = box end end
		local native = port.ScrollGui
		for _, state in {{Hover = false, Focus = false, Size = 10}, {Hover = true, Focus = false, Size = 6}, {Hover = true, Focus = true, Size = 0}, {Hover = true, Focus = false, Size = 6}, {Hover = false, Focus = false, Size = 10}} do
			tree:SetCSSState("hover", if state.Hover then port.Node else nil)
			tree:SetCSSState("focus", if state.Focus then port.Node else nil)
			layout.arrange(tree, 500, 0, 0, function() return true end)
			local vertical = writing ~= "horizontal-tb"
			assert(port.ScrollGui == native and native.ScrollBarThickness == state.Size, "Native scroll frame is reused with the current thickness")
			assert(port.ScrollX == state.Size * (if vertical then 2 else 1) and port.ScrollY == state.Size * (if vertical then 1 else 2), "Stable both-edges reserves the inline edges only")
			assert(port.ContentWidth == 200 - port.ScrollY and port.ContentHeight == 100 - port.ScrollX, "Content dimensions exclude all reserved gutters")
			assert(native.Position[1] == (if vertical then 0 else state.Size) and native.Position[2] == (if vertical then state.Size else 0), "The opposite gutter has real leading space")
			assert(native.Size[1] == 200 - port.ScrollLeadingX and native.Size[2] == 100 - port.ScrollLeadingY, "Native viewport agrees with CSS leading gutters")
			if state.Hover then
				assert(native.ScrollBarImageColor3 == Color3.fromRGB(255, 0, 0) and native.ElasticBehavior == Enum.ElasticBehavior.Never and native.ScrollingDirection == Enum.ScrollingDirection.Y)
				assert(port.Style.ScrollBehavior == "smooth" and body.Style.ScrollSnapAlign.Block == "end" and body.Style.ScrollSnapAlign.Inline == "end", "Live scroll behavior and target snap alignment recascade")
				assert(pixels(port.Style.ScrollPadding[1]) == 20 and pixels(body.Style.ScrollMargin[1]) == 8, "Scroll padding and margins recascade together")
			else
				assert(native.ScrollBarImageColor3 == Color3.fromRGB(139, 139, 139) and native.ElasticBehavior == Enum.ElasticBehavior.WhenScrollable)
			end
			count += 1
		end
	end end
	print("Scroll combinations: " .. count .. " block/flex/grid × writing-direction × hover/focus states, inline gutters, native geometry, snap properties and scrollbar reset")
end
