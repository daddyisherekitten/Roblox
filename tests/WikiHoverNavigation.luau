--!strict
-- Actual published Wiki scripts through mounted Browser -> HTML -> pointer input.
return function(loadBrowser,loadBinding,fixture,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages,website,workModules)
	local counting=false
	local counts={}
	local originals={}
	local function count(module,field,label)
		local original=assert(module[field],label..' instrumentation requires the actual module export')
		table.insert(originals,{Module=module,Field=field,Original=original})
		module[field]=function(...)
			if counting then counts[label]=(counts[label]or 0)+1 end
			return original(...)
		end
	end
	count(workModules.Style,'resolve','style resolution')
	count(workModules.Selectors,'matches','selector matching')
	count(workModules.Generated,'update','generated-content evaluation')
	count(workModules.BorderBox,'update','box repaint preparation')
	count(workModules.BorderBox,'repaint','border repaint')
	count(workModules.BoxTransform,'apply','box transform paint')
	local function beginHoverWork()
		table.clear(counts);counting=true
	end
	local function endHoverWork(operation)
		counting=false
		for label,amount in counts do
			assert(amount==0,'Wiki '..operation..' performed '..amount..' unnecessary '..label..' operations')
		end
	end
	local ok,message=xpcall(function()
	local f=fixture()
	local host=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local browser=loadBrowser(f).mount(host,{AutoOpen=false,PersistenceEnabled=false,ExternalBaseURL=website.URL,ResolveExternal=function(url,base)return{URL=URL.resolve(base or website.URL,url).URL,Kind='external'}end,Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task}})
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local layoutOverrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	layoutOverrides['Layout/WordLayout']=loadWordLayout(layoutOverrides)
	local block=loadBlockLayout(layoutOverrides)
	local trees={};local builds,mounts,ready=0,0,0
	local guiService={ReducedMotionEnabled=false,GetPropertyChangedSignal=function()return f.Signal()end}
	local hostGame={GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then guiService else nil end}
	local pageModule=loadHTMLPage({
		['Rendering/GuiFactory']=factory,
		['Rendering/RenderTree']={build=function(doc,root,diagnostic)builds+=1;local tree=renderer.build(doc,root,diagnostic,function(font)return font end);trees[doc]=tree;return tree end},
		['Layout/BlockLayout']=block,['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,hostGame,f)
	local diagnostics={}
	local engine={URL=URL,Websites={url=function()return website.URL end}}
	function engine.Websites.resolveURL(base,href)
		local result=URL.resolve(base,href)
		if result.Path=='/wiki1/index.html'then result.Kind='internal';result.Name='Wiki'
		elseif result.Path=='/fortuneCookie/index.html'then result.Kind='internal';result.Name='Target'
		else result.Kind='external'end
		return result
	end
	function engine.Websites.get(name)
		local source=if name=='Wiki'then website else{HTML='<!doctype html><html><body><p id="target">Navigated</p></body></html>',Options={JavaScript=false}}
		local result=table.clone(source);result.Options=table.clone(source.Options or{})
		result.Options.RenderWorkBudgetMS=0
		result.Options.InputServices={Task=f.Task}
		result.Options.JavaScriptServices=table.clone(result.Options.JavaScriptServices or{})
		result.Options.JavaScriptServices.Task=f.Task;result.Options.JavaScriptServices.Clock=function()return f:Clock()end
		return result
	end
	function engine.mountHTML(target,html,options)return pageModule.mount(target,html,options)end
	local binding=loadBinding(f).new(browser,engine,{Services={Create=f.Create,Input=f.Input,RunService=f.Run,PlayerGui=f.PlayerGui,Task=f.Task},Diagnostic=function(message)table.insert(diagnostics,tostring(message))end,PageMounted=function()mounts+=1 end,PageReady=function()ready+=1 end})
	local tab=browser:Open(website.URL);f:Drain()
	local page=assert(binding:GetPage(tab),'Wiki mount failed: '..tostring(tab.Error))
	assert(page.Alive and mounts==1 and ready==1 and #diagnostics==0,table.concat(diagnostics,'\n'))
	local tree=assert(trees[page.Document]);local wiki=assert(Node.findById(page.Document,'wikiLinks'))
	local anchors={}
	for _,li in wiki.Children do for _,child in li.Children do if child.Name=='a'then table.insert(anchors,child)end end end
	assert(#anchors==25,'Published Wiki must contain 15 real and 10 dead links')
	local html=assert(Node.findElement(page.Document,function(node)return node.Name=='html'end))
	local initialRootStyle,initialRootCursor=html.Attributes.style,tree.NodeStyles[html].Cursor
	local initialBuilds=builds
	local initialStats=page.LastLayoutStats
	local hidden,pending=0,0
	page.Root:GetPropertyChangedSignal('Visible'):Connect(function()if not page.Root.Visible then hidden+=1 end end)
	page.Root:GetAttributeChangedSignal('Status'):Connect(function()if page.Root:GetAttribute('Status')~='ready'then pending+=1 end end)
	local function descendant(node,ancestor)while node do if node==ancestor then return true end;node=node.Parent end;return false end
	local function hitGUI(anchor)
		for gui,node in tree.HitNodes do
			if descendant(node,anchor)and gui.Visible and gui.AbsoluteSize.X>0 and gui.AbsoluteSize.Y>0 then return gui end
		end
		error('Original Wiki anchor has no painted hit GUI: '..Node.textContent(anchor))
	end
	local function move(gui)
		beginHoverWork()
		local position,size=gui.AbsolutePosition,gui.AbsoluteSize
		local x,y=position.X+math.min(size.X/2,3),position.Y+math.min(size.Y/2,3)
		f:Hits(gui);f.Input.Mouse=f.Vector2.new(x,y)
		f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,x,y));f:Drain()
		endHoverWork('pointer movement')
		assert(html.Attributes.style==initialRootStyle and tree.NodeStyles[html].Cursor==initialRootCursor,'Link hover changed the inherited document cursor')
		return x,y
	end
	local function leave()
		beginHoverWork()
		f:Hits();f.Input.Mouse=f.Vector2.new(2000,2000)
		f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,2000,2000));f:Drain()
		endHoverWork('pointer exit')
		assert(html.Attributes.style==initialRootStyle and tree.NodeStyles[html].Cursor==initialRootCursor,'Link exit changed the inherited document cursor')
	end
	local function reveal(gui)
		local localY=gui.AbsolutePosition.Y-page.Root.AbsolutePosition.Y
		if localY<0 or localY+gui.AbsoluteSize.Y>=page.Root.AbsoluteSize.Y then
			page.Root.CanvasPosition=f.Vector2.new(0,page.Root.CanvasPosition.Y+localY-30);f:Drain()
		end
	end
	-- Original native callback names still run through real pointer input, while
	-- the host bridge expresses the pointer on the link itself through CSS.
	-- Merely retaining the GUI is insufficient: count actual cascade and paint
	-- work so a cursor-only document-wide recascade cannot regress silently.
	local first=anchors[1];local originalGUI=hitGUI(first)
	local x,y=move(originalGUI)
	assert(page.LastLayoutStats==initialStats,'Original Wiki LinkHover caused a layout pass')
	assert(originalGUI.Parent and hitGUI(first)==originalGUI,'Original Wiki LinkHover replaced the painted anchor GUI')
	assert(builds==initialBuilds,'Cursor-only Wiki hover rebuilt the render tree ('..initialBuilds..' -> '..builds..')')
	assert(tree.NodeStyles[first].Cursor=='pointer','Original Wiki link did not expose its CSS pointer cursor')
	for _=1,3 do move(originalGUI)end
	leave()
	assert(tree.NodeStyles[html].Cursor==initialRootCursor,'Original LinkOut handler changed the document cursor')
	assert(builds==initialBuilds,'Cursor-only Wiki hover rebuilt the render tree')
	assert(page.LastLayoutStats==initialStats,'Cursor-only Wiki hover caused layout work')
	assert(hidden==0 and pending==0 and page.Root.Visible and page.Root:GetAttribute('Presented'),'Wiki flashed/unpresented while hovering')
	assert(hitGUI(first)==originalGUI and originalGUI.Parent,'Hover replaced the anchor GUI')
	local entries=0;for _,child in wiki.Children do if child.Name=='li'then entries+=1 end end
	assert(entries==25 and binding:GetPage(tab)==page and mounts==1,'Hover changed the Wiki document')
	for _,anchor in anchors do
		local gui=hitGUI(anchor);reveal(gui);move(gui)
		assert(tree.NodeStyles[anchor].Cursor=='pointer','Wiki link did not expose its pointer cursor: '..Node.textContent(anchor))
		leave()
		assert(gui.Parent and hitGUI(anchor)==gui,'Hover replaced an original Wiki link: '..Node.textContent(anchor))
		assert(page.LastLayoutStats==initialStats and hidden==0 and pending==0,'Wiki link hover caused layout/presentation work: '..Node.textContent(anchor))
	end
	-- Rapid direct transitions and moves between separately painted fragments
	-- must obey the same zero-cascade/paint budget as enter/exit through gaps.
	for _,anchor in anchors do move(hitGUI(anchor))end
	local fragments={}
	for gui,node in tree.HitNodes do
		if descendant(node,first)and gui.Visible and gui.AbsoluteSize.X>0 and gui.AbsoluteSize.Y>0 then table.insert(fragments,gui)end
	end
	assert(#fragments>0,'The first original Wiki link has no rendered fragments')
	for index=1,20 do move(fragments[(index-1)%#fragments+1])end
	leave()
	-- Click a real site (not one of the original dead aliases) via native input.
	local fortune
	for _,anchor in anchors do if Node.textContent(anchor)=='Fortune Cookie'then fortune=anchor;break end end
	assert(fortune,'Published original Fortune Cookie alias is missing')
	local clickGUI=hitGUI(fortune)
	reveal(clickGUI)
	x,y=move(clickGUI)
	local before=#tab.History
	local pressed=f:Begin(clickGUI,nil,x,y);f.Input.InputEnded:Fire(pressed);f:Drain()
	assert(tab.URL=='http://localhost:8000/fortuneCookie/index.html','Original Wiki onclick could not navigate after hover: '..tostring(tab.URL))
	assert(#tab.History==before+1 and mounts==2 and ready==2 and not page.Alive,'Native click failed to replace the original page once')
	local target=assert(binding:GetPage(tab));assert(Node.findById(target.Document,'target'),'Navigation did not mount the target document')
	assert(#diagnostics==0,table.concat(diagnostics,'\n'))
	browser:Destroy();f:Drain();assert(not target.Alive and f:GlobalConnections()==0)
	print('WikiHoverNavigation: 25 original links, zero cascade/generated/box work on hover, stable presentation and native navigation passed')
	end,debug.traceback)
	counting=false
	for _,entry in originals do entry.Module[entry.Field]=entry.Original end
	assert(ok,message)
end
