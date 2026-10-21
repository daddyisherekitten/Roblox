--!strict
return function(Parser, DOM, State, Model, Events, Controller, loadRenderTree, loadWordLayout, loadBlockLayout)
	local doc=Parser.parse('<form id="f"><select id="s" name="choice" required><button><selectedcontent></selectedcontent></button><option value="" disabled>Bitte wählen<option value="a">Kurz<option value="b" selected>Eine lange Option</select></form>')
	assert(#doc.Diagnostics == 0,"Optional option end tags must parse without nesting options")
	-- HTML's group label algorithm uses only the first element child, and only
	-- when it is an HTML legend. Empty legends override the label as well.
	for _,case in {
		{'<optgroup label="Attribute">\n<!--x--><legend><b>Rich</b>  caption</legend><option>A</option></optgroup>','Rich caption'},
		{'<optgroup label="Attribute"><legend></legend><option>A</option></optgroup>',''},
		{'<optgroup label="Attribute"><span>Before</span><legend>Later</legend><option>A</option></optgroup>','Attribute'},
		{'<optgroup label="Attribute"><legend>First</legend><legend>Later</legend><option>A</option></optgroup>','First'},
		{'<optgroup label="Attribute"><legend>A <img alt="picture"><script>ignored()</script> B</legend><option>A</option></optgroup>','A picture B'},
		{'<optgroup label="&#160; A &#160;"><option>A</option></optgroup>','\u{a0} A \u{a0}'},
		{'<optgroup label="  A   B  "><option>A</option></optgroup>','  A   B  '},
	}do
		local grouped=Parser.parseDocument('<!doctype html><select id="group-probe" style="appearance:base-select">'..case[1]..'</select>')
		local record=State.create(DOM.findById(grouped,'group-probe'))
		assert(record.SelectRows[1].IsGroup and record.SelectRows[1].Caption==case[2],'First HTML legend/ASCII group label: '..case[1])
	end
	local c=State.create(DOM.findById(doc,"s"))
	assert(#c.Options == 3 and c.SelectedIndex == 3 and c.Caption == "Eine lange Option")
	local events=Events.new(error)
	local notifications,changes,submits=0,0,0
	local model=Model.new(doc,{c},events,function(_,layout) assert(not layout); changes+=1 end)
	events:On(nil,"input",function() notifications+=1 end)
	events:On(nil,"change",function() notifications+=1 end)
	events:On(nil,"submit",function() submits+=1 end)
	model:Select(c,1,true); assert(c.Value == "b", "Disabled options cannot be picked")
	model:Select(c,2,true); assert(c.Value == "a" and notifications == 2)
	model:Select(c,2,true); assert(notifications == 2,"Reselecting the same option emits no change")
	model:SetValue(c,"missing"); assert(c.SelectedIndex == 0 and c.Value == "" and c.Caption == "" and #model:Data(c.Form) == 0)
	model:Submit(c.Form); assert(submits == 0)
	model:SetValue(c,""); assert(c.SelectedIndex == 1 and #model:Data(c.Form) == 0)
	model:Submit(c.Form); assert(submits == 0)
	model:Reset(c.Form); assert(c.Value == "b" and c.SelectedIndex == 3 and notifications == 2)
	model:Submit(c.Form); assert(submits == 1 and model:Data(c.Form)[1].Value == "b")
	local cases={
		{'<select id="s"><option disabled>A<option>B</select>',"B",2},
		{'<select id="s"><option selected>A<option selected>B</select>',"B",2},
		{'<select id="s"><option disabled selected>A<option>B</select>',"A",1},
		{'<select id="s"><option disabled>A</select>',"",0},
		{'<select id="s"></select>',"",0},
		{'<select id="s"><optgroup disabled><option>A</optgroup><option label="Anzeige"> B  C </select>',"B C",2},
	}
	for _,case in cases do
		local parsed=Parser.parse(case[1]); assert(#parsed.Diagnostics == 0)
		local control=State.create(DOM.findById(parsed,"s")); assert(control.Value == case[2] and control.SelectedIndex == case[3])
	end
	local duplicateDoc=Parser.parse('<select id="s"><option value="x">First</option><option value="x" selected>Second</option></select>')
	local duplicate=State.create(DOM.findById(duplicateDoc,"s"))
	local duplicateModel=Model.new(duplicateDoc,{duplicate},Events.new(error),function() end)
	duplicateModel:SetValue(duplicate,"x"); assert(duplicate.SelectedIndex == 1 and duplicate.Caption == "First")
	local selectedContentDoc=Parser.parse('<form id="mirror-form"><select id="mirror"><button><selectedcontent></selectedcontent></button><option value="a" label="Popup Alpha">Alpha content</option><option value="b" label="Popup Beta" selected>Beta content</option></select></form>')
	local mirror=State.create(DOM.findById(selectedContentDoc,"mirror"))
	assert(mirror.SelectedContent and mirror.Caption=="Beta content" and mirror.Options[2].Caption=="Popup Beta",'selectedcontent mirrors option contents instead of the label attribute')
	local mirrorModel=Model.new(selectedContentDoc,{mirror},Events.new(error),function() end)
	mirrorModel:Select(mirror,1,true);assert(mirror.Caption=="Alpha content")
	mirrorModel:Reset(mirror.Form);assert(mirror.Caption=="Beta content",'selectedcontent follows reset')
	local multipleDoc=Parser.parse('<select id="multiple" multiple><button><selectedcontent></selectedcontent></button><option label="Popup">Content</option></select>')
	local multiple=State.create(DOM.findById(multipleDoc,'multiple'))
	assert(not multiple.SelectedContent and multiple.Caption=='' and multiple.SelectMultiple and multiple.SelectList,
		'multiple select starts empty without a selected option and disables selectedcontent')
	local listDoc=Parser.parse('<form id="many"><select id="colors" name="color" multiple size="3" required><option selected>Rot</option><option>Grün</option><option selected>Blau</option></select></form>')
	local colors=State.create(DOM.findById(listDoc,'colors'))
	assert(colors.SelectSize==3 and colors.SelectedIndices[1] and colors.SelectedIndices[3] and not colors.SelectedIndices[2])
	local listChanges=0
	local listModel=Model.new(listDoc,{colors},Events.new(error),function() listChanges+=1 end)
	local entries=listModel:Data(colors.Form)
	assert(#entries==2 and entries[1].Value=='Rot' and entries[2].Value=='Blau','Selected values appear separately in form data')
	listModel:Select(colors,2,true,false)
	assert(colors.SelectedIndices[2] and not colors.SelectedIndices[1] and not colors.SelectedIndices[3])
	listModel:Select(colors,3,true,true)
	assert(colors.SelectedIndices[2] and colors.SelectedIndices[3],'Ctrl-click adds a second option')
	listModel:Select(colors,2,true,true)
	assert(not colors.SelectedIndices[2] and colors.SelectedIndices[3],'Ctrl-click removes a selected option')
	listModel:Select(colors,1,true,false,true)
	assert(colors.SelectedIndices[1] and colors.SelectedIndices[2] and not colors.SelectedIndices[3],'Shift-click selects a range')
	listModel:Reset(colors.Form)
	assert(colors.SelectedIndices[1] and colors.SelectedIndices[3] and not colors.SelectedIndices[2] and listChanges==5,'Reset restores all default selections')
	local tallDoc=Parser.parse('<select id="tall" size="3"><option>A</option><option>B</option></select>')
	local tall=State.create(DOM.findById(tallDoc,'tall'))
	assert(tall.SelectList and not tall.SelectMultiple and tall.SelectedIndex==0,'A tall single-select starts without an implicit choice')
	local function signal()
		local entries={}; local s={}
		function s:Connect(fn)
			local entry={fn=fn,Connected=true}; function entry:Disconnect() self.Connected=false end
			table.insert(entries,entry); return entry
		end
		function s:Fire(...) for _,entry in table.clone(entries) do if entry.Connected then entry.fn(...) end end end
		return s
	end
	local objects={}
	local function offset(value,axis,parentSize)
		if not value then return 0 end
		local part=if axis == 1 then value.X else value.Y
		return if part then part.Offset+part.Scale*parentSize else value[axis]+(value[if axis == 1 then "XScale" else "YScale"] or 0)*parentSize
	end
	local factory={}
	function factory.create(class,parent,props)
		assert(class ~= "TextButton" and class ~= "ImageButton" and class ~= "TextBox")
		local gui=table.clone(props); gui.Parent=parent; gui.ClassName=class; gui.Visible=true; gui.Active=false
		local pos=if parent then parent.AbsolutePosition else Vector2.new(0,0)
		local size=if parent then parent.AbsoluteSize else Vector2.new(0,0)
		gui.AbsolutePosition=Vector2.new(pos.X+offset(props.Position,1,size.X),pos.Y+offset(props.Position,2,size.Y))
		gui.AbsoluteSize=Vector2.new(offset(props.Size,1,size.X),offset(props.Size,2,size.Y))
		local signals={}
		function gui:GetPropertyChangedSignal(key) signals[key]=signals[key] or signal(); return signals[key] end
		function gui:IsA(kind) return kind == class or kind == "GuiObject" end
		function gui:Destroy() self.Destroyed=true end
		table.insert(objects,gui); return gui
	end
	factory.modifier=function(_,_,props) return table.clone(props) end
	local target=factory.create("Frame",nil,{Size=UDim2.fromOffset(320,240)})
	local root=factory.create("ScrollingFrame",target,{Size=UDim2.fromOffset(320,240)})
	local renderer=loadRenderTree(factory)
	local tree=renderer.build(doc,root,error,function(font) return font end)
	local measured=0
	local overrides={["Layout/TextMeasure"]={measure=function(text,_,size) measured+=1; return {X=#text*5,Y=size} end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	blocks.arrange(tree,300,0,0,function() return true end)
	c=tree.Controls[1]; local width=c.Item.BoxWidth
	assert(c.Item.BoxHeight == 21 and c.Item.Label.TextSize == 14 and c.Item.Label.Position[2] == 3,
		"Select must match the input's 19px inner height without enlarging the text")
	assert(c.Item.BoxHeight-1-c.Item.Baseline == 5,"Select baseline must sit 5px above the lower inner border")
	local hits={}
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox() return nil end
	local modifier=nil
	function input:IsKeyDown(key) return key == modifier end
	function input:GetStringForKeyCode(key) return key.Name end
	local now=0
	local page={Document=doc,Root=root,Alive=true}
	function page:AddCleanup(fn) self.Cleanup=fn end
	local cleanup=Controller.start(page,tree,function() error("Select changes must not request page layout") end,error,
		{Input=input,PlayerGui={GetGuiObjectsAtPosition=function() return hits end},Factory=factory,Clock=function() return now end})
	c.Item.BoxGui.AbsolutePosition=Vector2.new(20,30); c.Item.BoxGui.AbsoluteSize=Vector2.new(100,20)
	local function live(name)
		for i=#objects,1,-1 do
			local object=objects[i]
			if object.Name == name then
				local p,valid=object,true
				while p do if p.Destroyed then valid=false; break end; p=p.Parent end
				if valid then return object end
			end
		end
		return nil
	end
	local function click(gui,y)
		hits={gui}
		local event={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(25,y or 35)}
		input.InputBegan:Fire(event,false); input.InputEnded:Fire(event,false)
	end
	local count=0; page:On("change",function() count+=1 end)
	click(c.Item.BoxGui); assert(live("SelectPopup"),"Click opens dropdown")
	local menu=live("SelectPopup")
	assert(menu.AbsolutePosition.X == c.Item.BoxGui.AbsolutePosition.X
		and menu.AbsolutePosition.Y == c.Item.BoxGui.AbsolutePosition.Y+c.Item.BoxGui.AbsoluteSize.Y
		and menu.AbsoluteSize.X == c.Item.BoxGui.AbsoluteSize.X,
		"Dropdown must align with both edges of the select field")
	local selectedRow=live("Option_3")
	assert(selectedRow.AbsolutePosition.X == selectedRow.Parent.AbsolutePosition.X
		and selectedRow.AbsoluteSize.X == selectedRow.Parent.AbsoluteSize.X and selectedRow.BackgroundTransparency == 0,
		"A select with selectedcontent but without base appearance keeps its native selection highlight")
	assert(not live('OptionCheck_3') and not live('OptionCheck_2') and live('OptionText_3').Position[1]==3,
		"The native picker has no custom check column")
	assert(live('Option_3').Position[2]==40 and live('SelectPopup').AbsoluteSize.Y==62,
		'selectedcontent popup uses compact browser option rows: '..tostring(live('Option_3').Position[2])..'/'..tostring(live('SelectPopup').AbsoluteSize.Y))
	assert(live("OptionText_3").BackgroundTransparency == 1)
	click(live("Option_1"),60); assert(live("SelectPopup") and c.Value == "b", "Disabled row keeps selection")
	click(live("OptionText_2"),100); assert(not live("SelectPopup") and c.Value == "a" and c.Item.Label.Text == "Kurz" and count == 1)
	local before=measured
	blocks.arrange(tree,300,0,0,function() return true end)
	assert(c.Item.BoxWidth == width and measured == before,"Selection must preserve intrinsic width and measurement cache")
	page:SetValue("s","b"); assert(c.Caption == "Eine lange Option" and count == 1)
	local key={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Up}
	input.InputBegan:Fire(key,false); assert(c.Value == "a" and count == 2)
	local space={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Space}
	input.InputBegan:Fire(space,false); input.InputEnded:Fire(space,false); assert(live("SelectPopup"))
	key.KeyCode=Enum.KeyCode.Down; input.InputBegan:Fire(key,false); assert(c.Value == "a","Open-list highlight is provisional")
	key.KeyCode=Enum.KeyCode.Escape; input.InputBegan:Fire(key,false); assert(not live("SelectPopup") and c.Value == "a")
	click(c.Item.BoxGui)
	click(root,220); assert(not live("SelectPopup"),"Outside click dismisses the list")
	click(c.Item.BoxGui); c.Item.BoxGui:GetPropertyChangedSignal("AbsolutePosition"):Fire(); assert(not live("SelectPopup"))
	click(c.Item.BoxGui); page:Reset("f"); assert(not live("SelectPopup") and c.Value == "b")
	page:SetValue("s","a");click(c.Item.BoxGui)
	local preventReset=page:On("reset",function(event)event:PreventDefault()end)
	page:Reset("f");assert(live("SelectPopup")and c.Value=="a","A canceled form reset preserves both the current selection and its open picker")
	preventReset:Disconnect();page:Reset("f");assert(not live("SelectPopup")and c.Value=="b")
	click(c.Item.BoxGui)
	key.KeyCode=Enum.KeyCode.Up; input.InputBegan:Fire(key,false)
	local enter={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Return}
	input.InputBegan:Fire(enter,false); input.InputEnded:Fire(enter,false)
	assert(not live("SelectPopup") and c.Value == "a","Enter commits the highlighted option")
	click(c.Item.BoxGui)
	hits={live("Option_3")}
	local touchPosition=setmetatable({X=25,Y=100},{__sub=function() return {Magnitude=12} end})
	local touch={UserInputType=Enum.UserInputType.Touch,Position=touchPosition}
	input.InputBegan:Fire(touch,false); input.InputChanged:Fire(touch); input.InputEnded:Fire(touch,false)
	assert(live("SelectPopup") and c.Value == "a","Dragging the popup must not select an option")
	input.InputBegan:Fire(touch,false); input.InputEnded:Fire(touch,false)
	assert(not live("SelectPopup") and c.Value == "b","A touch tap commits the option")
	c.Item.BoxGui.AbsolutePosition=Vector2.new(20,210)
	click(c.Item.BoxGui,215)
	assert(live("SelectPopup").AbsolutePosition.Y < 210,"A bottom-edge dropdown opens above its field")
	input.WindowFocusReleased:Fire(); assert(not live("SelectPopup"))
	c.Item.BoxGui.AbsolutePosition=Vector2.new(20,30)
	page:Focus('s'); page:SetValue('s','b')
	local initial=count
	local function typeKey(name,processed)
		input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode={Name=name,Value=string.byte(name:lower())}},processed or false)
	end
	typeKey('K'); assert(c.Value == 'a' and count == initial+1 and not live('SelectPopup'))
	typeKey('U'); assert(c.Value == 'a' and count == initial+1,'Unchanged prefix match emits no duplicate change')
	now=2; typeKey('E'); assert(c.Value == 'b' and count == initial+2)
	now=4; modifier=Enum.KeyCode.LeftControl; typeKey('K'); assert(c.Value == 'b'); modifier=nil
	typeKey('K',true); assert(c.Value == 'b','Processed keyboard events do not change selection')
	click(c.Item.BoxGui); assert(live('SelectPopup'))
	typeKey('K'); assert(c.Value == 'b' and count == initial+2 and live('Option_2').BackgroundTransparency == 0
		and live('Option_2').BackgroundColor3==Color3.fromRGB(0,117,255) and live('OptionText_2').TextColor3==Color3.new(1,1,1),
		'Unopted selectedcontent retains the native picker highlight and contrast')
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Escape},false)
	assert(c.Value == 'b' and not live('SelectPopup'),'Escape cancels an open-list search')
	click(c.Item.BoxGui); typeKey('K')
	input.InputBegan:Fire(enter,false); input.InputEnded:Fire(enter,false)
	assert(c.Value == 'a' and count == initial+3 and not live('SelectPopup'),'Enter commits exactly one selection change')
	c.Item.BoxGui.AbsolutePosition=Vector2.new(20,30)
	c.Disabled=true; click(c.Item.BoxGui); assert(not live("SelectPopup")); c.Disabled=false
	click(c.Item.BoxGui); page.Alive=false; cleanup(); cleanup(); assert(not live("SelectPopup"))
	local listTree=renderer.build(listDoc,root,error,function(font) return font end)
	blocks.arrange(listTree,300,0,0,function() return true end)
	local listControl=listTree.Controls[1]
	listControl.Item.BoxGui.AbsolutePosition=Vector2.new(20,30)
	listControl.Item.BoxGui.AbsoluteSize=Vector2.new(120,100)
	listControl.Item.SelectScroll.AbsolutePosition=Vector2.new(21,31)
	listControl.Item.SelectScroll.AbsoluteSize=Vector2.new(118,98)
	assert(listControl.Item.SelectScroll and not listControl.Item.Label and not listControl.Item.SelectArrow)
	assert(listControl.Item.SelectListRows[1].Gui.BackgroundTransparency==0
		and listControl.Item.SelectListRows[2].Gui.BackgroundTransparency==1
		and listControl.Item.SelectListRows[3].Gui.BackgroundTransparency==0
		and listControl.Item.SelectListRows[1].Gui.BackgroundColor3==Color3.fromRGB(206,206,206)
		and listControl.Item.SelectListRows[1].Label.TextColor3==Color3.fromRGB(16,16,16),
		'Multiple list paints inactive selections in browser gray')
	local listInput={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function listInput:GetFocusedTextBox() return nil end
	local listModifier=nil
	function listInput:IsKeyDown(key) return key==listModifier end
	function listInput:GetStringForKeyCode() return '' end
	local listHits={}
	local listPage={Document=listDoc,Root=root,Alive=true}
	function listPage:AddCleanup(fn) self.Cleanup=fn end
	local listCleanup=Controller.start(listPage,listTree,function() end,error,
		{Input=listInput,PlayerGui={GetGuiObjectsAtPosition=function() return listHits end},Factory=factory})
	local function clickOption(index,modifier)
		listModifier=modifier
		listHits={listControl.Item.SelectListRows[index].Label}
		local event={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(25,35)}
		listInput.InputBegan:Fire(event,false);listInput.InputEnded:Fire(event,false)
		listModifier=nil
	end
	clickOption(2)
	assert(listControl.SelectedIndices[2] and not listControl.SelectedIndices[1]
		and listControl.Item.SelectListRows[2].Gui.BackgroundColor3==Color3.fromRGB(0,117,255)
		and listControl.Item.SelectListRows[2].Label.TextColor3==Color3.new(1,1,1))
	listInput.WindowFocusReleased:Fire()
	assert(listControl.Item.SelectListRows[2].Gui.BackgroundColor3==Color3.fromRGB(206,206,206)
		and listControl.Item.SelectListRows[2].Label.TextColor3==Color3.fromRGB(16,16,16),
		'Leaving the list restores the inactive selection colors')
	clickOption(3,Enum.KeyCode.LeftControl)
	assert(listControl.SelectedIndices[2] and listControl.SelectedIndices[3] and #listPage:GetFormData('many')==2)
	clickOption(1,Enum.KeyCode.LeftShift)
	assert(listControl.SelectedIndices[1] and listControl.SelectedIndices[2] and listControl.SelectedIndices[3])
	listPage:Reset('many')
	assert(listControl.SelectedIndices[1] and not listControl.SelectedIndices[2] and listControl.SelectedIndices[3])
	listPage:Focus('colors')
	listInput.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Down},false)
	assert(listControl.SelectedIndices[2] and not listControl.SelectedIndices[1] and not listControl.SelectedIndices[3],
		'Arrow navigation replaces the selection')
	listModifier=Enum.KeyCode.LeftControl
	listInput.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Down},false)
	assert(listControl.ListActiveIndex==3 and listControl.SelectedIndices[2] and not listControl.SelectedIndices[3],
		'Ctrl-arrow moves the active row without changing values')
	listInput.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Space},false)
	assert(listControl.SelectedIndices[2] and listControl.SelectedIndices[3],'Space toggles the active option')
	listModifier=nil
	listPage.Alive=false;listCleanup()
	print("Select: option parsing/defaults, disabled/required, duplicate values, multiple list mouse/keys, form data/reset, popup and cleanup passed")
end
