--!strict
-- Execute the exact shipped review HTML/CSS and option-supplied module.
-- Native controls/layout/paint are retained; Canvas uses its CPU adapter.
return function(Parser,Node,Runtime,VM,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,Surface,html,css,pageOptions,browserStates)
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local guis={};local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(960,900)
		if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{ }
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,"Native GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument(html);local renderMessages={};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(renderMessages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{["styles.css"]=css},"http://localhost:8000/javascript-tests/index.html")
	local events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,DocumentURL="http://localhost:8000/javascript-tests/index.html",BaseURL="http://localhost:8000/javascript-tests/index.html",Root=root,FormModel=model,Events=events,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
	local surfaces={};local nativeCanvas={Alive=true}
	function nativeCanvas:Surface(node,create)local value=surfaces[node];if not value and create~=false then value=Surface.new(tonumber(node.Attributes.width)or 300,tonumber(node.Attributes.height)or 150);surfaces[node]=value end;return value end
	function nativeCanvas:Reset(node,w,h)local value=Surface.new(w,h);surfaces[node]=value;for _,item in tree.CanvasItems do if item.Node==node then item.CanvasSurface=value;item.IntrinsicWidth,item.IntrinsicHeight=w,h end end;return value end
	function nativeCanvas:Publish()end
	function page:EnsureCanvasRuntime()
		if not self.CanvasRuntime then self.CanvasRuntime=nativeCanvas;self:AddCleanup(function()nativeCanvas.Alive=false;table.clear(surfaces)end)end;return nativeCanvas
	end
	local now,realm,flushing=0,nil,false;local viewport={Width=960,Height=900,ClientWidth=960,ClientHeight=900,ScrollWidth=960,ScrollHeight=900,ScrollX=0,ScrollY=0}
	function page:GeometryViewport()return viewport end
	function page:HasPendingLayout()return false end
	local function arrange(targets)
		tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
		viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		local needed,targets=realm:Flush();if needed then arrange(targets)end
		flushing=false
	end
	arrange();root:SetAttribute("Status","ready")
	local options={JavaScriptServices=table.clone(pageOptions.JavaScriptServices or {})};options.JavaScriptServices.Clock=function()return now end
	options.JavaScriptServices.Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}
	options.JavaScriptServices.RunService={RenderStepped=signal()}
	local diagnostics={};realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,options)
	local function healthy()assert(#diagnostics==0,table.concat(diagnostics," | "))end
	local function settle()
		for _=1,24 do
			page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks()
			if not realm:HasPending()and tasks==0 then break end
		end;page:FlushScriptLayout();healthy()
	end
	local function node(id)local result=Node.findById(document,id);assert(result,id);return result end
	local function text(id)return Node.textContent(node(id))end
	local function expected(id,value)
		assert(text(id)==value,id.." expected="..value.." actual="..text(id))
		local owner=tree.NodeBoxes[node(id)];local painted={}
		for _,item in tree.TextItems do if item.TextOwner==owner then
			local gui=item.TextGui or item.Gui;assert(gui and not gui.Destroyed,"Visible result owns a live native text object")
			if gui.Visible~=false then if item.Glyphs then for _,glyph in item.Glyphs do table.insert(painted,glyph.Gui.Text)end else table.insert(painted,gui.Text or item.Text)end end
		end end
		assert(table.concat(painted):gsub("%s+","")==value:gsub("%s+",""),id.." native paint differs from its DOM text: "..table.concat(painted).." / "..value)
	end
	local function click(id)model:Activate(assert(model:Resolve(node(id))),nil,true);settle()end
	local function input(id,value)local c=model:Resolve(node(id));model:SetValue(c,value,true);settle()end
	local function run(code)realm:Run(code);settle()end
	local function advance(seconds)now+=seconds;realm:PumpTasks();settle()end
	settle();healthy();expected("js-status","Bereit · 5 Versuche · derselbe Code in beiden Ansichten")
	assert(#Runtime.scripts(document)==1,"The shipped page initializes once")
	local firstGui=tree.NodeBoxes[node("rule-left")].Gui
	local function color(source)
		local r,g,b=source:match("^rgb%((%d+), (%d+), (%d+)%)$")
		assert(r and g and b,"Expected opaque browser RGB");return Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b))
	end
	for _,case in browserStates do
		if case.action then click(case.action)end
		for _,sample in case.state do
			if sample.id:match("%-result$")or sample.id=="js-status"then expected(sample.id,sample.text)
			else
				local raw=node(sample.id);local style=tree.NodeStyles[raw];assert(style,"Rendered preview style")
				assert(style.Background==color(sample.background),tostring(case.action).." "..sample.id.." background matches Chromium")
				assert(style.Color==color(sample.color),tostring(case.action).." "..sample.id.." text color matches Chromium")
				local padding=tonumber(sample.padding:match("^(%d+)px$"))
				assert(padding and style.Padding[1]==padding,tostring(case.action).." "..sample.id.." padding matches Chromium")
				local box=tree.NodeBoxes[raw];assert(box.Gui.BackgroundColor3==style.Background,"Native background paints the computed style")
			end
		end
		assert(tree.NodeBoxes[node("rule-left")].Gui==firstGui and not firstGui.Destroyed,"CSSOM changes preserve existing GUI identity")
	end
	assert(#renderMessages==0,table.concat(renderMessages," | "))
	healthy();assert(options.MaxSteps==nil and options.JavaScriptServices.MaxSteps==nil,"Production instruction budget")
	page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;model:Destroy();events:Destroy()
	assert(not realm.Alive and realm.EventLoop.FrameCount==0,"CSSOM comparison releases callbacks without an idle frame loop")
	print("JavaScript CSSOM review page: 19 Chromium states match native paint, text and padding; objects retained and teardown complete")
end
