--!strict
return function(Parser,DOM,State,Model,Events,HitTest,Controller,loadRenderTree,loadWordLayout,loadBlockLayout,loadControlDefaults,loadFontProfiles,ControlView)
	-- EnumItems must differ from strings, as in Studio; a string mock hid this startup failure.
	local nativeEnum={Font={Arial={},SourceSans={},Ubuntu={}},FontWeight={Regular="Regular",Bold="Bold"},FontStyle={Normal="Normal",Italic="Italic"}}
	local nativeFont={fromEnum=function(value)
		assert(value == nativeEnum.Font.Arial)
		return {Family="native-arial",Weight="Regular",Style="Normal"}
	end,new=function(family,weight,style) return {Family=family,Weight=weight,Style=style} end}
	local nativeProfiles=loadFontProfiles(nativeFont,nativeEnum,type)
	local defaults=loadControlDefaults(nativeEnum)
	local colorDoc=Parser.parse('<form id="colors"><input id="swatch" name="color" type="color" value="#087F72"></form>')
	local colorControl=State.create(DOM.findById(colorDoc,'swatch'))
	assert(colorControl.Type=='color' and colorControl.Value=='#087f72')
	local colorModel=Model.new(colorDoc,{colorControl},{Emit=function() return {DefaultPrevented=false} end},function() end)
	colorModel:SetValue(colorControl,'#A1B2C3')
	assert(colorControl.Value=='#a1b2c3' and colorModel:Data(colorControl.Form)[1].Value=='#a1b2c3')
	colorModel:SetValue(colorControl,'not a color')
	assert(colorControl.Value=='#000000','Invalid color values use the native black fallback')
	colorModel:Reset(colorControl.Form)
	assert(colorControl.Value=='#087f72','Form reset restores the original color')
	colorModel:Destroy()
	for _,name in {"input","button","textarea"} do
		local style={}
		defaults.apply(Parser.parse('<'..name..'></'..name..'>').Children[1],style)
		local face=nativeProfiles.face(style.Font,style.FontWeight,style.FontStyle)
		assert(face.Family == (if name == "textarea" then "rbxasset://fonts/families/RobotoMono.json" else "native-arial"))
	end
	local function signal()
		local callbacks={}
		local s={}
		function s:Connect(fn)
			local connection={Connected=true}
			function connection:Disconnect() self.Connected=false end
			table.insert(callbacks,{fn,connection}); return connection
		end
		function s:Fire(...) for _,entry in table.clone(callbacks) do if entry[2].Connected then entry[1](...) end end end
		function s:Count() local n=0; for _,entry in callbacks do if entry[2].Connected then n+=1 end end; return n end
		return s
	end
	local allocations,focused,objects=0,nil,{}
	local function create(class,parent,props)
		allocations+=1
		local values={Parent=parent,ClassName=class,Visible=true,Active=false,Selectable=false,Text="",AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(100,40)}
		for key,value in props do values[key]=value end
		local changes={}
		local gui=setmetatable({}, {__index=values,__newindex=function(_,key,value)
			local old=values[key]; values[key]=value; if old ~= value and changes[key] then changes[key]:Fire() end
		end})
		function values:IsA(kind) return kind == class or (kind == "GuiObject" and (class == "Frame" or class == "TextLabel" or class == "TextBox" or class == "ScrollingFrame")) end
		function values:GetPropertyChangedSignal(key) changes[key]=changes[key] or signal(); return changes[key] end
		values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
		function values:IsFocused() return focused == gui end
		function values:CaptureFocus() if focused and focused ~= gui then focused:ReleaseFocus() end; focused=gui; values.Focused:Fire() end
		function values:ReleaseFocus() if focused == gui then focused=nil; values.FocusLost:Fire(false) end end
		function values:Destroy() values.Destroyed=true end
		table.insert(objects,gui); return gui
	end
	local document=Parser.parse([[<html><body><form id="f"><div class="field"><label id="label" for="text">Name</label><input id="text" name="name" maxlength="4" value="A"></div><label id="check-label"><input id="check" name="flag" type="checkbox"> Remember</label><input id="r1" type="radio" name="choice" value="a" checked><input id="r2" type="radio" name="choice" value="b" checked><input id="password" name="pw" type="password" placeholder="Passwort"><textarea id="area" name="message" rows="3">Start</textarea><input id="city" name="city" list="cities" placeholder="City"><datalist id="cities"><option value="Zurich"><option value="Bern"><option value="Geneva" disabled></datalist><input id="readonly" name="read" value="Fixed" readonly><button id="send" name="action" value="save">Test</button><button id="disabled" disabled>Disabled</button><button id="reset" type="reset">Reset</button><output id="out"></output></form><a id="next" href="../css-background-position/index.html#top" target="_self" rel="next">Background positions</a></body></html>]])
	local target=create("Frame",nil,{AbsoluteSize=Vector2.new(320,240)})
	local root=create("ScrollingFrame",target,{AbsoluteSize=Vector2.new(320,240)})
	local factory={create=create,modifier=create}
	local renderer=loadRenderTree(factory)
	local tree=renderer.build(document,root,error,function(font) return font end,nil,nil,nil,'.field > label {display:block} output {display:block}')
	assert(#tree.Controls == 12)
	local byId={}; for _,c in tree.Controls do byId[c.Node.Attributes.id]=c end
	assert(byId.area.Value == "Start" and byId.area.Item.Editor.MultiLine)
	assert(byId.password.Item.Editor.TextTransparency == 1 and byId.password.Item.Label.Text == "Passwort")
	assert(not byId.readonly.Item.Editor.TextEditable)
	assert(byId.city.Datalist and #byId.city.Options==3 and byId.city.Options[2].Value=='Bern' and byId.city.Options[2].Caption=='Bern' and byId.city.Options[3].Disabled)
	local measure={measure=function(text,_,size) return {X=(utf8.len(text) or 0)*5,Y=size} end}
	local overrides={["Layout/TextMeasure"]=measure,["Layout/FontProfiles"]={face=function(font) return font end}}
	local words=loadWordLayout(overrides); overrides["Layout/WordLayout"]=words
	local blocks=loadBlockLayout(overrides)
	local checkTree=renderer.build(Parser.parse('<style>#large{width:18px;height:18px}#large:hover{width:36px;height:36px}#accent{accent-color:#e58b35}#accent:hover{accent-color:#173d68}</style><input id="small" type="checkbox" checked><input id="large" type="checkbox" checked><input id="wide" type="checkbox" checked style="width:36px;height:18px"><input id="accent" type="checkbox" checked style="width:130px;height:36px"><input id="dark-accent" type="checkbox" checked style="accent-color:#173d68">'),create("Frame",nil,{}),error,function(font)return font end)
	blocks.arrange(checkTree,300,0,0,function()return true end)
	local checkItems={};for _,c in checkTree.Controls do checkItems[c.Node.Attributes.id]=c.Item end
	for index,part in checkItems.small.Ticks do
		local larger=checkItems.large.Ticks[index]
		assert(math.abs(larger.Size[1]/part.Size[1]-18/13)<.001 and math.abs(larger.Size[2]/part.Size[2]-18/13)<.001,
			"Checkbox mark length and thickness must scale with the rendered box")
		assert(math.abs(larger.Position[1]/part.Position[1]-18/13)<.001 and math.abs(larger.Position[2]/part.Position[2]-18/13)<.001)
		local wider=checkItems.wide.Ticks[index]
		assert(math.abs(wider.Position[1]-larger.Position[1])<.001 and wider.Size[1]==larger.Size[1],"The mark is positioned within the centered square")
	end
	assert(checkItems.wide.BoxGui.Size[1]==18 and checkItems.wide.BoxGui.Size[2]==18
		and math.abs(checkItems.wide.BoxGui.Position[1]-checkItems.large.BoxGui.Position[1]-9)<.001,
		"A wide checkbox keeps its layout width but paints a centered square")
	assert(checkItems.accent.BoxWidth==130 and checkItems.accent.BoxHeight==36
		and checkItems.accent.BoxGui.Size[1]==36 and checkItems.accent.BoxGui.Size[2]==36
		and math.abs(checkItems.accent.BoxGui.Position[1]-51)<.001,
		"The catalog accent checkbox paints a centered 36px square")
	assert(checkItems.accent.Ticks[1].BackgroundColor3==Color3.new(0,0,0)
		and checkItems.small.Ticks[1].BackgroundColor3==Color3.new(1,1,1)
		and checkItems['dark-accent'].Ticks[1].BackgroundColor3==Color3.new(1,1,1),
		"A light orange accent uses a dark mark; saturated blue stays white")
	local recolored,reflow=checkTree:SetCSSState("hover",checkItems.accent.Control.Node)
	assert(recolored and not reflow and checkItems.accent.Ticks[1].BackgroundColor3==Color3.new(1,1,1),
		"A hover-only accent change repaints the contrast mark without layout")
	checkTree:SetCSSState("hover",nil)
	assert(checkItems.accent.Ticks[1].BackgroundColor3==Color3.new(0,0,0))
	local blockCheck=renderer.build(Parser.parse('<style>.property-probe{display:block;width:130px;height:36px;accent-color:#e58b35}</style><input class="property-probe" id="block-accent" type="checkbox" checked>'),create("Frame",nil,{}),error,function(font)return font end)
	blocks.arrange(blockCheck,300,0,0,function()return true end)
	local blockItem=blockCheck.Controls[1].Item
	assert(blockItem.BoxWidth==130 and blockItem.BoxGui.Size[1]==36 and blockItem.BoxGui.Size[2]==36
		and blockItem.BoxGui.Position[1]==47 and blockItem.Ticks[1].BackgroundColor3==Color3.new(0,0,0),
		"Block-level checkbox faces are centered inside their declared CSS width")
	local mark=checkItems.large.Ticks[2];local markWidth=mark.Size[1];local checkAllocations=allocations
	assert(checkTree:SetCSSState("hover",checkItems.large.Control.Node));blocks.arrange(checkTree,300,0,0,function()return true end)
	assert(checkItems.large.BoxWidth==36 and math.abs(mark.Size[1]-markWidth*2)<.001 and allocations==checkAllocations,"Resizing updates the existing checkbox mark")
	blocks.arrange(tree,300,0,0,function() return true end)
	local before=allocations
	blocks.arrange(tree,200,0,0,function() return true end)
	assert(allocations == before,"Resize preserves controls/editors")
	assert(byId.text.Item.Editor.TextSize == 14 and byId.password.Item.Editor.TextSize == 14 and byId.send.Item.Label.TextSize == 14,"Arial form fields and buttons retain their corrected size after layout")
	for _,c in {byId.text,byId.password} do
		assert(c.Item.BoxHeight == 21 and c.Item.Editor.Position[2] == 3 and c.Item.Editor.Size[2] == 14,
			"Default inputs need 19px inside the border while retaining 14px text")
		assert(c.Item.BoxHeight-1-c.Item.Baseline == 5,"The text baseline must sit 5px above the lower inner border")
	end
	local paddedTree=renderer.build(Parser.parse('<input style="padding:8px 10px;font-size:16px">'),create("Frame",nil,{}),error,function(font) return font end)
	blocks.arrange(paddedTree,300,0,0,function() return true end)
	local padded=paddedTree.Controls[1].Item
	assert(padded.BoxHeight==38 and padded.Editor.Position[2]==10 and padded.Editor.Size[2]==17,'Padded input text must be centered inside its content box')
	local centeredTree=renderer.build(Parser.parse('<style>button,input[type=button],input[type=submit],input[type=reset]{padding:8px 12px;font:12px/1.6 Arial;min-height:38px;box-sizing:border-box}.start{align-content:start}.end{align-content:end}.uneven{padding-top:4px;padding-bottom:12px}.flex{display:flex;align-items:center;height:54px}</style><button id="pause">Pause</button><input id="submit" type="submit" value="Pause"><input id="reset" type="reset" value="Pause"><input id="input-button" type="button" value="Pause"><button id="start" class="start">Pause</button><button id="end" class="end">Pause</button><button id="uneven" class="uneven">Pause</button><button id="flex" class="flex">Pause</button>'),create('Frame',nil,{}),error,function(font)return font end)
	blocks.arrange(centeredTree,800,0,0,function()return true end)
	for _,control in centeredTree.Controls do
		local item=control.Item;local id=control.Node.Attributes.id
		local free=math.max(0,item.ContentHeight-item.TextSize)
		local offset=if id=='start'then 0 elseif id=='end'then free else free/2
		local expected=1+item.Style.Padding[1]+offset
		assert(math.abs(item.Label.Position[2]-expected)<.001,'Button content alignment: '..id)
		assert(item.Label.Size[2]<=item.TextSize and item.Label.Position[2]+item.Label.Size[2]<=item.BoxHeight-1-item.Style.Padding[3], 'Caption stays within its content box')
		if id=='pause'then assert(item.BoxHeight==38 and math.abs(item.Label.Position[2]-13)<.001,'Memory toolbar label is centered in the 38px button')end
	end
	assert(byId.password.Item.Label.Position[2] == byId.password.Item.Editor.Position[2]
		and byId.password.Item.Label.Size[2] == byId.password.Item.Editor.Size[2],"Password mask and editor must share the corrected position")
	local customButtonTree=renderer.build(Parser.parse('<button style="background:#7048a8">Custom</button>'),create("Frame",nil,{}),error,function(font) return font end)
	local customButton=customButtonTree.Controls[1]
	assert(customButton.Item.Style.ControlBackgroundSpecified and customButton.Item.BoxGui.BackgroundColor3==Color3.fromRGB(112,72,168))
	customButton.Hovered=true;ControlView.paint(customButton.Item)
	assert(customButton.Item.BoxGui.BackgroundColor3==Color3.fromRGB(112,72,168),'Author button background must survive hover')
	customButton.Pressed=true;ControlView.paint(customButton.Item)
	assert(customButton.Item.BoxGui.BackgroundColor3==Color3.fromRGB(112,72,168),'Author button background must survive press without :active CSS')
	local outputTree=renderer.build(Parser.parse('<style>output{display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;box-sizing:border-box;border:1px solid #aab8a7;border-radius:14px;font-size:11px;background:#e8ecd9}output:hover{border-color:red;background:#d0e0c0}</style><output>0</output>'),create('Frame',nil,{}),error,function(font)return font end)
	blocks.arrange(outputTree,200,0,0,function()return true end)
	local output=outputTree.Controls[1].Item
	local outputStroke
	for _,gui in objects do if gui.ClassName=='UIStroke'and gui.Parent==output.BoxGui and gui~=output.Stroke then outputStroke=gui end end
	assert(outputStroke and outputStroke.Color==Color3.fromRGB(170,184,167)and outputStroke.Thickness==1,'Authored output borders are painted even without a raster provider')
	assert(output.Corner.CornerRadius.Offset==14 and output.Label.TextXAlignment==Enum.TextXAlignment.Center,'Native output radius and flex text centering use the actual box size')
	assert(output.BoxGui.BackgroundColor3==Color3.fromRGB(232,236,217)and output.BoxGui.BackgroundTransparency==0,'Authored output background is visible')
	local outputGui=output.BoxGui
	assert(outputTree:SetCSSState('hover',output.Control.Node))
	assert(output.BoxGui==outputGui and outputStroke.Color==Color3.fromRGB(255,0,0)and output.BoxGui.BackgroundColor3==Color3.fromRGB(208,224,192),'Output paint hover retains its view and refreshes CSS border/background')
	local appearanceTree=renderer.build(Parser.parse('<input style="appearance:none;background:#eafaf7;border:2px solid #087f68" value="editable">'),create("Frame",nil,{}),error,function(font) return font end)
	blocks.arrange(appearanceTree,300,0,0,function() return true end)
	local appearance=appearanceTree.Controls[1].Item
	assert(appearance.Editor and appearance.Editor.ClassName=="TextBox","appearance:none must retain the native editable TextBox")
	assert(appearance.Style.ControlBackgroundSpecified and appearance.Style.ControlBorderSpecified)
	assert(appearance.BoxGui.BackgroundColor3==Color3.fromRGB(234,250,247) and appearance.BoxGui.BackgroundTransparency==0)
	assert(appearance.Stroke.Enabled and appearance.Stroke.Color==Color3.fromRGB(8,127,104) and appearance.Stroke.Thickness==2,
		"Author background and border must remain visible after appearance:none removes the default chrome")
	local outlineDoc=Parser.parse('<input id="focus-test" value="Editierbarer Text">')
	local outlineTree=renderer.build(outlineDoc,create("Frame",nil,{}),error,function(font) return font end,nil,nil,nil,
		'input{margin:5px;border:1px solid #78958a;border-radius:3px}:focus-visible{outline:3px solid #b44409;outline-offset:4px}')
	blocks.arrange(outlineTree,300,0,0,function() return true end)
	local outlined=outlineTree.Controls[1].Item
	assert(outlineDoc.LegacyFragment and outlined.Style.Display=='inline-block','A bare control in legacy parseHTML remains inline rather than becoming the document root')
	assert((not outlined.ControlOutline or outlined.ControlOutline.Gui.Visible==false) and outlined.Stroke.Color==Color3.fromRGB(120,149,138))
	assert(outlineTree:SetCSSState('focus-visible',outlined.Control.Node))
	outlined.Control.Focused=true;ControlView.paint(outlined)
	assert(outlined.ControlOutline and outlined.ControlOutline.Gui.Parent==outlined.Gui
		and outlined.ControlOutline.Style.BorderColor==Color3.fromRGB(180,68,9)
		and outlined.ControlOutline.Gui.Position[1]==-2 and outlined.ControlOutline.Gui.Position[2]==-2
		and outlined.ControlOutline.Gui.Size[1]==outlined.BoxWidth+14
		and outlined.Stroke.Color==Color3.fromRGB(120,149,138) and outlined.Stroke.Thickness==1,
		'Focused inputs keep their CSS border and draw the focus-visible outline outside the border box')
	assert(outlineTree:SetCSSState('focus-visible',nil))
	assert((not outlined.ControlOutline or outlined.ControlOutline.Gui.Visible==false),'Blur removes the author focus outline without retaining a visible ring')
	local flexFocusDoc=Parser.parse('<label style="display:flex;flex-direction:column"><input id="flex-focus" value="Editierbarer Text"></label>')
	local flexFocusTree=renderer.build(flexFocusDoc,create("Frame",nil,{}),error,function(font) return font end,nil,nil,nil,
		'input{border:1px solid #78958a;border-radius:3px}:focus-visible{outline:3px solid #b44409;outline-offset:4px}')
	blocks.arrange(flexFocusTree,300,0,0,function() return true end)
	local flexControl=flexFocusTree.Controls[1]
	assert(flexControl.Item.Style~=flexFocusTree.NodeStyles[flexControl.Node],
		'Flex items use a derived control style that must track later focus changes')
	assert(flexFocusTree:SetCSSState('focus-visible',flexControl.Node))
	blocks.arrange(flexFocusTree,300,0,0,function() return true end)
	assert(flexControl.Item.ControlOutline and flexControl.Item.ControlOutline.Gui.Position[1]==-7
		and flexControl.Item.ControlOutline.Style.BorderColor==Color3.fromRGB(180,68,9),
		'Flex form fields must paint the outer focus outline after their derived style is refreshed')
	assert(byId.area.Item.Editor.TextSize == 14 and byId.area.Item.TextSize == 14,"Final inline TextBox size must retain the textarea correction after resize")
	local sizingTree=renderer.build(Parser.parse('<textarea style="display:block">Block</textarea><div style="display:flex"><textarea>Flex</textarea></div><textarea style="font-size:20px">Large</textarea>'),create("Frame",nil,{}),error,function(font) return font end)
	for _,width in {300,200} do
		blocks.arrange(sizingTree,width,0,0,function() return true end)
		for index,c in sizingTree.Controls do
			local expected=if index == 3 then 22 else 14
			assert(c.Item.Editor.TextSize == expected and c.Item.TextSize == expected,"Block/flex and CSS sizes must use the corrected final TextBox size")
		end
	end
	for _,c in tree.Controls do assert(c.Item.BoxWidth > 0 or c.Type == "output") end
	-- Controls have independent natural dimensions, unlike images: width:100% must not stretch their height.
	local fieldTree=renderer.build(Parser.parse('<input style="width:100%;box-sizing:border-box"><textarea rows="3" style="width:100%;box-sizing:border-box"></textarea><input style="display:block;width:100%;box-sizing:border-box"><div style="display:flex"><textarea rows="3" style="width:100%;box-sizing:border-box"></textarea></div><input style="width:100%;height:35px;box-sizing:border-box">'),create("Frame",nil,{}),error,function(font) return font end)
	for _,width in {200,400,240} do
		blocks.arrange(fieldTree,width,0,0,function() return true end)
		for index,c in fieldTree.Controls do
			local expected=if index == 5 then 35 elseif c.Type == "textarea" then 48 else 21
			assert(c.Item.BoxHeight == expected,"Field height must follow text/rows or explicit CSS height, independently of width")
			assert(c.Item.Editor.TextSize == 14)
		end
	end
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox() return focused end
	function input:IsKeyDown() return false end
	local hits={}
	local playerGui={GetGuiObjectsAtPosition=function() return hits end}
	local navigations={}
	local page={Document=document,Root=root,Alive=true,Navigate=function(href,node,data) table.insert(navigations,{href,node,data}) end}
	function page:AddCleanup(fn) self.Cleanup=fn end
	local layouts=0
	local snapTimers={}
	local pendingSnaps=0
	local snapTask={
		delay=function(seconds,callback)
			assert(seconds==.12)
			local token={Callback=callback,Cancelled=false}
			table.insert(snapTimers,token);pendingSnaps+=1;return token
		end,
		cancel=function(token)
			assert(not token.Cancelled,"A snap timer is cancelled only once")
			token.Cancelled=true;pendingSnaps-=1
		end,
	}
	local cleanup=Controller.start(page,tree,function(force,item)
		assert(force and item == byId.out.Item,"Output requests identify their actual layout dependency")
		layouts+=1
	end,error,{Input=input,PlayerGui=playerGui,Factory=factory,Task=snapTask})
	assert(not byId.r1.Checked and byId.r2.Checked,"Last checked radio wins initially")
	tree.CollapsedTableCells={[byId.text.Node]=true}
	page:Focus('text'); assert(not focused,'Controls in collapsed table cells cannot acquire focus')
	tree.CollapsedTableCells={}
	local emitted={}
	page:On("input",function(event) table.insert(emitted,event.Type .. ":" .. event.Target.Attributes.id) end)
	local function click(gui,x,y)
		hits={gui}
		local event={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(x or 10,y or 20)}
		input.InputBegan:Fire(event,false); input.InputEnded:Fire(event,false)
	end
	local function live(name)
		for index=#objects,1,-1 do
			local object=objects[index]
			if object.Name==name then
				local current,valid=object,true
				while current do if current.Destroyed then valid=false; break end; current=current.Parent end
				if valid then return object end
			end
		end
		return nil
	end
	local linkGui
	for gui,node in tree.HitNodes do
		local current=node
		while current do if current.Attributes and current.Attributes.id=='next' then linkGui=gui; break end; current=current.Parent end
		if linkGui then break end
	end
	assert(linkGui); click(linkGui)
	assert(#navigations==1 and navigations[1][1]=='../css-background-position/index.html#top' and navigations[1][2].Attributes.id=='next')
	assert(navigations[1][3].Target=='_self' and navigations[1][3].Rel=='next','Link attributes reach the navigation callback')
	local stopLink=page:On('next','click',function(event) event:PreventDefault() end)
	click(linkGui); assert(#navigations==1,'PreventDefault cancels navigation'); stopLink:Disconnect()
	local enter={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Return}
	input.InputBegan:Fire(enter,false); input.InputEnded:Fire(enter,false)
	assert(#navigations==2,'Enter activates the focused hyperlink')
	local labelGui
	for gui,node in tree.HitNodes do if node.Attributes and node.Attributes.id == "label" then labelGui=gui end end
	assert(labelGui); click(labelGui)
	assert(focused == byId.text.Item.Editor and byId.text.Focused and byId.text.Item.Stroke.Thickness == 1)
	assert(byId.text.Item.ControlOutline and byId.text.Item.ControlOutline.Style.BorderSize==2,
		'Native focus adds an independent 2px outline without changing the input border')
	byId.text.Item.Editor.Text="ABCDE"
	assert(page:GetValue("text") == "ABCD" and byId.text.Item.Editor.Text == "ABCD" and emitted[#emitted] == "input:text")
	byId.city.Item.BoxGui.AbsolutePosition=Vector2.new(10,10); byId.city.Item.BoxGui.AbsoluteSize=Vector2.new(120,20)
	page:Focus('city'); assert(live('DatalistPopup'),'Focusing input[list] opens its suggestions')
	byId.city.Item.Editor:ReleaseFocus()
	assert(focused==nil and not live('DatalistPopup'),'Losing the native blinking caret must close datalist suggestions')
	page:Focus('city'); assert(live('DatalistPopup'),'The datalist can reopen after a real blur')
	byId.city.Item.Editor.Text='be'
	assert(live('DatalistPopup') and live('Option_2') and not live('Option_1'),'Typing filters datalist options without layout')
	live('DatalistPopup').AbsolutePosition=Vector2.new(10,30)
	live('DatalistPopup').AbsoluteSize=Vector2.new(120,22)
	-- Studio may report the focused TextBox instead of the visible option. The
	-- popup must still resolve its row from the pointer geometry.
	hits={byId.city.Item.Editor}
	local suggestionClick={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(20,40)}
	input.InputBegan:Fire(suggestionClick,false)
	byId.city.Item.Editor:ReleaseFocus() -- Roblox releases it before InputEnded.
	input.InputEnded:Fire(suggestionClick,false)
	assert(page:GetValue('city')=='Bern' and byId.city.Item.Editor.Text=='Bern' and focused==byId.city.Item.Editor and not live('DatalistPopup'),'Mouse selection must survive native FocusLost, update the visible editor and restore focus')
	local textClick={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(20,15)}
	byId.city.Item.Editor.InputBegan:Fire(textClick)
	assert(live('DatalistPopup'),'ControlText must forward its click to the datalist control box')
	live('DatalistPopup').AbsolutePosition=Vector2.new(10,30)
	live('DatalistPopup').AbsoluteSize=Vector2.new(120,22)
	hits={byId.city.Item.Editor}; input.InputBegan:Fire(textClick,false); input.InputEnded:Fire(textClick,false)
	assert(live('DatalistPopup'),'The forwarded ControlText click must not be treated as an outside-popup click')
	byId.city.Item.Editor.Text='z'
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Down},false)
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Return},false)
	assert(page:GetValue('city')=='Zurich' and byId.city.Item.Editor.Text=='Zurich' and not live('DatalistPopup'),'Arrow and Enter must update the model and visible editor')
	click(byId.check.Item.BoxGui)
	assert(page:GetChecked("check") and focused == nil and byId.check.Item.Ticks[1].Visible)
	assert(layouts == 0,"Input/focus/toggle operations must not trigger a full reflow")
	click(byId.r1.Item.BoxGui)
	assert(page:GetChecked("r1") and not page:GetChecked("r2"))
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Right},false)
	assert(not page:GetChecked("r1") and page:GetChecked("r2"))
	page:Focus("text")
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab},true)
	assert(byId.check.Focused,"Tab moves from a native editor to the next control")
	local prevent=page:On("check","click",function(event) event:PreventDefault() end)
	click(byId.check.Item.BoxGui); assert(page:GetChecked("check")); prevent:Disconnect()
	local submitCount=0
	page:On("f","submit",function(event)
		submitCount+=1; event:PreventDefault()
		assert(event.Data.Entries[1].Name == "name" and event.Data.Entries[1].Value == "ABCD")
		assert(event.Data.Submitter == byId.send.Node)
		page:SetValue("out","OK")
	end)
	click(byId.disabled.Item.BoxGui); assert(submitCount == 0)
	click(byId.send.Item.BoxGui); assert(submitCount == 1 and page:GetValue("out") == "OK" and layouts == 1)
	page:SetValue("password","secret"); assert(byId.password.Item.Label.Text == string.rep("•",6))
	local data=page:GetFormData("f"); local names={}; for _,entry in data do names[entry.Name]=entry.Value end
	assert(names.name == "ABCD" and names.flag == "on" and names.choice == "b" and names.pw == "secret" and names.city == "Zurich" and names.read == "Fixed" and names.action == nil)
	click(byId.reset.Item.BoxGui)
	assert(page:GetValue("text") == "A" and not page:GetChecked("check") and page:GetChecked("r2") and not page:GetChecked("r1") and page:GetValue("out") == "")
	byId.readonly.Item.Editor.Text="changed"; assert(page:GetValue("readonly") == "Fixed" and byId.readonly.Item.Editor.Text == "Fixed")
	page:Focus("send")
	local key={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Space}
	local stop=page:On("send","click",function(event) event:PreventDefault() end)
	input.InputBegan:Fire(key,false); assert(byId.send.Pressed); input.InputEnded:Fire(key,false); assert(not byId.send.Pressed); stop:Disconnect()
	local cover=create("Frame",root,{}); tree.HitNodes[cover]=DOM.findById(document,"f")
	assert(HitTest.pick({cover,byId.check.Item.Gui},tree.HitNodes,root) == DOM.findById(document,"f"),"Frontmost unrelated element blocks controls behind it")
	cover.Visible=false
	assert(HitTest.pick({cover,byId.check.Item.Gui},tree.HitNodes,root) == byId.check.Node)
	local clip=create("ScrollingFrame",root,{ClipsDescendants=true,AbsoluteWindowSize=Vector2.new(8,40)})
	local clipped=create("Frame",clip,{})
	tree.HitNodes[clipped]=byId.check.Node
	assert(HitTest.pick({clipped},tree.HitNodes,root,Vector2.new(10,20)) == nil,"Scrollbar gutter is not a control hit")
	assert(HitTest.pick({clipped},tree.HitNodes,root,Vector2.new(4,20)) == byId.check.Node)
	clip.AbsolutePosition=Vector2.new(20,0)
	assert(HitTest.pick({clipped},tree.HitNodes,root,Vector2.new(4,20)) == nil,"Ancestor clip excludes scrolled-out controls")
	local touchPosition=setmetatable({X=10,Y=20},{__sub=function() return {Magnitude=12} end})
	local touch={UserInputType=Enum.UserInputType.Touch,Position=touchPosition}
	hits={byId.check.Item.BoxGui}
	input.InputBegan:Fire(touch,false); input.InputChanged:Fire(touch); input.InputEnded:Fire(touch,false)
	assert(not page:GetChecked("check"),"Touch scrolling cancels click activation")
	input.InputBegan:Fire(touch,false); input.InputEnded:Fire(touch,false)
	assert(page:GetChecked("check"),"A stationary touch activates the control")
	local resetStop=page:On("f","reset",function(e) e:PreventDefault() end)
	page:Reset("f"); assert(page:GetChecked("check")); resetStop:Disconnect()
	page:Focus("text"); page:SetValue("text","Z")
	local redirectChange=page:On("text","change",function() page:Focus("readonly") end)
	page:Focus("area")
	assert(byId.readonly.Focused and not byId.area.Focused and focused == byId.readonly.Item.Editor,
		"A change handler can redirect focus without leaving two focused controls")
	redirectChange:Disconnect()
	page:Focus("send")
	local redirect=page:On("send","blur",function() page:Focus("readonly") end)
	page:Focus("area")
	assert(byId.readonly.Focused and not byId.area.Focused and focused == byId.readonly.Item.Editor,
		"A focus request from a blur handler must supersede the interrupted focus transition")
	redirect:Disconnect()
	for _=1,200 do input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseWheel,Position=Vector2.new(10,20)}) end
	assert(pendingSnaps==1,"A wheel burst retains only the trailing snap job")
	page:Focus("password")
	page:On("password","blur",function() page.Alive=false; cleanup() end)
	page:Focus("area")
	assert(not byId.area.Focused and focused == nil,"Disposal in a blur handler must stop the pending focus transition")
	cleanup()
	assert(pendingSnaps==0,"Page destruction cancels its pending scroll snap")
	for _,timer in snapTimers do timer.Callback() end -- also simulate a scheduler already resuming cancelled callbacks
	assert(input.InputBegan:Count() == 0 and input.InputEnded:Count() == 0 and focused == nil)
	assert(byId.text.Item.Editor:GetPropertyChangedSignal("Text"):Count() == 0)
	assert(State.limit("A😀B",3) == "A😀" and State.limit("A😀B",2) == "A")
	-- Event bubbling and cancellation remain independent of Roblox signals.
	local bus=Events.new(error); local visited={}
	bus:On(byId.text.Node,"test",function(e) table.insert(visited,"target"); e:StopPropagation() end)
	bus:On(nil,"test",function() table.insert(visited,"page") end)
	bus:Emit(byId.text.Node,"test"); assert(#visited == 1); bus:Destroy()
	-- Mutating listener lists and the DOM during callbacks preserves dispatch.
	local dispatch=Events.new(error)
	local oldParent,newParent={},{ }
	local eventNode={Parent=oldParent}
	local delivered={}
	local removed,added=false,false
	dispatch:On(eventNode,"mutate",function()
		table.insert(delivered,"target")
		eventNode.Parent=newParent
		removed:Disconnect()
		if not added then
			added=true
			dispatch:On(eventNode,"mutate",function() table.insert(delivered,"late-target") end)
			dispatch:On(oldParent,"mutate",function() table.insert(delivered,"late-parent") end)
		end
	end)
	removed=dispatch:On(eventNode,"mutate",function() error("Disconnected snapshot listeners must not run") end)
	dispatch:On(oldParent,"mutate",function() table.insert(delivered,"old-parent") end)
	dispatch:On(newParent,"mutate",function() table.insert(delivered,"new-parent") end)
	dispatch:On(nil,"mutate",function() table.insert(delivered,"page") end)
	for _=1,1000 do dispatch:On({},"unrelated",function() error("Unrelated listener") end) end
	local event=dispatch:Emit(eventNode,"mutate")
	assert(table.concat(delivered,",")=="target,old-parent,late-parent,page","Dispatch freezes ancestry and snapshots each target's relevant listeners at invocation")
	assert(event.CurrentTarget==nil,"CurrentTarget is cleared after dispatch")
	table.clear(delivered);dispatch:Emit(eventNode,"mutate")
	assert(table.concat(delivered,",")=="target,late-target,new-parent,page")
	local retained=dispatch:On(eventNode,"destroy",function() dispatch:Destroy() end)
	dispatch:On(eventNode,"destroy",function() error("Destroy stops later listeners in the current snapshot") end)
	dispatch:Emit(eventNode,"destroy");retained:Disconnect();dispatch:Destroy()
	assert(not pcall(function() dispatch:On(eventNode,"late",function() end) end))
	-- Mixed links/controls follow DOM order; positive tabindex still precedes it.
	local focusDoc=Parser.parse('<input id="first"><a id="middle" href="#">Middle</a><button id="last">Last</button><a id="invisible" href="#" style="visibility:hidden">Hidden</a><input id="radio-first" type="radio" name="group"><input id="radio-selected" type="radio" name="group" checked><a id="priority-link" href="#" tabindex="2">Priority</a><button id="priority-button" tabindex="1">Priority</button>')
	local focusRoot=create("ScrollingFrame",nil,{AbsoluteSize=Vector2.new(320,240)})
	local focusTree=renderer.build(focusDoc,focusRoot,error,function(font) return font end)
	blocks.arrange(focusTree,300,0,0,function() return true end)
	local focusPage={Document=focusDoc,Root=focusRoot,Alive=true,AddCleanup=function() end}
	local focusCleanup=Controller.start(focusPage,focusTree,function() end,error,{Input=input,PlayerGui=playerGui,Factory=factory})
	local focusEvents={}
	focusPage:On("focus",function(e) table.insert(focusEvents,e.Target.Attributes.id) end)
	local tabKey={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab}
	for _,expected in {"priority-button","priority-link","first","middle","last","radio-selected","priority-button"} do
		input.InputBegan:Fire(tabKey,true)
		assert(focusEvents[#focusEvents]==expected,"Keyboard focus must reach "..expected..", got "..tostring(focusEvents[#focusEvents]))
	end
	function input:IsKeyDown(key) return key==Enum.KeyCode.LeftShift end
	input.InputBegan:Fire(tabKey,true)
	assert(focusEvents[#focusEvents]=="radio-selected","Shift+Tab reverses the same document order")
	focusPage.Alive=false;focusCleanup()
	do
		function input:IsKeyDown() return false end
		local dialogDoc=Parser.parse('<button id="outside">Outside</button><dialog id="link-dialog"><button disabled>Disabled</button><input style="visibility:hidden"><a id="dialog-link" href="#">Link first</a><button id="dialog-button">Button second</button></dialog><dialog id="media-dialog"><div id="dialog-media" preload="none"></div><button>After media</button></dialog><dialog id="auto-dialog"><a href="#">Before autofocus</a><a id="dialog-auto" href="#" autofocus tabindex="-1">Autofocus</a></dialog>')
		local dialogRoot=create("ScrollingFrame",nil,{AbsoluteSize=Vector2.new(320,240),CanvasPosition=Vector2.new(0,0)})
		local dialogTree=renderer.build(dialogDoc,dialogRoot,error,function(font) return font end)
		blocks.arrange(dialogTree,300,0,0,function() return true end)
		-- The actual media runtime uses a deterministic native VideoFrame substitute.
		local mediaNode=DOM.findById(dialogDoc,"dialog-media")
		local dialogMedia={Node=mediaNode,MediaKind="video",Source="rbxassetid://21",Controls=true,VideoGui={Pause=function() end}}
		dialogTree.MediaItems={dialogMedia};dialogTree.MediaByNode={[mediaNode]=dialogMedia}
		local cleanups={}
		local dialogPage={Document=dialogDoc,Root=dialogRoot,Alive=true,AddCleanup=function(_,callback) table.insert(cleanups,callback) end}
		Controller.start(dialogPage,dialogTree,function() end,error,{Input=input,PlayerGui=playerGui,Factory=factory,RunService={Heartbeat=signal()},ContentProvider={}})
		local focusedId
		dialogPage:On("focus",function(e) focusedId=e.Target.Attributes.id end)
		assert(dialogPage:ShowModal("link-dialog") and focusedId=="dialog-link","Dialog initial focus includes links and skips disabled/hidden controls")
		input.InputBegan:Fire(tabKey,true)
		assert(focusedId=="dialog-button","Dialog Tab uses the same visible candidates in document order")
		dialogPage:CloseDialog("link-dialog")
		assert(dialogPage:ShowModal("media-dialog") and focusedId=="dialog-media" and dialogMedia.FocusVisible,"Dialog initial focus includes media controls before later buttons")
		dialogPage:CloseDialog("media-dialog")
		assert(not dialogMedia.FocusVisible,"Closing a media-focused dialog clears media focus")
		assert(dialogPage:ShowModal("auto-dialog") and focusedId=="dialog-auto","A focusable autofocus link overrides the first candidate even with negative tabindex")
		dialogPage.Alive=false
		for index=#cleanups,1,-1 do cleanups[index]() end
	end
	-- CSS state changes already repaint; only geometry changes require reflow.
	for _,case in {{CSS='background:#123456',Layouts=0},{CSS='width:80px',Layouts=1}} do
		local stateDoc=Parser.parse('<input id="state-check" type="checkbox">')
		local stateRoot=create('ScrollingFrame',nil,{AbsoluteSize=Vector2.new(320,240)})
		local stateTree=renderer.build(stateDoc,stateRoot,error,function(font) return font end,nil,nil,nil,
			'#state-check:checked{'..case.CSS..'}')
		blocks.arrange(stateTree,300,0,0,function() return true end)
		local statePage={Document=stateDoc,Root=stateRoot,Alive=true,AddCleanup=function() end}
		local requested=0
		local dispose=Controller.start(statePage,stateTree,function() requested+=1 end,error,
			{Input=input,PlayerGui=playerGui,Factory=factory})
		requested=0
		statePage:SetChecked('state-check',true)
		assert(requested==case.Layouts,'Form CSS must distinguish paint-only changes from layout changes: '..case.CSS..' requested '..requested)
		if case.Layouts==0 then
			assert(stateTree.Controls[1].Item.Style.Background==Color3.fromRGB(18,52,86),'Paint-only CSS remains applied')
		end
		statePage.Alive=false;dispose()
	end
	local validationDoc=Parser.parse('<form id="valid"><input id="required" name="field" required><button id="submit">Go</button></form>')
	local required=State.create(DOM.findById(validationDoc,"required"))
	local submitter=State.create(DOM.findById(validationDoc,"submit"))
	local validationEvents=Events.new(error)
	local validation=Model.new(validationDoc,{required,submitter},validationEvents,function() end)
	local invalidCount,validCount=0,0
	validationEvents:On(nil,"invalid",function() invalidCount+=1 end,true)
	validationEvents:On(nil,"submit",function() validCount+=1 end)
	function validation:Focus(c) self.Focused=c end
	validation:Activate(submitter)
	assert(invalidCount == 1 and validCount == 0 and validation.Focused == required)
	validation:SetValue(required,"filled"); validation:Activate(submitter)
	assert(validCount == 1)
	validation:SetValue(required,""); submitter.Node.Attributes.formnovalidate=""
	validation:Activate(submitter); assert(validCount == 2)
	validation:Destroy(); validationEvents:Destroy()
	do
		local radioDoc=Parser.parse('<form id="radio-a"></form><form id="radio-b"></form>')
		local formA,formB=DOM.findById(radioDoc,"radio-a"),DOM.findById(radioDoc,"radio-b")
		local radios,changedCount={},0
		local function radio(parent,name,checked,required)
			local attrs={type="radio",name=name}
			if checked then attrs.checked="" end
			if required then attrs.required="" end
			local node=DOM.element("input",attrs);DOM.append(parent,node)
			local c=State.create(node);table.insert(radios,c);return c
		end
		local first,last
		for index=1,1000 do
			local c=radio(formA,"large",true,index==1)
			if index==1 then first=c end
			last=c
		end
		local otherForm=radio(formB,"large",true,true)
		local unnamedA,unnamedB=radio(formA,"",true,false),radio(formA,"",true,false)
		local radioBus=Events.new(error)
		local radioModel=Model.new(radioDoc,radios,radioBus,function() changedCount+=1 end)
		assert(not first.Checked and last.Checked and otherForm.Checked and unnamedA.Checked and unnamedB.Checked,"Radio initialization chooses the last checked in each named form group; unnamed radios remain independent")
		radioModel:SetChecked(first,true)
		assert(first.Checked and not last.Checked and otherForm.Checked)
		changedCount=0;radioModel:Reset(formA)
		assert(changedCount==1002 and not first.Checked and last.Checked and otherForm.Checked,"Reset paints each affected control once and never toggles another form")
		local submits,invalids=0,0
		radioBus:On(formA,"submit",function() submits+=1 end)
		radioBus:On(nil,"invalid",function() invalids+=1 end,true)
		radioModel:Submit(formA)
		assert(submits==1 and invalids==0,"One checked member satisfies the entire required group")
		radioModel:SetChecked(last,false);radioModel:Submit(formA)
		assert(submits==1 and invalids==1,"Required radio validation is recalculated after selection changes")
		radioModel:Destroy();radioBus:Destroy()
	end
	print("Forms: layout/reuse, labels, text/password, datalist filtering, radio groups, events, submit/reset, hit ordering and cleanup passed")
end
