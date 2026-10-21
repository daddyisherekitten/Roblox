--!strict
return function(Parser,Controller,loadRenderTree)
	local function signal()
		local entries={}; local s={}
		function s:Connect(fn)
			local c={Connected=true,Fn=fn}; function c:Disconnect() self.Connected=false end
			table.insert(entries,c); return c
		end
		function s:Fire(...) for _,c in table.clone(entries) do if c.Connected then c.Fn(...) end end end
		function s:Count() local count=0; for _,c in entries do if c.Connected then count+=1 end end; return count end
		return s
	end
	local function setup(html,ready,external)
		local native=external
		local factory={}
		function factory.create(class,parent,props)
			local gui=table.clone(props); gui.Parent=parent; gui.Visible=true; gui.Enabled=true
			gui.AbsolutePosition=Vector2.new(0,0); gui.AbsoluteSize=Vector2.new(400,300)
			function gui:IsA(kind) return kind == class or (kind == 'GuiObject' and class ~= 'ScreenGui') or (kind == 'LayerCollector' and class == 'ScreenGui') end
			local properties,attributes,attributeSignals={},{},{}
			function gui:GetPropertyChangedSignal(name) properties[name]=properties[name] or signal(); return properties[name] end
			function gui:GetAttributeChangedSignal(name) attributeSignals[name]=attributeSignals[name] or signal(); return attributeSignals[name] end
			function gui:GetAttribute(name) return attributes[name] end
			function gui:SetAttribute(name,value)
				local old=attributes[name]; attributes[name]=value
				if old ~= value then self:GetAttributeChangedSignal(name):Fire() end
			end
			gui.Focused,gui.FocusLost=signal(),signal()
			function gui:IsFocused() return native == self end
			function gui:CaptureFocus() if native and native ~= self then native:ReleaseFocus() end; native=self; self.Focused:Fire() end
			function gui:ReleaseFocus() if native == self then native=nil; self.FocusLost:Fire(false) end end
			function gui:Destroy() self.Destroyed=true end
			return gui
		end
		factory.modifier=function(_,_,props) return table.clone(props) end
		local screen=factory.create('ScreenGui',nil,{})
		local root=factory.create('ScrollingFrame',screen,{})
		root:SetAttribute('Status',if ready then 'ready' else 'loading')
		local document=Parser.parse('<form id="f">'..html..'</form>')
		local tree=loadRenderTree(factory).build(document,root,error,function(font) return font end)
		local byId={}; for _,c in tree.Controls do byId[c.Node.Attributes.id]=c end
		local input={InputBegan=signal(),InputEnded=signal(),InputChanged=signal(),WindowFocusReleased=signal()}
		function input:GetFocusedTextBox() return native end
		function input:IsKeyDown() return false end
		local page={Document=document,Root=root,Alive=true}
		function page:AddCleanup(fn) self.Cleanup=fn end
		Controller.start(page,tree,function(force,item) assert(force and item.Control.Type == 'output','Only the existing output reset may request layout') end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function() return {} end},Factory=factory})
		return page,byId,input,screen
	end
	local page,c=setup([[<input id="disabled" autofocus disabled><fieldset disabled><input id="grouped" autofocus></fieldset>
		<input id="hidden" autofocus type="hidden"><input id="invisible" autofocus style="visibility:hidden">
		<div style="display:none"><input id="removed" autofocus></div><output id="out" autofocus>Output</output>
		<input id="first" type="email" autofocus="false" readonly tabindex="-1"><input id="second" autofocus>]])
	assert(not c.first.Focused and not c.second.Focused)
	local focused=0; page:On('focus',function() focused+=1 end)
	page.Root:SetAttribute('Status','waiting-size'); assert(focused == 0)
	page.Root:SetAttribute('Status','layout'); assert(focused == 0)
	page.Root:SetAttribute('Status','ready')
	assert(c.first.Focused and c.first.Item.Editor:IsFocused() and focused == 1,'First eligible DOM control, even readonly or tabindex=-1')
	assert(page.Root:GetAttributeChangedSignal('Status'):Count() == 1,'Only the cursor refresh listener remains after the autofocus attempt')
	page:Focus('second')
	page.Root:SetAttribute('Status','layout'); page.Root:SetAttribute('Status','ready'); page:Reset('f')
	assert(c.second.Focused and not c.first.Focused and focused == 2,'Resize, partial layout and reset must not reapply autofocus')
	page.Cleanup()
	page,c=setup('<input id="a" autofocus><input id="b">')
	page:Focus('b'); page.Root:SetAttribute('Status','ready'); assert(c.b.Focused and not c.a.Focused); page.Cleanup()
	local other={ReleaseFocus=function() error('Do not take focus from an external TextBox') end}
	page,c=setup('<input id="a" autofocus>',false,other)
	page.Root:SetAttribute('Status','ready'); assert(not c.a.Focused); page.Cleanup()
	local input
	page,c,input=setup('<input id="a" autofocus>')
	input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Tab},false)
	page.Root:SetAttribute('Status','ready'); assert(c.a.Focused,'Tab can focus the first eligible element before ready without a later autofocus override'); page.Cleanup()
	page,c,input=setup('<input id="a" autofocus>')
	input.WindowFocusReleased:Fire(); page.Root:SetAttribute('Status','ready'); assert(not c.a.Focused); page.Cleanup()
	local screen
	page,c,input,screen=setup('<input id="a" autofocus>'); screen.Enabled=false
	page.Root:SetAttribute('Status','ready'); assert(not c.a.Focused); page.Cleanup()
	page,c=setup('<input id="a" autofocus>'); page.Cleanup()
	page.Root:SetAttribute('Status','ready'); assert(not c.a.Focused and page.Root:GetAttributeChangedSignal('Status'):Count() == 0)
	page,c=setup('<button id="a" autofocus>Button</button>',true); assert(c.a.Focused); page.Cleanup()
	page,c=setup('<input id="a" autofocus>')
	page.Root:SetAttribute('Presented',false);page.Root:SetAttribute('Status','ready')
	assert(not c.a.Focused,'Autofocus waits while the measured document is still behind its loading surface')
	page.Root:SetAttribute('Presented',true)
	assert(c.a.Focused and page.Root:GetAttributeChangedSignal('Presented'):Count()==0,'First presentation applies autofocus once and disconnects the extra listener')
	page.Root:SetAttribute('Status','layout');page.Root:SetAttribute('Status','ready');assert(c.a.Focused);page.Cleanup()
	page,c=setup('<input id="a">'); assert(page.Root:GetAttributeChangedSignal('Status'):Count() == 1); page.Cleanup()
	print('Autofocus: first-ready timing, eligible DOM order, existing focus/input preservation, no repeated layout/reset focus and cleanup passed')
end
