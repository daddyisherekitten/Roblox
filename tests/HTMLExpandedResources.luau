--!strict
return function(Parser,Node,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,CanvasRuntime,MediaSources,fixture)
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local guis={};local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(800,900)
		if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,"Component GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)

 local document=Parser.parseDocument(fixture.html)
 local root=factory.create('ScrollingFrame',nil,{})
 local messages={};local mediaResolver=MediaSources.new({[fixture.assets.sound]='31'}, {[fixture.assets.sound]='32'}, {})
 local imageResolver=function(source)if source==fixture.assets.first then return 'rbxassetid://11'elseif source==fixture.assets.second then return 'rbxassetid://12'end;return nil end
 local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,imageResolver,nil,nil,nil,nil,nil,nil,'https://example.test/expanded-resources',mediaResolver)
 local events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
 local page={Alive=true,Document=document,DocumentURL='https://example.test/expanded-resources',BaseURL='https://example.test/expanded-resources',Root=root,FormModel=model,Events=events,Cleanups={}}
 function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
 function page:RefreshDOMControls()model:RefreshControls()end
 function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
 local realm,flushing=nil,false;local viewport={Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollWidth=800,ScrollHeight=600,ScrollX=0,ScrollY=0}
 function page:GeometryViewport()return viewport end
 function page:HasPendingLayout()return false end
 local layoutPasses=0
 local function arrange(targets)
  layoutPasses+=1;tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
  viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
 end
 function page:FlushScriptLayout()
  if flushing or not realm then return end;flushing=true;local needed,targets=realm:Flush();if needed then arrange(targets)end;flushing=false
 end
 local loads,temporaryDestroyed,canvasCreated,canvasDestroyed=0,0,0,0
 local function pixels(blue)
  local value=buffer.create(if blue then 8 else 4);for offset=0,buffer.len(value)-1,4 do buffer.writeu8(value,offset,if blue then 0 else 255);buffer.writeu8(value,offset+2,if blue then 255 else 0);buffer.writeu8(value,offset+3,255)end;return value
 end
 function page:EnsureCanvasRuntime()
  if not self.CanvasRuntime then self.CanvasRuntime=CanvasRuntime.start(self,tree,error,{HostOnly=true,Asset={
   CreateEditableImage=function()canvasCreated+=1;return {WritePixelsBuffer=function()end,Destroy=function()canvasDestroyed+=1 end}end,
   CreateEditableImageAsync=function(_,uri)loads+=1;local blue=uri=='rbxassetid://12';assert(blue or uri=='rbxassetid://11',tostring(uri));return {Size=Vector2.new(if blue then 2 else 1,1),ReadPixelsBuffer=function()return pixels(blue)end,Destroy=function()temporaryDestroyed+=1 end}end
  }},0)end;return self.CanvasRuntime
 end
 local services={Clock=function()return 0 end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end},
  LoadImage=function(_,callback,spec)local blue=spec.Source==fixture.assets.second;callback(true,{Width=if blue then 2 else 1,Height=1});return function()end end,
  AudioAdapter={CanPlayType=function()return 'probably'end,Open=function()return {Snapshot=function()return {Position=0,Duration=.1}end,Select=function()end,Load=function()end,Set=function()end,Pause=function()end,Play=function()end,Destroy=function()end}end}}
 arrange();root:SetAttribute('Status','ready')
 local diagnostics={};realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
 local function settle()
  for _=1,20 do page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks();if not realm:HasPending()and tasks==0 then break end end
  page:FlushScriptLayout();assert(#diagnostics==0,table.concat(diagnostics,' | '));assert(#messages==0,table.concat(messages,' | '))
 end
 local function run(code)assert(realm:Run(code),table.concat(realm.Diagnostics,' | '));settle()end
 local function check(expression,value,label)
  run('window.resourcesValue=JSON.stringify('..expression..');')
  assert(realm.Window.Get('resourcesValue')==value,label..' expected '..value..' actual '..tostring(realm.Window.Get('resourcesValue')))
 end
 local function node(id)return assert(Node.findById(document,id),id)end
 run(fixture.source..'\nwindow.resourcesSetup=expandedResourcesSetup('..fixture.assetsJson..');')
 check('resourcesSetup',fixture.setupJson,'Expanded media/source/track IDL')
 check('expandedResourceRects()',fixture.rectsJson,'Expanded mounted dimensions')
 local audio=assert(tree.MediaByNode[node('sound')]);local video=assert(tree.MediaByNode[node('movie')])
 assert(audio.MediaKind=='audio'and audio.Source=='rbxassetid://31'and audio.SelectedSource==fixture.assets.sound,'Expanded audio kind/source did not use actual HTML local names')
 assert(video.MediaKind=='video'and video.Source=='rbxassetid://32'and #video.Tracks==1 and video.Tracks[1].Node==node('real-track'),'Foreign/no-namespace tracks acquired HTML source semantics')
 local caption=assert(model:Resolve(node('caption')));local other=assert(model:Resolve(node('other')))
 local captionGui,otherGui=caption.Item.Gui,other.Item.Gui
 check('expandedResourceDraw()',fixture.firstJson,'Original prefixed image Canvas pixels')
 run('resizeRecords.sort((a,b)=>a[0]<b[0]?-1:a[0]>b[0]?1:0);')
 check('resizeRecords',fixture.resizeJson,'Expanded/non-HTML inline ResizeObserver boxes')
 local photo=assert(tree:FindImageItem(node('photo')));local photoGui=photo.ImageGui;local photoSource=node('photo')
 check('expandedResourceUpdate()',fixture.updateJson,'Prefixed native control captions')
 assert(caption.Caption=='Next'and other.Caption=='Next'and model:Resolve(node('caption'))==caption and model:Resolve(node('other'))==other and caption.Item.Gui==captionGui and other.Item.Gui==otherGui,'Prefixed live text/value update lost native control or caption')
 assert(tree:FindImageItem(photoSource)==photo and photo.ImageGui==photoGui and photo.Source=='rbxassetid://12'and photo.IntrinsicWidth==2 and photo.IntrinsicHeight==1,'Prefixed image resource update reused a stale source or recreated its image GUI')
 check('expandedResourceDraw()',fixture.secondJson,'Changed prefixed image Canvas pixels')
 assert(loads==2 and temporaryDestroyed==2,'Temporary decoded images were retained or old pixels were reused')
 check('expandedResourceForeignAttributes()',fixture.foreignJson,'Foreign attributes cannot change HTML image/control state')
 check('[resources.photo.complete,resources.photo.naturalWidth,resources.photo.naturalHeight]',fixture.naturalJson,'Prefixed decoded natural dimensions')
 local preserved=caption.Item.Gui
 run('resources.audio.controls=false;')
 assert(tree.MediaByNode[node('sound')]==nil and audio.Gui.Destroyed,'Hidden prefixed audio kept its rendering box/GUI')
 check('[resources.audio.getBoundingClientRect().width,resources.audio.getBoundingClientRect().height,resources.audio.controls,getComputedStyle(resources.audio).display]',fixture.offJson,'Prefixed audio controls off')
 run('resources.audio.controls=true;')
 check('[resources.audio.getBoundingClientRect().width,resources.audio.getBoundingClientRect().height,resources.audio.controls,getComputedStyle(resources.audio).display]',fixture.onJson,'Prefixed audio controls on')
 assert(tree.MediaByNode[node('sound')].MediaKind=='audio'and caption.Item.Gui==preserved,'Audio controls reattachment changed its kind or unrelated native control')
 check('expandedResourceDirectText()',fixture.directTextJson,'Prefixed button direct text mutation')
 assert(caption.Caption=='Direct'and caption.Item.Gui==preserved,'Direct prefixed button text mutation lost its retained control')
 for _,record in fixture.edges do
  check('expandedResourceEdges("'..record.mode..'")',record.rectsJson,'Inline replaced edges/transform '..record.mode)
  check('(function(){const latest={};for(const e of resizeRecords)latest[e[0]]=e;return ["photo","drawing","sound","movie"].map(id=>latest[id]);})()',record.resizeJson,'Inline replaced ResizeObserver edges/transform '..record.mode)
 end
 local before=layoutPasses
 run('resources.caption.style.color="rgb(10,20,30)";')
 assert(layoutPasses==before and caption.Item.Gui==preserved,'Paint-only prefixed control update performed layout/replaced its GUI')
 run('resourceObserver.disconnect();resources.photo.remove();resources.drawing.remove();resources.audio.remove();resources.movie.remove();')
 assert(photoGui.Destroyed,'Removed prefixed image did not dispose its GUI')
 page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;model:Destroy();events:Destroy()
 assert(canvasCreated==canvasDestroyed and temporaryDestroyed==loads,'Expanded resource disposal leaked native images')
 print('H05 expanded resource rendering: native rectangles, image pixels/replacement, source/track namespace guards, ResizeObserver, controls, retained paint and disposal passed')
end
