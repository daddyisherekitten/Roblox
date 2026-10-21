--!strict
return function(Icons: any, Parser: any, loadRenderTree: any, Disclosure: any)
	local allocations, releases, pixels = 0, 0, {}
	local function createImage(size: any): any
		allocations += 1
		assert(size.X == 12 and size.Y == 12)
		local index = allocations
		return {
			WritePixelsBuffer = function(_, origin, dimensions, data)
				assert(origin.X == 0 and origin.Y == 0 and dimensions.X == 12 and dimensions.Y == 12)
				pixels[index] = data
			end,
			Destroy = function() releases += 1 end,
		}
	end
	local icons = Icons.new(error, createImage)
	assert(allocations == 0, 'Pages without details allocate no marker images')
	local closed, open = icons:Get(false), icons:Get(true)
	assert(closed and open and closed ~= open and allocations == 2 and icons:Get(false) == closed)
	local function alpha(data: buffer, x: number, y: number): number
		return buffer.readu8(data, (y * 12 + x) * 4 + 3)
	end
	local fractional = false
	for y = 0, 11 do for x = 0, 11 do
		local a = alpha(pixels[1], x, y)
		assert(a == alpha(pixels[2], 11 - y, x), 'Open triangle is a clockwise rotation of the closed triangle')
		if a > 0 and a < 255 then fractional = true end
	end end
	assert(fractional, 'The mask preserves antialiased edges')
	local factory = {create = function(class: string, parent: any, props: any)
		local gui = table.clone(props)
		gui.ClassName, gui.Parent = class, parent
		if parent then parent.Children = parent.Children or {}; table.insert(parent.Children, gui) end
		return gui
	end}
	local renderer = loadRenderTree(factory)
	local tree = renderer.build(Parser.parse('<details><summary id="closed">Closed</summary>Text</details><details open><summary id="open">Open</summary>Text</details>'),
		{}, error, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, icons)
	local markers = {}
	for _, disclosure in tree.Disclosures do table.insert(markers, disclosure) end
	assert(#markers == 2 and allocations == 2, 'All summaries reuse the same two mask images')
	for _, disclosure in markers do
		local marker = disclosure.Marker
		local image
		for _, child in marker.Gui.Children or {} do if child.ClassName == 'ImageLabel' then image = child end end
		assert(image and image.ImageContent == (if disclosure.Open then open else closed))
		assert(marker.Gui.Rotation == 0 and marker.Kind == 'disclosure')
		marker:Arrange(disclosure.Summary.Style, 18, 0)
		assert(marker.Gui.Size[1] == 11 and marker.Gui.Size[2] == 11, 'The 16px marker is painted on an integer pixel grid')
		assert(image.ImageColor3 == disclosure.Summary.Style.Color and image.ImageTransparency == 0)
		local tinted = table.clone(disclosure.Summary.Style)
		tinted.Color, tinted.ColorAlpha = Color3.fromRGB(30, 60, 90), .4
		marker:Repaint(tinted)
		assert(image.ImageColor3 == tinted.Color and math.abs(image.ImageTransparency - .6) < .00001)
		local before = disclosure.Open
		Disclosure.toggle(disclosure)
		assert(disclosure.Open ~= before and image.ImageContent == (if disclosure.Open then open else closed) and allocations == 2)
	end
	icons:Destroy(); icons:Destroy()
	assert(releases == 2 and icons:Get(false) == nil)
	local warnings = 0
	local failed = Icons.new(function() warnings += 1 end, function() return nil end)
	assert(failed:Get(false) == nil and failed:Get(true) == nil and warnings == 1)
	local fallback = renderer.build(Parser.parse('<details><summary>Fallback</summary></details>'),
		{}, error, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, failed)
	local state
	for _, disclosure in fallback.Disclosures do state = disclosure end
	assert(state and state.Marker.Gui.Rotation == 0)
	Disclosure.toggle(state)
	assert(state.Marker.Gui.Rotation == 90, 'Unavailable image falls back to the existing native-frame arrow')
	failed:Destroy()
	print('Disclosure icons: shared antialiased masks, integer sizing, state changes, fallback and cleanup passed')
 do
  local originalContent=Content.fromObject
  local ok,message=pcall(function()
   for _,phase in {'allocate','upload','content'}do
    for triggerAt=1,2 do
     for _,throwAfter in {false,true}do
      if phase=='allocate'and throwAfter then continue end
      local cache;local images={};local closed=false;local destroyed,writes,lateWrites,lateContent,warnings=0,0,0,0,0
      local function close()closed=true;cache:Destroy()end
      Content.fromObject=function(image)
       if closed then lateContent+=1 end
       if phase=='content'and image.Ordinal==triggerAt then close();if throwAfter then error('content cancelled')end end
       return originalContent(image)
      end
      cache=Icons.new(function()warnings+=1 end,function()
       local image={Ordinal=#images+1};table.insert(images,image)
       function image:Destroy()assert(not self.Freed,'Native image destroyed twice');self.Freed=true;destroyed+=1 end
       function image:WritePixelsBuffer()
        writes+=1;if closed then lateWrites+=1 end
        if phase=='upload'and self.Ordinal==triggerAt then close();if throwAfter then error('upload cancelled')end end
       end
       if phase=='allocate'and image.Ordinal==triggerAt then close()end
       return image
      end)
      assert(cache:Get(false)==nil,'Destroyed cache must not publish returned content')
      assert(#images==triggerAt and destroyed==#images,'Each late or previously owned native image is released once, with no extra allocation')
      assert(lateWrites==0 and lateContent==0 and warnings==0,'Destroyed cache performs no later upload/content/fallback publication')
      local allocated=#images;assert(cache:Get(false)==nil and #images==allocated,'Destroyed cache remains empty');cache:Destroy()
      assert(destroyed==allocated,'Repeated cleanup is harmless')
     end
    end
   end
   for _,phase in {'allocate','upload','content'}do
    local cache;local attempts,destroyed,warnings=0,0,0
    Content.fromObject=function(image)if phase=='content'then error('content unavailable')end;return originalContent(image)end
    cache=Icons.new(function()warnings+=1 end,function()
     attempts+=1;if phase=='allocate'then return nil end
     return {Destroy=function()destroyed+=1 end,WritePixelsBuffer=function()if phase=='upload'then error('upload unavailable')end end}
    end)
    assert(cache:Get(false)==nil and cache:Get(false)==nil and attempts==1 and warnings==1,'Live allocation/upload/content failures retain one fallback attempt')
    cache:Destroy();assert(destroyed==(if phase=='allocate'then 0 else 1),'Failure releases partial ownership exactly once')
   end
  end)
  Content.fromObject=originalContent
  assert(ok,message)
 end

end
