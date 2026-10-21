--!strict
return function(Grip,Resize,Parser,View,Controller,loadRenderTree,loadWordLayout,loadBlockLayout)
	local images={}
	local function createImage(size)
		assert(size.X == 12 and size.Y == 12)
		local image={}
		function image:WritePixelsBuffer(_,_,pixels) self.Pixels=pixels end
		function image:Destroy() self.Destroyed=true end
		table.insert(images,image); return image
	end
	local cache=Grip.new(error,createImage)
	assert(#images == 0)
	local content=cache:Get(); assert(content == cache:Get() and #images == 1)
	local count=0
	for y=0,11 do for x=0,11 do
		local offset=(y*12+x)*4
		local opaque=buffer.readu8(images[1].Pixels,offset+3) == 255
		local expected=(x+y == 14 and x >= 4 and x <= 10) or (x+y == 18 and x >= 8 and x <= 10)
		assert(opaque == expected,'Resize grip must reproduce both reference diagonals')
		if opaque then count+=1; for channel=0,2 do assert(buffer.readu8(images[1].Pixels,offset+channel) == 102) end end
	end end
	assert(count == 10)
	local warnings=0
	local failed=Grip.new(function() warnings+=1 end,function() return nil end)
	assert(not failed:Get() and not failed:Get() and warnings == 1)
	local function signal()
		local callbacks={}; local s={}
		function s:Connect(fn)
			local c={Connected=true}; function c:Disconnect() self.Connected=false end
			table.insert(callbacks,{fn,c}); return c
		end
		function s:Fire(...) for _,e in table.clone(callbacks) do if e[2].Connected then e[1](...) end end end
		return s
	end
	local factory={}
	function factory.create(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		local gui=table.clone(props); gui.Parent=parent; gui.Visible=true
		gui.AbsolutePosition=Vector2.new(0,0); gui.AbsoluteSize=Vector2.new(500,500)
		function gui:IsA(kind) return kind == class or kind == 'GuiObject' end
		function gui:Destroy() self.Destroyed=true end
		local properties={}
		function gui:GetPropertyChangedSignal(name)
			properties[name]=properties[name] or signal(); return properties[name]
		end
		gui.Focused,gui.FocusLost=signal(),signal()
		local focused=false
		function gui:IsFocused() return focused end
		function gui:CaptureFocus() if not focused then focused=true; self.Focused:Fire() end end
		function gui:ReleaseFocus() if focused then focused=false; self.FocusLost:Fire(false) end end
		return gui
	end
	factory.modifier=function(_,_,props) return table.clone(props) end
	local document=Parser.parse('<textarea id="a" style="display:block; width:140px!important; width:150px!important; height:70px; box-sizing:border-box; max-width:220px; color:#123456; --keep:100px">Keep text</textarea><textarea id="b" style="resize:none">Other</textarea>')
	local root=factory.create('ScrollingFrame',nil,{})
	local tree=loadRenderTree(factory).build(document,root,error,function(font) return font end,nil,nil,nil,nil,nil,nil,nil,cache)
	local overrides={["Layout/TextMeasure"]={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	local function layout() blocks.arrange(tree,400,0,0,function() return true end) end
	layout()
	local c=tree.Controls[1]; local item=c.Item
	assert(item.ResizeGrip.ImageContent == content and tree.Controls[2].Item.ResizeGrip.ImageContent == content and #images == 1)
	assert(item.ResizeGrip.Size[1] == 12 and item.ResizeGrip.Position[1] == -13 and item.ResizeGrip.Position[2] == -13)
	assert(not tree.Controls[2].Item.ResizeGrip.Visible)
	item.BoxGui.AbsolutePosition=Vector2.new(0,0); item.BoxGui.AbsoluteSize=Vector2.new(150,70)
	local alive,requests=true,0
	local resize=Resize.new(function() return alive end,function(target) assert(target == item); requests+=1; layout() end)
	local press={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(144,64)}
	assert(resize:Begin(c,press)); resize:Finish(press); assert(requests == 0,'A grip click without movement must not resize')
	assert(resize:Begin(c,press))
	local movement={UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(194,94)}
	resize:Move(movement); assert(item.BoxWidth == 200 and item.BoxHeight == 100 and requests == 1)
	resize:Move(movement); assert(requests == 1,'Repeated pointer positions must not request another layout')
	assert(c.Value == 'Keep text' and item.Editor.Text == 'Keep text')
	press.Position=movement.Position; resize:Finish(press)
	assert(c.LayoutStyle.Width.Value == 200 and c.LayoutStyle.Height.Value == 100,'Block controls must resize their source style')
	local css=c.Node.Attributes.style
	assert(css:find('width:%s*200px') and css:find('height:%s*100px') and not css:find('150px') and not css:find('140px'), 'Native resize replaces duplicate/important inline dimensions')
	assert(css:find('max%-width:%s*220px') and css:find('box%-sizing:%s*border%-box') and css:find('color:%s*#123456') and css:find('%-%-keep:%s*100px'), 'Resizing preserves constraints and unrelated CSS declarations')
	item.BoxGui.AbsoluteSize=Vector2.new(200,100)
	press.Position=Vector2.new(194,94); resize:Begin(c,press)
	movement.Position=Vector2.new(294,94); resize:Move(movement); assert(item.BoxWidth == 220,'Existing CSS max-width still applies')
	resize:Cancel()
	c.LayoutStyle.Resize='vertical'; layout(); item.BoxGui.AbsoluteSize=Vector2.new(item.BoxWidth,item.BoxHeight)
	local widthValue=c.LayoutStyle.Width.Value
	press.Position=Vector2.new(item.BoxWidth-6,item.BoxHeight-6); resize:Begin(c,press)
	movement.Position=Vector2.new(press.Position.X+50,press.Position.Y+20); resize:Move(movement)
	assert(c.LayoutStyle.Width.Value == widthValue and item.BoxHeight == 120)
	assert(c.Node.Attributes.style:find('width:%s*'..tostring(widthValue)..'px') and c.Node.Attributes.style:find('height:%s*120px'), 'Vertical resize changes only the inline height')
	resize:Cancel()
	c.LayoutStyle.Resize='none'; layout(); assert(not resize:Begin(c,press))
	c.LayoutStyle.Resize='both'; layout(); item.BoxGui.AbsoluteSize=Vector2.new(item.BoxWidth,item.BoxHeight)
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox() return nil end
	function input:IsKeyDown() return false end
	local hits={item.ResizeGrip}
	local page={Document=document,Root=root,Alive=true}
	function page:AddCleanup(fn) self.Cleanup=fn end
	local stop=Controller.start(page,tree,function(force,target) assert(force == false and target == item); requests+=1; layout() end,error,
		{Input=input,PlayerGui={GetGuiObjectsAtPosition=function() return hits end}})
	local changes=0; page:On('input',function() changes+=1 end); page:On('change',function() changes+=1 end)
	local focusedWidth,focusedHeight,beforeFocus=item.BoxWidth,item.BoxHeight,requests
	page:Focus('a'); assert(c.Focused and item.Editor:IsFocused() and item.Stroke.Thickness == 1 and item.ControlOutline.Style.BorderSize == 2)
	assert(requests == beforeFocus and item.BoxWidth == focusedWidth and item.BoxHeight == focusedHeight, 'Focusing retains resized dimensions without requesting layout')
	local touch={UserInputType=Enum.UserInputType.Touch,Position=Vector2.new(item.BoxWidth-6,item.BoxHeight-6)}
	input.InputBegan:Fire(touch,false)
	assert(not c.Focused and not item.Editor:IsFocused() and item.Stroke.Thickness == 1 and (not item.ControlOutline or item.ControlOutline.Gui.Visible==false),'Resize must blur the editor and remove the focus outline')
	page:Focus('a'); item.Editor:CaptureFocus()
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab},false)
	assert(not c.Focused and not item.Editor:IsFocused(),'Native/API/keyboard focus cannot return during resize')
	item.Editor.Text='Unwanted typing'; item.Editor:GetPropertyChangedSignal('Text'):Fire()
	assert(item.Editor.Text == 'Keep text' and c.Value == 'Keep text' and changes == 0)
	local before=requests
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.Touch,Position=Vector2.new(0,0)}); assert(requests == before)
	touch.Position=Vector2.new(touch.Position.X-40,touch.Position.Y+30)
	input.InputChanged:Fire(touch); assert(requests == before+1 and item.BoxHeight == 150)
	input.InputEnded:Fire(touch); assert(changes == 0 and c.Value == 'Keep text')
	assert(not c.Focused and item.Stroke.Thickness == 1,'Release must not automatically refocus')
	focusedWidth,focusedHeight,beforeFocus=item.BoxWidth,item.BoxHeight,requests
	page:Focus('a'); assert(c.Focused and item.Editor:IsFocused() and item.Stroke.Thickness == 1 and item.ControlOutline.Style.BorderSize == 2,'Editing is available again after resize')
	assert(requests == beforeFocus and item.BoxWidth == focusedWidth and item.BoxHeight == focusedHeight, 'Refocusing after native touch resize preserves its size without layout')
	input.WindowFocusReleased:Fire(); stop()
	input.InputChanged:Fire(touch); assert(requests == before+1)
	cache:Destroy(); cache:Destroy(); assert(images[1].Destroyed and not cache:Get())
	print('Textarea resize: reference pixels, shared EditableImage, anchored grip, CSS constraints, block styles, mouse/touch, dirty requests and cleanup passed')
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
      cache=Grip.new(function()warnings+=1 end,function()
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
    cache=Grip.new(function()warnings+=1 end,function()
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
