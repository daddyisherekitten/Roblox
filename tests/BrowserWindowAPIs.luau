--!strict
return function(loadWindows,loadHost,loadBrowser,loadBinding,fixture,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages)
	local f=fixture();local services={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,RunService=f.Run,Task=f.Task}
	-- Relative references from host/content use the HTTP page base. The address
	-- field keeps search semantics, and all resolved URLs still need its host.
	do
		local browser,tab,reenter;local resolverCalls=0;local delivered={}
		local function resolve(href,base)
			resolverCalls+=1
			if reenter then local callback=reenter;reenter=nil;callback()end
			if href=='/forbidden'then return {Kind='external',URL='javascript:alert(1)'}end
			local resolved=URL.resolve(base or'http://localhost:8000/a/index.html',href)
			if resolved.Origin~='http://localhost:8000'or not resolved.Path:match('^/[ab]/index%.html$')then return nil end
			return {Kind='external',URL=resolved.URL,Title='Registered HTTP page',Icon='page'}
		end
		local parent=f.Create('Frame',f.Screen,{Name='RelativeBrowserHost',Size=f.UDim2.fromScale(1,1)})
		browser=loadBrowser(f).new(parent,{AutoOpen=false,PersistenceEnabled=false,Services=services,ResolveExternal=resolve})
		local base='http://localhost:8000/a/index.html?before=1#old'
		for _,row in {
			{'#part','http://localhost:8000/a/index.html?before=1#part'},
			{'../b/index.html','http://localhost:8000/b/index.html'},
			{'./index.html?after=2','http://localhost:8000/a/index.html?after=2'},
			{'/b/index.html#target','http://localhost:8000/b/index.html#target'},
		}do
			local result=browser.Address:Resolve(row[1],base,true)
			assert(result.Kind=='external'and result.URL==row[2],'Content relative address must retain its HTTP base: '..row[1])
			assert(browser.Address:Resolve(row[1],base,false).Route=='search','Omnibox relative text remains a search phrase')
		end
		local before=resolverCalls
		assert(browser.Address:Resolve('#part','wayline://home',true).Route=='search'and resolverCalls==before,'Relative URL mode requires a valid HTTP base')
		for _,text in {'javascript:alert(1)','file:///private','data:text/html,hello','/forbidden','//unregistered.test/a/index.html'}do
			assert(browser.Address:Resolve(text,base,true).Kind=='error','Relative mode must preserve host registration and scheme rejection: '..text)
		end
		local guarded;browser.BeforeNavigate=function(_,request)
			assert(request.Resolution and request.Resolution.URL,'Navigation guard must receive the one canonical resolution')
			guarded=request;return true
		end
		local connection=browser:OnNavigate(function(_,request)table.insert(delivered,request)end)
		tab=browser:Open('http://localhost:8000/a/index.html');f:Drain();local initial=delivered[#delivered]
		assert(browser:CompleteNavigation(tab,initial,{Title='A'}))
		local count=#delivered;local old=browser:Navigate(tab,'#superseded',{Source='content'})
		local current=browser:Navigate(tab,'../b/index.html',{Source='host'});f:Drain()
		assert(#delivered==count+1 and delivered[#delivered]==current and current.URL=='http://localhost:8000/b/index.html','Only the latest deferred relative navigation reaches its provider')
		assert(not browser:CompleteNavigation(tab,old,{Title='Old'})and browser:CompleteNavigation(tab,current,{Title='B'}),'Stale relative navigation cannot commit')
		local fragment=browser:Navigate(tab,'#part',{Source='content'});f:Drain()
		assert(fragment.URL=='http://localhost:8000/b/index.html#part'and browser:CompleteNavigation(tab,fragment,{Title='B part'}))
		before=resolverCalls;browser:Navigate(tab,'#literal',{Source='address'});f:Drain()
		assert(guarded.Resolution.URL=='wayline://search?q=%23literal'and resolverCalls==before,'BeforeNavigate sees the actual omnibox search destination without a second resolver call')
		assert(tab.URL=='wayline://search?q=%23literal','Address input keeps native search behavior even on an HTTP tab')
		local restore=browser:Navigate(tab,'http://localhost:8000/a/index.html',{Source='host'});f:Drain();assert(browser:CompleteNavigation(tab,restore,{Title='A'}))
		count=#delivered;local winner
		reenter=function()winner=browser:Navigate(tab,'wayline://home',{Source='host'})end
		local obsolete=browser:Navigate(tab,'../b/index.html',{Source='content'});f:Drain()
		assert(tab.URL=='wayline://home'and not tab.Pending and not browser:IsCurrent(tab,obsolete)and #delivered==count,'A resolver that navigates again cannot dispatch its returning stale request')
		assert(browser.Native and browser.Native.Tab==tab and browser.Native.Page,'Returning stale resolution cannot remove the newer native page')
		connection:Disconnect();browser:Destroy();parent:Destroy();f:Drain();assert(f:GlobalConnections()==0,'Relative navigation fixture releases all native input handlers')
	end
	local factory={create=f.Create,modifier=f.Create};local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new(#text*size*.45,size)end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local pageModule=loadHTMLPage({['Rendering/GuiFactory']=factory,['Rendering/RenderTree']={build=function(doc,root,diagnostic)return renderer.build(doc,root,diagnostic,function(font)return font end)end},
		['Layout/BlockLayout']=loadBlockLayout(overrides),['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,{GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then {GetPropertyChangedSignal=function()return f.Signal()end}else nil end},f)
	local pages={A='http://localhost:8000/a/index.html',B='http://localhost:8000/b/index.html',C='http://localhost:8000/c/index.html',D='http://other.test/d/index.html',E='http://localhost:8000/e/index.html',F='http://localhost:8000/f/index.html'}
	local html='<!doctype html><html><head><title>Document</title><style>#panel {width:180px;height:120px;background:#123456}#panel:fullscreen {background:#abcdef}</style></head><body><button id="button">Click</button><div id="value">original</div><section id="panel"><p>Fullscreen content</p><button id="inside">Inside</button></section><script>var boot=1;</script></body></html>'
	local engine={URL=URL,Websites={}}
	function engine.Websites.names()return{}end
	function engine.Websites.url()return pages.A end
	function engine.Websites.resolveURL(base,href)local result=URL.resolve(base,href);for name,url in pages do if result.URL:gsub('#.*$','')==url then result.Kind='internal';result.Name=name;break end end;return result end
	function engine.Websites.get(name)return {HTML=html,Options={DocumentOriginOpaque=name=='E'or name=='F',RenderWorkBudgetMS=0,InputServices={Task=f.Task},JavaScriptServices={Task=f.Task,Clock=function()return f:Clock()end}}}end
	function engine.mountHTML(target,source,options)return pageModule.mount(target,source,options)end
	-- With no registered documents the native home needs no HTML lookup.
	do
		local emptyEngine={URL=URL,Websites={names=function()return{}end,
			url=function()error('Empty catalog URL lookup')end,get=function()error('Empty catalog source lookup')end,
			resolveURL=function(base,href)return URL.resolve(base,href)end},mountHTML=function()error('Native home must not mount an HTML document')end}
		local emptyManager=loadWindows(f).new(f.Screen,{Services=services})
		local emptyHost=loadHost(f).new(emptyManager,loadBrowser(f),loadBinding(f),emptyEngine,{Services=services,PersistenceEnabled=false})
		local record=emptyHost:Open('wayline://home');f:Drain()
		local tab=record.Browser:GetActiveTab()
		assert(tab.URL=='wayline://home'and record.Browser.Native and record.Browser.Native.Page,'An empty catalog opens the native browser home')
		assert(record.Binding:GetPage(tab)==nil and record.Browser.Options.ExternalBaseURL=='http://localhost:8000/','Native home keeps no missing document dependency')
		record.Window:Close();emptyHost:Destroy();emptyManager:Destroy();f:Drain()
		assert(f:GlobalConnections()==0,'Empty-catalog startup releases its native input connections')
	end
	local messages={};local manager=loadWindows(f).new(f.Screen,{Services=services})
	local host=loadHost(f).new(manager,loadBrowser(f),loadBinding(f),engine,{Services=services,PersistenceEnabled=false,Diagnostic=function(m)table.insert(messages,tostring(m))end})
	local main=host:Open(pages.A);f:Drain();local page=assert(main.Binding:GetPage(main.Browser:GetActiveTab()))
	local function run(p,source)local ok,err=p.JavaScriptRuntime:Run(source);assert(ok,tostring(err));f:Drain()end
	local function global(p,key)return p.JavaScriptRuntime.Window.Get(key)end
	-- The initial about:blank document is synchronously usable, with inherited origin.
	page.JavaScriptRuntime:Run("var blank=open('','blank','popup,width=410,height=280');blank.document.body.textContent='initial blank';var initial=blank.document.body.textContent;")
	assert(global(page,'initial')=='initial blank');f:Drain()
	local blankWindow=manager:GetWindows()[2];local blankPage=host.Windows[blankWindow].Binding:GetPage(host.Windows[blankWindow].Browser:GetActiveTab())
	assert(Node.textContent(blankPage.Document):find('initial blank',1,true))
	run(page,"var sameBlank=open('','blank','popup');var keepsBlank=sameBlank===blank && sameBlank.document.body.textContent==='initial blank';")
	assert(global(page,'keepsBlank')==true and host.Windows[blankWindow].Binding:GetPage(host.Windows[blankWindow].Browser:GetActiveTab())==blankPage and blankPage.Alive,'Empty named URL reuses its authored initial document')
	run(page,"open('about:blank','blank','popup');")
	local explicitBlank=assert(host.Windows[blankWindow].Binding:GetPage(host.Windows[blankWindow].Browser:GetActiveTab()))
	assert(explicitBlank~=blankPage and not blankPage.Alive and Node.textContent(Node.findElement(explicitBlank.Document,function(node)return node.Name=='body'end))=='','Explicit about:blank performs a fresh named-window navigation')
	blankWindow:Close();f:Drain()
	run(page,"var child=open('../b/index.html','child','popup,width=410,height=280,left=40,top=50');")
	local window=manager:GetWindows()[2];local rec=host.Windows[window];local child=assert(rec.Binding:GetPage(rec.Browser:GetActiveTab()))
	run(page,"child.moveTo(70,80);child.moveBy(13,-9);child.resizeTo(500,390);child.resizeBy(-30,20);var measured=[child.screenX,child.screenY,child.outerWidth,child.outerHeight];")
	assert(window:GetPosition().X==83 and window:GetPosition().Y==71 and window:GetSize().X==480 and window:GetSize().Y==412,'Script resize applies the 480x392 host minimum before the relative size delta')
	run(child,"moveBy(1,2);resizeBy(10,5);var ownX=screenX;");assert(global(child,'ownX')==84 and window:GetPosition().Y==73 and window:GetSize().X==490 and window:GetSize().Y==417,'Relative geometry starts from the clamped native rectangle')
	local p=main.Window:GetPosition();run(page,'moveTo(1,1);resizeTo(330,230);');assert(main.Window:GetPosition().X==p.X,'A user-created main window must ignore JS geometry commands')
	run(page,[=[
	var doc=child.document;var sameDoc=doc===child.document;var sameWindow=doc.defaultView===child;var value=doc.getElementById('value');value.textContent='changed across realms';
	value.style.color='red';var made=doc.createElement('p');made.id='added';made.textContent='added';doc.body.appendChild(made);
	var reads=[value.textContent,value.id,made.parentNode===doc.body];var fromChild=0;
	doc.getElementById('button').addEventListener('click',function(event){fromChild++;document.getElementById('value').textContent='callback '+event.type;});
	]=])
	assert(global(page,'sameDoc')==true and global(page,'sameWindow')==true and Node.textContent(Node.findById(child.Document,'value'))=='changed across realms'and Node.findById(child.Document,'added'))
	child.Events:Emit(Node.findById(child.Document,'button'),'click',{},{Bubbles=true});f:Drain()
	assert(global(page,'fromChild')==1 and Node.textContent(Node.findById(page.Document,'value'))=='callback click','Foreign callback failed to flush its owning runtime')
	run(page,[=[var received=0;var senderMatches=false;var sent={text:'hello',nested:[1,2]};
	window.addEventListener('message',function(e){received=e.data.answer;senderMatches=e.source===child;});]=])
	run(child,"window.addEventListener('message',function(e){document.getElementById('value').textContent=e.data.text; e.source.postMessage({answer:7},e.origin);});var hasOpener=opener!==null;")
	assert(global(child,'hasOpener')==true)
	run(page,"child.postMessage(sent,location.origin);sent.text='mutated after send';");assert(global(page,'received')==7 and global(page,'senderMatches')==true)
	assert(Node.textContent(Node.findById(child.Document,'value'))=='hello','Messages must clone before returning')
	run(page,"received=0;child.postMessage(sent,'http://wrong.test');");assert(global(page,'received')==0)
	run(page,"var cloneError=false;try{child.postMessage(function(){},'*');}catch(e){cloneError=e.name==='DataCloneError';}");assert(global(page,'cloneError')==true)
	local oldDoc=child.Document;run(page,"child.location.href='../c/index.html';");local nextPage=assert(rec.Binding:GetPage(rec.Browser:GetActiveTab()));assert(nextPage~=child and not child.Alive)
	run(page,"var newDoc=child.document;var changedDoc=newDoc!==doc;var staleDenied=false;try{value.textContent='stale';}catch(e){staleDenied=e.name==='InvalidStateError';}")
	assert(global(page,'changedDoc')==true and global(page,'staleDenied')==true)
	run(page,"child.location.replace('../b/index.html');");local back=assert(rec.Binding:GetPage(rec.Browser:GetActiveTab()));assert(back.DocumentURL==pages.B)
	run(page,"child.location.reload();");assert(not back.Alive)
	-- Same-origin policy is checked again after a cross-origin navigation.
	run(page,"child.location.href='http://other.test/d/index.html';");local foreign=assert(rec.Binding:GetPage(rec.Browser:GetActiveTab()));assert(foreign.DocumentURL==pages.D)
	run(page,"var denied=false;try{child.document.body;}catch(e){denied=e.name==='SecurityError';}var hrefDenied=false;try{child.location.href;}catch(e){hrefDenied=e.name==='SecurityError';}")
	assert(global(page,'denied')==true and global(page,'hrefDenied')==true)
	run(foreign,"window.addEventListener('message',function(e){e.source.postMessage({answer:9},e.origin);});")
	run(page,"received=0;child.postMessage({cross:true},'http://other.test');");assert(global(page,'received')==9 and global(page,'senderMatches')==true,'Cross-origin messaging must keep source identity')
	run(page,"child.location.href='../b/index.html';");child=assert(rec.Binding:GetPage(rec.Browser:GetActiveTab()))
	-- Fullscreen on an arbitrary element, with CSS state and restored native geometry.
	rec.Browser:SetNavigationVisible(true)
	run(child,"var rejected=0;var errors=0;document.addEventListener('fullscreenerror',function(){errors++;});document.getElementById('panel').requestFullscreen().catch(function(e){if(e.name==='TypeError')rejected++;});")
	assert(global(child,'rejected')==1 and global(child,'errors')==1 and not window.Fullscreen,'Fullscreen must reject without user activation')
	child.FormModel.UserActivationUntil=os.clock()+10
	run(child,"var invalidReceiver=false;try{Document.prototype.exitFullscreen.call({});}catch(e){invalidReceiver=e.name==='TypeError';}var detached=document.createElement('div');detached.requestFullscreen().catch(function(e){if(e.name==='TypeError')rejected++;});")
	assert(global(child,'invalidReceiver')==true and global(child,'rejected')==2 and not window.Fullscreen)
	local position,size=window:GetPosition(),window:GetSize()
	local panelNode=Node.findById(child.Document,'panel')
	run(child,"var fullReady=false;document.getElementById('panel').requestFullscreen().then(function(){fullReady=document.fullscreenElement.id==='panel';});")
	assert(global(child,'fullReady')==true and window.Fullscreen and not rec.Browser.Chrome.Visible)
	local presentation=assert(child.FullscreenPresentation);assert(presentation.Layer and presentation.Surface.Parent==presentation.Layer and presentation.Surface.AbsoluteSize.X>400,
		'Fullscreen surface: '..tostring(presentation.Surface and presentation.Surface.AbsoluteSize.X)..'; box='..tostring(presentation.Box and presentation.Box.OuterWidth)..'; root='..child.Root.AbsoluteSize.X..'; target='..child.Root.Parent.AbsoluteSize.X..'; layer='..presentation.Layer.AbsoluteSize.X..'; window='..window.Root.AbsoluteSize.X..'; width='..tostring(presentation.Box.Style.Width.Value)..'/'..tostring(presentation.Box.Style.Width.Percent)..'; diagnostics='..table.concat(child.JavaScriptRuntime.Diagnostics,' | '))
	run(child,"var insideClicks=0;document.getElementById('inside').addEventListener('click',function(){insideClicks++;document.getElementById('inside').textContent='Still clickable';});")
	local inside=child.FormModel:Resolve(Node.findById(child.Document,'inside')).Item.BoxGui
	f.Input.Mouse=f.Vector2.new(inside.AbsolutePosition.X+2,inside.AbsolutePosition.Y+2)
	local pressed=f:Begin(inside,nil,f.Input.Mouse.X,f.Input.Mouse.Y);f.Input.InputEnded:Fire(pressed);f:Drain()
	assert(global(child,'insideClicks')==1,'Fullscreen must retain native hit routing after reparenting')
	run(child,"var matches=document.querySelector(':fullscreen').id;document.exitFullscreen();");assert(global(child,'matches')=='panel'and not window.Fullscreen and rec.Browser.Chrome.Visible)
	assert(window:GetPosition().X==position.X and window:GetSize().X==size.X)
	assert(presentation.Layer==nil and not panelNode.FullscreenFlag)
	run(child,"var afterBounds=document.getElementById('panel').getBoundingClientRect().width;");assert(global(child,'afterBounds')==180,'Fullscreen exit must restore authored element size')
	run(child,"document.documentElement.requestFullscreen();");assert(window.Fullscreen)
	f.Input.InputBegan:Fire(f:Event(f.Enum.UserInputType.Keyboard,0,0,f.Enum.KeyCode.Escape),false);f:Drain();assert(not window.Fullscreen)
	run(child,"document.getElementById('panel').requestFullscreen();");assert(window.Fullscreen)
	main.Window:Focus();f:Drain();assert(not window.Fullscreen and rec.Browser.Chrome.Visible and not panelNode.FullscreenFlag,'Changing windows must leave fullscreen')
	window:Focus();run(child,"document.getElementById('panel').requestFullscreen();document.getElementById('panel').remove();")
	assert(not window.Fullscreen and rec.Browser.Chrome.Visible and child.FullscreenPresentation.Layer==nil,'Removing a fullscreen element must restore the window')
	run(child,'document.documentElement.requestFullscreen();');assert(window.Fullscreen)
	run(page,'child.location.reload();');assert(not child.Alive and not window.Fullscreen and rec.Browser.Chrome.Visible,'Navigation must release fullscreen presentation')
	child=assert(rec.Binding:GetPage(rec.Browser:GetActiveTab()))
	-- HTML-only mounting and fullscreen have no window manager/browser connection.
	local target=f.Create('Frame',f.Screen,{Position=f.UDim2.fromOffset(20,30),Size=f.UDim2.fromOffset(400,300)})
	local standalone=pageModule.mount(target,html,{DocumentURL=pages.A,RenderWorkBudgetMS=0,InputServices={Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task},JavaScriptServices={RunService=f.Run,Task=f.Task}});f:Drain()
	standalone.FormModel.UserActivationUntil=os.clock()+10
	run(standalone,"var noHost=open()===null;var standaloneReady=false;document.getElementById('panel').requestFullscreen().then(function(){standaloneReady=true;});")
	assert(global(standalone,'noHost')==true and global(standalone,'standaloneReady')==true and target.AbsoluteSize.X==f.Screen.AbsoluteSize.X)
	run(standalone,'document.exitFullscreen();');assert(target.Size.X.Offset==400 and target.Position.Y.Offset==30)
	run(standalone,"document.documentElement.requestFullscreen();");assert(target.AbsoluteSize.X==f.Screen.AbsoluteSize.X)
	standalone:Destroy();assert(target.Size.X.Offset==400 and target.Position.Y.Offset==30,'HTML-only disposal must restore its target');target:Destroy()
	child.FormModel.UserActivationUntil=os.clock()+10;run(child,'document.documentElement.requestFullscreen();');assert(window.Fullscreen)
	window:Close();f:Drain();assert(not child.Alive and manager.Fullscreen==nil,'Closing must release fullscreen and its realm')
	run(page,"var closedNow=child.closed;var closedDenied=false;try{child.document;}catch(e){closedDenied=e.name==='InvalidStateError';}")
	assert(global(page,'closedNow')==true and global(page,'closedDenied')==true)
	-- Different opaque origins both serialize as "null", but are never identical.
	run(page,"var opaque=open('../e/index.html','opaque','popup');")
	local opaqueWindow=manager:GetWindows()[2];local opaqueRecord=host.Windows[opaqueWindow]
	local opaque=assert(opaqueRecord.Binding:GetPage(opaqueRecord.Browser:GetActiveTab()))
	run(opaque,"var peer=open('../f/index.html','opaquePeer','popup');var selfMessages=0;window.addEventListener('message',function(){selfMessages++;});")
	local peerWindow=manager:GetWindows()[3];local peerRecord=host.Windows[peerWindow]
	local peer=assert(peerRecord.Binding:GetPage(peerRecord.Browser:GetActiveTab()))
	assert(type(opaque.DocumentOrigin)=='table'and type(peer.DocumentOrigin)=='table'and opaque.DocumentOrigin~=peer.DocumentOrigin)
	run(peer,"var opaqueMessages=0;var sourceOrigin='';window.addEventListener('message',function(e){opaqueMessages++;sourceOrigin=e.origin;});")
	run(opaque,"peer.postMessage({text:'must not arrive'});peer.postMessage({text:'also denied'},'/');postMessage({self:true});")
	assert(global(peer,'opaqueMessages')==0 and global(opaque,'selfMessages')==1,'Default targetOrigin must compare opaque identity, not the serialized null string')
	run(opaque,"peer.postMessage({text:'wildcard'},'*');")
	assert(global(peer,'opaqueMessages')==1 and global(peer,'sourceOrigin')=='null')
	peerWindow:Close();opaqueWindow:Close();f:Drain()
	main.Window:Close();host:Destroy();manager:Destroy();f:Drain()
	assert(f:GlobalConnections()==0 and #messages==0,table.concat(messages,' | '))
	print('BrowserWindowAPIs: initial blank DOM, geometry, guarded document/callback access, cloned messages, origin checks, navigation/reload, fullscreen and HTML-only operation passed')
end
