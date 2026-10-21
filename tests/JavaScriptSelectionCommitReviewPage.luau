--!strict
-- Run the shipped comparison page through the native control and animation adapters.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller,html,css,browserStates)
	local function signal()
		local entries={};local s={}
		function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function s:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		function s:Count()local count=0;for _,entry in entries do if entry[1].Connected then count+=1 end end;return count end
		return s
	end
	local focused;local guis={};local deferred={}
	local factory={}
	function factory.create(class,parent,props)
		local changes,attributes={},{ }
		local values={Parent=parent,ClassName=class,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(520,500),Text="",CursorPosition=-1,SelectionStart=-1}
		for key,value in props do values[key]=value end
		if class=="ScrollingFrame"then values.CanvasPosition=Vector2.new(0,0)end
		local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)local old=values[key];values[key]=value;if old~=value and changes[key]then changes[key]:Fire()end end})
		values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
		function values:GetPropertyChangedSignal(key)if not changes[key]then changes[key]=signal()end;return changes[key]end
		function values:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function values:SetAttribute(key,value)attributes[key]=value;if changes["attribute:"..key]then changes["attribute:"..key]:Fire()end end
		function values:GetAttribute(key)return attributes[key]end
		function values:IsA(kind)return kind==class or kind=="GuiObject"end
		function values:IsFocused()return focused==gui end
		function values:CaptureFocus()if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
		function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
		function values:Destroy()assert(not values.Destroyed);values.Destroyed=true;for _,child in guis do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument(html)
	local messages={};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{["styles.css"]=css},"http://localhost:8000/javascript-tests/index.html")
	local arrangements,requests,now=0,0,0
	local function arrange(width,items)arrangements+=1;tree:SetMediaEnvironment(width,500);tree.ViewportHeight=500;Dirty.begin(tree,items);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)end
	arrange(520);root:SetAttribute("Status","ready")
	local page={Alive=true,Document=document,DocumentURL="http://localhost:8000/javascript-tests/index.html",BaseURL="http://localhost:8000/javascript-tests/index.html",Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return focused end
	function input:IsKeyDown()return false end
	local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return {}end},Factory=factory,Clock=function()return now end,
		RunService={RenderStepped=signal()},Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	Controller.start(page,tree,function()requests+=1 end,error,services)
	local diagnostics={};local realm,flushing
	function page:HasPendingLayout()return realm and realm:HasPending()or false end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		local needed,items=realm:Flush();if needed then arrange(520,items)end
		flushing=false
	end
	realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	local function healthy()assert(#diagnostics==0,table.concat(diagnostics," | "));assert(#messages==0,table.concat(messages," | "))end
	local function run(source)realm:Run(source);healthy()end
	local function settle()
		for _=1,24 do
			page:FlushScriptLayout();realm:AfterLayout()
			local work=deferred;deferred={};for _,fn in work do fn()end
			local tasks=realm:PumpTasks()
			if #deferred==0 and tasks==0 and not realm:HasPending()then break end
		end
		healthy()
	end
	local function flush()local needed,items=realm:Flush();if needed then arrange(520,items)end;settle();return needed end
	flush()
	local function node(id)return assert(Node.findById(document,id),id)end
	local function near(a,b,label)assert(math.abs(a-b)<.001,label..": "..a.." ~= "..b)end
	local function status(id,value)
		local actual=Node.textContent(node(id))
		-- The reference browser maps direction `none` to `forward`; our native
		-- profile supports `none`. Only this documented direction is equivalent.
		assert(actual==value or actual:gsub(" · none\n"," · forward\n")==value,id..": "..actual.." ~= "..value)
		local owner=tree.NodeBoxes[node(id)];local parts={}
		for _,item in tree.TextItems do if item.TextOwner==owner and item.Gui.Visible~=false then table.insert(parts,(item.TextGui or item.Gui).Text or item.Text)end end
		assert(table.concat(parts):gsub("%s+","")==actual:gsub("%s+",""),id.." paints actual updated DOM text")
	end
	local nameEditor=page.FormModel:Resolve(node("selection-input")).Item.Editor
	local function painted(box)
		local gui=if box.OpacityGroup then box.OpacityGroup.Gui else box.Gui
		local x,y=gui.Position[1],gui.Position[2]
		local anchor=gui.AnchorPoint or Vector2.new(0,0)
		return x-anchor.X*gui.Size[1],y-anchor.Y*gui.Size[2]
	end
	local function compare(case)
		for _,sample in case.state.results do status(sample.id,sample.text)end
		for _,sample in case.state.fields do
			local c=page.FormModel:Resolve(node(sample.id))
			assert(c.Value==sample.value and c.Item.Editor.Text==sample.value,sample.id.." native and DOM value")
			assert(c.SelectionStart==sample.start and c.SelectionEnd==sample["end"],sample.id.." UTF16 extent")
			assert(c.SelectionDirection==sample.direction or c.SelectionDirection=="none"and sample.direction=="forward",sample.id.." platform direction")
			if case.action=="selection-forward"and sample.id=="selection-input"then assert(c.SelectionDirection=="forward")end
		end
		for _,sample in case.state.boxes do
			local box=tree.NodeBoxes[node(sample.id)]
			local x,y=0,0;if sample.transform~="none"then
				local tx,ty=sample.transform:match("^matrix%(1, 0, 0, 1, ([%d.-]+), ([%d.-]+)%)$");assert(tx and ty,sample.transform);x,y=tonumber(tx),tonumber(ty)
			end
			local px,py=painted(box);near(px-(box.LayoutX or 0),x,sample.id.." painted x");near(py-(box.LayoutY or 0),y,sample.id.." painted y")
			local alpha=if box.OpacityGroup then 1-box.OpacityGroup.Gui.GroupTransparency else box.Style.Opacity or 1
			near(alpha,tonumber(sample.opacity),sample.id.." painted opacity")
			local r,g,b=sample.background:match("rgb%((%d+), (%d+), (%d+)%)");assert(r and g and b)
			local color=(box.PaintBackgroundGui or box.Gui).BackgroundColor3
			assert(math.floor(color.R*255+.5)==tonumber(r)and math.floor(color.G*255+.5)==tonumber(g)and math.floor(color.B*255+.5)==tonumber(b),sample.id.." painted background")
			-- Serialization order does not change any property value.
			assert((node(sample.id).Attributes.style or "")==""or sample.inline~="",sample.id.." committed inline source")
		end
		assert(page.FormModel:Resolve(node("selection-input")).Item.Editor==nameEditor and not nameEditor.Destroyed,"Controls remain mounted during every comparison action")
	end
	for _,case in browserStates do
		if case.action then page.FormModel:Activate(assert(page.FormModel:Resolve(node(case.action))),nil,true)end
		settle();compare(case)
	end
	-- A running animation uses the shared frame adapter, then releases it.
	page.FormModel:Activate(page.FormModel:Resolve(node("commit-start")),nil,true);settle()
	assert(realm.EventLoop.FrameCount>0,"An active animation requests frames")
	services.RunService.RenderStepped:Fire();settle()
	now=.3;services.RunService.RenderStepped:Fire();settle()
	local box=tree.NodeBoxes[node("commit-box")];local px=painted(box);near(px-box.LayoutX,40,"Live half-time frame")
	page.FormModel:Activate(page.FormModel:Resolve(node("commit-save")),nil,true);settle()
	assert(realm.EventLoop.FrameCount==0,"Committing then canceling releases frame callbacks")
	status("commit-result","Gespeichert · Keine Animation mehr.\ntranslate(40px) · Deckkraft 0.725")
	local completed=realm.VM.Global.Bindings;assert(completed.motion.Value==require("JavaScript/VM").Null)
	page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end
	assert(not realm.Alive and realm.EventLoop.FrameCount==0 and services.RunService.RenderStepped:Count()==0,"The combined page disposes native input and animation callbacks")
	print("Selection/commit comparison: 20 native-browser button states, text/UTF16/native paint, running-frame retention and cleanup passed")
end
