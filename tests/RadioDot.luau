--!strict
return function(RadioDot, View, Parser, loadRenderTree)
	local allocations, writes, releases = 0, 0, 0
	local data
	local function createImage(size)
		allocations += 1
		assert(size.X == 9 and size.Y == 9)
		return {
			WritePixelsBuffer = function(_, origin, dimensions, pixels)
				assert(origin.X == 0 and origin.Y == 0 and dimensions.X == 9 and dimensions.Y == 9)
				writes += 1; data = pixels
			end,
			Destroy = function() releases += 1 end,
		}
	end
	local cache = RadioDot.new(error, createImage)
	assert(allocations == 0, "Pages without radios allocate no dot image")
	local content = cache:Get()
	assert(content == cache:Get() and allocations == 1 and writes == 1)
	local function alpha(x,y) return buffer.readu8(data, (y*9+x)*4+3) end
	local area, blended = 0, false
	for y=0,8 do
		for x=0,8 do
			local a=alpha(x,y)
			assert(a == alpha(8-x,y) and a == alpha(x,8-y) and a == alpha(y,x), "Dot must be centered and symmetric")
			assert(buffer.readu8(data,(y*9+x)*4) == 255, "White mask must support tinting")
			area += a/255
			blended = blended or (a > 0 and a < 255)
		end
	end
	assert(alpha(4,4) == 255 and alpha(0,0) == 0 and blended)
	-- Reference RGB samples: blue (0,117,255) composited over white.
	-- Keep these as image-derived colors, independently of the renderer's alpha table.
	for _,sample in {{4,0,153,200,255},{3,0,185,217,255},{1,1,215,233,255},{2,1,53,146,255},{4,1,0,117,255}} do
		local a=alpha(sample[1],sample[2])/255
		for channel,foreground in {0,117,255} do
			local painted=math.floor(foreground*a+255*(1-a)+.5)
			assert(math.abs(painted-sample[channel+2]) <= 1,"Dot edge must reproduce the supplied HTML reference colors")
		end
	end
	assert(area > 47 and area < 50, "Reference coverage must retain the dot's apparent size")
	local factory={create=function(class,parent,props)
		local gui=table.clone(props); gui.ClassName=class; gui.Parent=parent; return gui
	end}
	local renderer=loadRenderTree(factory)
	local tree=renderer.build(Parser.parse('<input type="radio" checked><input type="radio" style="display:block" checked><div style="display:flex"><input type="radio" checked></div>'),{},error,nil,nil,nil,nil,nil,nil,nil,cache)
	for _,c in tree.Controls do
		local item=c.Item
		assert(item.DotImage and item.Dot.ClassName == "ImageLabel" and item.Dot.ImageContent == content,
			"Inline, block and flex radios share the page image")
		for _,state in {{false,false,false},{true,false,false},{true,true,false},{true,true,true}} do
			c.Hovered,c.Pressed,c.Disabled=state[1],state[2],state[3]
			View.paint(item)
			assert(item.Dot.ImageColor3 == item.Stroke.Color and item.Dot.ImageColor3 == item.BoxGui.BackgroundColor3,
				"Image tint must follow ring color for hover, press and disabled states")
			assert(item.Dot.BackgroundTransparency == 1)
		end
		c.Checked=false; View.paint(item); assert(not item.Dot.Visible)
	end
	assert(allocations == 1 and writes == 1, "State changes must not redraw or allocate images")
	cache:Destroy(); cache:Destroy()
	assert(releases == 1 and cache:Get() == nil)
	local independent=RadioDot.new(error,createImage)
	assert(independent:Get() ~= content and allocations == 2, "Pages own independent image lifetimes")
	independent:Destroy()
	for _,failWrite in {false,true} do
		local tries,warnings,destroyed=0,0,0
		local failed=RadioDot.new(function() warnings+=1 end,function()
			tries+=1
			if not failWrite then return nil end
			return {WritePixelsBuffer=function() error("write failed") end,Destroy=function() destroyed+=1 end}
		end)
		assert(failed:Get() == nil and failed:Get() == nil and tries == 1 and warnings == 1)
		local fallback=renderer.build(Parser.parse('<input type="radio" checked>'),{},error,nil,nil,nil,nil,nil,nil,nil,failed).Controls[1].Item
		assert(not fallback.DotImage and fallback.Dot.ClassName == "Frame" and fallback.Dot.Visible)
		failed:Destroy(); assert(destroyed == (if failWrite then 1 else 0))
	end
	print("Radio dots: fractional alpha coverage, centering, shared images, tint states, lazy allocation, fallback and disposal passed")
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
      cache=RadioDot.new(function()warnings+=1 end,function()
       local image={Ordinal=#images+1};table.insert(images,image)
       function image:Destroy()assert(not self.Freed,'Native image destroyed twice');self.Freed=true;destroyed+=1 end
       function image:WritePixelsBuffer()
        writes+=1;if closed then lateWrites+=1 end
        if phase=='upload'and self.Ordinal==triggerAt then close();if throwAfter then error('upload cancelled')end end
       end
       if phase=='allocate'and image.Ordinal==triggerAt then close()end
       return image
      end)
      assert(cache:Get()==nil,'Destroyed cache must not publish returned content')
      assert(#images==triggerAt and destroyed==#images,'Each late or previously owned native image is released once, with no extra allocation')
      assert(lateWrites==0 and lateContent==0 and warnings==0,'Destroyed cache performs no later upload/content/fallback publication')
      local allocated=#images;assert(cache:Get()==nil and #images==allocated,'Destroyed cache remains empty');cache:Destroy()
      assert(destroyed==allocated,'Repeated cleanup is harmless')
     end
    end
   end
   for _,phase in {'allocate','upload','content'}do
    local cache;local attempts,destroyed,warnings=0,0,0
    Content.fromObject=function(image)if phase=='content'then error('content unavailable')end;return originalContent(image)end
    cache=RadioDot.new(function()warnings+=1 end,function()
     attempts+=1;if phase=='allocate'then return nil end
     return {Destroy=function()destroyed+=1 end,WritePixelsBuffer=function()if phase=='upload'then error('upload unavailable')end end}
    end)
    assert(cache:Get()==nil and cache:Get()==nil and attempts==1 and warnings==1,'Live allocation/upload/content failures retain one fallback attempt')
    cache:Destroy();assert(destroyed==(if phase=='allocate'then 0 else 1),'Failure releases partial ownership exactly once')
   end
  end)
  Content.fromObject=originalContent
  assert(ok,message)
 end

end
