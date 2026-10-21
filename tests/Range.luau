--!strict
return function(Range,Parser,DOM,Controller,loadRenderTree,loadWordLayout,loadBlockLayout)
	for _,case in {
		{{},"","50"},{{},"999","100"},{{},"-5","0"},{{},"NaN","50"},{{},"0x20","50"},
		{{min="0",max="100",step="20"},"50","60"},
		{{min="10",max="0"},"100","10"},{{min="4",max="4"},"","4"},
		{{min="0",max="10",step="3"},"10","9"},
		{{min=".1",max=".9",step=".2"},".4","0.5"},
		{{min="0",max="1",step="any"},".123","0.123"},
		{{value=".5",step="1"},"1","1.5"},
		{{min="invalid",max="1e2",step="-2"},"1.5","2"},
		{{min="0",max="1",step="1e-3"},".1234","0.123"},
	} do
		assert(Range.normalize(Range.read(case[1]),case[2]) == case[3],"Unexpected range normalization: " .. case[2])
	end
	for _,attributes in {{min="-1e308",max="1e308"},{step="1e-308"},{min="1e308",max="-1e308"}} do
		local r=Range.read(attributes)
		local value=Range.at(r,.5)
		assert(tonumber(value) and math.abs(tonumber(value)) < math.huge)
	end
	local function signal()
		local entries={}; local s={}
		function s:Connect(fn)
			local e={Fn=fn,Connected=true}; function e:Disconnect() self.Connected=false end
			table.insert(entries,e); return e
		end
		function s:Fire(...) for _,e in table.clone(entries) do if e.Connected then e.Fn(...) end end end
		return s
	end
	local factory={}
	function factory.create(class,parent,props)
		assert(class ~= "TextButton" and class ~= "ImageButton" and class ~= "TextBox","Range uses only passive GUI")
		local gui=table.clone(props); gui.Parent=parent; gui.Visible=true
		gui.AbsolutePosition=Vector2.new(0,0); gui.AbsoluteSize=Vector2.new(400,300)
		function gui:IsA(kind) return kind == class or kind == "GuiObject" end
		function gui:Destroy() self.Destroyed=true end
		return gui
	end
	factory.modifier=function(_,_,props) return table.clone(props) end
	local doc=Parser.parse('<form id="f"><input id="r" name="volume" type="range" min="0" max="100" step="1" value="50" readonly maxlength="1" required></form>')
	local root=factory.create("ScrollingFrame",nil,{})
	local tree=loadRenderTree(factory).build(doc,root,error,function(font) return font end)
	local overrides={["Layout/TextMeasure"]={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	blocks.arrange(tree,300,0,0,function() return true end)
	local c=tree.Controls[1]; local item=c.Item
	assert(c.Type == "range" and not c.ReadOnly and c.Value == "50")
	assert(item.BoxWidth == 129 and item.BoxHeight == 16 and not item.Editor and not item.Label)
	assert(item.BoxGui.BackgroundTransparency == 1 and not item.Stroke.Enabled)
	assert(item.RangeThumb.Size[1] == 16 and item.RangeThumb.Position[1] == 56.5)
	assert(item.RangeTrack.Size[2] == 8 and item.RangeTrackStroke.Thickness == 1
		and item.RangeTrackStroke.Color == Color3.fromRGB(178,178,178)
		and item.RangeTrack.BackgroundColor3 == Color3.fromRGB(239,239,239))
	item.BoxGui.AbsolutePosition=Vector2.new(10,10); item.BoxGui.AbsoluteSize=Vector2.new(129,16)
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox() return nil end
	function input:IsKeyDown() return false end
	local hits={item.RangeThumb}
	local page={Document=doc,Root=root,Alive=true}
	function page:AddCleanup(fn) self.Cleanup=fn end
	local cleanup=Controller.start(page,tree,function() error("Range changes must not request layout") end,error,
		{Input=input,PlayerGui={GetGuiObjectsAtPosition=function() return hits end},Factory=factory})
	local inputs,changes=0,0
	page:On("input",function() inputs+=1 end)
	page:On("change",function() changes+=1 end)
	local function mouse(x)
		return {UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(x,18)}
	end
	local function move(x,y)
		input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(x,y or 18)})
	end
	hits={item.RangeTrack}
	move(30); assert(item.RangeThumb.BackgroundColor3 == Color3.fromRGB(0,117,255),"Track hover must not darken the thumb")
	assert(item.RangeFill.BackgroundColor3 == Color3.fromRGB(0,95,204),"Track hover darkens the fill independently")
	assert(item.RangeTrack.BackgroundColor3 == Color3.fromRGB(229,229,229),"Track background darkens on hover")
	hits={item.RangeThumb}
	move(74.5); assert(item.RangeThumb.BackgroundColor3 == Color3.fromRGB(0,95,204),"Thumb hover darkens within the same control")
	assert(item.RangeFill.BackgroundColor3 == Color3.fromRGB(0,95,204),"Thumb hover darkens both fill and thumb")
	move(81,11); assert(item.RangeThumb.BackgroundColor3 == Color3.fromRGB(0,117,255),"Transparent corners are outside the circular thumb")
	move(74.5)
	page:SetValue("r","0"); assert(item.RangeThumb.BackgroundColor3 == Color3.fromRGB(0,117,255),"Moving the thumb away clears its hover color")
	page:Reset("f"); assert(item.RangeThumb.BackgroundColor3 == Color3.fromRGB(0,95,204))
	hits={}; move(200); assert(item.RangeThumb.BackgroundColor3 == Color3.fromRGB(0,117,255))
	assert(item.RangeFill.BackgroundColor3 == Color3.fromRGB(0,117,255),"Leaving the control restores both colors")
	assert(item.RangeTrack.BackgroundColor3 == Color3.fromRGB(239,239,239),"Leaving restores the track background")
	hits={item.RangeThumb}
	assert(inputs == 0 and changes == 0,"Hover must not emit value events")
	local press=mouse(77) -- slightly right of the thumb center at 74.5
	input.InputBegan:Fire(press,false)
	assert(c.Value == "50" and inputs == 0,"Grabbing thumb must not jump")
	assert(item.RangeTrack.BackgroundColor3 == Color3.fromRGB(245,245,245),"Pressed track background becomes lighter")
	hits={}
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(300,18)})
	assert(c.Value == "100" and inputs == 1 and changes == 0,"Pointer remains captured outside the box")
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(400,18)})
	assert(inputs == 1,"Unchanged clamped value emits no input")
	input.InputEnded:Fire(mouse(400))
	assert(changes == 1 and not c.Pressed and item.RangeThumb.Position[1] == 113)
	assert(item.RangeTrack.BackgroundColor3 == Color3.fromRGB(239,239,239),"Release outside restores normal background")
	input.InputEnded:Fire(mouse(400)); assert(changes == 1)
	page:SetValue("r","-10"); assert(c.Value == "0" and inputs == 1 and changes == 1)
	assert(page:GetFormData("f")[1].Value == "0")
	page:Reset("f"); assert(c.Value == "50" and changes == 1)
	hits={item.RangeTrack}
	local touch={UserInputType=Enum.UserInputType.Touch,Position=Vector2.new(30,18)}
	input.InputBegan:Fire(touch,false)
	local before=c.Value
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.Touch,Position=Vector2.new(120,18)})
	assert(c.Value == before,"Second touch must not move the captured slider")
	touch.Position=Vector2.new(131,18); input.InputChanged:Fire(touch)
	assert(c.Value == "100","Touch drag must not cancel after 6 pixels")
	input.InputEnded:Fire(touch); assert(changes == 2)
	page:Focus("r")
	local key={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Left}
	input.InputBegan:Fire(key,false); assert(c.Value == "99" and changes == 3)
	key.KeyCode=Enum.KeyCode.Home; input.InputBegan:Fire(key,false); assert(c.Value == "0" and changes == 4)
	key.KeyCode=Enum.KeyCode.End; input.InputBegan:Fire(key,false); assert(c.Value == "100" and changes == 5)
	c.Disabled=true
	move(131); assert(item.RangeTrack.BackgroundColor3 == Color3.fromRGB(245,245,245),"Disabled background overrides hover")
	input.InputBegan:Fire(key,false)
	press=mouse(20); input.InputBegan:Fire(press,false); input.InputEnded:Fire(press)
	assert(c.Value == "100" and changes == 5 and #page:GetFormData("f") == 0)
	c.Disabled=false; page:Reset("f")
	press=mouse(30); input.InputBegan:Fire(press,false)
	input.WindowFocusReleased:Fire(); assert(changes == 6 and not c.Pressed)
	before=c.Value
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(131,18)})
	input.InputEnded:Fire(press); assert(c.Value == before and changes == 6)
	-- CSS sizing changes track travel without changing numeric semantics.
	item.ContentWidth=216; item.BoxWidth=216
	page:SetValue("r","100"); assert(item.RangeThumb.Position[1] == 200)
	-- An input listener may unmount the page synchronously while the drag begins.
	page:On("input",function() page.Alive=false; cleanup() end)
	input.InputBegan:Fire(mouse(20),false)
	assert(not page.Alive)
	before=c.Value
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(131,18)})
	input.InputEnded:Fire(mouse(131)); assert(c.Value == before and changes == 6)
	print("Range: sanitization, passive rendering, captured mouse/touch, keyboard, events, reset and cleanup passed")
end
