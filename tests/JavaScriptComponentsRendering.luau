--!strict
-- Mounted component updates must change the retained flat render tree, not
-- merely produce correct light-DOM wrappers in a DOM-only test adapter.
return function(Parser,Node,Runtime,VM,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel)
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local guis={};local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(760,900)
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
	local modifiers={}
	factory.modifier=function(class,parent,properties)
		local item=table.clone(properties);item.ClassName,item.Parent=class,parent
		table.insert(modifiers,item);return item
	end
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument([=[<!doctype html><html><body><input id="outside" value="outside"><div id="host"><div id="one" slot="main" class="named">Alpha<input id="note" value="initial"></div><div id="two" slot="alt">Beta</div></div><p id="after">Following block.</p><div id="mount"></div><script>globalThis.componentsReady=true;</script></body></html>]=])
	local messages={};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,
		".inside { color: #ff0000 !important; } #host { display: block; width: 360px; } #one,#two { display: block; } input { width: 90px; }",nil,nil,nil,nil,nil,"https://example.test/components")
	local events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,DocumentURL="https://example.test/components",BaseURL="https://example.test/components",Root=root,FormModel=model,Events=events,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
	local realm,flushing,layoutCalls=nil,false,0;local viewport={Width=760,Height=900,ClientWidth=760,ClientHeight=900,ScrollWidth=760,ScrollHeight=900,ScrollX=0,ScrollY=0}
	function page:GeometryViewport()return viewport end
	function page:HasPendingLayout()return false end
	local function arrange(targets)
		layoutCalls+=1
		tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
		viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true;local needed,targets=realm:Flush();if needed then arrange(targets)end;flushing=false
	end
	arrange();root:SetAttribute("Status","ready")
	local services={Clock=function()return 0 end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	local diagnostics={};realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	local function settle()
		for _=1,16 do page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks();if not realm:HasPending()and tasks==0 then break end end
		page:FlushScriptLayout();assert(#diagnostics==0,table.concat(diagnostics," | "));assert(#messages==0,table.concat(messages," | "))
	end
	local function run(code)realm:Run(code);settle()end
	local function node(id)return assert(Node.findById(document,id),id)end
	local outside=model:Resolve(node("outside"));local outsideGui=outside.Item.Gui;local afterBox=tree.NodeBoxes[node("after")]
	local note=model:Resolve(node("note"));local noteGui=note.Item.Gui
	local function stable()
		assert(model:Resolve(node("outside"))==outside and outside.Item.Gui==outsideGui and not outsideGui.Destroyed,"Component update recreated unrelated native input")
		assert(tree.NodeBoxes[node("after")]==afterBox,"Component update recreated following layout block")
	end
	run([=[
	const check=(value,message)=>{if(!value)throw new Error(message);};
	const host=document.getElementById('host'),one=document.getElementById('one'),two=document.getElementById('two');
	document.getElementById('note').value='edited';
	const shadow=host.attachShadow({mode:'open'});
	shadow.innerHTML='<style>:host(.raised) { padding: 10px; background: #ddeeff; } :host(.raised) > .inside { color: #00aa00; } .inside { display: block; color: #123456; } #main,#alt { display: block; } slot::slotted(.named) { color: #aa3300; }</style><div id="surface" class="inside">Shadow content.</div><div id="main"><slot id="main-slot" name="main"><span id="fallback-main">Main fallback.</span></slot></div><div id="alt"><slot name="alt"><span>Alt fallback.</span></slot></div>';
	check(shadow.querySelector('#main-slot').assignedElements()[0]===one,'main assignment');
	]=])
	stable();local shadow=realm.VM.Global.Bindings.shadow.Value.DOMNode;local surface=assert(Node.findById(shadow,"surface"));local main=assert(Node.findById(shadow,"main"));local alt=assert(Node.findById(shadow,"alt"))
	local surfaceBox=assert(tree.NodeBoxes[surface],"Attached shadow subtree was not rendered")
	assert(surfaceBox.Style.Color==Color3.fromRGB(18,52,86),"Document .inside selector escaped into shadow root")
	assert(tree.NodeStyles[node("one")].Color==Color3.fromRGB(170,51,0),"Qualified ::slotted selector did not match assigned light child")
	assert(model:Resolve(node("note"))==note and note.Item.Gui==noteGui and note.Value=="edited"and not noteGui.Destroyed,"Attaching a shadow with matching slot lost the existing native input")
	assert(tree.NodeBoxes[node("one")].Gui.Parent==tree.NodeBoxes[main].Gui and tree.NodeBoxes[node("two")].Gui.Parent==tree.NodeBoxes[alt].Gui,"Assigned nodes did not move into flat render parents")
	run("host.classList.add('raised');")
	stable();assert(surfaceBox.Style.Color==Color3.fromRGB(0,170,0)and tree.NodeBoxes[node("host")].Style.Padding[1]==10,"Host compound/direct descendant rules were not recascaded")
	local heightBefore=surfaceBox.OuterHeight
	run("shadow.querySelector('#surface').textContent='A much longer shadow text that wraps onto several lines at this constrained width. '.repeat(6);")
	stable();assert(tree.NodeBoxes[surface]==surfaceBox and surfaceBox.OuterHeight>heightBefore,"Shadow text mutation did not reflow retained box")
	run("const inserted=document.createElement('div');inserted.id='dynamic-shadow';inserted.className='inside';inserted.textContent='Dynamic shadow child';shadow.append(inserted);")
	stable();local inserted=realm.VM.Global.Bindings.inserted.Value.DOMNode;local insertedBox=assert(tree.NodeBoxes[inserted],"Dynamic shadow structural insertion was not rendered")
	assert(insertedBox.Style.Color==Color3.fromRGB(0,170,0),"Dynamic shadow child missed host descendant selector")
	run("one.slot='alt';two.slot='main';")
	stable();assert(tree.NodeBoxes[node("one")].Gui.Parent==tree.NodeBoxes[alt].Gui and tree.NodeBoxes[node("two")].Gui.Parent==tree.NodeBoxes[main].Gui,"Changing slot attributes did not redistribute retained GUI parents")
	assert(model:Resolve(node("note"))==note and note.Item.Gui==noteGui and note.Value=="edited","Slot swap recreated native input state")
	run("two.remove();")
	stable();local fallback=assert(Node.findById(shadow,"fallback-main"));local fallbackText=false
	for _,item in tree.TextItems do if item.Text and item.Text:find("fallback",1,true)then fallbackText=true end end
	assert(fallbackText,"Empty slot did not display fallback text")
	run("shadow.querySelector('#main-slot').name='alt';")
	stable();assert(tree.NodeBoxes[node("one")].Gui.Parent==tree.NodeBoxes[main].Gui,"Renaming the first matching slot did not move the assigned node")
	run([=[
	const sheet=new CSSStyleSheet();sheet.replaceSync('.inside { color: #112233 !important; }');shadow.adoptedStyleSheets=[sheet];
	]=])
	stable();assert(surfaceBox.Style.Color==Color3.fromRGB(17,34,51)and insertedBox.Style.Color==Color3.fromRGB(17,34,51),"Adopted shadow stylesheet was not projected into its root")
	run("sheet.cssRules[0].style.setProperty('color','#445566','important');")
	stable();assert(surfaceBox.Style.Color==Color3.fromRGB(68,85,102),"Shared adopted sheet rule edit did not recascade shadow renderer")
	run([=[
	globalThis.connections=0;
	class NotesPanel extends HTMLElement {
	 constructor(){super();this.attachShadow({mode:'open'}).innerHTML='<style>:host { display: block; padding: 8px; } input { width: 160px; }</style><input id="local" value="Start"><slot></slot>';}
	 connectedCallback(){connections++;}
	}
	customElements.define('notes-panel',NotesPanel);
	const panel=document.createElement('notes-panel');panel.id='panel';document.getElementById('mount').append(panel);
	const local=panel.shadowRoot.querySelector('input');local.value='Kept';check(connections===1,'connected callback');
	]=])
	stable();local panel=realm.VM.Global.Bindings.panel.Value.DOMNode;local localNode=realm.VM.Global.Bindings["local"].Value.DOMNode;local localControl=assert(model:Resolve(localNode),"CE-created input was not rendered")
	local localGui=localControl.Item.Gui;assert(localControl.Value=="Kept","CE-created input value write before first render was lost")
	run("panel.shadowRoot.append(document.createTextNode(' More content.'));panel.setAttribute('data-state','updated');")
	stable();assert(model:Resolve(localNode)==localControl and localControl.Item.Gui==localGui and localControl.Value=="Kept","CE shadow update recreated its input")
	run("inserted.remove();")
	stable();assert(not tree.NodeBoxes[inserted]and insertedBox.Gui.Destroyed,"Removed shadow box resources were not released")
	run([=[
	const propertyStyle=document.createElement('style');propertyStyle.textContent='@property --component-width {syntax:"<length>";inherits:false;initial-value:31px}';shadow.append(propertyStyle);
	const externalTyped=document.createElement('div');externalTyped.id='external-typed';externalTyped.textContent='Document typed width';externalTyped.style.width='var(--component-width)';document.body.append(externalTyped);
	const docProperties=document.createElement('style');docProperties.textContent='@property --doc-width {syntax:"<length>";inherits:false;initial-value:37px}';document.head.append(docProperties);
	shadow.querySelector('#surface').style.width='var(--doc-width)';
	]=])
	stable();local typed=node('external-typed');local typedBox=assert(tree.NodeBoxes[typed]);assert(typedBox.Style.Width.Value==31 and surfaceBox.Style.Width.Value==37,'@property registrations must apply document-wide across shadow boundaries')
	run("propertyStyle.textContent='@property --component-width {syntax:\"<length>\";inherits:false;initial-value:45px}';")
	stable();assert(tree.NodeBoxes[typed]==typedBox and typedBox.Style.Width.Value==45,'Changed shadow registration did not recompute document custom-property defaults')
	run("propertyStyle.remove();")
	stable();assert(typedBox.Style.Width==nil,'Removing a shadow registration left document typed defaults behind')
	run([=[
	const scopeMount=document.createElement('section');scopeMount.innerHTML='<style>@scope { .scoped {color:blue} }</style><p id="scope-inside" class="scoped">Inside</p>';document.body.append(scopeMount);
	const scopeOutside=document.createElement('p');scopeOutside.id='scope-outside';scopeOutside.className='scoped';scopeOutside.textContent='Outside';document.body.append(scopeOutside);
	const scopeStyle=scopeMount.querySelector('style');scopeStyle.sheet.cssRules[0].cssRules[0].style.color='green';
	const layerStyle=document.createElement('style');layerStyle.textContent='@layer before,after;@layer before {#external-typed {color:red!important}} @layer after {#external-typed {color:blue!important}}';document.head.append(layerStyle);
	]=])
	stable();assert(tree.NodeStyles[node('scope-inside')].Color==Color3.fromRGB(0,128,0)and tree.NodeStyles[node('scope-outside')].Color~=Color3.fromRGB(0,128,0),'CSSOM edit lost the implicit @scope stylesheet owner')
	assert(typedBox.Style.Color==Color3.fromRGB(255,0,0),'Mounted important layer order was not applied')
	run("layerStyle.sheet.cssRules[1].cssRules[0].style.setProperty('color','#112233','important');")
	stable();assert(typedBox.Style.Color==Color3.fromRGB(17,34,51),'Dynamic layered rule declarations did not repaint retained native box')
	run([=[
	const partStyle=document.createElement('style');partStyle.textContent='#part-host::part(label){color:green}#part-host::part(label strong){background:#ddeedd}#part-host::part(locked){color:red!important}#part-host::part(forwarded){color:blue}#part-host::part(label)::before{content:"External "}';document.head.append(partStyle);
	const partHost=document.createElement('div');partHost.id='part-host';document.getElementById('mount').classList.add('theme');document.getElementById('mount').append(partHost);
	const partRoot=partHost.attachShadow({mode:'open'});partRoot.innerHTML='<style>:host-context(.theme){padding:7px}:host-context(.theme) > .label{border:3px solid red}#part-label{color:red}#part-locked{color:blue!important}</style><div id="part-label" class="label" part="label strong">Label</div><div id="part-locked" part="locked">Locked</div><div id="part-inner" exportparts="local:forwarded"></div>';
	const nestedHost=partRoot.querySelector('#part-inner');const nestedRoot=nestedHost.attachShadow({mode:'open'});nestedRoot.innerHTML='<style>span{color:#663300}</style><span id="part-local" part="local">Forwarded</span>';
	const slottedStyle=document.createElement('style');slottedStyle.textContent='slot[name="alt"]::slotted(.named){color:blue}::slotted(.named){color:red}::slotted(.named)::before{content:"Slotted "}';shadow.append(slottedStyle);
	]=])
	stable();local partRoot=realm.VM.Global.Bindings.partRoot.Value.DOMNode;local nestedRoot=realm.VM.Global.Bindings.nestedRoot.Value.DOMNode
	local partLabel=assert(Node.findById(partRoot,'part-label'));local partLocked=assert(Node.findById(partRoot,'part-locked'));local partLocal=assert(Node.findById(nestedRoot,'part-local'))
	assert(tree.NodeStyles[partLabel].Color==Color3.fromRGB(0,128,0)and tree.NodeStyles[partLabel].Background==Color3.fromRGB(221,238,221),'External part normal/multi-name selectors must override inner normal styles: '..tostring(tree.NodeStyles[partLabel].Color)..' background '..tostring(tree.NodeStyles[partLabel].Background))
	assert(tree.NodeStyles[partLocked].Color==Color3.fromRGB(0,0,255),'Inner important part declarations must outrank external important declarations')
	assert(tree.NodeStyles[partLocal].Color==Color3.fromRGB(0,0,255),'Nested exportparts alias did not expose the inner part')
	assert(tree.NodeStyles[node('part-host')].Padding[1]==7 and tree.NodeStyles[partLabel].BorderWidth==3,'Host-context must match shadow-including host ancestry and direct shadow descendants')
	assert(tree.NodeStyles[node('one')].Color==Color3.fromRGB(0,0,255),'Qualified slot selector specificity must precede later unqualified slotted selector')
	local externalBefore,slottedBefore=false,false
	local observed={};for _,item in tree.TextItems do if item.Text then table.insert(observed,item.Text);if item.Text:find('External',1,true)then externalBefore=true elseif item.Text:find('Slotted',1,true)then slottedBefore=true end end end
	assert(externalBefore and slottedBefore,'Tree-abiding pseudo-elements after ::part/::slotted were not rendered: '..table.concat(observed,'|'))
	run("partRoot.querySelector('#part-label').style.color='purple';partHost.style.setProperty('color','red','important');const hostImportant=document.createElement('style');hostImportant.textContent=':host{color:blue!important}';partRoot.append(hostImportant);")
	stable();assert(tree.NodeStyles[partLabel].Color==Color3.fromRGB(0,128,0),'Outer part normal declarations must outrank inner inline normal styles')
	assert(tree.NodeStyles[node('part-host')].Color==Color3.fromRGB(0,0,255),'Inner host important declarations must outrank outer host inline important style')
	run("partRoot.querySelector('#part-label').setAttribute('part','other');nestedHost.removeAttribute('exportparts');document.getElementById('mount').classList.remove('theme');")
	stable();assert(tree.NodeStyles[partLabel].Color==Color3.fromRGB(128,0,128)and tree.NodeStyles[partLocal].Color==Color3.fromRGB(102,51,0),'Removing part exposure must stop external declarations while retaining inner inline styles')
	assert(tree.NodeStyles[node('part-host')].Padding[1]==0 and tree.NodeStyles[partLabel].BorderStyle=='none','Host-context ancestor mutation did not recascade host and shadow descendants')
	run([=[
	const list=document.createElement('ol');list.id='live-list';list.start=5;list.innerHTML='<li id="live-a">A</li><li id="live-b">B</li><li id="live-c">C</li>';document.body.append(list);
	const listStyle=document.createElement('style');listStyle.textContent='#live-list li::marker{content:counters(list-item,".")". "}';document.head.append(listStyle);
	]=])
	local function marker(id)return assert(tree.NodeBoxes[node(id)].Marker,id)end
	stable();assert(marker('live-a').CustomText=='5. 'and marker('live-c').CustomText=='7. ','Initial list hints did not feed generated marker content')
	run("list.start=10;document.getElementById('live-b').value=30;")
	stable();assert(marker('live-a').CustomText=='10. 'and marker('live-b').CustomText=='30. 'and marker('live-c').CustomText=='31. ','Live start/value changes did not refresh following markers')
	run("list.reversed=true;")
	stable();assert(marker('live-a').CustomText=='10. 'and marker('live-c').CustomText=='29. ','Live reversed did not change the implicit increment direction')
	run("list.removeAttribute('start');document.getElementById('live-b').removeAttribute('value');const addedItem=document.createElement('li');addedItem.id='live-added';addedItem.textContent='Added';list.append(addedItem);")
	stable();assert(marker('live-a').CustomText=='4. 'and marker('live-added').CustomText=='1. ','Automatic reversed start must recompute after structural changes')
	run("document.getElementById('live-b').style.display='none';")
	stable();assert(marker('live-a').CustomText=='3. 'and marker('live-c').CustomText=='2. ','Hidden list item must not alter the automatic reversed count')
	run([=[
	const adoptedHost=document.createElement('x-adopted');adoptedHost.id='adopted-host';adoptedHost.innerHTML='<strong slot="title">Adopted title</strong><input id="adopted-note" slot="note" value="kept">';document.body.append(adoptedHost);
	const adoptedRoot=adoptedHost.attachShadow({mode:'open'});adoptedRoot.innerHTML='<h3 class="heading"><slot name="title"></slot></h3><div class="inside"><slot name="note"></slot></div>';
	const adoptedSheet=new CSSStyleSheet();adoptedSheet.replaceSync(':host{display:block;background:#edf2e8;padding:14px}:host([tone="warm"]){background:#f6e6d8}.heading{color:green}slot[name="title"]::slotted(strong){color:blue}slot[name="note"]::slotted(input){width:100%;min-width:0}.inside{padding:3px}');
	check(adoptedSheet.cssRules.length===6,'all constructed host/slotted rules retained');adoptedRoot.adoptedStyleSheets=[adoptedSheet];
	]=])
	stable();local adoptedHost=node('adopted-host');local adoptedBox=assert(tree.NodeBoxes[adoptedHost]);local adoptedNote=model:Resolve(node('adopted-note'));local adoptedNoteGui=adoptedNote.Item.Gui
	assert(adoptedBox.Style.Background and adoptedBox.Style.Background==Color3.fromRGB(237,242,232)and adoptedBox.Style.Padding[1]==14,'Constructed :host rules must paint an adopted block host')
	run("document.getElementById('adopted-note').value='edited adopted';adoptedHost.setAttribute('tone','warm');")
	stable();assert(adoptedBox.Style.Background and adoptedBox.Style.Background==Color3.fromRGB(246,230,216),'Adopted host attribute change must recascade actual box paint')
	assert(model:Resolve(node('adopted-note'))==adoptedNote and adoptedNote.Item.Gui==adoptedNoteGui and adoptedNote.Value=='edited adopted','Adopted host recascade must retain slotted native input state')
	run([=[
	class MountedField extends HTMLElement {
	 static formAssociated=true;
	 constructor(){super();this.internals=this.attachInternals();const r=this.attachShadow({mode:'open'});r.innerHTML='<style>:host{display:block;border:2px solid #345678;padding:6px}:host(:state(\\65 dited)){background:#ddeeff}:host(:state(\\e9 clair)){border-color:rgb(17,53,91)}:host(:invalid){border-color:#cc3300}input{width:100%}</style><div id="nested-editor"></div><slot></slot>';this.nested=r.getElementById('nested-editor').attachShadow({mode:'open'});this.nested.innerHTML='<style>input{width:100%;min-width:0}</style><input id="face-editor" value="seed"><slot></slot>';this.editor=this.nested.querySelector('input');this.internals.setFormValue('seed');}
	 formDisabledCallback(v){this.editor.disabled=v;}
	 formResetCallback(){this.editor.value='seed';this.internals.setFormValue('seed');this.internals.setValidity({});this.internals.states.clear();}
	}
	customElements.define('mounted-field',MountedField);
	const faceForm=document.createElement('form');faceForm.id='face-form';faceForm.innerHTML='<fieldset id="face-fieldset"><label for="face-host">Nested note</label><mounted-field id="face-host" name="note"></mounted-field></fieldset>';document.getElementById('mount').append(faceForm);
	const face=document.getElementById('face-host');face.editor.value='edited';face.internals.setFormValue('edited');face.internals.states.add('edited');
	check(new FormData(faceForm).get('note')==='edited','FACE successful value');
	]=])
	stable();local faceNode=node('face-host');local faceBox=assert(tree.NodeBoxes[faceNode]);local faceRoot=faceNode.InternalShadowRoot
	local nestedEditor=assert(Node.findById(faceRoot,'nested-editor'));local editorNode=assert(Node.findById(nestedEditor.InternalShadowRoot,'face-editor'))
	local editorControl=assert(model:Resolve(editorNode));local editorGui=editorControl.Item.Gui
	assert(editorControl.Value=='edited'and faceBox.Style.Background==Color3.fromRGB(221,238,255),'FACE state selector must repaint the mounted custom host and retain nested native edit')
	local beforeStateLayout,beforeStateGUI=layoutCalls,#guis
	run("face.editor.setSelectionRange(1,4,'backward');")
	local stateEditor=assert(editorControl.Item.Editor)
	local stateBorder
	for _,item in modifiers do if item.ClassName=='UIStroke'and item.Parent==faceBox.Gui then stateBorder=item;break end end
	assert(stateBorder,'Custom state paint needs the actual retained border modifier')
	run("face.internals.states.add('éclair');check(face.matches(':state(éclair)'),'Unicode state query');")
	stable();assert(faceBox.Style.BorderColor==Color3.fromRGB(17,53,91),'Escaped Unicode :host state must repaint the retained FACE border')
	assert(stateBorder.Color==Color3.fromRGB(17,53,91),'Escaped Unicode :state must paint the native border color')
	run("check(face.editor.selectionStart===1&&face.editor.selectionEnd===4&&face.editor.selectionDirection==='backward','Retained backward state selection');")
	assert(layoutCalls==beforeStateLayout and #guis==beforeStateGUI and tree.NodeBoxes[faceNode]==faceBox and model:Resolve(editorNode)==editorControl and editorControl.Item.Gui==editorGui and editorControl.Item.Editor==stateEditor,'Paint-only custom state mutation must preserve layout, GUI and backward editor selection')
	run("face.internals.states.delete('éclair');")
	run("check(face.editor.selectionStart===1&&face.editor.selectionEnd===4&&face.editor.selectionDirection==='backward','Retained backward state deletion selection');")
	stable();assert(faceBox.Style.BorderColor==Color3.fromRGB(52,86,120)and layoutCalls==beforeStateLayout and #guis==beforeStateGUI and editorControl.Item.Editor==stateEditor,'Custom state deletion must restore retained paint without layout or editor reset')
	assert(stateBorder.Color==Color3.fromRGB(52,86,120),'Custom state deletion must repaint the original border modifier')
	run("face.internals.setValidity({customError:true},'Enter a note',face.editor);check(!faceForm.checkValidity(),'FACE form validation');")
	stable();assert(faceBox.Style.BorderColor==Color3.fromRGB(204,51,0),'FACE invalid selector must repaint the retained border')
	run("document.getElementById('face-fieldset').disabled=true;check(!face.internals.willValidate&&!new FormData(faceForm).has('note'),'disabled FACE exclusion');")
	stable();assert(editorControl.Disabled and editorControl.Item.Gui==editorGui and not editorGui.Destroyed,'FACE disabled reaction must paint the same nested native control')
	run("document.getElementById('face-fieldset').disabled=false;faceForm.reset();check(face.internals.validity.valid&&new FormData(faceForm).get('note')==='seed','FACE reset');")
	stable();assert(editorControl.Value=='seed'and not editorControl.Disabled and editorControl.Item.Gui==editorGui,'FACE reset must restore nested native state without replacing GUI')
	run("const faceLegend=document.createElement('legend');faceLegend.id='face-legend';faceLegend.textContent='Editable legend';document.getElementById('face-fieldset').prepend(faceLegend);")
	stable();local fieldsetBox=assert(tree.NodeBoxes[node('face-fieldset')]);local legendBox=assert(tree.NodeBoxes[node('face-legend')]);assert(fieldsetBox.Legend==legendBox and fieldsetBox.LegendGap,'Dynamic legend insertion must use the ordinary retained fieldset layout and border gap')
	run("faceLegend.remove();")
	stable();assert(fieldsetBox.Legend==nil and fieldsetBox.LegendGap==nil and model:Resolve(editorNode)==editorControl and editorControl.Item.Gui==editorGui,'Removing a legend must clear the fieldset border gap without replacing its native editor')
	viewport.Width,viewport.ClientWidth=320,320;arrange();settle()
	assert(tree.NodeBoxes[faceNode]==faceBox and model:Resolve(editorNode)==editorControl and editorControl.Item.Gui==editorGui,'Narrow resize recreated the FACE/native editor')
	for _,cleanup in page.Cleanups do cleanup()end;model:Destroy();events:Destroy()
	print("JavaScript components rendering: attach/flat ownership, slot updates/fallback, scoped/adopted host styles, text/structure, custom-element inputs, global typed registration, CSSOM scope/layers and resource retention passed")
end
