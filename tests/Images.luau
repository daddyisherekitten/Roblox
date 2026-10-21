--!strict
return function(Parser: any, Style: any, loadRenderTree: any, loadWordLayout: any, loadImageLoad: any)
 local fixtureElement=require('DOM/Node').element
	local allocated, warnings, measurements = {}, {}, 0
	local renderer = loadRenderTree({create = function(class, parent, props)
		local gui = table.clone(props)
		gui.ClassName, gui.Parent = class, parent
		table.insert(allocated, gui)
		return gui
	end})
	local function warn(message) table.insert(warnings, message) end
	local function build(content, css)
		local tree = renderer.build(Parser.parse('<p style="' .. (css or '') .. '">' .. content .. '</p>'), {}, warn,
			function(font) return font end, nil, nil, function(src) return if src == "scene.png" then "rbxassetid://123" else nil end)
		return tree.Children[1].Children[1], tree
	end
	local layout = loadWordLayout({
		["Layout/FontProfiles"] = {face = function(font) return font end},
		["Layout/TextMeasure"] = {measure = function(text, _, size)
			assert(type(text) == "string", "Image content must never enter native text measurement")
			measurements += 1
			return {X = if text == " " then 5 else 20, Y = size}
		end},
	})
	local function arrange(run, width) return layout.arrange(run, width or 200, 0, 0, function() return true end) end
	local run, tree = build('AA <img src="scene.png" alt="A &amp; B" width="40" height="30"> BB')
	assert(#warnings == 0 and #run.Items == 3 and #tree.ImageItems == 1)
	local a, img, b = run.Items[1], run.Items[2], run.Items[3]
	assert(img.Kind == "Image" and img.Source == "rbxassetid://123" and img.AltGui.Text == "A & B")
	assert(img.ImageGui.ScaleType == Enum.ScaleType.Stretch and not img.AltGui.Visible)
	assert(not img.ErrorGui.Visible, "Pending images do not show an error icon")
	local height = arrange(run)
	assert(img.Width == 40 and img.Height == 30 and img.X == 25 and b.X == 70)
	assert(img.Y + img.Height == a.Y + a.Baseline and height > 30, "Images rest on the text baseline and retain the line descender gap")
	assert(img.Gui.FontFace == nil and img.Gui.TextSize == nil)
	local count, allocations, gui = measurements, #allocated, img.Gui
	arrange(run, 65)
	assert(img.LineIndex == 1 and b.LineIndex == 2)
	arrange(run, 64)
	assert(img.LineIndex == 2 and img.X == 0, "Space at a wrapped image is collapsed")
	arrange(run)
	assert(measurements == count and #allocated == allocations and img.Gui == gui)
	assert(not img.ErrorGui.Visible, "Layout must not turn the error icon back on")
	local adjacent = build('AA<img src="scene.png" width="40" height="30">BB')
	arrange(adjacent, 40)
	assert(adjacent.Items[2].LineIndex == 2 and adjacent.Items[3].LineIndex == 3, "Replaced inline elements permit breaks without invented spaces")
	local nowrap = build('AA<img src="scene.png" width="40" height="30">BB', 'white-space: nowrap')
	arrange(nowrap, 40)
	assert(nowrap.Items[3].LineIndex == 1 and nowrap.Items[3].X == 60)
	for fit, expected in {contain = Enum.ScaleType.Fit, cover = Enum.ScaleType.Crop, fill = Enum.ScaleType.Stretch} do
		local fitted = build('<img src="scene.png" width="400" height="200" style="width: 50%; height: auto; max-width: 80px; object-fit: ' .. fit .. '">')
		arrange(fitted, 200)
		local image = fitted.Items[1]
		assert(image.Width == 80 and image.Height == 40 and image.ImageGui.ScaleType == expected)
		arrange(fitted, 100)
		assert(image.Width == 50 and image.Height == 25)
	end
	local zero = build('<img src="scene.png" width="0" height="30">')
	arrange(zero)
	assert(zero.Items[1].Width == 0 and not zero.Items[1].Gui.Visible)
	local hidden = build('Hel<img src="missing" style="display: none">lo')
	assert(#hidden.Items == 1 and hidden.Items[1].Text == "Hello" and #warnings == 0)
	local missing = build('<img src="absent" alt="Missing" width="60" height="40">')
	arrange(missing)
	assert(#warnings == 1 and missing.Items[1].AltGui.Visible and missing.Items[1].ImageGui == nil)
	assert(missing.Items[1].FallbackGui.Visible and missing.Items[1].ErrorGui.Image == "rbxassetid://112299903593689")
	assert(missing.Items[1].TextFallback and missing.Items[1].ErrorGui.Visible)
	assert(missing.Items[1].Width==36 and missing.Items[1].Height==missing.Items[1].TextSize,"Inline alt fallback ignores attribute dimensions and reserves a 16px error icon")
	local fallback = build('AA <img src="absent" alt="Missing" width="200" height="80" style="width: 300px; min-width: 300px; height: 100px; border: 1px solid gray; padding: 3px; margin: 9px 2px"> BB')
	local fallbackHeight = arrange(fallback,400)
	local text, replacement, following = fallback.Items[1], fallback.Items[2], fallback.Items[3]
	assert(replacement.Width==312 and replacement.BoxHeight==replacement.TextSize+8,"Inline broken image honors CSS min-width and box edges")
	assert(replacement.Y + replacement.Baseline == text.Y + text.Baseline, "Alt shares the surrounding text baseline")
	assert(replacement.BoxGui.Position[2]+replacement.FallbackGui.Position[2]+replacement.AltGui.Position[2]==13)
	assert(fallbackHeight>=42 and following.X==342,"Broken inline image keeps its margins and shifts following content consistently")
	local measured = measurements
	arrange(fallback, 50); arrange(fallback)
	assert(measurements == measured, "Alt measurements survive reflow")
	local absentAlt = build('<img src="absent" width="60" height="40">')
	assert(absentAlt.Items[1].ErrorGui and not absentAlt.Items[1].AltGui)
	local emptyAlt = build('<img src="absent" alt="" width="60" height="40">')
	assert(not emptyAlt.Items[1].ErrorGui and not emptyAlt.Items[1].FallbackGui, "Explicit empty alt suppresses the broken-image icon")
	local decorated = build('AA <img src="scene.png" width="40" height="30"> BB', 'text-decoration: underline')
	arrange(decorated)
	assert(decorated.Items[1].DecorationFrames and decorated.Items[3].DecorationFrames)
	for _, line in decorated.Items[2].DecorationFrames or {} do
		assert(line.Position[1] + line.Size[1] <= 0, "Only the preceding whitespace is decorated, never the image itself")
	end
	local automatic = build('<img src="scene.png" width="400" height="200" style="width: auto; height: auto; max-width: 80px">')
	arrange(automatic)
	assert(automatic.Items[1].Width == 80 and automatic.Items[1].Height == 40)
	local parent = {Font = "Arial", FontSize = 16, Color = Color3.new(0, 0, 0)}
	local style = Style.resolve(fixtureElement("img",{width = "400", height = "200", style = "width: 80px; height: auto; object-fit: cover"}), parent, warn, true)
	assert(style.Width.Value == 80 and style.Height == nil and style.ObjectFit == "cover")
	local before = #warnings
	Style.resolve(fixtureElement("span",{style = "width: 40px"}), parent, warn, true)
	assert(#warnings == before + 1, "Image sizing must not silently enable widths on inline text")
	Style.resolve(fixtureElement("img",{style = "object-fit: bogus; padding: 2px; display: block"}), parent, warn, true)
	assert(#warnings == before + 2, "Unsupported object-fit is diagnosed; image display:block and padding are supported")
	-- Success preserves the box; definitive failure with alt requests reflow.
	local queue, active, requests = {}, true, 0
	local callback
	local success, failure = {Name = "Success"}, {Name = "Failure"}
	local function mockImage(loaded)
		local handlers = {}
		local gui = {IsLoaded = loaded, Image = "rbxassetid://123"}
		function gui:GetPropertyChangedSignal(property)
			assert(property == "IsLoaded")
			return {Connect = function(_, handler)
				handlers[handler] = true
				return {Disconnect = function() handlers[handler] = nil end}
			end}
		end
		function gui:Complete()
			self.IsLoaded = true
			for handler in handlers do handler() end
		end
		function gui:ConnectionCount()
			local count = 0
			for _ in handlers do count += 1 end
			return count
		end
		return gui
	end
	local loader = loadImageLoad({GetService = function()
		return {PreloadAsync = function(_, targets, report)
			requests += 1
			assert(#targets == 1 and targets[1].Image == "rbxassetid://123")
			if callback then callback(report) else report("rbxassetid://123", success) end
		end}
	end}, {defer = function(fn) table.insert(queue, fn) end}, {AssetFetchStatus = {Success = success}})
	local image1 = {Source = "rbxassetid://123", ImageGui = mockImage(true), AltGui = {}, FallbackGui = {}, ErrorGui = {}}
	local image2 = {Source = "rbxassetid://123", ImageGui = mockImage(false), Alt = "Landschaft", AltGui = {}, FallbackGui = {}, ErrorGui = {}}
	local targets = {image1, image2}
	local stop = loader.start(targets, function() return active end, warn)
	assert(requests == 0)
	table.remove(queue, 1)()
	assert(requests == 1 and #targets == 2 and targets[1]==image1 and targets[2]==image2 and image1.ImageGui.Visible and not image1.AltGui.Visible,
		"Preload retains the renderer's image registry and item identities")
	assert(image2.ImageGui.Visible and not image2.AltGui.Visible and not image2.ErrorGui.Visible)
	assert(not image2.TextFallback, "A completed request without IsLoaded is still pending, not broken")
	assert(not image1.FallbackGui.Visible and not image2.FallbackGui.Visible)
	assert(not image1.ErrorGui.Visible, "Loaded images hide the icon itself as well as its parent")
	image2.ImageGui:Complete()
	assert(image2.ImageGui.Visible and not image2.AltGui.Visible, "Late IsLoaded updates remove fallback without hiding the image permanently")
	assert(not image2.FallbackGui.Visible, "A late successful load also removes the error icon")
	stop(); stop()
	assert(image1.ImageGui:ConnectionCount() == 0 and image2.ImageGui:ConnectionCount() == 0)
	active = false
	local inactive, inactiveLifecycle = loader.start({image1}, function() return active end, warn)
	assert(inactive == nil and inactiveLifecycle, "Inactive pages return an empty incremental lifecycle without registering images")
	assert(#queue == 0, "Inactive pages schedule no asset request or deferred no-op")
	assert(requests == 1)
	assert(image1.ImageGui:ConnectionCount() == 0 and image2.ImageGui:ConnectionCount() == 0, "Inactive pages attach no IsLoaded listeners")
	inactiveLifecycle:Destroy(); inactiveLifecycle:Destroy()
	assert(#queue == 0 and requests == 1 and image1.ImageGui:ConnectionCount() == 0 and image2.ImageGui:ConnectionCount() == 0, "Inactive lifecycle cleanup is idempotent and remains allocation-free")
	active = true
	callback = function() active = false; image1.ImageGui.Visible = nil end
	stop = loader.start({image1}, function() return active end, warn)
	table.remove(queue, 1)()
	assert(image1.ImageGui.Visible == nil, "Page disposed during preload must not be touched")
	image1.ImageGui:Complete()
	assert(image1.ImageGui.Visible == nil)
	stop()
	active = true
	image2.ImageGui.IsLoaded = false
	callback = function() error("asset request failed") end
	before = #warnings
	stop = loader.start({image2}, function() return active end, warn)
	table.remove(queue, 1)()
	assert(not image2.AltGui.Visible and not image2.ErrorGui.Visible and #warnings == before + 1, "A preload exception alone does not prove the image is broken")
	stop()
	callback = function(report)
		report("rbxassetid://123", failure)
		report("rbxassetid://123", failure)
	end
	before = #warnings
	local changes = 0
	stop = loader.start({image1, image2}, function() return active end, warn, function() changes += 1 end)
	table.remove(queue, 1)()
	assert(#warnings == before + 1 and warnings[#warnings]:find("rbxassetid://123", 1, true))
	assert(warnings[#warnings]:find("Failure", 1, true), "Non-throwing asset failure reports its ID and status once")
	assert(image2.TextFallback and not image1.TextFallback and changes == 1, "Only an unloaded alt image changes size after failure")
	assert(image2.AltGui.Visible and image2.ErrorGui.Visible and not image1.ErrorGui.Visible)
	image2.ImageGui:Complete()
	assert(not image2.TextFallback and changes == 2, "Late success restores the image dimensions through reflow")
	assert(not image2.AltGui.Visible and not image2.ErrorGui.Visible and not image2.FallbackGui.Visible)
	stop()
	image1.ImageGui.IsLoaded = false
	stop = loader.start({image1}, function() return active end, warn)
	table.remove(queue, 1)()
	assert(image1.ErrorGui.Visible and image1.FallbackGui.Visible, "Confirmed failures without alt retain the error icon")
	image1.ImageGui:Complete()
	assert(not image1.ErrorGui.Visible and not image1.FallbackGui.Visible, "Recovery directly hides the error icon")
	stop()
	image2.FilterReady=true; image2.ImageGui.IsLoaded=false
	stop=loader.start({image2},function() return active end,warn)
	table.remove(queue,1)()
	assert(not image2.TextFallback and not image2.FallbackGui.Visible,'Filtered content survives failure of the original asset preload')
	stop(); image2.FilterReady=nil
	callback=nil
	local empty,lifecycle=loader.start({},function()return active end,warn)
	assert(empty==nil and lifecycle,"Empty registries retain an incremental loader API without scheduling")
	local before=requests
	lifecycle:Add({image1});lifecycle:Remove({image1});table.remove(queue,1)()
	assert(requests==before and image1.ImageGui:ConnectionCount()==0,"Removing an image cancels its deferred preload before allocation")
	lifecycle:Add({image1});table.remove(queue,1)();assert(requests==before+1)
	lifecycle:Remove({image1});assert(image1.ImageGui:ConnectionCount()==0)
	lifecycle:Destroy();lifecycle:Destroy()
	print("Images: mapping, CSS sizes/ratio, native fit, inline baseline/whitespace/wrapping, reuse, alt and preload lifecycle passed")
end
