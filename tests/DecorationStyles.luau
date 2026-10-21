--!strict
return function(Style, Pixels, Patterns, loadTextDecoration, SkipInk, Parser, loadRenderTree)
 local fixtureElement=require('DOM/Node').element
	local base = {Font = "Inter", FontSize = 24, Color = Color3.new(0, 0, 0)}
	local function resolve(css, parent)
		return Style.resolve(fixtureElement("u",{style = css}), parent or base, error, true)
	end
	for _, name in {"solid", "double", "dotted", "dashed", "wavy"} do
		local origin = resolve("text-decoration-style: " .. name)
		assert(origin.Decorations[1].Style == name)
		local child = resolve("text-decoration-style: solid", origin)
		assert(child.Decorations[1] == origin.Decorations[1] and child.Decorations[2].Style == "solid")
	end
	assert(resolve("text-decoration-style: wavy; text-decoration: underline").Decorations[1].Style == "solid")
	assert(resolve("text-decoration-style: wavy !important; text-decoration: underline").Decorations[1].Style == "wavy")
	assert(resolve("text-decoration-style: dotted", resolve("text-decoration-style: wavy")).Decorations[2].Style == "dotted")
	for _, css in {"underline wavy red", "red underline wavy", "wavy red underline"} do
		local d = resolve("text-decoration: " .. css).Decorations[1]
		assert(d.Underline and d.Style == "wavy" and d.Color == Color3.fromRGB(255, 0, 0))
	end
	local shorthand = resolve("text-decoration: underline line-through dashed rgba(255, 0, 0, .5) 10%").Decorations[1]
	assert(shorthand.Underline and shorthand.Strike and shorthand.Style == "dashed" and shorthand.Alpha == .5 and shorthand.Thickness == 2)
	assert(resolve("text-decoration: red wavy").TextDecoration.Underline == nil, "Omitted lines default to none, even on u")
	assert(#resolve("text-decoration: none red wavy").Decorations == 0)
	assert(resolve("text-decoration: underline currentcolor double; color: blue").Decorations[1].Color == Color3.fromRGB(0, 0, 255))
	assert(resolve("text-decoration: underline transparent").Decorations[1].Alpha == 0)
	assert(resolve("text-decoration: underline wavy red; text-decoration-style: double").Decorations[1].Style == "double")
	assert(resolve("text-decoration: underline wavy red !important; text-decoration-style: double").Decorations[1].Style == "wavy")
	assert(resolve("text-decoration-style: double !important; text-decoration: underline wavy red").Decorations[1].Style == "double")
	assert(resolve("text-decoration: underline wavy red 3px; text-decoration: underline auto").Decorations[1].Thickness == 1)
	local compiled = Style.compile("text-decoration: underline wavy red 10%")
	local a = Style.resolve(fixtureElement("span",{}), base, error, true, compiled)
	local b = Style.resolve(fixtureElement("span",{}), {FontSize = 50, Font = "Inter", Color = base.Color}, error, true, compiled)
	assert(a.Decorations[1].Thickness == 2 and b.Decorations[1].Thickness == 5, "Compiled percentages remain relative to each origin")
	for _, bad in {"underline red blue", "underline solid wavy", "none underline", "none none", "underline 1px 2px", "underline -1px", "underline from-font", "underline rgba(255, 0, 0, .5"} do
		local errors = 0
		local preserved = Style.resolve(fixtureElement("u",{style = "text-decoration: underline wavy red; text-decoration: " .. bad}), base, function() errors += 1 end, true)
		assert(errors == 1 and preserved.Decorations[1].Style == "wavy", "Invalid shorthand is ignored as a whole: " .. bad)
	end
	for _, bad in {"underline red", "underline wavy", "underline 2px"} do
		local errors = 0
		Style.resolve(fixtureElement("u",{style = "text-decoration-line: " .. bad}), base, function() errors += 1 end, true)
		assert(errors == 1, "The line longhand accepts no other components")
	end
	local warnings = {}
	local invalid = Style.resolve(fixtureElement("u",{style = "text-decoration-style: dashed; text-decoration-style: invalid"}), base, function(m) table.insert(warnings, m) end, true)
	assert(invalid.Decorations[1].Style == "dashed" and #warnings == 1)
	for _, style in {"dotted", "dashed", "wavy"} do
		for _, t in {1, 2, 4, 32} do
			local w, h = Pixels.size(style, t)
			local data = Pixels.render(style, t)
			assert(buffer.len(data) == w * h * 4)
			local visible, clear = false, false
			for offset = 0, buffer.len(data) - 4, 4 do
				assert(buffer.readu8(data, offset) == 255)
				local alpha = buffer.readu8(data, offset + 3)
				visible = visible or alpha > 0; clear = clear or alpha == 0
			end
			assert(visible and clear, "Every tile must contain visible strokes and transparent gaps")
		end
	end
	assert(Pixels.size("wavy", 33) == nil and Pixels.size("dotted", 0) == nil)
	local dash = Pixels.render("dashed", 2)
	assert(buffer.readu8(dash, 5 * 4 + 3) == 255 and buffer.readu8(dash, 6 * 4 + 3) == 0)
	local created, messages = {}, {}
	local function create(size)
		local image = {Size = size, Writes = 0, DestroyCalls = 0}
		function image:WritePixelsBuffer(position, extent, data)
			assert(position.X == 0 and position.Y == 0 and extent == size)
			assert(buffer.len(data) == size.X * size.Y * 4)
			self.Writes += 1
		end
		function image:Destroy() self.DestroyCalls += 1 end
		table.insert(created, image)
		return image
	end
	local cache = Patterns.new(function(m) table.insert(messages, m) end, create)
	local wave = cache:Get("wavy", 2)
	assert(wave == cache:Get("wavy", 2) and #created == 1 and created[1].Writes == 1)
	local factory = {create = function(class, parent, props)
		local gui = table.clone(props); gui.ClassName, gui.Parent = class, parent
		return gui
	end}
	local painter = loadTextDecoration(factory)
	local origin = resolve("text-decoration: underline line-through wavy red 2px")
	local d = origin.Decorations[1]
	local item = {Kind = "Word", Text = "p", Style = origin, Gui = {}, X = 5, Width = 30, Baseline = 18, LineIndex = 1,
		SkipInkTop = 8, SkipInkBottom = 23, SkipInkCuts = {{Left = 8, Right = 12}}}
	local run = {Items = {item}, Style = origin, DecorationPatterns = cache}
	painter.draw(run)
	assert(#item.DecorationFrames == 3, "Two underline segments plus uninterrupted strike")
	assert(item.DecorationFrames[1].Size[2] == 6 and item.DecorationFrames[3].Position[2] == item.Baseline + d.StrikeOffset - 2)
	assert(item.DecorationImages[1].Position[1] == -5 and item.DecorationImages[2].Position[1] == -1, "Cuts preserve phase in the shared wave")
	local frames, labels = table.clone(item.DecorationFrames), table.clone(item.DecorationImages)
	item.X = 20
	painter.draw(run)
	assert(#created == 1 and item.DecorationFrames[1] == frames[1] and item.DecorationImages[1] == labels[1])
	assert(item.DecorationImages[1].Position[1] == -4, "Reflow updates phase without redrawing image pixels")
	local nextWord = {Kind = "Word", Style = origin, SpaceStyle = origin, Gui = {}, X = 55, Width = 20, Baseline = 18, LineIndex = 1}
	run.Items = {item, nextWord}
	painter.draw(run)
	assert(nextWord.DecorationFrames[1].Position[1] == -5 and nextWord.DecorationImages[1].Position[1] == -2)
	assert(nextWord.DecorationImages[1].ImageContent == item.DecorationImages[1].ImageContent and #created == 1, "Words and their intervening spaces share one continuous tile")
	run.Items = {item}
	item.Style = resolve("text-decoration-style: double; text-decoration-thickness: 2px")
	painter.draw(run)
	assert(item.DecorationFrames[1].Size[2] == 2 and not labels[1].Visible)
	assert(item.DecorationFrames[3].Size[1] == 30, "Lower double stroke closes when below descender")
	assert(item.DecorationFrames[3].Position[2] == 24)
	item.Style = resolve("text-decoration-style: wavy; text-decoration-thickness: 2px; text-underline-offset: 8px")
	painter.draw(run)
	assert(item.DecorationFrames[1].Size[1] == 30 and not item.DecorationFrames[2].Visible)
	assert(not SkipInk.intersects(item, item.Style.Decorations[1]))
	-- A negative offset may place only the bottom of a wave in the ink range.
	local high = resolve("text-decoration-style: wavy; text-decoration-thickness: 2px; text-underline-offset: -13px").Decorations[1]
	assert(SkipInk.intersects(item, high) and not SkipInk.intersects(item, high, 0, 2))
	item.Style = resolve("text-decoration: none")
	painter.draw(run)
	for _, frame in item.DecorationFrames do assert(not frame.Visible) end
	local tree = loadRenderTree(factory).build(Parser.parse('<p><u style="text-decoration-style: dashed">Hello world</u></p>'), {}, error, nil, cache)
	local function checkRuns(node)
		if node.Kind == "Words" then assert(node.DecorationPatterns == cache) end
		for _, child in node.Children or {} do checkRuns(child) end
	end
	checkRuns(tree)
	for _, name in {"solid", "double", "dotted", "dashed", "wavy"} do
		item.Style = resolve("text-decoration-line: overline; text-decoration-style: " .. name .. "; text-decoration-thickness: 2px")
		painter.draw(run)
		local bottom = item.Baseline + item.Style.Decorations[1].OverlineOffset + 2
		assert(item.DecorationFrames[1].Position[2] + item.DecorationFrames[1].Size[2] == bottom)
		assert(item.DecorationFrames[1].Size[1] == item.Width, "Overlines stay continuous across descender cuts")
		if name == "double" then
			assert(item.DecorationFrames[2].Visible and item.DecorationFrames[2].Position[2] == bottom - 6)
		else assert(not item.DecorationFrames[2].Visible) end
	end
	cache:Destroy(); cache:Destroy()
	assert(created[1].DestroyCalls == 1 and cache:Get("wavy", 2) == nil)
	local attempts = 0
	local unavailable = Patterns.new(function(m) table.insert(messages, m) end, function() attempts += 1; return nil end)
	assert(unavailable:Get("wavy", 1) == nil and unavailable:Get("dotted", 1) == nil and attempts == 1 and #messages == 1)
	local faulty = Patterns.new(function(m) table.insert(messages, m) end, function(size)
		local image = create(size)
		function image:WritePixelsBuffer() error("write failed") end
		return image
	end)
	assert(faulty:Get("dashed", 1) == nil and created[#created].DestroyCalls == 1)
	local limited = Patterns.new(function(m) table.insert(messages, m) end, create)
	for t = 1, 16 do assert(limited:Get("dotted", t)) end
	local count = #created
	assert(limited:Get("dotted", 17) == nil and limited:Get("dotted", 33) == nil and #created == count)
	limited:Destroy()
	local pixelLimited = Patterns.new(function(m) table.insert(messages, m) end, create)
	assert(pixelLimited:Get("wavy", 32) and pixelLimited:Get("wavy", 31))
	assert(pixelLimited:Get("wavy", 30) == nil, "Pixel budget applies before the entry limit")
	pixelLimited:Destroy()
	for _, image in created do assert(image.DestroyCalls == 1) end
	-- API failure paints a usable solid stroke, without creating image labels.
	item.Style = resolve("text-decoration-style: wavy")
	run.DecorationPatterns = unavailable
	painter.draw(run)
	assert(item.DecorationFrames[1].BackgroundTransparency == 0 and not labels[1].Visible)
	print("Decoration styles: CSS, raster tiles, shared cache/cleanup, phase/reflow, double/skip-ink and fallback passed")
 do
  local originalContent=Content.fromObject
  local ok,message=pcall(function()
   for _,phase in {'allocate','upload','content'}do
    for triggerAt=1,1 do
     for _,throwAfter in {false,true}do
      if phase=='allocate'and throwAfter then continue end
      local cache;local images={};local closed=false;local destroyed,writes,lateWrites,lateContent,warnings=0,0,0,0,0
      local function close()closed=true;cache:Destroy()end
      Content.fromObject=function(image)
       if closed then lateContent+=1 end
       if phase=='content'and image.Ordinal==triggerAt then close();if throwAfter then error('content cancelled')end end
       return originalContent(image)
      end
      cache=Patterns.new(function()warnings+=1 end,function()
       local image={Ordinal=#images+1};table.insert(images,image)
       function image:Destroy()assert(not self.Freed,'Native image destroyed twice');self.Freed=true;destroyed+=1 end
       function image:WritePixelsBuffer()
        writes+=1;if closed then lateWrites+=1 end
        if phase=='upload'and self.Ordinal==triggerAt then close();if throwAfter then error('upload cancelled')end end
       end
       if phase=='allocate'and image.Ordinal==triggerAt then close()end
       return image
      end)
      assert(cache:Get('wavy',1)==nil,'Destroyed cache must not publish returned content')
      assert(#images==triggerAt and destroyed==#images,'Each late or previously owned native image is released once, with no extra allocation')
      assert(lateWrites==0 and lateContent==0 and warnings==0,'Destroyed cache performs no later upload/content/fallback publication')
      local allocated=#images;assert(cache:Get('wavy',1)==nil and #images==allocated,'Destroyed cache remains empty');cache:Destroy()
      assert(destroyed==allocated,'Repeated cleanup is harmless')
     end
    end
   end
   for _,phase in {'allocate','upload','content'}do
    local cache;local attempts,destroyed,warnings=0,0,0
    Content.fromObject=function(image)if phase=='content'then error('content unavailable')end;return originalContent(image)end
    cache=Patterns.new(function()warnings+=1 end,function()
     attempts+=1;if phase=='allocate'then return nil end
     return {Destroy=function()destroyed+=1 end,WritePixelsBuffer=function()if phase=='upload'then error('upload unavailable')end end}
    end)
    assert(cache:Get('wavy',1)==nil and cache:Get('wavy',1)==nil and attempts==1 and warnings==1,'Live allocation/upload/content failures retain one fallback attempt')
    cache:Destroy();assert(destroyed==(if phase=='allocate'then 0 else 1),'Failure releases partial ownership exactly once')
   end
  end)
  Content.fromObject=originalContent
  assert(ok,message)
 end

 do
  local cache;local allocated,destroyed,writes=0,0,0
  cache=Patterns.new(error,function()
   allocated+=1
   return {Destroy=function()destroyed+=1 end,WritePixelsBuffer=function()writes+=1 end}
  end)
  require('WorkContext').with(function()cache:Destroy()end,function()
   assert(cache:Get('wavy',1)==nil,'A texture checkpoint may cancel its cache before the first native upload')
  end)
  assert(allocated==1 and destroyed==1 and writes==0,'Cancelled texture checkpoint releases its unpublished image without uploading')
 end

end
