--!strict
-- Exercise the mounted native TextBox/controller, including property signals.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller)
	local function signal()
		local entries={};local s={}
		function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function s:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		function s:Count()local count=0;for _,entry in entries do if entry[1].Connected then count+=1 end end;return count end
		return s
	end
	local focused;local guis={};local deferred={};local deferredNativeFocus=false;local nativeFocusCalls=0
	local factory={}
	function factory.create(class,parent,props)
		local changes,attributes={},{ }
		local values={Parent=parent,ClassName=class,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(520,500),Text="",CursorPosition=-1,SelectionStart=-1}
		for key,value in props do values[key]=value end
		if class=="ScrollingFrame"then values.CanvasPosition=Vector2.new(0,0)end
		local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)local old=values[key];values[key]=value;if old~=value and changes[key]then changes[key]:Fire()end end})
		values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
		function values:GetPropertyChangedSignal(key)if not changes[key]then changes[key]=signal()end;return changes[key]end
		function values:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function values:SetAttribute(key,value)attributes[key]=value;if changes["attribute:"..key]then changes["attribute:"..key]:Fire()end end
		function values:GetAttribute(key)return attributes[key]end
		function values:IsA(kind)return kind==class or kind=="GuiObject"end
		function values:IsFocused()return focused==gui end
		function values:CaptureFocus()
			nativeFocusCalls+=1;assert(nativeFocusCalls<100,'Native focus entered a recapture loop')
			if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1
			if deferredNativeFocus then table.insert(deferred,function()self.Focused:Fire()end)else self.Focused:Fire()end
		end
		function values:ReleaseFocus()
			if focused==gui then
				nativeFocusCalls+=1;assert(nativeFocusCalls<100,'Native focus entered a release loop')
				focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1
				if deferredNativeFocus then table.insert(deferred,function()self.FocusLost:Fire(false)end)else self.FocusLost:Fire(false)end
			end
		end
		function values:Destroy()assert(not values.Destroyed);values.Destroyed=true;for _,child in guis do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides)
	local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument('<html><body><form id="f"><div id="container"><input id="i" value="Aä😀Z" style="caret-color:red"><textarea id="t" style="box-sizing:border-box;width:140px!important;width:150px!important;height:70px;max-width:220px;color:#123456;--keep:100px">first\nsecond</textarea><input id="email" type="email" value="a@example.test"><input id="number" type="number" value="123"></div><p id="after">Unchanged text below.</p><div id="blank" style="width:120px;height:50px"></div><div id="nonselectable" style="user-select:none">Preserve selection.</div><button type="button" id="button">Button</button><input type="radio" id="radio"><a id="link" href="#after">Link</a><input id="date" type="date" value="2026-10-08"><details><summary id="summary">Summary</summary><p>Detail</p></details></form><script>globalThis.boot=1;</script></body></html>')
	local messages={};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end)
	local arrangements,requests=0,0
	local function arrange(width,items)arrangements+=1;tree:SetMediaEnvironment(width,500);tree.ViewportHeight=500;Dirty.begin(tree,items);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)end
	arrange(520)
	local page={Alive=true,Document=document,DocumentURL="https://example.test/selection",BaseURL="https://example.test/selection",Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:HasPendingLayout()return false end
	function page:GeometryViewport()return {Width=520,Height=500,ClientWidth=520,ClientHeight=500,ScrollWidth=520,ScrollHeight=500,ScrollX=0,ScrollY=0} end
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return focused end
	function input:IsKeyDown()return false end
	local hitObjects={}
	local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return hitObjects end},Factory=factory,Clock=function()return 0 end,
		RunService={RenderStepped=signal()},Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	Controller.start(page,tree,function()requests+=1 end,error,services)
	local diagnostics={};local realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services})
	local function healthy()assert(#diagnostics==0,table.concat(diagnostics," | "));assert(#messages==0,table.concat(messages," | "))end
	local function run(source)realm:Run(source);healthy()end
	local function settle()
		for _=1,16 do
			local work=deferred;deferred={};for _,fn in work do fn()end
			local tasks=realm:PumpTasks()
			if #deferred==0 and tasks==0 then break end
		end
		healthy()
	end
	local function flush()local needed,items=realm:Flush();if needed then arrange(520,items)end;settle();return needed end
	flush()
	local node=Node.findById(document,"i");local c=page.FormModel:Resolve(node);local editor=c.Item.Editor
	local after=tree.NodeBoxes[Node.findById(document,"after")].Gui
	run("const i=document.getElementById('i');i.focus();i.setSelectionRange(1,4,'backward');globalThis.selectEvents=0;globalThis.selectionEvents=0;i.addEventListener('select',()=>selectEvents++);i.addEventListener('selectionchange',()=>selectionEvents++);")
	settle()
	assert(editor.CursorPosition==2 and editor.SelectionStart==8 and focused==editor,"Script UTF16 positions paint the actual native UTF8 selection")
	assert(editor:GetPropertyChangedSignal("CursorPosition"):Count()==1 and editor:GetPropertyChangedSignal("SelectionStart"):Count()==1,"Each native selection signal binds once")
	local before=arrangements;local beforeRequests=requests
	run("i.setSelectionRange(2,4,'forward');")
	settle();assert(not realm:HasPending() and not flush() and arrangements==before and requests==beforeRequests,"Pure selection does not dirty or arrange layout")
	assert(editor.CursorPosition==8 and editor.SelectionStart==4)
	for _,width in {240,640}do arrange(width);assert(c.Item.Editor==editor and editor.CursorPosition==8 and editor.SelectionStart==4,"Resize retains native editor and selection")end
	run("selectEvents=0;selectionEvents=0;")
	-- A native action writes its cursor and anchor separately, with one event pair.
	editor.CursorPosition=4;editor.SelectionStart=2
	assert(#deferred==1,"Property notifications coalesce instead of installing a permanent frame loop")
	settle()
	run("if(i.selectionStart!==1||i.selectionEnd!==2||i.selectionDirection!=='forward'||selectEvents!==1||selectionEvents!==1)throw new Error('native selection state');globalThis.inputSelection='';i.addEventListener('input',()=>{inputSelection=i.selectionStart+':'+i.selectionEnd;});")
	-- Native editing supplies the final cursor synchronously to input handlers.
	editor.CursorPosition=5;editor.SelectionStart=-1;editor.Text="AäYZ"
	settle()
	assert(c.Value=="AäYZ" and realm.VM.Global.Bindings.inputSelection.Value=="3:3","Input listeners read the already-updated selection and value")
	run("i.value='Aä😀Z';i.setSelectionRange(1,4,'backward');i.blur();")
	settle();assert(c.SelectionStart==1 and c.SelectionEnd==4 and c.SelectionDirection=="backward" and focused==nil,"Native blur preserves DOM selection")
	run("i.focus();")
	settle();assert(editor.CursorPosition==2 and editor.SelectionStart==8,"Refocusing restores a remembered DOM selection")
	-- Roblox can deliver native focus signals after another control has already
	-- acquired focus. A stale Focused/FocusLost pair must not recapture editors.
	local otherEditor=page.FormModel:Resolve(Node.findById(document,'t')).Item.Editor
	local capturesBefore=nativeFocusCalls;deferredNativeFocus=true
	editor:ReleaseFocus();otherEditor:CaptureFocus();editor:CaptureFocus()
	settle();assert(#deferred==0,'Delayed focus and cursor notifications converge')
	assert(focused==editor and page.FormModel.Focused==c,'Delayed notifications preserve the actual final native focus')
	assert(nativeFocusCalls==capturesBefore+4,'Stale focus events add no native release or capture calls')
	deferredNativeFocus=false
	run("i.remove();");flush()
	assert(editor.Destroyed and editor:GetPropertyChangedSignal("Text"):Count()==0 and editor:GetPropertyChangedSignal("CursorPosition"):Count()==0 and editor:GetPropertyChangedSignal("SelectionStart"):Count()==0,"Detached native editors release all input/selection connections")
	run("i.setSelectionRange(2,4,'forward');document.getElementById('container').appendChild(i);");flush()
	c=page.FormModel:Resolve(node);editor=c.Item.Editor
	assert(c.SelectionStart==2 and c.SelectionEnd==4 and c.SelectionDirection=="forward" and after==tree.NodeBoxes[Node.findById(document,"after")].Gui,"Detached JS selection survives native record recreation without rebuilding unrelated boxes")
	run("i.focus();")
	settle();assert(editor.CursorPosition==8 and editor.SelectionStart==4)
	assert(editor:GetPropertyChangedSignal("CursorPosition"):Count()==1 and editor:GetPropertyChangedSignal("SelectionStart"):Count()==1)
	run("i.setRangeText('X',2,3,'select');")
	settle();assert(c.Value~=editor.Text and editor.Text=="AäX�Z" and c.SelectionStart==2 and c.SelectionEnd==3,"A lone UTF16 unit remains exact in JS and projects safely as a replacement glyph to native text")
	run("i.readOnly=true;");settle();assert(c.ReadOnly)
	editor.Text="denied";settle()
	assert(editor.Text=="AäX�Z"and c.Value~=editor.Text,"A blocked native edit restores the safe native presentation while preserving the exact DOM value")
	for _,id in {"email","number"}do
		run("globalThis.extra=document.getElementById('"..id.."');extra.focus();extra.select();if(extra.selectionStart!==null||extra.selectionEnd!==null||extra.selectionDirection!==null)throw new Error('UI-only selection getters');")
		settle();local extra=page.FormModel:Resolve(Node.findById(document,id));local box=extra.Item.Editor
		assert(box.CursorPosition==#box.Text+1 and box.SelectionStart==1,"select() selects the email/number editor while range getters remain null")
	end
	local numeric=page.FormModel:Resolve(Node.findById(document,"number"));local numericBox=numeric.Item.Editor
	numericBox.CursorPosition=4;numericBox.SelectionStart=-1;numericBox.Text="12e";settle()
	assert(numeric.Value==""and numeric.EditText=="12e","The number UI retains invalid in-progress text separately from its value")
	run("extra.select();");settle()
	assert(numericBox.CursorPosition==4 and numericBox.SelectionStart==1,"Number select() operates on the actual editable text, including an incomplete numeric value")
	-- Native resize is an actual style-attribute mutation, visible to script
	-- and observers before a subsequent focus recascade can read the dimensions.
	run("globalThis.nativeArea=document.getElementById('t');globalThis.resizeRecords=[];globalThis.resizeInputEvents=0;globalThis.resizeOriginalCSS=nativeArea.getAttribute('style');nativeArea.addEventListener('input',()=>resizeInputEvents++);nativeArea.addEventListener('change',()=>resizeInputEvents++);globalThis.resizeObserver=new MutationObserver(records=>{for(const record of records)resizeRecords.push({name:record.attributeName,old:record.oldValue});});resizeObserver.observe(nativeArea,{attributes:true,attributeFilter:['style'],attributeOldValue:true});nativeArea.focus();")
	settle()
	local area=page.FormModel:Resolve(Node.findById(document,"t"));local areaItem=area.Item;local areaEditor=areaItem.Editor
	assert(areaItem.BoxWidth==150 and areaItem.BoxHeight==70)
	areaItem.BoxGui.AbsoluteSize=Vector2.new(areaItem.BoxWidth,areaItem.BoxHeight)
	hitObjects={areaItem.ResizeGrip}
	local resizePress={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(144,64)}
	input.InputBegan:Fire(resizePress,false)
	assert(not area.Focused and focused~=areaEditor,"Native grip interaction blurs its editor")
	local resizeRequests=requests
	input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(194,94)})
	assert(requests==resizeRequests+1,"Native resize requests one layout for the changed dimensions")
	arrange(520,{[areaItem]=true})
	resizePress.Position=Vector2.new(194,94);input.InputEnded:Fire(resizePress);hitObjects={}
	flush()
	assert(area.Item==areaItem and areaItem.Editor==areaEditor and areaItem.BoxWidth==200 and areaItem.BoxHeight==100,"Resize retains the mounted editor and updates its box")
	run("if(nativeArea.style.width!=='200px'||nativeArea.style.height!=='100px'||nativeArea.style.maxWidth!=='220px'||nativeArea.style.color!=='rgb(18, 52, 86)'||nativeArea.style.getPropertyValue('--keep')!=='100px'||nativeArea.style.getPropertyPriority('width')!=='')throw new Error('native resize CSS reflection');if(resizeRecords.length!==1||resizeRecords[0].name!=='style'||resizeRecords[0].old!==resizeOriginalCSS||resizeInputEvents!==0)throw new Error('native resize mutation delivery');if(getComputedStyle(nativeArea).width!=='200px'||getComputedStyle(nativeArea).height!=='100px')throw new Error('native resize used dimensions');")
	local resizeArrangements,refocusRequests=arrangements,requests
	run("nativeArea.focus();nativeArea.blur();nativeArea.focus();")
	settle()
	assert(not flush() and arrangements==resizeArrangements and requests==refocusRequests
		and areaItem.BoxWidth==200 and areaItem.BoxHeight==100 and areaItem.Editor==areaEditor,"Focus/blur recascades preserve resized dimensions without another layout")
	run("resizeObserver.disconnect();")
	-- Actual document selection + native pointer events: a blank hit supplies a
	-- collapsed DOM boundary instead of an absent hit which restores the range.
	run("globalThis.sample=document.getElementById('after');globalThis.selectionChanges=0;document.addEventListener('selectionchange',()=>selectionChanges++);globalThis.selectSample=()=>{const r=document.createRange();r.selectNodeContents(sample);const s=getSelection();s.removeAllRanges();s.addRange(r);};")
	run("document.getElementById('summary').addEventListener('click',e=>e.preventDefault());")
	local selectionRequests,selectionLayouts=requests,arrangements
	local sourceGui=after
	local function click(gui,kind)
		hitObjects={gui}
		local event={UserInputType=kind or Enum.UserInputType.MouseButton1,Position=Vector2.new(15,15)}
		input.InputBegan:Fire(event,false);input.InputEnded:Fire(event);hitObjects={};settle()
	end
	local function selectSample()
		run("selectSample();");settle()
		assert(next(tree.TextSelection.Overlays),'A script-selected document range is visibly painted')
	end
	local blankNode=Node.findById(document,'blank')
	selectSample();run("selectionChanges=0;");click(tree.NodeBoxes[blankNode].Gui)
	run("if(String(getSelection())!==''||!getSelection().isCollapsed||getSelection().rangeCount!==1||getSelection().anchorNode!==document.getElementById('blank'))throw new Error('blank click collapses selection');")
	run("if(selectionChanges!==1)throw new Error('blank collapse delivers one selectionchange');")
	assert(not next(tree.TextSelection.Overlays)and not next(tree.TextSelection.Gaps),'Blank click removes every selection overlay')
	for _,id in {'i','t','email','number','date'}do
		selectSample()
		local item=page.FormModel:Resolve(Node.findById(document,id)).Item
		click(item.Editor or item.BoxGui)
		run("if(!getSelection().isCollapsed||getSelection().rangeCount!==1||getSelection().getRangeAt(0).toString()!==''||getSelection().anchorNode!==document.getElementById('"..id.."').parentNode)throw new Error('field click collapses document range: "..id.."');")
		assert(not next(tree.TextSelection.Overlays)and item.Control.Focused and (not item.Editor or focused==item.Editor),'Editable-field click clears document highlight and focuses the retained control')
	end
	selectSample();click(tree.NodeBoxes[Node.findById(document,'summary')].Gui)
	run("if(!getSelection().isCollapsed||getSelection().rangeCount!==1)throw new Error('summary click collapses range');")
	selectSample();click(root)
	run("if(!getSelection().isCollapsed||getSelection().rangeCount!==1||getSelection().anchorNode!==document.body)throw new Error('viewport click collapses range');")
	selectSample();click(tree.NodeBoxes[blankNode].Gui,Enum.UserInputType.MouseButton2)
	run("if(getSelection().getRangeAt(0).toString()!==sample.textContent||getSelection().isCollapsed)throw new Error('right click preserves selection');")
	for _,id in {'nonselectable','button','radio','link'}do
		selectSample()
		local element=Node.findById(document,id);local control=page.FormModel:Resolve(element)
		local hitGui=if control then control.Item.BoxGui else tree.NodeBoxes[element]and tree.NodeBoxes[element].Gui
		if not hitGui then for gui,hitNode in tree.HitNodes do if hitNode==element then hitGui=gui;break end end end
		assert(hitGui,'Mounted hit surface: '..id);click(hitGui)
		run("if(getSelection().getRangeAt(0).toString()!==sample.textContent||getSelection().isCollapsed)throw new Error('native non-text control preserves selection: "..id.."');")
	end
	for _,eventType in {'mousedown','pointerdown'}do
		run("globalThis.cancelSelection=e=>e.preventDefault();document.getElementById('blank').addEventListener('"..eventType.."',cancelSelection);")
		selectSample();click(tree.NodeBoxes[blankNode].Gui)
		run("if(getSelection().isCollapsed||getSelection().getRangeAt(0).toString()!==sample.textContent)throw new Error('canceled pointer preserves range');document.getElementById('blank').removeEventListener('"..eventType.."',cancelSelection);")
	end
	selectSample()
	local textItem;for _,item in tree.TextItems do if item.TextOwner==tree.NodeBoxes[Node.findById(document,'after')]then textItem=item;break end end
	assert(textItem)
	click(textItem.TextGui or textItem.Gui)
	run("if(!getSelection().isCollapsed||getSelection().rangeCount!==1)throw new Error('text click collapses range');")
	assert(not next(tree.TextSelection.Overlays)and requests==selectionRequests and arrangements==selectionLayouts and tree.NodeBoxes[Node.findById(document,'after')].Gui==sourceGui,'Pointer selection only changes highlights, without layout or recreating page content')
	assert(services.RunService.RenderStepped:Count()==0,"Selection keeps no idle frame connection")
	for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end
	page.Alive=false
	assert(editor:GetPropertyChangedSignal("Text"):Count()==0 and editor:GetPropertyChangedSignal("CursorPosition"):Count()==0 and editor:GetPropertyChangedSignal("SelectionStart"):Count()==0 and input.InputBegan:Count()==0,"Page disposal releases all native input callbacks")
	local work=deferred;deferred={};for _,fn in work do fn()end
	healthy()
	print("Text-control rendering: native focus/edit/byte selection, resize/mutation reflection, detach/reattach, lone UTF16, document-selection collapse on blank/text/field/date/summary clicks, preserved controls/cancellation, paint-only events and cleanup passed")
end
