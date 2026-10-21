--!strict
-- The real data parser, mounted script adapter and retained renderer share one
-- document. Only native GUI/font services are replaced by deterministic hosts.
return function(Parser,Node,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel)
	local function check(byteSource)
	local function signal()
		local entries={};local api={}
		function api:Connect(callback)local item={Connected=true,Callback=callback};function item:Disconnect()self.Connected=false end;table.insert(entries,item);return item end
		function api:Fire(...)for _,item in table.clone(entries)do if item.Connected then item.Callback(...)end end end
		function api:Count()local n=0;for _,item in entries do if item.Connected then n+=1 end end;return n end
		return api
	end
	local guis={};local factory={create=function(class,parent,props)
		local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent;gui.Visible=true
		gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(400,300)
		gui.CanvasPosition=Vector2.new(0,0);gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal()
		local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)signals[key]=signals[key]or signal();return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
		function gui:SetAttribute(key,value)attributes[key]=value end;function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=='GuiObject'end;function gui:IsFocused()return false end
		function gui:Destroy()
			assert(not self.Destroyed,'GUI disposed twice');self.Destroyed=true
			for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil
		end
		table.insert(guis,gui);return gui
	end};factory.modifier=factory.create
	local renderer=loadRenderTree(factory)
	local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
	local source=[=[<!doctype html><html><head><script>
document.write('<style>html,body{margin:0;padding:0}#written{height:25px;background:#123456}</style>');
globalThis.order=[];document.addEventListener('DOMContentLoaded',()=>order.push('dcl'));
</script></head><body><input id="kept" value="default"><div id="outside">Stable outside</div><script>
globalThis.input=document.getElementById('kept');input.value='edited';
document.write('<div id=written>Written</div>');
</script><p id="tail">Tail</p></body></html>]=]
	local parser=if byteSource then Parser.newDocumentBytes(source,{ScriptingEnabled=true,TransportEncoding='utf-8',DecodeChunkBytes=7})
		else Parser.newDocument(source,{ScriptingEnabled=true})
	local first=parser:Advance();local document=parser.Document
	assert(not document.Body,'Mounted page must pause at its first head script')
	local root=factory.create('ScrollingFrame',nil,{})
	local messages,diagnostics={},{}
	local tree=renderer.build(document,root,function(value)table.insert(messages,value)end,function(font)return font end)
	local events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end,true)
	local time,arrangements,realm,flushing=0,0,nil,false
	local frames=signal();local page={Alive=true,Document=document,DocumentURL='https://scripts.test/index.html',BaseURL='https://scripts.test/index.html',
		Root=root,Events=events,FormModel=model,Cleanups={},ParserSession=parser,ParserFirstScript=first}
	function page:AddCleanup(callback)table.insert(self.Cleanups,callback)end
	function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
	function page:GeometryViewport()return {Width=400,Height=300,ClientWidth=400,ClientHeight=300,ScrollWidth=400,ScrollHeight=300,ScrollX=0,ScrollY=0}end
	function page:HasPendingLayout()return false end
	function page:RefreshDOMControls()model:RefreshControls()end
	local function arrange(targets)
		arrangements+=1;tree:SetMediaEnvironment(400,300);tree.ViewportHeight=300;Dirty.begin(tree,targets)
		layout.arrange(tree,400,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		local needed,targets=realm:Flush();if needed then arrange(targets)end;flushing=false
	end
	arrange()
	local services={Clock=function()return time end,RunService={RenderStepped=frames},Task={delay=function(_,callback)return {Callback=callback}end,cancel=function(ticket)ticket.Cancelled=true end}}
	local stylesheetCallbacks={};local stylesheetCancels=0
	services.LoadStylesheet=function(url,complete)
		stylesheetCallbacks[url]=complete
		local imported={
			['https://scripts.test/with-import.css']='@import "nested-import.css";#outside{height:73px}',
			['https://scripts.test/nested-import.css']='@import "leaf.css";#outside{height:84px}',
			['https://scripts.test/leaf.css']='#outside{height:95px!important}#kept{color:blue}',
			['https://scripts.test/dynamic.css']='#outside{height:112px!important}',
		}
		if imported[url]then local id=realm.EventLoop.Methods.setTimeout({function()complete(true,{Source=imported[url],MIME='text/css'})end,1});return function()stylesheetCancels+=1;realm.EventLoop.Methods.clearTimeout({id})end end
		if url:sub(-9)=='/late.css'then
			local id=realm.EventLoop.Methods.setTimeout({function()complete(true,{Source='#outside{height:61px;background:#010203}#kept{color:#ff0000}',MIME='text/css'})end,10})
			return function()stylesheetCancels+=1;realm.EventLoop.Methods.clearTimeout({id})end
		end
		return function()stylesheetCancels+=1 end
	end
	local function healthy()
		assert(#messages==0,table.concat(messages,' | '));assert(#diagnostics==0,table.concat(diagnostics,' | '))
		assert(frames:Count()==0,'Parser work must not retain an idle rendering subscription')
	end
	local function settle()
		for _=1,16 do time+=.001;page:FlushScriptLayout();realm:AfterLayout();realm:PumpTasks();realm.EventLoop:Checkpoint()end
		page:FlushScriptLayout();healthy()
	end
	local function node(id)return assert(Node.findById(document,id),id)end
	local function run(source)realm:Run(source);settle()end
	realm=HTMLScripts.start(page,tree,function()end,function(value)table.insert(diagnostics,value)end,{JavaScriptServices=services})
	settle()
	local input=model:Resolve(node('kept'));local outside=tree.NodeBoxes[node('outside')];local written=tree.NodeBoxes[node('written')]
	assert(input and input.Value=='edited'and written.ContentHeight==25 and written.Style.Background==Color3.fromRGB(18,52,86),'Parser continuation must render body, written stylesheet and live control value')
	assert(tree.NodeBoxes[node('tail')]and document.Body and parser.Done,'Remaining source must appear in the same retained document')
	run("if(order.join(',')!=='dcl'||document.readyState!=='complete')throw new Error('parser readiness');")
	local oldInput,oldOutside,oldWritten=input.Item.Gui,outside.Gui,written.Gui
	run("document.body.append(document.createElement('p'));if(input.value!=='edited')throw new Error('lost parser value');")
	assert(model:Resolve(node('kept'))==input and input.Item.Gui==oldInput and outside.Gui==oldOutside and written.Gui==oldWritten,'Later child mutations retain already published boxes and controls')
	run([=[
const namespaceStyle=document.createElement('style');
namespaceStyle.textContent="#outside[*|shade='blue']{background:#0000ff}#outside[custom-status=active]{background:#ff00ff}";
document.head.append(namespaceStyle);
input.autocapitalize='words';input.autocorrect=false;input.writingSuggestions='false';
if(input.autocapitalize!=='words'||input.autocorrect!==false||input.writingSuggestions!=='false')throw new Error('mounted editing attributes');
input.setAttributeNS('urn:foreign','disabled','');
input.setAttributeNS('urn:foreign','type','checkbox');
input.setAttributeNS('urn:foreign','value','foreign');
input.setAttributeNS('urn:foreign','style','height:999px');
if(input.disabled||input.type!=='text'||input.value!=='edited')throw new Error('foreign control attributes acquired HTML behavior');
]=])
	assert(input.Type=='text'and not input.Disabled and input.Value=='edited'and input.Item.Gui==oldInput and outside.Gui==oldOutside,'Mounted editing reflection and foreign attributes preserve native control state and GUI identity')
	local beforeNamespacePaint=arrangements
	run("document.getElementById('outside').setAttributeNS('urn:paint','shade','blue');")
	assert(outside.Style.Background==Color3.fromRGB(0,0,255)and outside.Gui==oldOutside and arrangements==beforeNamespacePaint,'Wildcard namespace selectors repaint retained geometry without layout')
	run("document.getElementById('outside').removeAttributeNS('urn:paint','shade');")
	assert(outside.Gui==oldOutside and arrangements==beforeNamespacePaint and outside.Style.Background~=Color3.fromRGB(0,0,255),'Removing a namespaced selector input restores retained paint without layout')
	run("document.getElementById('outside').setAttribute('custom-status','active');")
	assert(outside.Style.Background==Color3.fromRGB(255,0,255)and outside.Gui==oldOutside and arrangements==beforeNamespacePaint,'Ordinary author-defined attributes use the same retained selector paint path')
	run("document.getElementById('outside').removeAttribute('custom-status');")
	assert(outside.Style.Background~=Color3.fromRGB(255,0,255)and arrangements==beforeNamespacePaint,'Removing an author-defined attribute restores paint without layout')
	run("input.removeAttributeNS('urn:foreign','disabled');input.removeAttributeNS('urn:foreign','type');input.removeAttributeNS('urn:foreign','value');input.removeAttributeNS('urn:foreign','style');namespaceStyle.remove();")
	assert(input.Type=='text'and input.Value=='edited'and input.Item.Gui==oldInput and not oldInput.Destroyed,'Removing foreign attributes preserves the same mounted edited control')
	run("globalThis.late=document.createElement('link');late.rel='stylesheet';late.href='/late.css';document.head.append(late);")
	assert(outside.ContentHeight==61 and outside.Style.Background==Color3.fromRGB(1,2,3),'Loaded external CSS must reach the same mounted style and layout paths')
	assert(model:Resolve(node('kept'))==input and input.Item.Gui==oldInput and input.Value=='edited'and outside.Gui==oldOutside,'External CSS retains author inputs and unaffected GUI identities')
	run("if(late.sheet.cssRules.length!==2)throw new Error('loaded CSSOM association');late.sheet.insertRule('#written{height:29px}',0);")
	assert(written.ContentHeight==29 and written.Gui==oldWritten,'Loaded external sheet CSSOM writes share the retained renderer provider')
	run("late.href='/pending.css';")
	local pendingStylesheetCallback=assert(stylesheetCallbacks['https://scripts.test/pending.css'])
	assert(outside.ContentHeight~=61 and written.ContentHeight==25,'Changing href removes previous source while its next resource is pending')
	run("globalThis.imports=document.createElement('link');imports.rel='stylesheet';imports.href='/with-import.css';document.head.append(imports);")
	assert(outside.ContentHeight==95 and outside.Gui==oldOutside and input.Item.Gui==oldInput and input.Value=='edited','Nested asynchronous imports reach the retained actual cascade')
	run("globalThis.child=imports.sheet.cssRules[0].styleSheet;globalThis.leaf=child.cssRules[0].styleSheet;if(child.parentStyleSheet!==imports.sheet||child.ownerRule!==imports.sheet.cssRules[0]||child.ownerNode!==null||leaf.parentStyleSheet!==child||leaf.media!==child.cssRules[0].media||leaf!==child.cssRules[0].styleSheet)throw new Error('import sheet identities');leaf.insertRule('#outside{height:103px!important}',2);")
	assert(outside.ContentHeight==103 and outside.Gui==oldOutside,'Imported CSSOM mutations invalidate the retained root source and renderer')
	run("leaf.disabled=true;");assert(outside.ContentHeight==73,'Disabling imported CSSOM sheet hides its subtree')
	run("leaf.disabled=false;");assert(outside.ContentHeight==103,'Re-enabling imported CSSOM sheet preserves its overlay')
	run("imports.sheet.cssRules[0].media.mediaText='print';");assert(outside.ContentHeight==73,'Import MediaList updates alter actual child applicability')
	run("imports.sheet.cssRules[0].media.mediaText='all';");assert(outside.ContentHeight==103,'Restored import media exposes retained descendant overlay')
	run("imports.sheet.insertRule('@import \"dynamic.css\";',1);globalThis.dynamicRule=imports.sheet.cssRules[1];if(dynamicRule.styleSheet!==null)throw new Error('insert import must begin asynchronously');")
	assert(outside.ContentHeight==112 and outside.Gui==oldOutside and input.Item.Gui==oldInput and input.Value=='edited','Asynchronous inserted import participates in actual cascade without replacing the retained owner/control')
	run("globalThis.dynamicSheet=dynamicRule.styleSheet;imports.sheet.deleteRule(1);if(dynamicRule.styleSheet!==dynamicSheet||dynamicSheet.parentStyleSheet!==null||dynamicSheet.ownerRule!==dynamicRule||dynamicRule.parentStyleSheet!==null)throw new Error('removed import identity');")
	assert(outside.ContentHeight==103 and outside.Gui==oldOutside,'Deleting a loaded import restores actual preceding cascade and retains held detached objects')
	run("leaf.insertRule('@import \"cancelled-import.css\";',0);")
	local deletedImportCallback=assert(stylesheetCallbacks['https://scripts.test/cancelled-import.css']);local beforeCancel=stylesheetCancels
	run("leaf.deleteRule(0);")
	assert(stylesheetCancels>beforeCancel and realm.StylesheetResources.Pending==1,'Deleting an inserted child import cancels its host request while retaining the unrelated pending link')
	deletedImportCallback(true,{Source='#outside{height:999px!important}',MIME='text/css'});settle()
	assert(outside.ContentHeight==103 and outside.Gui==oldOutside and input.Item.Gui==oldInput,'Deleted import completion cannot alter retained render geometry or input identity')
	run("document.open();document.write('<!doctype html><html><body><div id=host></div>');document.write('<script>document.getElementById(\"host\").setAttribute(\"data-kept\",\"yes\");<\\/script>');document.write('<div id=shadowhost><template shadowrootmode=open><style>#shadowcontent{height:37px;background:#654321}</style><div id=shadowcontent>Shadow</div></template></div>');document.close();")
	assert(stylesheetCancels>0 and realm.StylesheetResources.Pending==0,'Document replacement cancels pending stylesheet ownership')
	pendingStylesheetCallback(true,{Source='div{height:999px}',MIME='text/css'});settle()
	local shadowHost=node('shadowhost');local shadowNode=Node.findById(shadowHost.InternalShadowRoot,'shadowcontent');local shadowBox=tree.NodeBoxes[shadowNode]
	assert(shadowBox and shadowBox.ContentHeight==37 and shadowBox.Style.Background==Color3.fromRGB(101,67,33),'Parser-created shadow content and scoped styles must reach the mounted renderer')
	local retainedShadow=shadowBox.Gui
	run("document.getElementById('host').textContent='Kept';")
	assert(shadowBox.Gui==retainedShadow and not retainedShadow.Destroyed,'Unrelated parser-era mutations retain shadow rendering')
	run("document.open();document.write('<!doctype html><html><head><style>#replacement{height:40px;background:#abcdef}</style></head><body><div id=replacement>New</div></body></html>');document.close();")
	local replacement=tree.NodeBoxes[node('replacement')]
	assert(replacement and replacement.ContentHeight==40 and replacement.Style.Background==Color3.fromRGB(171,205,239),'Document replacement must reconcile root ownership and stylesheet sources')
	assert(oldInput.Destroyed and oldOutside.Destroyed and oldWritten.Destroyed and #tree.Controls==0,'Document replacement releases prior rendered controls and boxes')
	assert(retainedShadow.Destroyed,'Replacing a document disposes the declarative shadow render subtree')
	assert(tree.NodeBoxes[document]==tree and tree.Gui==root and not root.Destroyed,'Document replacement retains the page viewport and document render owner')
	page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;events:Destroy();tree.VisualEffects:Destroy();root:Destroy()
	assert(not parser.Alive and frames:Count()==0,'Disposal releases parser and work subscriptions')
	print('Mounted document streams ('..(if byteSource then 'incremental byte decoding'else 'Unicode source')..'): parser-time body/styles/control state, retained later mutations, document replacement and resource disposal passed')
	end
	check(false);check(true)
end
