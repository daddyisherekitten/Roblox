--!strict
-- Mounted authored directory with real pointer dispatch and a real destination.
return function(loadBrowser,loadBinding,fixture,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages,websites)
	local byRoute={};for _,entry in websites do byRoute[entry.Route]=entry.Website end
	local f=fixture()
	local host=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local entryURL='http://localhost:8000/verzeichnis/index.html'
	local browser=loadBrowser(f).mount(host,{AutoOpen=false,PersistenceEnabled=false,ExternalBaseURL=entryURL,
		ResolveExternal=function(url,base)return{URL=URL.resolve(base or entryURL,url).URL,Kind='external'}end,
		Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task}})
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local layout={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	layout['Layout/WordLayout']=loadWordLayout(layout)
	local trees={};local builds,mounts,ready=0,0,0
	local guiService={ReducedMotionEnabled=false,GetPropertyChangedSignal=function()return f.Signal()end}
	local hostGame={GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then guiService else nil end}
	local pageModule=loadHTMLPage({
		['Rendering/GuiFactory']=factory,
		['Rendering/RenderTree']={build=function(doc,root,diagnostic,_,...)builds+=1;local tree=renderer.build(doc,root,diagnostic,function(font)return font end,...);trees[doc]=tree;return tree end},
		['Layout/BlockLayout']=loadBlockLayout(layout),['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,hostGame,f)
	local diagnostics={}
	local engine={URL=URL,Websites={url=function(name)return 'http://localhost:8000'..name end}}
	function engine.Websites.resolveURL(base,href)
		local result=URL.resolve(base,href)
		if byRoute[result.Path]then result.Kind='internal';result.Name=result.Path else result.Kind='missing'end
		return result
	end
	function engine.Websites.get(name)
		local result=table.clone(assert(byRoute[name],name));result.Options=table.clone(result.Options)
		result.Options.RenderWorkBudgetMS=0;result.Options.InputServices={Task=f.Task}
		result.Options.JavaScriptServices=table.clone(result.Options.JavaScriptServices or{})
		result.Options.JavaScriptServices.Task=f.Task;result.Options.JavaScriptServices.Clock=function()return f:Clock()end
		return result
	end
	function engine.mountHTML(target,html,options)return pageModule.mount(target,html,options)end
	local binding=loadBinding(f).new(browser,engine,{Services={Create=f.Create,Input=f.Input,RunService=f.Run,PlayerGui=f.PlayerGui,Task=f.Task},
		Diagnostic=function(message)table.insert(diagnostics,tostring(message))end,PageMounted=function()mounts+=1 end,PageReady=function()ready+=1 end})
	local context=browser:Open(entryURL);f:Drain()
	local page=assert(binding:GetPage(context),'Directory failed to mount: '..tostring(context.Error))
	assert(page.Alive and mounts==1 and ready==1 and #diagnostics==0,table.concat(diagnostics,'\n'))
	local tree=assert(trees[page.Document]);local initialBuilds,initialStats=builds,page.LastLayoutStats
	local hidden,pending=0,0
	page.Root:GetPropertyChangedSignal('Visible'):Connect(function()if not page.Root.Visible then hidden+=1 end end)
	page.Root:GetAttributeChangedSignal('Status'):Connect(function()if page.Root:GetAttribute('Status')~='ready'then pending+=1 end end)
	local anchors={}
	local function visit(node)
		if node.Name=='a'and(node.Attributes.href or''):match('^/[^/]+/index%.html$')then table.insert(anchors,node)end
		for _,child in node.Children or{}do visit(child)end
	end
	visit(page.Document);assert(#anchors==15,'Directory must link to all 15 authored sites')
	local function descendant(node,ancestor)while node do if node==ancestor then return true end;node=node.Parent end;return false end
	local function hitGUI(anchor)
		for gui,node in tree.HitNodes do if descendant(node,anchor)and gui.Visible and gui.AbsoluteSize.X>0 and gui.AbsoluteSize.Y>0 then return gui end end
		error('Unpainted directory link '..Node.textContent(anchor))
	end
	local function reveal(gui)
		local y=gui.AbsolutePosition.Y-page.Root.AbsolutePosition.Y
		if y<0 or y+gui.AbsoluteSize.Y>=page.Root.AbsoluteSize.Y then page.Root.CanvasPosition=f.Vector2.new(0,page.Root.CanvasPosition.Y+y-30);f:Drain()end
	end
	local function move(gui)
		local p,s=gui.AbsolutePosition,gui.AbsoluteSize;local x,y=p.X+math.min(3,s.X/2),p.Y+math.min(3,s.Y/2)
		f:Hits(gui);f.Input.Mouse=f.Vector2.new(x,y);f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,x,y));f:Drain()
		return x,y
	end
	for _,anchor in anchors do
		local gui=hitGUI(anchor);reveal(gui);move(gui)
		assert(tree.NodeStyles[anchor].Cursor=='pointer','Directory links must expose a hand cursor')
		f:Hits();f.Input.Mouse=f.Vector2.new(2000,2000);f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,2000,2000));f:Drain()
		assert(gui.Parent and hitGUI(anchor)==gui,'Hover replaced directory text')
		assert(builds==initialBuilds and page.LastLayoutStats==initialStats,'Hover caused a directory layout/rebuild')
		assert(hidden==0 and pending==0 and page.Root.Visible,'Hover flashed the directory')
	end
	local target
	for _,anchor in anchors do if anchor.Attributes.href=='/nullpost/index.html'then target=anchor end end
	local gui=hitGUI(assert(target));reveal(gui);local x,y=move(gui)
	local pressed=f:Begin(gui,nil,x,y);f.Input.InputEnded:Fire(pressed);f:Drain()
	assert(context.URL=='http://localhost:8000/nullpost/index.html','Native directory link did not navigate')
	assert(mounts==2 and ready==2 and not page.Alive,'Navigation should mount the destination exactly once')
	local destination=assert(binding:GetPage(context));assert(destination.Alive and #diagnostics==0,table.concat(diagnostics,'\n'))
	browser:Destroy();f:Drain();assert(not destination.Alive and f:GlobalConnections()==0)
	print('NightwebNavigation: 15 stable native link hovers, authored destination navigation and complete cleanup passed')
end
