--!strict
return function(Style, Fit, Parser, loadRenderTree, loadWordLayout)
 local fixtureElement=require('DOM/Node').element
	local parent = {Font = "Arial", FontSize = 20, Color = Color3.new(0, 0, 0)}
	local function resolve(css, diagnostic)
		return Style.resolve(fixtureElement("img",{style = css}), parent, diagnostic or error, true)
	end
	local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. " ~= " .. tostring(b)) end
	local function rectangle(css, naturalW, naturalH, expected)
		local item = {Style = resolve(css), ContentWidth = 100, ContentHeight = 80, IntrinsicWidth = naturalW, IntrinsicHeight = naturalH}
		local values = {Fit.rectangle(item)}
		for index, value in expected do near(values[index], value) end
		return item
	end
	rectangle('object-fit: fill; object-position: right bottom', 200, 100, {0, 0, 100, 80})
	rectangle('object-fit: fill; object-position: -5px 10px', 200, 100, {-5, 10, 100, 80})
	rectangle('object-fit: contain', 200, 100, {0, 15, 100, 50})
	rectangle('object-fit: contain; object-position: bottom', 200, 100, {0, 30, 100, 50})
	rectangle('object-fit: cover; object-position: 75% 25%', 200, 100, {-45, 0, 160, 80})
	rectangle('object-fit: cover; object-position: left top', 100, 200, {0, 0, 100, 200})
	rectangle('object-fit: none', 200, 100, {-50, -10, 200, 100})
	rectangle('object-fit: none; object-position: top right', 200, 100, {-100, 0, 200, 100})
	rectangle('object-fit: none; object-position: -50% 150%', 200, 100, {50, -30, 200, 100})
	rectangle('object-fit: scale-down', 200, 100, {0, 15, 100, 50})
	rectangle('object-fit: scale-down', 40, 20, {30, 30, 40, 20})
	rectangle('object-fit: none; object-position: right 10px bottom 5px', 40, 20, {50, 55, 40, 20})
	rectangle('object-fit: none; object-position: bottom 25% left 20%', 40, 20, {12, 45, 40, 20})
	rectangle('object-fit: none; object-position: left 10px top 50%', 40, 20, {10, 30, 40, 20})
	rectangle('object-fit: none; object-position: left 50% top 5px', 40, 20, {30, 5, 40, 20})
	rectangle('object-fit: none; object-position: 10px', 40, 20, {10, 30, 40, 20})
	rectangle('object-fit: none; object-position: center left', 40, 20, {0, 30, 40, 20})
	rectangle('object-fit: none; object-position: right 10px', 40, 20, {60, 10, 40, 20})
	rectangle('object-fit: none; object-position: calc(50% - 2px)', 40, 20, {28, 30, 40, 20})
	local warnings = 0
	for _, value in {'left right', 'top bottom', 'top 10px', '10px left', '10', '-+5px', 'left 1px 2px', 'center 1px top', 'left top center', 'right 2px right', 'left 0 top 0 center', 'left 10px center', 'center top 5px', 'right 10px bottom'} do
		local style = resolve('object-position: 25% 75%; object-position: ' .. value, function() warnings += 1 end)
		assert(style.ObjectPosition.X.Value == 25 and style.ObjectPosition.Y.Value == 75, value)
	end
	assert(warnings == 14)
	local fontPosition=resolve('object-position:1ex');assert(fontPosition.ObjectPosition.X.Value==parent.FontSize*.5 and not fontPosition.ObjectPosition.X.Percent,'Font-relative position uses shared length context')
	parent.ObjectPosition = resolve('object-position: left top').ObjectPosition
	assert(resolve('').ObjectPosition.X.Value == 50, 'object-position is not inherited')
	for _, fit in {'fill', 'contain', 'cover'} do
		assert(not Fit.custom(resolve('object-fit: ' .. fit .. '; object-position: center center')))
	end
	assert(not Fit.needsDimensions(resolve('width: 100px; height: 80px; object-fit: fill; object-position: 2px 3px')))
	for _, css in {'object-fit: none', 'object-fit: scale-down', 'object-fit: cover; object-position: right'} do
		assert(Fit.needsDimensions(resolve('width: 100px; height: 80px;' .. css)))
	end
	local allocated = {}
	local function create(class, owner, props)
		local gui = table.clone(props); gui.ClassName, gui.Parent = class, owner
		table.insert(allocated, gui); return gui
	end
	local renderer = loadRenderTree({create = create, modifier = create})
	local layout = loadWordLayout({['Layout/FontProfiles'] = {face = function(font) return font end},
		['Layout/TextMeasure'] = {measure = function(_, _, size) return {X = 10, Y = size} end}})
	local function build(css)
		local tree = renderer.build(Parser.parse('<p>A<img src="x" width="100" height="80" style="' .. css .. '">B</p>'), {}, error, nil, nil, nil, function() return 'rbxassetid://123' end)
		local run = tree.Children[1].Children[1]
		return run, run.Items[2]
	end
	local function arrange(run, width) layout.arrange(run, width or 1000, 0, 0, function() return true end) end
	local fillRun, fill = build('object-fit: fill; object-position: right bottom; border-radius: 12px')
	arrange(fillRun)
	assert(not fill.ImageClip and fill.ImageCorner.Parent == fill.ImageGui, 'A percentage position cannot shift fill: keep the native image without a render texture')
	assert(fill.ImageGui.Position[1] == 0 and fill.ImageGui.Size[1] == 100)
	local shiftedRun, shifted = build('object-fit: fill; object-position: right 10px bottom 0px')
	arrange(shiftedRun)
	assert(shifted.ImageClip and shifted.ImageGui.Position[1] == -10, 'Pixel offsets on fill still need clipping')
	local run, item = build('object-fit: cover; object-position: right top; border-radius: 12px; padding: 3px; border: 2px solid red')
	item.IntrinsicWidth, item.IntrinsicHeight = 200, 100
	arrange(run)
	assert(item.ImageClip.ClassName == 'CanvasGroup' and item.ImageClip.ClipsDescendants)
	assert(item.ImageClip.Parent == item.BoxGui and item.ImageGui.Parent == item.ImageClip)
	assert(item.ImageCorner.Parent == item.ImageClip and item.ImageCorner.CornerRadius.Offset == 7)
	assert(item.ImageClip.Position[1] == 5 and item.ImageClip.Position[2] == 5)
	assert(item.ImageClip.Size[1] == 100 and item.ImageClip.Size[2] == 80)
	assert(item.ImageGui.Position[1] == -60 and item.ImageGui.Position[2] == 0)
	assert(item.ImageGui.Size[1] == 160 and item.ImageGui.Size[2] == 80)
	assert(item.Width == 110 and run.Items[3].X == 120, 'Object overflow does not advance surrounding text')
	local count = #allocated
	arrange(run, 100); arrange(run)
	assert(#allocated == count and not item.ErrorGui.Visible, 'Reflow reuses clipping and keeps error hidden')
	local plain, square = build('object-fit: none; object-position: left top')
	arrange(plain)
	assert(square.ImageClip.ClassName == 'Frame' and square.ImageClip.ClipsDescendants)
	assert(square.ImageGui.Size[1] == 100 and square.ImageGui.Size[2] == 80, 'Unknown natural size uses attribute fallback')
	square.IntrinsicWidth, square.IntrinsicHeight = 200, 100
	arrange(plain)
	assert(square.ImageGui.Size[1] == 200 and square.ImageGui.Size[2] == 100 and square.Width == 100)
	square.ContentWidth, square.ContentHeight = 0, 0
	square.Style.ObjectFit = 'scale-down'
	local _, _, w, h = Fit.rectangle(square)
	assert(w == 0 and h == 0, 'Zero content sizes stay finite')
	print('Image fitting: five modes, position grammar, crop geometry, clipping, rounding, fallback and reflow passed')
end
