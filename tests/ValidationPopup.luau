--!strict
return function(Parser,Controller,Messages,Popup,loadRenderTree)
	assert(Messages.get({Type='email',Value='adaw'},'email') == "Please include an '@' in the email address. 'adaw' is missing an '@'.")
	assert(Messages.get({Type='email',Value='a@b,broken',Multiple=true},'email'):find("'broken'",1,true))
	assert(Messages.get({Type='textarea',Value='abc',MinLength=5},'short'):find('5 characters',1,true))
	assert(not Messages.get({Type='password',Value='secret',MinLength=10},'short'):find('secret',1,true))
	local function signal()
		local entries={}; local s={}
		function s:Connect(fn)
			local entry={Connected=true,Fn=fn}; function entry:Disconnect() self.Connected=false end
			table.insert(entries,entry); return entry
		end
		function s:Fire(...) for _,entry in table.clone(entries) do if entry.Connected then entry.Fn(...) end end end
		function s:Count() local count=0; for _,entry in entries do if entry.Connected then count+=1 end end; return count end
		return s
	end
	local objects,focused={},nil
	local factory={}
	function factory.create(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		local values={Parent=parent,Visible=true,Active=false,Selectable=false,Text='',AbsolutePosition=Vector2.new(10,20),AbsoluteSize=Vector2.new(400,300)}
		for key,value in props do values[key]=value end
		local signals={}
		local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)
			local old=values[key]; values[key]=value; if old ~= value and signals[key] then signals[key]:Fire() end
		end})
		function values:IsA(kind) return kind == class or kind == 'GuiObject' end
		function values:GetPropertyChangedSignal(key) signals[key]=signals[key] or signal(); return signals[key] end
		values.Focused,values.FocusLost=signal(),signal()
		function values:IsFocused() return focused == gui end
		function values:CaptureFocus() if focused and focused ~= gui then focused:ReleaseFocus() end; focused=gui; self.Focused:Fire() end
		function values:ReleaseFocus() if focused == gui then focused=nil; self.FocusLost:Fire(false) end end
		function values:Destroy() values.Destroyed=true end
		table.insert(objects,gui); return gui
	end
	function factory.modifier(_,_,props) return table.clone(props) end
	local function live(name)
		for index=#objects,1,-1 do
			local object=objects[index]
			if object.Name == name then
				local parent=object; while parent and not parent.Destroyed do parent=parent.Parent end
				if not parent then return object end
			end
		end
		return nil
	end
	local parent=factory.create('Frame',nil,{})
	local root=factory.create('ScrollingFrame',parent,{})
	local document=Parser.parse('<form id="f"><input id="email" type="email" value="adaw"><button id="submit">Send</button></form>')
	local tree=loadRenderTree(factory).build(document,root,error,function(font) return font end)
	local c,button=tree.Controls[1],tree.Controls[2]
	c.Item.BoxGui.AbsolutePosition=Vector2.new(30,50); c.Item.BoxGui.AbsoluteSize=Vector2.new(200,21)
	local input={InputBegan=signal(),InputEnded=signal(),InputChanged=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox() return focused end
	function input:IsKeyDown() return false end
	local hits={button.Item.BoxGui}
	local page={Document=document,Root=root,Alive=true}
	function page:AddCleanup(fn) self.Cleanup=fn end
	local services={Factory=factory,Input=input,PlayerGui={GetGuiObjectsAtPosition=function() return hits end},MeasureValidationText=function(_,width) assert(width > 0); return Vector2.new(width,42) end}
	local cleanup=Controller.start(page,tree,function() error('Validation must not request layout') end,error,services)
	local submits=0; page:On('submit',function() submits+=1 end)
	local function send()
		hits={button.Item.BoxGui}
		local event={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(40,100)}
		input.InputBegan:Fire(event,false); input.InputEnded:Fire(event,false)
	end
	send()
	assert(live('ValidationPopup') and live('ValidationIcon') and live('ValidationArrow'))
	assert(live('ValidationText').Text == Messages.get(c,'email') and live('ValidationText').RichText == false)
	assert(focused == c.Item.Editor and submits == 0)
	assert(live('ValidationPopup').Parent == parent and live('ValidationPopup').Position[2] == 51)
	local old=live('ValidationPopup'); send(); assert(old.Destroyed and live('ValidationPopup'))
	c.Item.Editor.Text='valid@example.com'; assert(not live('ValidationPopup'),'Typing dismisses the message')
	send(); assert(submits == 1 and not live('ValidationPopup'))
	page:SetValue('email','bad'); send()
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Escape},false)
	assert(not live('ValidationPopup') and focused == c.Item.Editor)
	send(); page:Focus('submit'); assert(not live('ValidationPopup'))
	send(); page:Reset('f'); assert(not live('ValidationPopup'))
	send(); root:GetPropertyChangedSignal('CanvasPosition'):Fire(); assert(not live('ValidationPopup'))
	send(); c.Item.BoxGui:GetPropertyChangedSignal('AbsoluteSize'):Fire(); assert(not live('ValidationPopup'))
	send(); input.WindowFocusReleased:Fire(); assert(not live('ValidationPopup'))
	local cancel=page:On('email','invalid',function(event) assert(event.Data.Reason == 'email' and event.Data.Message); event:PreventDefault() end)
	send(); assert(not live('ValidationPopup') and focused ~= c.Item.Editor and submits == 1)
	cancel:Disconnect()
	c.Item.BoxGui.AbsolutePosition=Vector2.new(330,280); send()
	local host=live('ValidationPopup')
	assert(host and host.Position[1]+host.Size[1] <= 400 and host.Position[2]+host.Size[2] < 280,'Bottom/right edges must keep the message inside the viewport')
	local watched=c.Item.BoxGui:GetPropertyChangedSignal('AbsolutePosition')
	assert(watched:Count() == 1)
	page.Alive=false; cleanup(); cleanup(); assert(not live('ValidationPopup') and watched:Count() == 0)
	local popup=Popup.new(page,services); popup:Open(c,'Test'); assert(not live('ValidationPopup'))
	print('Validation popup: English messages, passive geometry/edge placement, invalid focus/cancellation, editing, reset, scrolling, Escape and cleanup passed')
end
