--!strict
return function(loadWindows,loadHost,loadBrowser,loadBinding,fixture,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages,demoSources,loadCatalog)
	local f=fixture();local services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,RunService=f.Run,Task=f.Task}
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local block=loadBlockLayout(overrides);local trees={}
	local guiService={ReducedMotionEnabled=false,GetPropertyChangedSignal=function()return f.Signal()end}
	local pageModule=loadHTMLPage({['Rendering/GuiFactory']=factory,
		['Rendering/RenderTree']={build=function(doc,root,diagnostic)local tree=renderer.build(doc,root,diagnostic,function(font)return font end);trees[doc]=tree;return tree end},
		['Layout/BlockLayout']=block,['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,{GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then guiService else nil end},f)
	local sources={A=[=[<!doctype html><html><head><title>Main</title></head><body><button id="count">Count</button><div id="n">0</div><script>
	var keys=0;var clicks=0;window.addEventListener('keydown',function(){keys++;document.getElementById('n').textContent=String(keys);});
	document.getElementById('count').addEventListener('click',function(){clicks++;});
	</script></body></html>]=],B=[=[<!doctype html><html><head><title>Child</title></head><body><button id="bye">Close</button><div id="n">0</div><script>
	var keys=0;window.addEventListener('keydown',function(){keys++;document.getElementById('n').textContent=String(keys);});
	document.getElementById('bye').addEventListener('click',function(){window.close();});
	</script></body></html>]=]}
	local function module(name,value,children)
		local item={Name=name,Value=value,Children=children or{}}
		function item:IsA(class)return class=='ModuleScript'end
		function item:FindFirstChild(key)for _,child in self.Children do if child.Name==key then return child end end end
		function item:GetChildren()return self.Children end;return item
	end
	local catalogChildren={}
	for name,source in demoSources or{}do table.insert(catalogChildren,module(name,source.Metadata,{module('HTML',source.HTML),module('CSS',source.CSS),module('JavaScript',source.JavaScript)}))end
	local catalog=if loadCatalog then loadCatalog(module('Websites',nil,catalogChildren))else nil
	local engine={URL=URL,Websites={}}
	function engine.Websites.names()return{}end
	function engine.Websites.url()return 'http://localhost:8000/a/index.html'end
	function engine.Websites.resolveURL(base,href)
		local r=URL.resolve(base,href);local names={['/a/index.html']='A',['/b/index.html']='B',['/window-demo/index.html']='Demo',['/window-popup/index.html']='Popup'}
		if names[r.Path]then r.Name=names[r.Path];r.Kind='internal'end;return r
	end
	function engine.Websites.get(name)
		local source=demoSources and demoSources[name]
		if source then
			local website=catalog.get(name);local options=table.clone(website.Options);local js=table.clone(options.JavaScriptServices or{})
			assert(js.ScriptSources and js.ScriptSources[URL.resolve(website.URL,'app.js').URL]==source.JavaScript,'Generated website/catalog lost the external script')
			js.Task=f.Task;js.Clock=function()return f:Clock()end;options.JavaScriptServices=js;options.InputServices={Task=f.Task};options.RenderWorkBudgetMS=0
			return {HTML=website.HTML,Stylesheets=website.Stylesheets,Options=options}
		end
		return {HTML=assert(sources[name]),Options={RenderWorkBudgetMS=0,InputServices={Task=f.Task},JavaScriptServices={Task=f.Task,Clock=function()return f:Clock()end}}}
	end
	local pauseNext,pendingThread,latePage,lateError
	function engine.mountHTML(target,html,options)
		if pauseNext and options.DocumentURL~='about:blank'then
			pauseNext=false;pendingThread=coroutine.running();coroutine.yield('held mount')
			local ok,result=pcall(pageModule.mount,target,html,options)
			if not ok then lateError=result;error(result)end;latePage=result;return latePage
		end
		return pageModule.mount(target,html,options)
	end
	local messages={};local manager=loadWindows(f).new(f.Screen,{Services=services})
	local Browser=loadBrowser(f)
	Browser.PersistenceClient.new=function()error('WindowHost must not start persistent storage by default')end
	local host=loadHost(f).new(manager,Browser,loadBinding(f),engine,{Services=services,MaxWindows=3,Diagnostic=function(m)table.insert(messages,m)end})
	assert(host.Persistence==nil,'The default window family keeps browser data only in memory')
	local record=host:Open(engine.Websites.url());f:Drain();local tab=record.Browser:GetActiveTab();local page=assert(record.Binding:GetPage(tab),tab.Error)
	assert(not record.Browser.Window:FindFirstChild('Resize11')and record.Browser.Window.Position.X.Offset==0,'External window must be the only geometry owner')
	local function run(p,source)p.JavaScriptRuntime:Run(source);assert(#p.JavaScriptRuntime.Diagnostics==0,table.concat(p.JavaScriptRuntime.Diagnostics,' | '))end
	local function global(p,key)return p.JavaScriptRuntime.Window.Get(key)end
	run(page,"var child=window.open('../b/index.html','preview','popup,width=420,height=300,left=60,top=70');var opened=child!==null && !child.closed;")
	f:Drain();assert(global(page,'opened')==true and #manager:GetWindows()==2)
	local second=manager:GetWindows()[2];local childRecord=assert(host.Windows[second]);local childPage=assert(childRecord.Binding:GetPage(childRecord.Browser:GetActiveTab()))
	assert(second:GetSize().X==480 and second:GetSize().Y==448 and second:GetPosition().X==60 and second:GetPosition().Y==70,'Popup features use the current 480px browser minimum and 360px content minimum plus native chrome')
	assert(childRecord.Browser.View.TabStrip==nil and childRecord.Browser.View.Address.Visible and not childRecord.Browser.View.Back.Root.Visible,'Popup keeps its address field and hides navigation actions')
	assert(childPage.Root.Visible and page.Root.Visible and not record.Browser.Input.Active and childRecord.Browser.Input.Active,'Unfocused pages stay painted but input belongs to the foreground window')
	local key=f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.X);f.Input.InputBegan:Fire(key,false);f:Drain()
	assert(global(page,'keys')==0 and global(childPage,'keys')==1,'Keyboard must reach exactly one realm')
	run(page,"var again=window.open('../b/index.html','preview','popup,width=900');var reused=again===child;");f:Drain()
	assert(global(page,'reused')==true and #manager:GetWindows()==2,'Named windows must reuse their stable proxy')
	local priorChild=childPage;childPage=assert(childRecord.Binding:GetPage(childRecord.Browser:GetActiveTab()))
	assert(childPage~=priorChild and not priorChild.Alive,'A nonempty named-window URL navigates its existing context to a fresh document')
	-- First mouse click on the background content both focuses and activates it.
	local count=Node.findById(page.Document,'count');local countGui=page.FormModel:Resolve(count).Item.BoxGui
	f.Input.Mouse=f.Vector2.new(countGui.AbsolutePosition.X+2,countGui.AbsolutePosition.Y+2)
	local click=f:Begin(countGui,nil,f.Input.Mouse.X,f.Input.Mouse.Y);f.Input.InputEnded:Fire(click);f:Drain()
	assert(manager:GetFocused()==record.Window and global(page,'clicks')==1,'First background click was lost during scope reconnection')
	f.Input.InputBegan:Fire(key,false);f:Drain();assert(global(page,'keys')==1 and global(childPage,'keys')==0,'Foreground main receives the key; the navigated child retains its fresh keyboard state')
	local before=page.LastLayoutStats;local grip=assert(record.Window.Root:FindFirstChild('Grip_SE'),'Imported WindowManager exposes the southeast native resize grip')
	local start=grip.AbsolutePosition+f.Vector2.new(2,2);local held=f:Begin(grip,nil,start.X,start.Y)
	f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,start.X+40,start.Y+30));f:Drain()
	assert(record.Browser:IsResizing()and page.Root.Parent:GetAttribute('HTMLViewportResizing')and page.LastLayoutStats==before,'Managed resize must hold real HTML layout until release')
	f.Input.InputEnded:Fire(held);f:Drain();assert(not record.Browser:IsResizing()and not page.Root.Parent:GetAttribute('HTMLViewportResizing'))
	second:Minimize();assert(not childPage.Root.Visible);second:Restore();assert(childPage.Root.Visible)
	-- Child-side close is queued: its current JS handler finishes before disposal.
	run(childPage,"window.close();var finished=true;");assert(global(childPage,'finished')==true and childPage.Alive);f:Drain()
	assert(not second.Alive and not childPage.Alive and #manager:GetWindows()==1)
	run(page,"var wasClosed=child.closed;window.close();var mainStillOpen=!window.closed;");f:Drain()
	assert(global(page,'wasClosed')==true and global(page,'mainStillOpen')==true and record.Window.Alive,'Scripts must not close a user-created main window')
	run(page,"var separateWindow=window.open('../b/index.html');");f:Drain();assert(#manager:GetWindows()==2 and #record.Browser:GetTabs()==1,'An open without popup features still creates a separate window')
	local regularRecord=assert(host.Windows[manager:GetWindows()[2]]);assert(#regularRecord.Browser:GetTabs()==1 and regularRecord.Browser.View.TabStrip==nil and regularRecord.Browser.View.Back.Root.Visible,'A regular auxiliary window owns one document and the navigation toolbar')
	run(page,"separateWindow.close();");f:Drain();assert(#manager:GetWindows()==1 and #record.Browser:GetTabs()==1)
	run(page,"var safe=window.open('../b/index.html','preview','popup,noopener');var noProxy=safe===null;");f:Drain();assert(global(page,'noProxy')==true and #manager:GetWindows()==2)
	local safeWindow=manager:GetWindows()[2];safeWindow:Close();f:Drain()
	run(page,"var selfWindow=window.open('','_self');var isSelf=selfWindow===window;var blocked=window.open('https://example.com/','_blank','popup')===null;");f:Drain()
	assert(global(page,'isSelf')==true and global(page,'blocked')==true and #manager:GetWindows()==1,'Self target='..tostring(global(page,'isSelf'))..'; external rejected='..tostring(global(page,'blocked'))..'; windows='..#manager:GetWindows())
	run(page,"var one=window.open('../b/index.html','one','popup');var two=window.open('../b/index.html','two','popup');var limited=window.open('../b/index.html','three','popup')===null;");f:Drain()
	assert(global(page,'limited')==true and #manager:GetWindows()==3)
	run(page,"one.close();two.close();");f:Drain();assert(#manager:GetWindows()==1)
	-- Close while a real mount is suspended, then let its stale completion return.
	pauseNext=true;run(page,"var slow=window.open('../b/index.html','slow','popup');");f:Drain();assert(pendingThread and #manager:GetWindows()==2)
	manager:GetWindows()[2]:Close();f:Resume(pendingThread);f:Drain();assert(latePage and not latePage.Alive and #manager:GetWindows()==1,'Suspended mount after close: page='..tostring(latePage)..'; error='..tostring(lateError)..'; windows='..#manager:GetWindows())
	-- Opener navigation does not close a separately opened window.
	run(page,"var separate=window.open('../b/index.html','survivor','popup');");f:Drain();local survivor=manager:GetWindows()[2]
	record.Browser:Reload();f:Drain();assert(not page.Alive and survivor.Alive)
	local replacement=assert(record.Binding:GetPage(tab));survivor:Close();record.Window:Close();f:Drain()
	assert(not replacement.Alive and #manager:GetWindows()==0 and next(host.Contexts)==nil and next(host.Names)==nil)
	if demoSources then
		local demo=host:Open(demoSources.Demo.Metadata.URL);f:Drain();local demoPage=assert(demo.Binding:GetPage(demo.Browser:GetActiveTab()))
		demoPage.Events:Emit(Node.findById(demoPage.Document,'open'),'click',{},{Bubbles=true});f:Drain();assert(#manager:GetWindows()==2)
		local popup=manager:GetWindows()[2];local popupRecord=host.Windows[popup];local popupPage=assert(popupRecord.Binding:GetPage(popupRecord.Browser:GetActiveTab()))
		assert(not popupRecord.Browser.View.NavigationVisible and popupRecord.Browser.View.Bar.Visible and popupRecord.Browser.View.Address.Visible and popupRecord.Browser.View.ChromeHeight==46 and popupRecord.Browser.View.TabStrip==nil,'Popup must hide only navigation buttons and retain its address bar')
		assert(not popupRecord.Browser.View.Back.Root.Visible and not popupRecord.Browser.View.Forward.Root.Visible and not popupRecord.Browser.View.Reload.Root.Visible)
		popupRecord.Browser:SetNavigationVisible(false);assert(not popupRecord.Browser.View.NavigationVisible and not popupRecord.Browser.View.Back.Root.Visible)
		popupRecord.Browser:SetNavigationVisible(true);assert(popupRecord.Binding:GetPage(popupRecord.Browser:GetActiveTab())==popupPage,'Toggling popup controls remounted HTML')
		assert(popup.Native.title=='Mein Zusatzfenster'and #popupPage.JavaScriptRuntime.Diagnostics==0 and #demoPage.JavaScriptRuntime.Diagnostics==0,
			'Actual demo: title='..popup.Native.title..'; popup='..table.concat(popupPage.JavaScriptRuntime.Diagnostics,' | ')..'; main='..table.concat(demoPage.JavaScriptRuntime.Diagnostics,' | '))
		local function clickDemo(id)demoPage.Events:Emit(Node.findById(demoPage.Document,id),'click',{},{Bubbles=true});f:Drain()end
		local function clickToolbar(button)
			local gui=button.Root;assert(gui.Visible and button.Entry.Enabled~=false,'Toolbar action must be visible and enabled')
			local point=gui.AbsolutePosition+f.Vector2.new(gui.AbsoluteSize.X/2,gui.AbsoluteSize.Y/2);f.Input.Mouse=point
			local click=f:Begin(gui,nil,point.X,point.Y);f.Input.InputEnded:Fire(click);f:Drain()
		end
		clickDemo('position');clickDemo('move');clickDemo('size');clickDemo('grow');clickDemo('measure')
		assert(popup:GetPosition().X==105 and popup:GetPosition().Y==95 and popup:GetSize().X==560)
		clickDemo('write-dom');assert(Node.textContent(Node.findById(popupPage.Document,'remote-value'))=='Hallo aus dem Hauptfenster')
		clickDemo('append-dom');clickDemo('read-dom');assert(Node.textContent(Node.findById(popupPage.Document,'extra')):find('Im Hauptfenster erstellt.',1,true))
		clickDemo('send');assert(Node.textContent(Node.findById(demoPage.Document,'message-status')):find('Hallo zurück!',1,true))
		clickDemo('wrong-origin');assert(Node.textContent(Node.findById(demoPage.Document,'message-status'))=='Falsche Herkunft: Diese Nachricht muss verworfen werden.')
		clickDemo('navigate');popupPage=assert(popupRecord.Binding:GetPage(popupRecord.Browser:GetActiveTab()))
		assert(popupPage.DocumentURL:find('variante=2',1,true)and Node.textContent(Node.findById(popupPage.Document,'variant')):find('Variante 2',1,true))
		clickToolbar(popupRecord.Browser.View.Back);popupPage=assert(popupRecord.Binding:GetPage(popupRecord.Browser:GetActiveTab()))
		assert(not popupPage.DocumentURL:find('variante=2',1,true),'Popup toolbar Back failed')
		clickToolbar(popupRecord.Browser.View.Forward);popupPage=assert(popupRecord.Binding:GetPage(popupRecord.Browser:GetActiveTab()))
		assert(popupPage.DocumentURL:find('variante=2',1,true),'Popup toolbar Forward failed')
		clickToolbar(popupRecord.Browser.View.Reload);assert(not popupPage.Alive,'Popup toolbar Reload failed')
		clickDemo('replace');clickDemo('reload');popupPage=assert(popupRecord.Binding:GetPage(popupRecord.Browser:GetActiveTab()))
		demoPage.FormModel.UserActivationUntil=os.clock()+10;clickDemo('fullscreen')
		assert(demo.Window.Fullscreen and demoPage.JavaScriptRuntime.Fullscreen.Element==Node.findById(demoPage.Document,'fullscreen-panel'))
		clickDemo('exit-fullscreen');assert(not demo.Window.Fullscreen)
		popupPage.Events:Emit(Node.findById(popupPage.Document,'close'),'click',{},{Bubbles=true});f:Drain();assert(not popup.Alive)
		demoPage.Events:Emit(Node.findById(demoPage.Document,'check'),'click',{},{Bubbles=true});f:Drain()
		assert(Node.textContent(Node.findById(demoPage.Document,'status'))=='Das Zusatzfenster ist geschlossen.')
  -- Actual current website close handler displays the synchronous getter value.
  clickDemo('open');local immediatePopup=assert(manager:GetWindows()[2]);local immediateRecord=assert(host.Windows[immediatePopup]);local immediatePage=assert(immediateRecord.Binding:GetPage(immediateRecord.Browser:GetActiveTab()))
  demoPage.Events:Emit(Node.findById(demoPage.Document,'close'),'click',{},{Bubbles=true})
  assert(Node.textContent(Node.findById(demoPage.Document,'status'))=='Schließen angefordert · closed unmittelbar danach: true'and immediatePopup.Alive and immediatePage.Alive,'Actual demo must show logical closed=true before deferred physical close')
  f:Drain();assert(not immediatePopup.Alive and not immediatePage.Alive,'Actual demo close request completes physical disposal')
  clickDemo('close');assert(Node.textContent(Node.findById(demoPage.Document,'status'))=='Kein geöffnetes Zusatzfenster vorhanden.','Actual demo repeated close reports no live target')

		demo.Window:Close();f:Drain()
	end
	host:Destroy();manager:Destroy();assert(f:GlobalConnections()==0 and #messages==0,table.concat(messages,' | '))
	print('BrowserWindowsMounted: real HTML/JS auxiliary windows, named reuse, first-click focus, resize hold, close restrictions and complete cleanup passed')
end
