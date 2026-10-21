--!strict
-- Every actual website mounted with its real controls, script host and renderer.
return function(loadBrowser,loadBinding,fixture,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages,websites)
	local byRoute={};for _,entry in websites do byRoute[entry.Route]=entry.Website end
	local f=fixture()
	local host=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local browser=loadBrowser(f).mount(host,{AutoOpen=false,PersistenceEnabled=false,ExternalBaseURL='http://localhost:8000',
		ResolveExternal=function(url,base)return{URL=URL.resolve(base or'http://localhost:8000',url).URL,Kind='external'}end,
		Services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task}})
	local failures={};local failNavigation=browser.FailNavigation
	function browser:FailNavigation(context,request,message)table.insert(failures,tostring(message));return failNavigation(self,context,request,message)end
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local NativeCorners=require('Rendering/BorderCorners')
	local function editable(size)
		local image={Size=size};function image:WritePixelsBuffer(_,_,pixels)self.Pixels=pixels end;function image:Destroy()self.Pixels=nil end;return image
	end
	local layout={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	layout['Layout/WordLayout']=loadWordLayout(layout)
	local guiService={ReducedMotionEnabled=false,GetPropertyChangedSignal=function()return f.Signal()end}
	local hostGame={GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then guiService else nil end}
	local pageModule=loadHTMLPage({['Rendering/GuiFactory']=factory,['Rendering/RenderTree']={build=function(doc,root,diagnostic,_,...)return renderer.build(doc,root,diagnostic,function(font)return font end,...)end},
		['Rendering/BorderCorners']={new=function(diagnostic)return NativeCorners.new(diagnostic,editable)end},
		['Rendering/ResizeGrip']={new=function(diagnostic)return require('Rendering/ResizeGrip').new(diagnostic,editable)end},
		['Rendering/RadioDot']={new=function(diagnostic)return require('Rendering/RadioDot').new(diagnostic,editable)end},
		['Rendering/DisclosureIcons']={new=function(diagnostic)return require('Rendering/DisclosureIcons').new(diagnostic,editable)end},
		-- Native texture allocation is the boundary here; exact SVG scene sources
		-- are exercised independently by NightwebIllustrations.
		['Rendering/SVGImages']={start=function(owner)owner.Root:SetAttribute('SVGReady',true);owner.Root:SetAttribute('SVGVisibleReady',true);return{AddItems=function()end,RemoveItems=function()end}end},
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
		result.Options.JavaScriptServices.Task=f.Task;result.Options.JavaScriptServices.Clock=function()return f:Clock()end
		return result
	end
	function engine.mountHTML(target,html,options)return pageModule.mount(target,html,options)end
	local diagnostics={}
	local binding=loadBinding(f).new(browser,engine,{Services={Create=f.Create,Input=f.Input,RunService=f.Run,PlayerGui=f.PlayerGui,Task=f.Task},Diagnostic=function(message)table.insert(diagnostics,tostring(message))end})
	local pages,probes=0,0
	for _,entry in websites do
		local context=browser:Open(entry.Website.URL);f:Drain()
		local page=assert(binding:GetPage(context),entry.Route..' failed to mount: '..table.concat(failures,'\n'))
		assert(page.Alive and page.Root:GetAttribute('Presented'),entry.Route..' was not presented')
		assert(#diagnostics==0,entry.Route..': '..table.concat(diagnostics,'\n'))
		local problems={};for _,problem in page.Document.Diagnostics do table.insert(problems,tostring(problem.Code)..': '..tostring(problem.Message or problem.Value or''))end
		assert(#problems==0,entry.Route..' document diagnostics: '..table.concat(problems,'\n'))
		assert(Node.findElement(page.Document,function(node)return node.Name=='title'end),entry.Route..' missing title')
		if entry.Probe~=''then
			local realm=assert(page.JavaScriptRuntime,entry.Route..' requires its script runtime')
			realm:Run(entry.Probe);f:Drain()
			assert(#realm.Diagnostics==0,entry.Route..' interaction: '..table.concat(realm.Diagnostics,'\n'))
			assert(#diagnostics==0,entry.Route..': '..table.concat(diagnostics,'\n'));probes+=1
		end
		pages+=1
	end
	assert(pages==25 and probes>=15,'Expected all 25 documents and an interaction for every site')
	browser:Destroy();f:Drain();assert(f:GlobalConnections()==0,'Page iteration leaked input connections')
	print('NightwebRuntime: '..pages..' actual HTML/CSS/JS page mounts, '..probes..' real control/DOM probes and complete cleanup passed')
end
