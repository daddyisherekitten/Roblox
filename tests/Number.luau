--!strict
return function(Number,Parser,DOM,State,Controller,loadRenderTree,loadWordLayout,loadBlockLayout)
	local function state(attributes)
		return State.create(DOM.findById(Parser.parse('<input id="n" type="number" '..attributes..'>'),"n"))
	end
	assert(state('').Value == '' and state('value="invalid"').Value == '')
	for _,raw in {'-','1e','NaN','Infinity','0x20','1,5'} do assert(Number.sanitize(raw) == '') end
	assert(Number.sanitize('1e2') == '1e2' and Number.sanitize('-.5') == '-.5')
	for _,case in {
		{'',1,'1'},{'',-1,'-1'},{'min="5"',1,'5'},
		{'min="1" max="10" value="10"',1,'10'},
		{'min="0" max="10" step="3" value="10"',-1,'9'},
		{'min="0" step=".2" value=".3"',1,'0.4'},
		{'min="0" step=".2" value=".3"',-1,'0.2'},
		{'value=".5"',1,'1.5'}, {'step="any" value="1.5"',1,'2.5'},
	} do assert(Number.step(state(case[1]),case[2]) == case[3],case[1]) end
	assert(Number.step(state('min="10" max="5"'),1) == nil)
	assert(Number.step(state('min="5" value="2"'),-1) == nil)
	assert(Number.step(state('max="10" value="20"'),1) == nil)
	assert(not Number.invalid(state('')) and Number.invalid(state('required')))
	assert(Number.invalid(state('min="0" max="10" value="11"')))
	assert(Number.invalid(state('min="0" step="2" value="3"')))
	assert(not Number.invalid(state('step="any" value=".123"')))
	local function signal()
		local callbacks={}; local s={}
		function s:Connect(fn)
			local c={Connected=true}; function c:Disconnect() self.Connected=false end
			table.insert(callbacks,{fn,c}); return c
		end
		function s:Fire(...) for _,e in table.clone(callbacks) do if e[2].Connected then e[1](...) end end end
		return s
	end
	local focused
	local function create(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		local values={Parent=parent,Visible=true,Text='',AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(400,300)}
		for k,v in props do values[k]=v end
		local signals={}
		local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)
			local old=values[key]; values[key]=value
			if old ~= value and signals[key] then signals[key]:Fire() end
		end})
		function values:IsA(kind) return kind == class or kind == 'GuiObject' end
		function values:GetPropertyChangedSignal(key) signals[key]=signals[key] or signal(); return signals[key] end
		values.Focused,values.FocusLost=signal(),signal()
		function values:IsFocused() return focused == gui end
		function values:CaptureFocus() if focused and focused ~= gui then focused:ReleaseFocus() end; focused=gui; values.Focused:Fire() end
		function values:ReleaseFocus() if focused == gui then focused=nil; values.FocusLost:Fire(false) end end
		function values:Destroy() values.Destroyed=true end
		return gui
	end
	local doc=Parser.parse('<form id="f"><input id="n" name="amount" type="number" min="0" max="10" step=".5" value="2" maxlength="1"><button id="submit">Send</button><input id="other"></form>')
	local root=create('ScrollingFrame',nil,{})
	local tree=loadRenderTree({create=create,modifier=function(_,_,p) return table.clone(p) end}).build(doc,root,error,function(font) return font end)
	local overrides={["Layout/TextMeasure"]={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	loadBlockLayout(overrides).arrange(tree,300,0,0,function() return true end)
	local c=tree.Controls[1]; local item=c.Item
	assert(item.Editor.TextSize == 14 and item.BoxHeight == 21 and item.Editor.Position[2] == 3)
	assert(item.NumberArrows[1] and item.NumberArrows[-1] and item.Editor.Size[1] == item.ContentWidth-18)
	assert(item.NumberArrows[1].Size[1] == 15 and item.NumberArrows[1].Size[2] == 7)
	assert(item.NumberArrows[1].Position[1]+15 == item.BoxWidth-4)
	assert(item.NumberArrows[1].Position[2]+item.NumberGlyphs[1].Position[2] == 4)
	assert(item.NumberArrows[-1].Position[2]+item.NumberGlyphs[-1].Position[2] == 12)
	item.BoxGui.AbsolutePosition=Vector2.new(10,10); item.BoxGui.AbsoluteSize=Vector2.new(item.BoxWidth,item.BoxHeight)
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox() return focused end
	function input:IsKeyDown() return false end
	local hits={item.BoxGui}
	local page={Document=doc,Root=root,Alive=true}
	function page:AddCleanup(fn) self.Cleanup=fn end
	local cleanup=Controller.start(page,tree,function() error('Number changes must not request layout') end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function() return hits end}})
	local inputs,changes,invalid,submits=0,0,0,0
	page:On('input',function() inputs+=1 end); page:On('change',function() changes+=1 end)
	page:On('invalid',function() invalid+=1 end); page:On('submit',function() submits+=1 end)
	page:Focus('n'); item.Editor.Text='-'
	assert(c.Value == '' and c.BadInput and item.Editor.Text == '-' and inputs == 1)
	item.Editor.Text='1e'; assert(c.BadInput and item.Editor.Text == '1e' and inputs == 2)
	item.Editor.Text='1e1'; assert(c.Value == '1e1' and not c.BadInput and inputs == 3)
	page:Focus('other'); assert(changes == 1)
	page:SetValue('n','bad'); assert(c.Value == '' and item.Editor.Text == '' and not c.BadInput and inputs == 3)
	page:Reset('f'); assert(c.Value == '2' and item.Editor.Text == '2')
	page:Focus('n')
	local key={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Up}
	input.InputBegan:Fire(key,true); assert(c.Value == '2.5' and changes == 2)
	page:Focus('other'); assert(changes == 2,'Stepping must not emit a second change on blur')
	local function click(direction,kind)
		hits={item.BoxGui}
		input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(10+item.BoxWidth-7,if direction == 1 then 15 else 26)})
		hits={item.NumberArrows[direction]}
		local event={UserInputType=kind or Enum.UserInputType.MouseButton1,Position=Vector2.new(10+item.BoxWidth-7,if direction == 1 then 15 else 26)}
		input.InputBegan:Fire(event,false); input.InputEnded:Fire(event,false)
	end
	click(-1); assert(c.Value == '2' and changes == 3)
	click(-1,Enum.UserInputType.Touch); assert(c.Value == '1.5')
	click(1,Enum.UserInputType.Touch); assert(c.Value == '2' and changes == 5)
	local listener=page:On('n','click',function(e) e:PreventDefault() end)
	click(1); assert(c.Value == '2'); listener:Disconnect()
	c.ReadOnly=true; click(1); input.InputBegan:Fire(key,true); assert(c.Value == '2')
	c.ReadOnly=false; c.Disabled=true; click(1); assert(c.Value == '2' and #page:GetFormData('f') == 0)
	c.Disabled=false
	local function submit()
		local send=tree.Controls[2].Item; hits={send.BoxGui}
		send.BoxGui.AbsolutePosition=Vector2.new(0,0); send.BoxGui.AbsoluteSize=Vector2.new(400,300)
		local event={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(20,20)}
		input.InputBegan:Fire(event,false); input.InputEnded:Fire(event,false)
	end
	page:SetValue('n','11'); submit(); assert(invalid == 1 and submits == 0 and c.Value == '11')
	page:SetValue('n','2.3'); submit(); assert(invalid == 2 and submits == 0)
	page:SetValue('n','2.5'); submit(); assert(submits == 1 and page:GetFormData('f')[1].Value == '2.5')
	page:Focus('n'); item.Editor.Text='-'; submit(); assert(invalid == 3 and submits == 1)
	page:Reset('f'); assert(c.Value == '2' and not c.BadInput and item.Editor.Text == '2')
	page:Focus('n')
	local beforeChange=changes
	local redirect=page:On('n','input',function() page:Focus('other') end)
	input.InputBegan:Fire(key,true)
	assert(c.Value == '2.5' and changes == beforeChange+1,'Focus redirection during stepping must not duplicate change')
	redirect:Disconnect(); page:Reset('f')
	local before=inputs; cleanup(); item.Editor.Text='3'; assert(c.Value == '2' and inputs == before)
	print('Number: draft input, steps/bounds, validation, passive arrows, keyboard, event counts, reset and cleanup passed')
end
