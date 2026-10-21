--!strict
-- All three current game Wikis through Browser, HTML, CSS, VM and pointer input.
return function(loadBrowser,loadBinding,fixture,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages,websites,Memory)
	local f=fixture();local byRoute={};for _,entry in websites do byRoute[entry.Route]=entry.Website end
	local storageHost=Memory.new()
	local host=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local browser=loadBrowser(f).mount(host,{AutoOpen=false,PersistenceEnabled=false,ExternalBaseURL='http://localhost:8000/wiki1/index.html',
		ResolveExternal=function(url,base)return{URL=URL.resolve(base or'http://localhost:8000/wiki1/index.html',url).URL,Kind='external'}end,
		Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task}})
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local layout={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	layout['Layout/WordLayout']=loadWordLayout(layout)
	local trees={};local builds,mounts,ready=0,0,0
	local guiService={ReducedMotionEnabled=false,GetPropertyChangedSignal=function()return f.Signal()end}
	local hostGame={GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then guiService else nil end}
	local pageModule=loadHTMLPage({['Rendering/GuiFactory']=factory,
		['Rendering/RenderTree']={build=function(doc,root,diagnostic,_,...)builds+=1;local tree=renderer.build(doc,root,diagnostic,function(font)return font end,...);trees[doc]=tree;return tree end},
		['Layout/BlockLayout']=loadBlockLayout(layout),['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,hostGame,f)
	local engine={URL=URL,Websites={url=function(name)return'http://localhost:8000'..name end}}
	function engine.Websites.resolveURL(base,href)
		local result=URL.resolve(base,href);if byRoute[result.Path]then result.Kind='internal';result.Name=result.Path else result.Kind='missing'end;return result
	end
	function engine.Websites.get(name)
		local result=table.clone(assert(byRoute[name],name));result.Options=table.clone(result.Options)
		result.Options.RenderWorkBudgetMS=0;result.Options.InputServices={Task=f.Task}
		result.Options.JavaScriptServices=table.clone(result.Options.JavaScriptServices or{})
		result.Options.JavaScriptServices.Task=f.Task;result.Options.JavaScriptServices.Clock=function()return f:Clock()end;return result
	end
	function engine.mountHTML(target,html,options)return pageModule.mount(target,html,options)end
	local diagnostics={}
	local binding=loadBinding(f).new(browser,engine,{StorageHost=storageHost,Services={Create=f.Create,Input=f.Input,RunService=f.Run,PlayerGui=f.PlayerGui,Task=f.Task},
		Diagnostic=function(message)table.insert(diagnostics,tostring(message))end,PageMounted=function()mounts+=1 end,PageReady=function()ready+=1 end})
	local context=browser:Open('http://localhost:8000/wiki1/index.html');f:Drain()
	local function descendant(node,ancestor)while node do if node==ancestor then return true end;node=node.Parent end;return false end
	local hoverCount=0
	for index=1,3 do
		local page=assert(binding:GetPage(context),'Wiki '..index..' did not mount')
		assert(page.DocumentURL=='http://localhost:8000/wiki'..index..'/index.html')
		assert(#diagnostics==0,table.concat(diagnostics,'\n'))
		assert(page.JavaScriptRuntime and #page.JavaScriptRuntime.Diagnostics==0,'Original Wiki scripts failed')
		local wiki=assert(Node.findById(page.Document,'wikiLinks'));local tree=assert(trees[page.Document])
		local anchors={};for _,li in wiki.Children do for _,child in li.Children do if child.Name=='a'then table.insert(anchors,child)end end end
		assert(#anchors==32,'Each Wiki must expose 20 sites, 10 dead links and the other two Wikis')
		if index==1 then for _,anchor in anchors do
			assert(anchor.Attributes.class~='visted'and tree.NodeStyles[anchor].Color==Color3.fromRGB(0,46,196),'A fresh play host must begin with unvisited blue Wiki links')
		end end
		local html=Node.findElement(page.Document,function(node)return node.Name=='html'end)
		local rootStyle,rootCursor=html.Attributes.style,tree.NodeStyles[html].Cursor
		local initialStats,initialBuilds=page.LastLayoutStats,builds
		local function hitGUI(anchor)
			for gui,node in tree.HitNodes do if descendant(node,anchor)and gui.Visible and gui.AbsoluteSize.X>0 and gui.AbsoluteSize.Y>0 then return gui end end
			error('Wiki link has no painted hit surface')
		end
		local function move(anchor)
			local gui=hitGUI(anchor);local localY=gui.AbsolutePosition.Y-page.Root.AbsolutePosition.Y
			if localY<0 or localY+gui.AbsoluteSize.Y>=page.Root.AbsoluteSize.Y then page.Root.CanvasPosition=f.Vector2.new(0,page.Root.CanvasPosition.Y+localY-30);f:Drain()end
			local p,s=gui.AbsolutePosition,gui.AbsoluteSize;local x,y=p.X+math.min(3,s.X/2),p.Y+math.min(3,s.Y/2)
			f:Hits(gui);f.Input.Mouse=f.Vector2.new(x,y);f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,x,y));f:Drain()
			return gui,x,y
		end
		for _,anchor in anchors do
			local gui=move(anchor)
			assert(tree.NodeStyles[anchor].Cursor=='pointer','Original Wiki link lost hand cursor')
			f:Hits();f.Input.Mouse=f.Vector2.new(2000,2000);f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,2000,2000));f:Drain()
			assert(gui.Parent and hitGUI(anchor)==gui,'Original Wiki hover replaced its text')
			assert(builds==initialBuilds and page.LastLayoutStats==initialStats,'Original Wiki hover caused layout/rebuild work')
			assert(html.Attributes.style==rootStyle and tree.NodeStyles[html].Cursor==rootCursor,'Hover mutated the inherited root cursor');hoverCount+=1
		end
		local nextIndex=if index==3 then 1 else index+1
		local wanted="SiteClick('http://wiki"..nextIndex..".ann')";local target
		for _,anchor in anchors do if anchor.Attributes.onclick==wanted then target=anchor end end
		local gui,x,y=move(assert(target,'Cross-Wiki link missing'))
		local pressed=f:Begin(gui,nil,x,y);f.Input.InputEnded:Fire(pressed);f:Drain()
		assert(context.URL=='http://localhost:8000/wiki'..nextIndex..'/index.html','Native cross-Wiki navigation failed')
		assert(not page.Alive and mounts==index+1 and ready==index+1,'A native Wiki click must commit exactly once')
	end
	assert(hoverCount==96 and #diagnostics==0)
	local function wikiVisit(page,index,expected)
		local wiki=assert(Node.findById(page.Document,'wikiLinks'));local tree=assert(trees[page.Document]);local found=false
		for _,li in wiki.Children do for _,anchor in li.Children do
			if anchor.Name=='a'and anchor.Attributes.onclick=="SiteClick('http://wiki"..index..".ann')"then
				found=true
				assert((anchor.Attributes.class=='visted')==expected,'Original Wiki visited class must follow the current play host')
				assert(tree.NodeStyles[anchor].Color==(if expected then Color3.fromRGB(72,2,98)else Color3.fromRGB(0,46,196)),'Original Wiki CSS must paint visited purple only in the same play session')
			end
		end end
		assert(found,'Cross-Wiki link missing from visited assertion')
	end
	local returned=assert(binding:GetPage(context))
	wikiVisit(returned,2,true);wikiVisit(returned,3,true)
	assert(storageHost:Prepare(context.URL)('local').Values['wttg2:visited:wiki2.ann']=='1','The actual imported bridge records a Wiki visit in the shared memory host')
	browser:Destroy();f:Drain();assert(f:GlobalConnections()==0)
	local function standaloneWiki(memory)
		local website=engine.Websites.get('/wiki1/index.html');local options=table.clone(website.Options)
		options.DocumentURL='http://localhost:8000/wiki1/index.html';options.StorageHost=memory;options.CSS=website.CSS;options.Stylesheets=website.Stylesheets
		options.InputServices={Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task};options.JavaScriptServices.RunService=f.Run
		local page=pageModule.mount(host,website.HTML,options);f:Drain()
		assert(page.JavaScriptRuntime and #page.JavaScriptRuntime.Diagnostics==0,'Standalone original Wiki scripts failed')
		return page
	end
	local sameRun=standaloneWiki(storageHost)
	wikiVisit(sameRun,2,true);wikiVisit(sameRun,3,true);sameRun:Destroy();f:Drain()
	storageHost:Destroy()
	local freshHost=Memory.new();local freshRun=standaloneWiki(freshHost)
	wikiVisit(freshRun,2,false);wikiVisit(freshRun,3,false)
	assert(freshHost:Prepare('http://localhost:8000/wiki1/index.html')('local').Values['wttg2:visited:wiki2.ann']==nil,'A new play host must not restore visited markers')
	freshRun:Destroy();freshHost:Destroy();f:Drain();assert(f:GlobalConnections()==0)
	print('FullGameWikiNavigation: three actual Wikis, 96 stable pointer hovers, native I→II→III→I navigation, same-session purple visits, fresh-session blue reset and cleanup passed')
end
