--!strict
-- CSSOM mutations must retain native controls and repaint/layout only changed
-- computed values. The DOM and MutationObserver view remain independent.
return function(Parser,Node,Runtime,VM,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,Controller,selectSizing,selectPseudos,editingSelectors)
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		function api:Count()local count=0;for _,entry in listeners do if entry[1].Connected then count+=1 end end;return count end
		return api
	end
	local guis={};local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(960,900)
		if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,"Native GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end}
	factory.modifier=factory.create
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local html=[=[<!doctype html><html><head><style id="sheet">.token { color: #123456; width: 180px; padding: 8px; }</style><link id="linked" rel="stylesheet" href="local.css"></head><body><div class="token" id="token">A stable surface.<input id="notes" value="kept"><button type="button" id="button">Keep</button></div><p id="outside">Outside the changing box.</p><script>globalThis.clicks=0; document.getElementById('button').onclick=function(){clicks++;};</script></body></html>]=]
	local document=Parser.parseDocument(html);local messages={};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{["local.css"]=".token { background: #abcdef; }"},"https://example.test/page")
	local model,events
	local page={Alive=true,Document=document,DocumentURL="https://example.test/page",BaseURL="https://example.test/page",Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
	local realm,flushing=nil,false;local viewport={Width=960,Height=900,ClientWidth=960,ClientHeight=900,ScrollWidth=960,ScrollHeight=900,ScrollX=0,ScrollY=0}
	local controlLayout,controlTargets=false,{}
	function page:GeometryViewport()return viewport end
	function page:HasPendingLayout()return controlLayout end
	local arrangements,lastLayout,lastTargets=0,false,nil
	local function arrange(targets)
		arrangements+=1;tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
		viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		lastLayout,lastTargets=realm:Flush()
		if controlLayout then
			lastLayout=true;lastTargets=lastTargets or{}
			for item in controlTargets do lastTargets[item]=true end
			controlLayout=false;table.clear(controlTargets)
		end
		if lastLayout then arrange(lastTargets)end
		flushing=false
	end
	arrange();root:SetAttribute("Status","ready")
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return nil end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode()return ''end
	local stopInput=Controller.start(page,tree,function(_,item)
		controlLayout=true;if item then controlTargets[item]=true end
	end,error,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=function()return 0 end,PickerLayout=layout})
	model,events=page.FormModel,page.Events
	local services={Clock=function()return 0 end,ScriptSources={
		["https://example.test/first.js"]="globalThis.scriptOrder.push('first');",
		["https://example.test/second.js"]="globalThis.scriptOrder.push('second');",
	},RunService={RenderStepped=signal()},Task={
		delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	local diagnostics={};realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	local function healthy()
		assert(#diagnostics==0,table.concat(diagnostics," | "));assert(#messages==0,table.concat(messages," | "))
		assert(services.RunService.RenderStepped:Count()==0,"CSSOM work does not install an idle frame connection")
	end
	local function settle()
		for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks();if not realm:HasPending()and tasks==0 then break end end
		page:FlushScriptLayout();healthy()
	end
	local function run(code)realm:Run(code);settle()end
	local function node(id)return assert(Node.findById(document,id),id)end
	local token=tree.NodeBoxes[node("token")];local outside=tree.NodeBoxes[node("outside")];local control=model:Resolve(node("notes"));local button=model:Resolve(node("button"))
	local nativeToken,nativeInput,nativeOutside,nativeButton=token.Gui,control.Item.Gui,outside.Gui,button.Item.Gui
	local function stable()
		assert(tree.NodeBoxes[node("token")].Gui==nativeToken and tree.NodeBoxes[node("outside")].Gui==nativeOutside,"Style changes retain existing native surfaces")
		assert(model:Resolve(node("notes"))==control and control.Item.Gui==nativeInput and control.Value=="edited","Style changes retain native input identity and edited value")
		assert(model:Resolve(node("button"))==button and button.Item.Gui==nativeButton,"Style changes retain event/control identity")
	end
	local function color(hex)
		local r,g,b=tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
		local value=tree.NodeStyles[node("token")].Color
		assert(math.abs(value.R-r)<1e-6 and math.abs(value.G-g)<1e-6 and math.abs(value.B-b)<1e-6,"Computed color does not match #"..hex)
	end
	settle();run([=[
const owner=document.getElementById('sheet'), target=document.getElementById('token');
const oldText=owner.textContent;const sheet=owner.sheet;
globalThis.styleRecords=0;
const observer=new MutationObserver(records=>{styleRecords+=records.length;});
observer.observe(owner,{attributes:true,childList:true,subtree:true,characterData:true});
document.getElementById('notes').value='edited';
if(document.styleSheets.length!==2 || document.styleSheets[0]!==sheet)throw new Error('source order');
if(document.getElementById('linked').sheet.href!=='https://example.test/local.css')throw new Error('resolved stylesheet URL');
if(sheet.title!==null || document.getElementById('linked').sheet.title!==null)throw new Error('unlabelled sheet title');
]=])
	color("123456");local before=arrangements
	run([=[const linked=document.getElementById('linked');globalThis.linkRecords=[];
const linkObserver=new MutationObserver(records=>{for(const record of records)linkRecords.push(record.attributeName);});
linkObserver.observe(linked,{attributes:true});linked.disabled=true;
if(!linked.disabled || !linked.hasAttribute('disabled') || !linked.sheet.disabled)throw new Error('link disabled reflection');]=])
	assert(tree.NodeStyles[node("token")].Background==nil,"The disabled link no longer contributes its background");stable()
	run("linked.disabled=false;if(linked.disabled || linked.hasAttribute('disabled') || linked.sheet.disabled)throw new Error('link enabled reflection');")
	assert(tree.NodeStyles[node("token")].Background==Color3.fromRGB(171,205,239),"Re-enabling the link restores its background");stable()
	run("linked.media='not all';if(linked.getAttribute('media')!=='not all' || linked.sheet.media.mediaText!=='not all')throw new Error('link media reflection');")
	assert(tree.NodeStyles[node("token")].Background==nil,"Reflected link media changes render eligibility")
	run("linked.media='screen';linked.href='local.css';if(linked.href!=='https://example.test/local.css' || linked.sheet.href!==linked.href)throw new Error('link href reflection');")
	assert(tree.NodeStyles[node("token")].Background==Color3.fromRGB(171,205,239),"Reflected media and href keep the available source active")
	run("if(linkRecords.join(',')!=='disabled,disabled,media,media,href')throw new Error('link mutation observer reflection');")
	assert(arrangements==before,"Link color/background source eligibility changes remain paint-only");stable()
	run("sheet.cssRules[0].style.color='#aa2200';")
	color("aa2200");stable();assert(arrangements==before,"A stylesheet color change repaints without layout")
	run("sheet.cssRules[0].style.setProperty('--tone','#dd6600');sheet.cssRules[0].style.color='var(--tone)';")
	color("dd6600");stable();assert(arrangements==before,"Color custom properties repaint their consumers without layout")
	run("sheet.cssRules[0].style.color='#aa2200';sheet.cssRules[0].style.removeProperty('--tone');")
	color("aa2200");assert(arrangements==before,"Removing unused custom properties does not arrange")
	run("if(owner.textContent!==oldText || styleRecords!==0)throw new Error('CSSOM rewrote DOM');")
	run("sheet.cssRules[0].style.width='240px';")
	stable();assert(arrangements>before and token.ContentWidth==240,"A changed width arranges the existing box")
	before=arrangements
	run("sheet.cssRules[0].style.setProperty('--size','260px');sheet.cssRules[0].style.width='var(--size)';")
	stable();assert(arrangements>before and token.ContentWidth==260,"Geometry custom property consumers still request layout")
	before=arrangements;run("sheet.cssRules[0].style.setProperty('--size','280px');")
	stable();assert(arrangements>before and token.ContentWidth==280,"Changing only a used geometry variable updates the existing box")
	run("sheet.cssRules[0].style.width='240px';sheet.cssRules[0].style.removeProperty('--size');")
	stable();assert(token.ContentWidth==240)
	run("document.getElementById('button').click();if(clicks!==1)throw new Error('lost click handler');")
	before=arrangements;run("sheet.disabled=true;")
	color("000000");stable();run("if(document.styleSheets.length!==2 || owner.sheet!==sheet)throw new Error('disabled association');")
	run("sheet.disabled=false;");color("aa2200");stable()
	run([=[const dynamic=document.createElement('style');dynamic.id='dynamic';dynamic.textContent='.token { color: #006600; }';document.head.append(dynamic);]=])
	color("006600");stable()
	run("dynamic.sheet.media.mediaText='print';if(dynamic.getAttribute('media')!==null)throw new Error('media rewrote DOM');")
	color("aa2200");stable()
	run("dynamic.setAttribute('media','screen and (min-width: 1000px)');")
	color("aa2200");stable()
	viewport.Width=1200;tree:SetMediaEnvironment(viewport.Width,viewport.Height);arrange();color("006600")
	viewport.Width=960;tree:SetMediaEnvironment(viewport.Width,viewport.Height);arrange();color("aa2200")
	run("dynamic.setAttribute('media','screen');");color("006600")
	run("dynamic.firstChild.data='.token { color: #002266; }';");color("002266");stable()
	run("const detachedSheet=dynamic.sheet;dynamic.remove();if(dynamic.sheet!==null)throw new Error('detached association');")
	color("aa2200");stable()
	run("document.body.append(dynamic);if(dynamic.sheet===detachedSheet)throw new Error('reinserted association');")
	color("002266");stable()
	before=arrangements
	run("const adopted=new CSSStyleSheet();adopted.replaceSync('.token { color: #440088; }');document.adoptedStyleSheets=[adopted];if(document.styleSheets.length!==3)throw new Error('adopted in ordinary sheets');")
	color("440088");stable();assert(arrangements==before,"Adoption of color-only rules does not arrange the page")
	run("adopted.replaceSync('.token { color: #884400; }');");color("884400");stable()
	run("document.adoptedStyleSheets=[];dynamic.remove();");color("aa2200");stable()
	-- A scoped constructed sheet can introduce/change/remove border paint on
	-- an already mounted box. Assert actual surfaces, not only computed styles.
	local function strokeFor(gui)
		for _,item in guis do if item.ClassName=='UIStroke'and item.Parent==gui and not item.Destroyed then return item end end
		return nil
	end
	-- Native nesting preserves source-order declarations rather than moving
	-- every declaration ahead of child rules. The same rule objects must drive
	-- real paint, media-dependent geometry and regenerated attribute/counter text.
	run([=[adopted.replaceSync('#token{color:#102030;counter-reset:badge 3;&.selected{color:#00aa00}color:#223344;@media(min-width:1000px){width:300px;&.selected{height:120px}}&::before{content:"[" counter(badge) "]" attr(data-caption);color:#884400}}');document.adoptedStyleSheets=[adopted];target.setAttribute('data-caption','A');]=])
	color('223344');stable()
	local function generatedText()
		local out={};for _,item in tree.TextItems do if item.Style and item.Style.Node==node('token')and item.Style.PseudoElement=='before'then table.insert(out,item.Text or'')end end
		return table.concat(out)
	end
	assert(generatedText()=='[3]A','A nested pseudo rule did not paint its counter/attribute text: '..generatedText())
	before=arrangements
	run("adopted.cssRules[0].cssRules[1].style.color='#334455';")
	color('334455');stable();assert(arrangements==before,'Nested declaration colors must remain paint-only')
	run("target.classList.add('selected');")
	color('00aa00');stable();assert(arrangements==before,'A nested compound selector must repaint without arranging')
	run("target.classList.remove('selected');target.setAttribute('data-caption','B');")
	color('334455');stable();assert(generatedText()=='[3]B','Attribute changes failed to regenerate nested pseudo content')
	viewport.Width=1200;tree:SetMediaEnvironment(viewport.Width,viewport.Height);arrange();assert(token.ContentWidth==300,'Nested media declarations failed to change real width')
	viewport.Width=960;tree:SetMediaEnvironment(viewport.Width,viewport.Height);arrange();assert(token.ContentWidth==240,'Leaving nested media failed to restore author width')
	run("adopted.cssRules[0].cssRules[3].style.content='none';")
	stable();assert(generatedText()=='','Removing nested pseudo content left generated glyphs')
	before=arrangements
	run("adopted.cssRules[0].insertRule('&.selected{background-color:#112233}',4);target.classList.add('selected');")
	assert(token.Style.Background==Color3.fromRGB(17,34,51)and arrangements==before,'Inserted nested CSSOM rule must repaint the retained surface')
	run("document.adoptedStyleSheets=[];target.classList.remove('selected');target.removeAttribute('data-caption');")
	color('aa2200');stable()
	assert(not strokeFor(nativeToken),'Borderless fixture unexpectedly owns a stroke')
	run("adopted.replaceSync('@scope (#token){#token{border:2px solid rgba(84,113,90,.5)}}');document.adoptedStyleSheets=[adopted];")
	stable();assert(not strokeFor(nativeToken)and token.InsetEdges==nil,'An implicit scoped subject does not style its own root')
	run("adopted.cssRules[0].cssRules[0].selectorText=':scope';")
	stable();local scopedStroke=assert(strokeFor(nativeToken),'Adopting a scoped border did not allocate native paint')
	assert(scopedStroke.Thickness==2 and scopedStroke.Color==Color3.fromRGB(84,113,90)and scopedStroke.Transparency==.5,'Constructed scoped border width/color/alpha did not reach its stroke')
	run("adopted.cssRules[0].cssRules[0].style.border='none';")
	stable();assert(scopedStroke.Destroyed and not strokeFor(nativeToken)and token.InsetEdges==nil,'Removing a border must dispose only the old border surfaces')
	run("adopted.replaceSync('@scope (#token){#token{border:3px dashed rgba(84,113,90,.5);opacity:.6}}');")
	stable();assert(token.InsetEdges==nil and token.OpacityGroup==nil and token.Style.Opacity==1,'Implicit scoped root rules paint neither dashed borders nor opacity')
	run("adopted.cssRules[0].cssRules[0].selectorText=':scope';")
	stable();local patterned=assert(token.InsetEdges,'Changing to dashed did not allocate strips')
	assert(patterned.Factory and token.OpacityGroup and token.Style.Opacity==.6,'Patterned border or combined opacity group was not applied')
	local visibleSegment=false;for _,pool in patterned.Pools do for _,segment in ipairs(pool)do if segment.Visible then assert(segment.BackgroundTransparency==.5,'Patterned border alpha is incorrect');visibleSegment=true end end end
	assert(visibleSegment,'Dashed border has no visible paint segments')
	run("adopted.cssRules[0].cssRules[0].style.border='1px solid #dd5500';")
	stable();local replacementStroke=assert(strokeFor(nativeToken),'Returning to solid did not allocate a native stroke')
	for index=1,4 do assert(patterned[index].Destroyed,'Obsolete patterned strip was retained')end
	assert(replacementStroke.Thickness==1 and replacementStroke.Color==Color3.fromRGB(221,85,0),'Replacement native border paint is incorrect')
	before=arrangements;run("adopted.cssRules[0].cssRules[0].style.borderColor='#0055dd';")
	stable();assert(strokeFor(nativeToken)==replacementStroke and replacementStroke.Color==Color3.fromRGB(0,85,221)and arrangements==before,'Color-only border changes must reuse their surface without layout')
	run("document.adoptedStyleSheets=[];");stable();assert(replacementStroke.Destroyed and not strokeFor(nativeToken),'Unadoption left stale border paint')
	before=arrangements
	run("adopted.replaceSync('@namespace h url(http://www.w3.org/1999/xhtml);@scope(h|div#token){h|div#token{color:#11355b}}');document.adoptedStyleSheets=[adopted];")
	color('aa2200');stable();assert(arrangements==before,'An implicit namespaced root rule must retain unscoped color without layout')
	run("adopted.cssRules[1].cssRules[0].selectorText='h|div#token:scope';")
	color('11355b');stable();assert(arrangements==before,'Namespaced scope adoption must use the retained paint path')
	run("adopted.cssRules[1].cssRules[0].style.color='#224466';")
	color('224466');stable();assert(arrangements==before,'Editing a namespaced scope must repaint without arranging')
	run("document.adoptedStyleSheets=[];");color('aa2200');stable()
	run("owner.textContent='.token { color: #112233; width: 180px; padding: 8px; }';if(owner.sheet===sheet)throw new Error('text did not reset sheet');")
	color("112233");stable()
	before=arrangements
	run("const sameValueSheet=owner.sheet;sameValueSheet.cssRules[0].style.color='#aabbcc';")
	color("aabbcc");assert(arrangements==before,"Source override color remains paint-only")
	run("owner.textContent=owner.textContent;if(owner.sheet===sameValueSheet)throw new Error('same text did not reset sheet');")
	color("112233");stable();assert(arrangements==before,"Same-value source mutation resets CSSOM paint without layout")
	-- Structural mutations still reconcile actual rendered children.
	run("const added=document.createElement('p');added.id='new-child';added.textContent='Added content';target.append(added);")
	local addedNode=node("new-child");assert(tree.NodeBoxes[addedNode]~=nil,"Ordinary DOM insertion remains rendered");stable()
	run("added.remove();");assert(not tree.NodeBoxes[addedNode],"Removed node is absent from the renderer")
	-- Exercise script insertion through the real renderer preflight and flush,
	-- rather than a DOM-only host that never validates structural mutations.
	before=arrangements;local guiCount=#guis
	run([=[
globalThis.scriptRuns=0;globalThis.scriptOrder=[];
const inlineScript=document.createElement('script');
inlineScript.text='globalThis.scriptRuns++;';document.head.append(inlineScript);
if(scriptRuns!==1 || inlineScript.parentNode!==document.head)throw new Error('head inline execution');
inlineScript.remove();document.body.append(inlineScript);document.head.append(inlineScript);
if(scriptRuns!==1)throw new Error('script ran again after moving');
const emptyScript=document.createElement('script');document.head.append(emptyScript);
emptyScript.append(document.createTextNode('globalThis.scriptRuns++;'));
if(scriptRuns!==2)throw new Error('connected script text insertion');
emptyScript.firstChild.data='globalThis.scriptRuns+=100;';
const bodyScript=document.createElement('script');document.body.append(bodyScript);
bodyScript.textContent='globalThis.scriptRuns++;';
if(scriptRuns!==3)throw new Error('connected body script text');
const inertScript=document.createElement('script');inertScript.type='application/json';
inertScript.textContent='{"project":"kept"}';document.head.append(inertScript);
inertScript.append(document.createComment('metadata'));inertScript.remove();
const fragment=document.createDocumentFragment();
for(const file of ['first.js','second.js']){
  const external=document.createElement('script');external.async=false;external.src=file;fragment.append(external);
}
document.head.append(fragment);
]=])
	run("if(scriptRuns!==3 || scriptOrder.join(',')!=='first,second')throw new Error('ordered dynamic script result');inlineScript.remove();emptyScript.remove();bodyScript.remove();")
	run("owner.sheet.insertRule('body:has(> script.dynamic-marker) #token { background-color: #fedcba; }',owner.sheet.cssRules.length);inlineScript.className='dynamic-marker';document.body.append(inlineScript);")
	assert(tree.NodeStyles[node("token")].Background==Color3.fromRGB(254,220,186),
		"Hidden script insertion still invalidates relational selectors on rendered elements")
	run("document.head.append(inlineScript);")
	assert(tree.NodeStyles[node("token")].Background==Color3.fromRGB(171,205,239),
		"Moving a script to head updates selectors on its previous body parent")
	stable();assert(arrangements==before and #guis==guiCount,
		"Non-rendered script insertion, text edits, moves and removal retain controls and do not arrange or allocate GUI surfaces")
	-- Metadata is ordinary live DOM. It must update URL-dependent script
	-- preparation inside this same script, before the renderer batch runs.
	before=arrangements;guiCount=#guis
	services.ScriptSources['https://example.test/resources/probe.js']="globalThis.metadataLoads.push(document.currentScript.src);"
	services.ScriptSources['https://example.test/next/probe.js']="globalThis.metadataLoads.push(document.currentScript.src);"
	run([=[
document.title='  A\n  live title  ';
if(document.title!=='A live title')throw new Error('title DOM mutation');
const liveMeta=document.createElement('meta');liveMeta.setAttribute('name','theme-color');
liveMeta.setAttribute('content','#223344');document.head.append(liveMeta);
const liveBase=document.createElement('base');liveBase.setAttribute('href','resources/');
liveBase.setAttribute('target','');document.head.prepend(liveBase);
if(document.baseURI!=='https://example.test/resources/')throw new Error('live base read');
const laterBase=document.createElement('base');laterBase.setAttribute('href','ignored/');
laterBase.setAttribute('target','ignored');document.head.append(laterBase);
globalThis.metadataLoads=[];
const resourceScript=document.createElement('script');resourceScript.src='probe.js';
document.head.append(resourceScript);
]=])
	assert(page.Title=='A live title'and root:GetAttribute('Title')==page.Title,'Dynamic title was not published to its mounted page')
	assert(page.BaseURL=='https://example.test/resources/'and tree.BaseURL==page.BaseURL and page.DefaultTarget=='','First base href/empty target must reach resource and link consumers')
	assert(root:GetAttribute('ThemeColor')=='#223344','Dynamic theme metadata was not published')
	run("if(metadataLoads.join(',')!=='https://example.test/resources/probe.js')throw new Error('live script resolution');liveBase.setAttribute('href','next/');const nextScript=document.createElement('script');nextScript.src='probe.js';document.head.append(nextScript);")
	assert(page.BaseURL=='https://example.test/next/','Changing base href must update the mounted resolver')
	run("if(metadataLoads.join(',')!=='https://example.test/resources/probe.js,https://example.test/next/probe.js')throw new Error('base attribute script resolution');nextScript.remove();resourceScript.remove();laterBase.remove();liveBase.remove();liveMeta.remove();document.title='';")
	assert(page.BaseURL=='https://example.test/page'and page.DefaultTarget==''and root:GetAttribute('ThemeColor')==nil,'Removing metadata restores document defaults without retaining stale attributes')
	stable();assert(arrangements==before and #guis==guiCount,'Metadata updates must retain native controls and avoid layout or GUI allocation')
	-- Body child-list work must not rescan the complete document's metadata.
	-- Metadata nested inside an inserted/removed subtree still invalidates it.
	local documentInfo=require("HTML/DocumentInfo");local collectMetadata=documentInfo.collect;local metadataScans=0
	documentInfo.collect=function(...)metadataScans+=1;return collectMetadata(...)end
	run("const plainMetadataProbe=document.createElement('p');plainMetadataProbe.textContent='Ordinary result';document.body.append(plainMetadataProbe);")
	run("plainMetadataProbe.textContent='Changed ordinary result';plainMetadataProbe.remove();")
	assert(metadataScans==0,'Ordinary body insertion/text/removal rescanned document metadata')
	run("const nestedMetadataHolder=document.createElement('div'),nestedTheme=document.createElement('meta');nestedTheme.name='theme-color';nestedTheme.content='#334455';nestedMetadataHolder.append(nestedTheme);document.body.append(nestedMetadataHolder);")
	assert(metadataScans==1 and root:GetAttribute('ThemeColor')=='#334455','Metadata nested in a connected insertion was not published')
	run("nestedTheme.setAttribute('content','#445566');")
	assert(metadataScans==2 and root:GetAttribute('ThemeColor')=='#445566','Nested metadata attribute changes left the evaluated snapshot stale')
	run("nestedMetadataHolder.remove();")
	assert(metadataScans==3 and root:GetAttribute('ThemeColor')==nil,'Removing a subtree with metadata must restore defaults')
	documentInfo.collect=collectMetadata;stable()
	-- Language defaults invalidate real matching/paint without replacing controls.
	run("const languageSheet=document.createElement('style');languageSheet.textContent='#outside:lang(de){color:red}#outside:lang(fr){color:blue}';document.head.append(languageSheet);")
	local languageLayouts=arrangements
	run("const languageMeta=document.createElement('meta');languageMeta.httpEquiv='content-language';languageMeta.content='de';document.head.append(languageMeta);")
	assert(tree.NodeStyles[node('outside')].Color==Color3.fromRGB(255,0,0)and arrangements==languageLayouts,'Meta insertion recascades language selectors as retained paint only')
	run("languageMeta.content='fr';languageMeta.remove();")
	assert(tree.NodeStyles[node('outside')].Color==Color3.fromRGB(255,0,0)and arrangements==languageLayouts,'Meta edits/removal preserve the processed language')
	run("document.head.append(languageMeta);")
	assert(tree.NodeStyles[node('outside')].Color==Color3.fromRGB(0,0,255)and arrangements==languageLayouts,'Reinsertion applies the new pragma without layout')
	for _,case in selectPseudos.cases do
		run("globalThis.pseudoHolder=document.createElement('section');pseudoHolder.innerHTML="..string.format('%q',case.html)..";document.body.append(pseudoHolder);globalThis.pseudoRecords=[];")
		local original=model:Resolve(node('pseudoSelect'));local originalGui=original.Item.Gui
		run("{const record=(...values)=>pseudoRecords.push(values.map(String).join('|'));"..case.code.."}")
		local expected=table.concat(case.expected,';')
		run("if(pseudoRecords.join(';')!=="..string.format('%q',expected)..")throw new Error('Select pseudo reference: '+pseudoRecords.join(';'));")
		assert(model:Resolve(node('pseudoSelect'))==original and original.Item.Gui==originalGui,'Pseudo changes retain the select record and surface')
		if case.name=='Author picker icon and reversible content/style changes'then
			local visibleIcon
			for _,item in tree.TextItems do if item.Text=='v'and item.Style.PseudoElement=='picker-icon'then visibleIcon=item end end
			assert(visibleIcon and visibleIcon.Gui.TextColor3==Color3.fromRGB(255,0,0),'Author picker content/color reaches the actual retained painter')
		end
		run("pseudoHolder.remove();")
	end
	stable()
	-- A value write affects range matching immediately, including before a
	-- render flush. The cascade then repaints related retained siblings.
	run("const rangeSheet=document.createElement('style');rangeSheet.textContent='#rangeProbe:in-range{color:red}#rangeProbe:out-of-range{color:blue}#token:has(#rangeProbe:out-of-range)+#outside{background:blue}';document.head.append(rangeSheet);const numberProbe=document.createElement('input');numberProbe.id='rangeProbe';numberProbe.type='number';numberProbe.min='3';numberProbe.max='7';numberProbe.value='4';target.append(numberProbe);")
	local rangeLayouts=arrangements
	local rangeGui=model:Resolve(node('rangeProbe')).Item.Gui
	assert(tree.NodeStyles[node('rangeProbe')].Color==Color3.fromRGB(255,0,0),'Mounted in-range color reaches the control')
	run("numberProbe.value='9';if(!numberProbe.matches(':out-of-range'))throw new Error('Immediate out-of-range query');")
	assert(tree.NodeStyles[node('rangeProbe')].Color==Color3.fromRGB(0,0,255),'Range value recascades the control color')
	assert(tree.NodeStyles[node('outside')].Background==Color3.fromRGB(0,0,255),'Range value recascades the related sibling')
	assert(arrangements==rangeLayouts,'Range color changes need no layout: '..arrangements..' ~= '..rangeLayouts)
	run("numberProbe.max='10';if(!numberProbe.matches(':in-range'))throw new Error('Immediate limit query');")
	assert(tree.NodeStyles[node('rangeProbe')].Color==Color3.fromRGB(255,0,0)and model:Resolve(node('rangeProbe')).Item.Gui==rangeGui and arrangements==rangeLayouts,'Limit changes recascade the retained actual control without layout')
	run("numberProbe.remove();rangeSheet.remove();")
	run("rangeSheet.textContent='#token:has(#selectProbe option:checked[value=b])+#outside{color:purple}';document.head.append(rangeSheet);const selectProbe=document.createElement('select');selectProbe.id='selectProbe';selectProbe.innerHTML='<option value=a selected>A</option><option value=b>B</option>';target.append(selectProbe);")
	local selectedLayouts=arrangements
	run("selectProbe.value='b';if(!selectProbe.options[1].matches(':checked')||!selectProbe.options[0].matches(':default'))throw new Error('Current option selection vs default');")
	assert(tree.NodeStyles[node('outside')].Color==Color3.fromRGB(128,0,128)and arrangements==selectedLayouts,'Option selectedness reaches relational CSS matching without changing the default attribute or layout')
	run("selectProbe.value='a';")
	assert(tree.NodeStyles[node('outside')].Color==Color3.fromRGB(0,0,255)and arrangements==selectedLayouts,'Old selectedness snapshots remain independent when the selected option changes')
	local selectControl=model:Resolve(node('selectProbe'));local selectItem=selectControl.Item
	local selectGui,selectBox,oldCaption,oldArrow=selectItem.Gui,selectItem.BoxGui,selectItem.Label,selectItem.SelectArrowGui
	root.Parent=factory.create('Frame',nil,{})
	selectBox.AbsolutePosition=Vector2.new(20,40);selectBox.AbsoluteSize=Vector2.new(120,26)
	run("rangeSheet.textContent+='#selectProbe:open{color:teal}#token:has(#selectProbe:open)+#outside{background:teal}';")
	local openLayouts=arrangements
	model:ToggleSelect(selectControl)
	run("if(!selectProbe.matches(':open')||selectProbe.hasAttribute('open'))throw new Error('Dropdown open state is separate from attributes');")
	assert(tree.NodeStyles[node('selectProbe')].Color==Color3.fromRGB(0,128,128)and tree.NodeStyles[node('outside')].Background==Color3.fromRGB(0,128,128)and arrangements==openLayouts,'Opening the picker recascades retained local and relational paint only')
	model:ToggleSelect(selectControl)
	run("if(selectProbe.matches(':open'))throw new Error('Closed dropdown state');")
	assert(tree.NodeStyles[node('selectProbe')].Color~=Color3.fromRGB(0,128,128)and tree.NodeStyles[node('outside')].Background~=Color3.fromRGB(0,128,128)and arrangements==openLayouts,'Closing restores CSS paint without layout')
	model:ToggleSelect(selectControl)
	page:Focus(selectControl.Node)
	run("selectProbe.size=3;")
	assert(tree.CSSStates.open==nil,'Switching an open dropdown to a list closes its picker and state')
	assert(selectControl.SelectList and selectItem.SelectScroll and not selectItem.Label and not selectItem.SelectArrow,
		'A live size change replaces dropdown contents with the list view')
	assert(oldCaption.Destroyed and oldArrow.Destroyed and selectItem.Gui==selectGui and selectItem.BoxGui==selectBox and selectControl.Focused,
		'Only anonymous dropdown contents are replaced; the focused native control stays intact')
	local listScroll=selectItem.SelectScroll;local listRow=selectItem.SelectListRows[1].Gui
	run("selectProbe.multiple=true;selectProbe.options[0].selected=true;selectProbe.options[1].selected=true;")
	assert(selectControl.SelectedIndices[1]and selectControl.SelectedIndices[2]and selectItem.SelectScroll==listScroll and selectItem.SelectListRows[1].Gui==listRow,
		'Multiple selection keeps list rows and their scroll host')
	run("selectProbe.multiple=false;")
	assert(not selectControl.SelectMultiple and selectControl.SelectedIndex==1 and selectItem.SelectScroll==listScroll,'Removing multiple keeps the first selected option and list host')
	run("selectProbe.size=1;")
	assert(not selectControl.SelectList and listScroll.Destroyed and listRow.Destroyed and selectItem.Label.Text=='A'and selectItem.SelectArrowGui,
		'Returning to dropdown releases old list rows and paints the current value')
	assert(model:Resolve(selectControl.Node)==selectControl and selectItem.Gui==selectGui and selectItem.BoxGui==selectBox and selectControl.Focused,
		'Dropdown/list round trips retain the control record, native outer surfaces and focus')
	local label=selectItem.Label
	run("selectProbe.size=0;selectProbe.style.appearance='none';")
	assert(selectItem.Label==label and not selectControl.SelectList and selectItem.SelectArrow[1].Visible==false,'Invalid size fallback and primitive appearance retain the caption but hide the native icon')
	run("selectProbe.style.appearance='auto';selectProbe.removeAttribute('size');")
	assert(selectItem.Label==label and selectItem.SelectArrow[1].Visible and selectItem.Gui==selectGui,'Native appearance restores the original retained dropdown icon')
	run("selectProbe.style.appearance='base-select';rangeSheet.textContent+='#selectProbe:open::picker(select){appearance:base-select;background:red;color:blue}';")
	-- Base appearance lays out on the retained primary select surface. These
	-- substitutes do not derive Absolute* from their fitted Size/Position.
	selectItem.BoxGui.AbsolutePosition=Vector2.new(20,40);selectItem.BoxGui.AbsoluteSize=Vector2.new(120,26)
	model:ToggleSelect(selectControl)
	local openPopup,openOptions,openPicker
	for _,gui in guis do if not gui.Destroyed then if gui.Name=='SelectPopup'then openPopup=gui elseif gui.Name=='Options'then openOptions=gui
		elseif gui.Parent and gui.Parent.Name=='PickerContent'then openPicker=gui end end end
	assert(openPopup and openOptions and openPicker and not openOptions.Visible and openPicker.BackgroundColor3==Color3.fromRGB(255,0,0),'Open-dependent custom picker styling reaches its actual CSS box')
	run("rangeSheet.textContent+='#selectProbe:open::picker(select){background:green}';")
	assert(not openPopup.Destroyed and not openOptions.Destroyed and not openPicker.Destroyed and openPicker.BackgroundColor3==Color3.fromRGB(0,128,0)and tree.CSSStates.open==selectControl.Node,'Live picker color changes retain its actual CSS box, host and semantic open state')
	run("rangeSheet.textContent+='#selectProbe:open::picker(select){appearance:auto}';")
	assert(not openPopup.Destroyed and not openOptions.Destroyed and openOptions.Visible and openPicker.Destroyed and tree.CSSStates.open==selectControl.Node,'Changing the open picker appearance releases only its CSS view and restores the native rows')
	model:ToggleSelect(selectControl)
	run("selectProbe.style.appearance='auto';")
	run("selectProbe.options[1].text='A considerably longer caption';selectProbe.value='a';")
	local fixedSelectWidth=selectItem.BoxWidth
	run("selectProbe.value='b';")
	assert(selectItem.BoxWidth==fixedSelectWidth,'Fixed preferred select width includes unselected options')
	run("selectProbe.style.fieldSizing='content';selectProbe.value='a';")
	local shortSelectWidth=selectItem.BoxWidth
	assert(shortSelectWidth<fixedSelectWidth and selectItem.Style.FieldSizing=='content','Content sizing measures the displayed caption rather than all options')
	run("selectProbe.value='b';")
	assert(selectItem.BoxWidth>shortSelectWidth and selectItem.BoxWidth==fixedSelectWidth and selectItem.Gui==selectGui,'A script selection updates actual content-sized geometry on the retained native control')
	run("selectProbe.size=6;")
	assert(selectItem.IntrinsicHeight==selectItem.SelectRowHeight*2,'A content-sized list shows its actual rows rather than the size attribute')
	run("selectProbe.style.fieldSizing='fixed';")
	assert(selectItem.IntrinsicHeight==selectItem.SelectRowHeight*6,'Fixed sizing restores the requested list height')
	stable()
	run("selectProbe.remove();rangeSheet.remove();")
	stable()
	-- Radio validity changes even on peers whose checked bit stays false.
	-- Compare real paint before/after immutable snapshots, including relational
	-- form/fieldset rules and the live pattern adapter.
	run([=[const validitySheet=document.createElement('style');validitySheet.textContent='#validationProbe input:invalid,#validationProbe button:invalid{color:red}#validationProbe input:valid,#validationProbe button:valid{color:blue}#validationProbe:invalid{background:red}#validationFields:invalid{background:red}';document.head.append(validitySheet);
const validationProbe=document.createElement('form');validationProbe.id='validationProbe';validationProbe.innerHTML='<fieldset id="validationFields"><input id="radioRequired" type="radio" name="group" required><input id="radioOptional" type="radio" name="group"><input id="patternProbe" pattern="[A-Z]{2}" value="AB"><button id="submitProbe">Submit</button></fieldset>';document.body.append(validationProbe);
const radioRequired=document.getElementById('radioRequired'),radioOptional=document.getElementById('radioOptional'),patternProbe=document.getElementById('patternProbe'),submitProbe=document.getElementById('submitProbe');]=])
	local validityLayouts=arrangements
	local requiredGui=model:Resolve(node('radioRequired')).Item.Gui
	local optionalGui=model:Resolve(node('radioOptional')).Item.Gui
	local function validationColors(required,optional)
		assert(tree.NodeStyles[node('radioRequired')].Color==required and tree.NodeStyles[node('radioOptional')].Color==optional,'A radio peer retained stale validity paint')
		assert(model:Resolve(node('radioRequired')).Item.Gui==requiredGui and model:Resolve(node('radioOptional')).Item.Gui==optionalGui and arrangements==validityLayouts,'Radio/pattern validity paint must retain controls without layout')
	end
	local red,blue=Color3.fromRGB(255,0,0),Color3.fromRGB(0,0,255)
	validationColors(red,red)
	run("radioOptional.checked=true;if(!radioRequired.matches(':valid')||!validationProbe.checkValidity())throw new Error('Radio peer group validity');")
	validationColors(blue,blue)
	assert(tree.NodeStyles[node('validationProbe')].Background~=red and tree.NodeStyles[node('validationFields')].Background~=red,'Radio selection clears relational form/fieldset invalid paint')
	run("radioOptional.checked=false;")
	validationColors(red,red)
	assert(tree.NodeStyles[node('validationProbe')].Background==red and tree.NodeStyles[node('validationFields')].Background==red,'Clearing a peer restores form/fieldset invalid paint')
	run("radioRequired.checked=true;patternProbe.value='ab';if(!patternProbe.validity.patternMismatch||!patternProbe.matches(':invalid'))throw new Error('Live pattern flags');")
	validationColors(blue,blue);assert(tree.NodeStyles[node('patternProbe')].Color==red,'Pattern validation reaches native CSS paint')
	run("patternProbe.value='AB';submitProbe.setCustomValidity('A submit button can fail validation');")
	assert(tree.NodeStyles[node('patternProbe')].Color==blue and tree.NodeStyles[node('submitProbe')].Color==red,'Pattern recovery and custom submit validity share the CSS flag path')
	run("submitProbe.setCustomValidity('');validationProbe.remove();validitySheet.remove();")
	stable()
	-- Execute the recorded browser sequence against the actual mounted DOM,
	-- controller and script geometry host, rather than a hand-written measure.
	for _,case in selectSizing.cases do
		run("globalThis.sizingHolder=document.createElement('section');sizingHolder.innerHTML="..string.format('%q',case.html)..";document.body.append(sizingHolder);globalThis.sizingRecords=[];")
		run("{const record=(...values)=>sizingRecords.push(values.map(String).join('|'));"..case.code.."}")
		local expected=table.concat(case.standardExpected or case.expected,';')
		run("if(sizingRecords.join(';')!=="..string.format('%q',expected)..")throw new Error('Select sizing reference: '+sizingRecords.join(';'));sizingHolder.remove();")
	end
	stable()
	-- Named anchor fallbacks use the same live CSSOM/source publication path
	-- as ordinary rules, and must not replace an already mounted surface.
	run([=[globalThis.anchorSheet=new CSSStyleSheet();anchorSheet.replaceSync('@position-try --fit{left:40px;top:20px;width:30px}');document.adoptedStyleSheets=[anchorSheet];
globalThis.anchorHolder=document.createElement('section');anchorHolder.innerHTML='<div id="anchorRoot" style="position:relative;width:400px;height:220px"><div id="anchorSource" style="anchor-name:--a;position:absolute;left:350px;top:175px;width:40px;height:25px"></div><div id="anchorTip" style="position:absolute;position-anchor:--a;left:anchor(right);top:anchor(bottom);width:80px;height:35px;position-try-fallbacks:--fit"></div></div>';document.body.append(anchorHolder);globalThis.anchorTip=document.getElementById('anchorTip');]=])
	local anchored=tree.NodeBoxes[node('anchorTip')];local anchorGui,anchorStyle=anchored.Gui,anchored.Style
	assert(anchored.PaintX==40 and anchored.PaintY==20 and anchored.OuterWidth==30,'An adopted @position-try rule changes the mounted box geometry')
	run("anchorSheet.cssRules[0].style.left='65px';anchorSheet.cssRules[0].style.width='45px';")
	assert(anchored.PaintX==65 and anchored.OuterWidth==45 and anchored.Gui==anchorGui and anchored.Style==anchorStyle,'Live position-try descriptors invalidate used layout while retaining box/style identity')
	run("anchorSheet.cssRules[0].style.width='anchor-size(width)';")
	assert(anchored.OuterWidth==40,'A live fallback size resolves the actual anchor border box')
	local anchorPaintLayouts=arrangements
	run("anchorTip.style.color='blue';if(getComputedStyle(anchorTip).color!=='rgb(0, 0, 255)')throw new Error('Stale anchor used color');if(getComputedStyle(anchorTip).width!=='40px')throw new Error('Anchor used width');")
	assert(arrangements==anchorPaintLayouts and anchored.Gui==anchorGui,'A pure color edit on a box with used anchor styles needs no layout')
	run("anchorSheet.insertRule('@position-try --other{left:5px;top:5px;width:25px;height:20px}',1);anchorTip.style.positionTry='most-width --fit, --other';if(getComputedStyle(anchorTip).positionTryOrder!=='most-width'||getComputedStyle(anchorTip).positionTryFallbacks!=='--fit, --other')throw new Error('Anchor order computed style');")
	assert(anchored.PaintX==5 and anchored.PaintY==5 and anchored.OuterWidth==25 and anchored.Gui==anchorGui and anchored.Style==anchorStyle,'A mounted shorthand ranks candidates by available inset space rather than element width')
	run("anchorTip.style.positionTryOrder='normal';")
	assert(anchored.PaintX==65 and anchored.PaintY==20 and anchored.OuterWidth==40,'A fallback-sensitive order change resets the retained choice through the live CSSOM path')
	local orderedPaintLayouts=arrangements
	run("anchorTip.style.color='red';if(getComputedStyle(anchorTip).color!=='rgb(255, 0, 0)')throw new Error('Ordered anchor color');")
	assert(arrangements==orderedPaintLayouts and anchored.Gui==anchorGui,'Ordered anchor color paint remains layout-free')
	run("anchorHolder.remove();document.adoptedStyleSheets=[];")
	stable()
	-- Logical dimensions use the same live CSSOM, dirty-layout and control path
	-- as physical dimensions; changing mode remaps existing fields and GUIs.
	local editor=control.Item.Editor
	run("document.getElementById('notes').setSelectionRange(1,3,'backward');")
	for _,mode in {'horizontal-tb','vertical-rl','vertical-lr','sideways-rl','sideways-lr'}do
		run("target.style.cssText='width:140px;height:90px;min-width:0;min-height:0;max-width:none;max-height:none;inline-size:180px;block-size:80px;writing-mode:"..mode.."';")
		local vertical=mode~='horizontal-tb';local width,height=if vertical then 80 else 180,if vertical then 180 else 80
		run("{const s=getComputedStyle(target);if(s.width!=='"..width.."px'||s.height!=='"..height.."px'||s.inlineSize!=='180px'||s.blockSize!=='80px')throw new Error('Live logical dimension pair '+s.width+'/'+s.height+'/'+s.inlineSize+'/'+s.blockSize);const input=document.getElementById('notes');if(input.value!=='edited'||input.selectionStart!==1||input.selectionEnd!==3||input.selectionDirection!=='backward')throw new Error('Logical sizing replaced input state');}")
		stable();assert(control.Item.Editor==editor,'Logical sizing retains the native editor and its event bindings')
		local paintLayouts=arrangements
		run("target.style.color='blue';if(getComputedStyle(target).color!=='rgb(0, 0, 255)')throw new Error('Logical sizing color paint');")
		assert(arrangements==paintLayouts,'Color on a logically sized surface must remain layout-free')
	end
	run("target.removeAttribute('style');")
	stable()
	-- Editing ownership is live selector state. Paint the captured browser
	-- sequence through the normal DOM/controller/recascade path and retain the
	-- native text/control surfaces and selection throughout.
	run(editingSelectors.paint.setup)
	run("editingPaintInput.setSelectionRange(1,4,'backward');")
	local editingControl=model:Resolve(node('editingPaintInput'))
	local editingEditor=editingControl.Item.Editor
	local editingNative={}
	for _,id in {'editingPaintHolder','editingPaintText','editingPaintIsland','editingPaintIslandText','editingPaintInput'}do
		editingNative[id]=tree.NodeBoxes[node(id)]or model:Resolve(node(id)).Item
	end
	local editingLayouts,editingAllocations=arrangements,#guis
	local editingWords={}
	for _,item in tree.TextItems do
		if item.Kind=='Word'and(item.Style.Node==node('editingPaintText')or item.Style.Node==node('editingPaintIslandText'))then
			table.insert(editingWords,{Item=item,Gui=item.Gui,Index=if item.Style.Node==node('editingPaintText')then 1 else 2})
		end
	end
	assert(#editingWords>0,'Editing paint controls need actual retained text labels')
	for _,state in editingSelectors.paint.states do
		run(state.code)
		run("window.editingPaintResult="..editingSelectors.paint.sample..";if(editingPaintInput.value!=='retained'||editingPaintInput.selectionStart!==1||editingPaintInput.selectionEnd!==4||editingPaintInput.selectionDirection!=='backward')throw new Error('Editing recascade replaced selection');")
		assert(realm.Window.Get('editingPaintResult')==state.json,state.name..': stale editing-state CSS paint')
		assert(arrangements==editingLayouts and #guis==editingAllocations,state.name..': editing color changes require neither layout nor native allocation')
		for id,item in editingNative do
			assert((tree.NodeBoxes[node(id)]or model:Resolve(node(id)).Item)==item and not item.Gui.Destroyed,state.name..': editing state replaced a native surface')
		end
		assert(model:Resolve(node('editingPaintInput'))==editingControl and editingControl.Item.Editor==editingEditor,state.name..': editing state replaced a native editor')
		local colors={}
		for r,g,b in state.json:gmatch('rgb%((%d+), (%d+), (%d+)%)')do table.insert(colors,Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b)))end
		for _,word in editingWords do
			assert(table.find(tree.TextItems,word.Item)and word.Item.Gui==word.Gui and word.Gui.TextColor3==colors[word.Index],state.name..': editing state must repaint the original text label')
		end
		assert(editingEditor.TextColor3==colors[3]and editingNative.editingPaintHolder.Gui.BackgroundColor3==colors[4],state.name..': editing control/background paint is stale')
		stable()
	end
	run("editingPaintHolder.remove();editingPaintSheet.remove();")
	stable()
	-- The draft heading selector uses HTML's live computed DOM level. Offset
	-- and reset attributes change semantic matching, not a heading's font/rank.
	run([=[
		const headingPaintSheet=document.createElement('style');
		headingPaintSheet.textContent='#headingPaintHolder{background-color:rgb(3,7,11)}#headingPaintHolder:has(:heading(3)){background-color:rgb(20,40,60)}#headingPaintText{color:rgb(91,53,17)}#headingPaintText:heading(3){color:rgb(17,53,91)}#headingPaintInput{color:inherit}';
		document.head.append(headingPaintSheet);
		const headingPaintHolder=document.createElement('section');
		headingPaintHolder.id='headingPaintHolder';
		headingPaintHolder.innerHTML='<h2 id="headingPaintText">Retained semantic heading<input id="headingPaintInput" value="retained"></h2>';
		document.body.append(headingPaintHolder);
		const headingPaintText=document.getElementById('headingPaintText'),headingPaintInput=document.getElementById('headingPaintInput');
		headingPaintInput.setSelectionRange(1,4,'backward');
	]=])
	local headingControl=model:Resolve(node('headingPaintInput'))
	local headingEditor=headingControl.Item.Editor
	local headingHolder,headingText=tree.NodeBoxes[node('headingPaintHolder')],tree.NodeBoxes[node('headingPaintText')]
	local headingWords={}
	for _,item in tree.TextItems do
		if item.Kind=='Word'and item.Style.Node==node('headingPaintText')then table.insert(headingWords,{Item=item,Gui=item.Gui})end
	end
	assert(#headingWords>0,'Heading selector paint needs actual retained labels')
	local headingLayouts,headingAllocations=arrangements,#guis
	for _,state in {
		{'',false},
		{'headingPaintHolder.headingOffset=1;',true},
		{"headingPaintHolder.setAttributeNS('urn:test','x:headingoffset','7');",true},
		{'headingPaintHolder.headingReset=true;document.body.headingOffset=2;',true},
		{'headingPaintHolder.headingReset=false;',false},
		{'headingPaintText.headingReset=true;headingPaintText.headingOffset=1;',true},
		{'headingPaintText.headingReset=false;',false},
		{"headingPaintText.removeAttribute('headingoffset');document.body.removeAttribute('headingoffset');",true},
		{'headingPaintHolder.headingOffset=0;',false},
	}do
		run(state[1])
		local matched=state[2]
		run("if(headingPaintText.matches(':heading(3)')!=="..tostring(matched).."||headingPaintHolder.matches(':has(:heading(3))')!=="..tostring(matched)..")throw new Error('Live semantic heading state');if(headingPaintInput.value!=='retained'||headingPaintInput.selectionStart!==1||headingPaintInput.selectionEnd!==4||headingPaintInput.selectionDirection!=='backward')throw new Error('Heading state replaced selection');")
		local expected=if matched then Color3.fromRGB(17,53,91)else Color3.fromRGB(91,53,17)
		local background=if matched then Color3.fromRGB(20,40,60)else Color3.fromRGB(3,7,11)
		assert(arrangements==headingLayouts and #guis==headingAllocations,'Heading semantic colors need no layout or allocation')
		assert(tree.NodeBoxes[node('headingPaintHolder')]==headingHolder and tree.NodeBoxes[node('headingPaintText')]==headingText and headingControl.Item.Editor==headingEditor,'Heading semantic state retains boxes and native editor')
		assert(headingHolder.Gui.BackgroundColor3==background,'Heading relational background paint is stale: '..state[1])
		assert(headingEditor.TextColor3==expected,'Heading editor paint is stale: '..state[1]..' RGB '..tostring(headingEditor.TextColor3.R)..'/'..tostring(headingEditor.TextColor3.G)..'/'..tostring(headingEditor.TextColor3.B))
		for _,word in headingWords do assert(table.find(tree.TextItems,word.Item)and word.Item.Gui==word.Gui and word.Gui.TextColor3==expected,'Heading state repaints the original text labels')end
		stable()
	end
	run("headingPaintHolder.remove();headingPaintSheet.remove();")
	stable()
	-- Intrinsic preferred widths have no numeric Value and cannot be treated
	-- as definite caption bounds by the retained control paint shortcut.
	local captionLabel=button.Item.Label
	for _,keyword in {'min-content','max-content','fit-content'}do
		run("document.getElementById('button').style.width='"..keyword.."';document.getElementById('button').textContent='A';")
		local narrow=button.Item.BoxWidth
		run("document.getElementById('button').textContent='ABCDEFGHIJKLMN';")
		assert(button.Item.BoxWidth>narrow and button.Item.Gui==nativeButton and button.Item.Label==captionLabel,'Intrinsic-width captions remeasure without replacing their native control/label')
		assert(button.Item.Style.Width.Intrinsic==keyword and button.Item.Style.Width.Value==nil,'Intrinsic control width must remain separate from definite lengths')
		stable()
	end
	-- Intrinsic control limits use the existing widget measurements. Exercise
	-- the mounted CSSOM/controller path without rebuilding or rebinding editors.
	for _,keyword in {'min-content','max-content','fit-content'}do
		run("{const input=document.getElementById('notes');input.style.cssText='box-sizing:content-box;width:2px;height:2px;min-width:"..keyword..";min-height:"..keyword.."';if(getComputedStyle(input).minWidth!=='"..keyword.."'||getComputedStyle(input).minHeight!=='"..keyword.."')throw new Error('Intrinsic input minimum CSSOM');}")
		assert(control.Item.ContentWidth==control.Item.IntrinsicWidth and control.Item.ContentHeight==control.Item.IntrinsicHeight,'Mounted control intrinsic minimums use measured widget dimensions')
		run("document.getElementById('notes').style.cssText='box-sizing:content-box;width:500px;height:200px;max-width:"..keyword..";max-height:"..keyword.."';")
		assert(control.Item.ContentWidth==control.Item.IntrinsicWidth and control.Item.ContentHeight==control.Item.IntrinsicHeight,'Mounted control intrinsic maximums limit preferred dimensions')
		run("{const input=document.getElementById('notes');if(input.value!=='edited'||input.selectionStart!==1||input.selectionEnd!==3||input.selectionDirection!=='backward')throw new Error('Intrinsic limits replaced edited selection');}")
		assert(control.Item.Editor==editor,'Intrinsic size limits retain the native editor and its event bindings');stable()
		local paintLayouts=arrangements
		run("document.getElementById('notes').style.color='red';")
		assert(arrangements==paintLayouts,'A control with intrinsic limits still paints color without layout')
	end
	for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;stopInput();healthy()
	print("JavaScript CSSOM rendering: retained surfaces/controls/events, color paint, local width layout, owner sources/media, live sheets/adoption and normal DOM reconciliation passed")
end
