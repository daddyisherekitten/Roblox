--!strict
-- Real page renderer/controller and JS realm. The native fixture checks focus,
-- text and isolation; it does not emulate the operating system clipboard.
return function(loadBrowser,loadBinding,fixture,URL,loadHTMLPage,loadRenderTree,loadWordLayout,loadBlockLayout,Controller,HTMLScripts,Node,loadDimensions,loadImages,loadIFrameRuntime)
	-- Complete the runner's deliberately small keyboard Enum for native copy.
	for _,name in {'C','X','V'}do Enum.KeyCode[name]=name end
	local f=fixture();local factory={create=f.Create,modifier=f.Create}
	local renderer=loadRenderTree(factory);local trees={};local diagnostics={}
	local measure={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return Vector2.new((utf8.len(text)or 0)*size*.5,size)end}}
	measure['Layout/WordLayout']=loadWordLayout(measure);local layout=loadBlockLayout(measure)
	local guiService={ReducedMotionEnabled=false,GetPropertyChangedSignal=function()return f.Signal()end}
	local hostGame={GetService=function(_,name)return if name=='UserInputService'then f.Input elseif name=='GuiService'then guiService else nil end}
	local module=loadHTMLPage({
		['Rendering/GuiFactory']=factory,
		['Rendering/RenderTree']={build=function(doc,root,diagnostic)local tree=renderer.build(doc,root,diagnostic,function(font)return font end);trees[doc]=tree;return tree end},
		['Layout/BlockLayout']=layout,['Input/Controller']=Controller,['Rendering/HTMLScripts']=HTMLScripts,
		['Rendering/IFrameRuntime']=loadIFrameRuntime(f.Task),
		['Rendering/ImageDimensions']=loadDimensions({},f.Task),['Rendering/ImageLoad']=loadImages({},f.Task,f.Enum),
	},f.Task,function()return f:Clock()end,hostGame,f)
	local sources={
		copy=[=[<!doctype html><html><head><title>Copy selection</title><style>body{margin:0}p{margin:8px 0;font:16px Arial}#copy{text-transform:uppercase}#editable{caret-animation:manual}</style></head><body><p id="copy">straße Äpfel<br>last</p><input id="field" value="native field"><div id="editable" contenteditable="true">editable text</div><button id="next">Next</button><script>var copyKeys=0,copyUps=0;window.addEventListener('keydown',function(){copyKeys++;});window.addEventListener('keyup',function(){copyUps++;});</script></body></html>]=],
		other='<!doctype html><html><head><title>Other</title></head><body><p id="copy">other page</p><script>var copyKeys=0;window.addEventListener("keydown",function(){copyKeys++;});</script></body></html>',
	}
	local function attribute(text)return text:gsub('&','&amp;'):gsub('"','&quot;'):gsub('<','&lt;'):gsub('>','&gt;')end
	local leaf='<html><body style="margin:0"><p id="copy">nested selection</p><input id="field" value="nested native"><script>var copyKeys=0;window.addEventListener("keydown",function(){copyKeys++;});</script></body></html>'
	local child='<html><body style="margin:0"><p id="copy">child selection</p><input id="field" value="child native"><iframe srcdoc="'..attribute(leaf)..'" width="440" height="200"></iframe><script>var copyKeys=0;window.addEventListener("keydown",function(){copyKeys++;});</script></body></html>'
	sources.frames='<html><body style="margin:0"><iframe srcdoc="'..attribute(child)..'" width="600" height="360"></iframe><script>var copyKeys=0;</script></body></html>'
	local engine={URL=URL,Websites={url=function()return 'https://copy.test/copy/index.html'end}}
	function engine.Websites.resolveURL(base,href)local result=URL.resolve(base,href);result.Name=if result.Path=='/other/index.html'then 'other'elseif result.Path=='/frames/index.html'then 'frames'else 'copy';result.Kind='internal';return result end
	function engine.Websites.get(name)return {HTML=assert(sources[name]),Options={RenderWorkBudgetMS=0,InputServices={Task=f.Task,Factory=factory},JavaScriptServices={Task=f.Task,Clock=function()return f:Clock()end}}}end
	function engine.mountHTML(target,html,options)return module.mount(target,html,options)end
	local browserServices={Create=f.Create,Input=f.Input,PlayerGui=f.PlayerGui,RunService=f.Run,Task=f.Task}
	local function makeBrowser(name,visible)
		local host=f.Create('Frame',f.Screen,{Name=name,Size=f.UDim2.fromScale(1,1)})
		local browser=loadBrowser(f).mount(host,{AutoOpen=false,PersistenceEnabled=false,Visible=visible,Focused=visible,ExternalBaseURL='https://copy.test/copy/index.html',ResolveExternal=function(url,base)return {URL=URL.resolve(if base and base:match('^https?://')then base else 'https://copy.test/copy/index.html',url).URL,Kind='external'}end,Services=browserServices})
		local binding=loadBinding(f).new(browser,engine,{Services=browserServices,Diagnostic=function(message)table.insert(diagnostics,tostring(message))end})
		if visible==false then binding:SetVisible(false);binding:SetInputActive(false)end
		return browser,binding,host
	end
	local browser,binding,host=makeBrowser('Foreground',true)
	local tab=browser:Open('https://copy.test/copy/index.html');f:Drain()
	local page=assert(binding:GetPage(tab),'Initial HTML mount failed: '..tostring(tab.Error)..' | '..table.concat(diagnostics,' | '));local tree=assert(trees[page.Document])
	local function node(current,id)return assert(Node.findById(current.Document,id),id)end
	local function belongs(child,parent)while child do if child==parent then return true end;child=child.Parent end;return false end
	local function textItems(current,id)
		local target=node(current,id);local list={}
		for _,item in assert(trees[current.Document]).TextItems do
			local selected=false;for _,span in item.SourceSpans or{}do if belongs(span.Node,target)then selected=true;break end end
			if selected and item.Kind~='Space'and item.Gui and item.Gui:IsA('TextLabel')then table.insert(list,item)end
		end
		assert(#list>0,'Missing rendered selectable words for '..id);return list
	end
	local function drag(current,id)
		local words=textItems(current,id);local first,last=words[1].Gui,words[#words].Gui
		local p=first.AbsolutePosition;local q,s=last.AbsolutePosition,last.AbsoluteSize
		f.Input.Mouse=f.Vector2.new(p.X,p.Y+first.AbsoluteSize.Y/2)
		local down=f:Begin(first,nil,f.Input.Mouse.X,f.Input.Mouse.Y)
		f:Hits(last);f.Input.Mouse=f.Vector2.new(q.X+s.X,q.Y+s.Y/2)
		f.Input.InputChanged:Fire(f:Event(f.Enum.UserInputType.MouseMovement,f.Input.Mouse.X,f.Input.Mouse.Y))
		assert(f.Input:GetFocusedTextBox()==nil,'A live mouse drag must not capture native text focus')
		down.Position=f.Input.Mouse;f.Input.InputEnded:Fire(down);f:Drain()
		return assert(f.Input:GetFocusedTextBox(),'Completed page text selection must prepare the native copy field before C arrives')
	end
	local function key(name,ending)
		local code=f.Enum.KeyCode[name]
		f.Input.Keys[code]=if ending then nil else true
		local event=f:Event(f.Enum.UserInputType.Keyboard,0,0,code)
		if ending then f.Input.InputEnded:Fire(event)else f.Input.InputBegan:Fire(event,false)end
		f:Drain();return event
	end
	local function click(object)
		local p,s=object.AbsolutePosition,object.AbsoluteSize
		local down=f:Begin(object,nil,p.X+s.X/2,p.Y+s.Y/2);f.Input.InputEnded:Fire(down);f:Drain()
	end
	assert(page.JavaScriptRuntime:Run("getSelection().selectAllChildren(document.getElementById('copy'));"));f:Drain()
	key('LeftControl');key('C');key('C',true);key('LeftControl',true)
	assert(f.Input:GetFocusedTextBox()==nil,'A programmatic range without a genuine page selection must not capture native focus')
	local original=Node.textContent(node(page,'copy'));local layoutBefore=page.LastLayoutStats;local proxy=drag(page,'copy')
	assert(proxy:IsA('TextBox')and proxy.Text=='straße Äpfel\nlast','Copy must use source case, Unicode and the rendered BR boundary: '..tostring(proxy.Text))
	assert(proxy.TextEditable==false and proxy.ClearTextOnFocus==false and proxy.Active==false and proxy.Selectable==false,'Copy bridge must remain read-only and passive')
	assert(proxy.SelectionStart>0 and proxy.CursorPosition>proxy.SelectionStart,'The complete copy text must be natively selected')
	local before=page.JavaScriptRuntime.Window.Get('copyKeys');local beforeUps=page.JavaScriptRuntime.Window.Get('copyUps')
	key('LeftControl');key('C');key('C',true)
	assert(f.Input:GetFocusedTextBox()==proxy,'Ctrl+C must retain the native selection through shortcut processing')
	assert(page.JavaScriptRuntime.Window.Get('copyKeys')==before+2,'Copy proxy must not swallow document keyboard events')
	assert(Node.textContent(node(page,'copy'))==original,'Copy must not mutate the page source')
	key('LeftControl',true);assert(f.Input:GetFocusedTextBox()==nil,'Modifier release must restore ordinary page focus')
	assert(page.JavaScriptRuntime.Window.Get('copyUps')==beforeUps+2,'Copy proxy must preserve both DOM keyup events through modifier release')
	assert(next(tree.TextSelection.Overlays)~=nil,'Releasing native copy focus must retain the visible HTML selection')
	assert(page.LastLayoutStats==layoutBefore,'Selection and copy must not request another document layout')
	key('LeftMeta');assert(f.Input:GetFocusedTextBox()==proxy,'Cmd must rearm the last genuine selection')
	key('C');key('C',true);key('LeftMeta',true)
	assert(Node.textContent(node(page,'copy'))==original)
	key('C');key('C',true);assert(f.Input:GetFocusedTextBox()==nil,'Plain C must not capture an old selection')
	assert(page.JavaScriptRuntime:Run("var cancelCopyKey=false,canceledCopyKeys=0;window.addEventListener('keydown',function(event){if(cancelCopyKey){canceledCopyKeys++;event.preventDefault();}});"));f:Drain()
	key('LeftControl');assert(f.Input:GetFocusedTextBox()==proxy)
	assert(page.JavaScriptRuntime:Run('cancelCopyKey=true;'));f:Drain()
	key('C')
	assert(f.Input:GetFocusedTextBox()==nil and proxy.Text=='','A canceled DOM copy key must release native focus and erase the copy buffer')
	assert(Node.textContent(node(page,'copy'))==original,'Canceled copying must not mutate source text')
	key('C',true);key('LeftControl',true)
	assert(page.JavaScriptRuntime.Window.Get('canceledCopyKeys')==1,'The actual C keydown must reach the canceling page handler')
	assert(page.JavaScriptRuntime:Run('cancelCopyKey=false;'));f:Drain()
	-- Plain typing, cut and paste never write into ordinary page text.
	for _,name in {'X','V'}do
		key('LeftControl');assert(f.Input:GetFocusedTextBox()==proxy)
		key(name);assert(f.Input:GetFocusedTextBox()==nil,'Non-copy shortcuts must release the proxy')
		key(name,true);key('LeftControl',true)
		assert(Node.textContent(node(page,'copy'))==original,'Ordinary selected page text changed after '..name)
	end
	proxy=drag(page,'copy')
	assert(page.JavaScriptRuntime:Run('getSelection().removeAllRanges();'));f:Drain()
	assert(f.Input:GetFocusedTextBox()==nil and proxy.Text=='','Clearing the document range must erase its stale native copy buffer')
	key('LeftControl');key('C');key('C',true);key('LeftControl',true)
	assert(f.Input:GetFocusedTextBox()==nil and proxy.Text=='','A copy shortcut must not restore a cleared document range')
	local function rangeEquals(before,label)
		local after=assert(page.JavaScriptRuntime.Selection:Snapshot(),label..' lost the DOM range')
		assert(after.StartNode==before.StartNode and after.StartOffset==before.StartOffset and after.EndNode==before.EndNode and after.EndOffset==before.EndOffset,label..' unexpectedly changed the selected boundaries')
	end
	proxy=drag(page,'copy')
	for _,attributeName in {'data-copy-note','title'}do
		assert(page.JavaScriptRuntime:Run("document.getElementById('next').setAttribute('"..attributeName.."','unrelated metadata');"));f:Drain()
		assert(f.Input:GetFocusedTextBox()==proxy and proxy.Text=='straße Äpfel\nlast','An unrelated '..attributeName..' mutation must not leave an owned copy selection empty')
	end
	local adapter=page.JavaScriptRuntime.SelectionAdapter;local actualCopyText=adapter.CopyText;local extractions=0
	adapter.CopyText=function(self,...)extractions+=1;return actualCopyText(self,...)end
	for _,item in textItems(page,'copy')do item.Gui.TextColor3=f.Color3.fromRGB(70,80,90)end
	for _=1,8 do tree.SelectionPaintChanged()end
	assert(extractions==0 and f.Input:GetFocusedTextBox()==proxy and proxy.Text=='straße Äpfel\nlast','Pure color repaint notifications must retain the copy buffer without rescanning selected source text')
	adapter.CopyText=actualCopyText
	proxy=drag(page,'copy');local selectedBefore=assert(page.JavaScriptRuntime.Selection:Snapshot())
	assert(page.JavaScriptRuntime:Run("document.getElementById('copy').firstChild.replaceData(2,1,'X');"));f:Drain()
	assert(proxy.Text~='straße Äpfel\nlast','A same-length mutation must retire stale selected copy text after the renderer flush')
	rangeEquals(selectedBefore,'Same-length text mutation')
	key('LeftControl');assert(f.Input:GetFocusedTextBox()==proxy and proxy.Text=='stXaße Äpfel\nlast','Copy must read the current selected source after a same-length mutation')
	key('C');key('C',true);key('LeftControl',true)
	assert(page.JavaScriptRuntime:Run("document.getElementById('copy').firstChild.replaceData(2,1,'r');"));f:Drain()
	assert(Node.textContent(node(page,'copy'))==original)
	for _,property in {'visibility','userSelect'}do
		proxy=drag(page,'copy');selectedBefore=assert(page.JavaScriptRuntime.Selection:Snapshot())
		assert(page.JavaScriptRuntime:Run("document.getElementById('copy').style."..property.."='"..(if property=='userSelect'then 'none'else 'hidden').."';"));f:Drain()
		local sourceStyle=tree.NodeStyles[node(page,'copy')];local itemStyle=textItems(page,'copy')[1].Style
		assert(proxy.Text=='','A '..property..' change must retire text that can no longer be copied: buffer='..string.format('%q',proxy.Text)..'; source='..tostring(sourceStyle.UserSelect)..'/'..tostring(sourceStyle.Visibility)..'; item='..tostring(itemStyle.UserSelect)..'/'..tostring(itemStyle.Visibility))
		rangeEquals(selectedBefore,property..' paint mutation')
		key('LeftControl');key('C');key('C',true);key('LeftControl',true)
		assert(f.Input:GetFocusedTextBox()==nil and proxy.Text=='','Copy must not restore stale '..property..' text')
		assert(page.JavaScriptRuntime:Run("document.getElementById('copy').style."..property.."='"..(if property=='userSelect'then 'auto'else 'visible').."';"));f:Drain()
	end
	proxy=drag(page,'copy')
	key('LeftControl');key('LeftControl',true)
	key('Tab');key('Tab',true)
	local field=assert(page.FormModel:Resolve(node(page,'field'))).Item.Editor
	assert(f.Input:GetFocusedTextBox()==field,'Native copy focus must not break the first Tab into the form')
	field.CursorPosition,field.SelectionStart=7,1
	key('LeftControl');key('C');key('C',true);key('LeftControl',true)
	assert(f.Input:GetFocusedTextBox()==field and field.Text=='native field'and field.CursorPosition==7 and field.SelectionStart==1,'Native input selection must remain owned by the form')
	field:ReleaseFocus(false)
	proxy=drag(page,'copy');key('LeftControl')
	local modalKeys,modalUps=page.JavaScriptRuntime.Window.Get('copyKeys'),page.JavaScriptRuntime.Window.Get('copyUps')
	local dismiss=browser.Overlays:ScriptDialog({Kind='alert',Message='Modal owns keyboard input'},function()end);f:Drain()
	assert(browser.Input.Modal~=nil,'Expected the real browser script dialog shield')
	key('C');key('C',true);key('LeftControl',true)
	assert(page.JavaScriptRuntime.Window.Get('copyKeys')==modalKeys and page.JavaScriptRuntime.Window.Get('copyUps')==modalUps,'An open browser modal must block copy passthrough, including a modifier keyup paired before it opened')
	assert(proxy.Text==''and Node.textContent(node(page,'copy'))==original,'Modal display must not retain stale selected copy text')
	dismiss();f:Drain()
	assert(f.Input:GetFocusedTextBox()~=proxy,'Dismissing a browser modal must not leave an unarmed empty copy proxy focused')
	proxy=drag(page,'copy');click(browser.View.URL)
	assert(browser.View.URL:IsFocused(),'Address field focus was not acquired')
	key('LeftControl');key('C');key('C',true);key('LeftControl',true)
	assert(browser.View.URL:IsFocused(),'HTML copy must never steal the address field')
	browser.View.URL:ReleaseFocus(false)
	-- An unrelated native field (chat, menu or another application widget) wins.
	local external=f.Create('TextBox',f.Screen,{Name='ExternalEditor',Text='external',TextEditable=true})
	assert(page.JavaScriptRuntime:Run('cancelCopyKey=true;'));f:Drain()
	local canceledBefore=page.JavaScriptRuntime.Window.Get('canceledCopyKeys')
	external:CaptureFocus();key('LeftControl');key('C');key('C',true);key('LeftControl',true)
	assert(external:IsFocused()and external.Text=='external','Selection copy stole another native editor')
	assert(page.JavaScriptRuntime.Window.Get('canceledCopyKeys')==canceledBefore,'Unrelated native field keyboard input must not enter or be canceled by the HTML document')
	external:ReleaseFocus(false);external:Destroy()
	assert(page.JavaScriptRuntime:Run('cancelCopyKey=false;'));f:Drain()
	proxy=drag(page,'copy');page:FocusDOMElement(node(page,'editable'));f:Drain()
	local editable=f.Input:GetFocusedTextBox();assert(editable and editable~=proxy,'Contenteditable must keep its own native editor')
	key('LeftControl');key('C');key('C',true);key('LeftControl',true)
	assert(f.Input:GetFocusedTextBox()==editable and Node.textContent(node(page,'editable'))=='editable text','Copy must not replace or edit contenteditable focus')
	editable:ReleaseFocus(false)
	proxy=drag(page,'copy')
	local otherBrowser,otherBinding,otherHost=makeBrowser('Background',false)
	local otherTab=otherBrowser:Open('https://copy.test/other/index.html');f:Drain();local otherPage=assert(otherBinding:GetPage(otherTab))
	assert(f.Input:GetFocusedTextBox()==proxy,'Mounting a hidden page stole selection focus')
	browser:SetFocused(false);binding:SetInputActive(false);binding:SetVisible(false)
	assert(f.Input:GetFocusedTextBox()==nil,'Hiding/deactivating a page must release its copy editor')
	otherBrowser:SetVisible(true);otherBinding:SetVisible(true);otherBrowser:SetFocused(true);otherBinding:SetInputActive(true)
	key('LeftControl');key('C');key('C',true);key('LeftControl',true)
	assert(f.Input:GetFocusedTextBox()==nil,'A hidden selection must not rearm in another browser')
	otherBrowser:Destroy();otherHost:Destroy();browser:Destroy();host:Destroy();f:Drain()
	assert(not page.Alive and not otherPage.Alive and proxy.Destroyed,'Page cleanup must destroy the native copy field')
	local framesBrowser,framesBinding,framesHost=makeBrowser('EmbeddedDocuments',true)
	local framesTab=framesBrowser:Open('https://copy.test/frames/index.html');f:Drain()
	local framesPage=assert(framesBinding:GetPage(framesTab),'Embedded root failed: '..tostring(framesTab.Error))
	local childPage=assert(assert(framesPage.IFrames[1],'Missing srcdoc frame').ChildPage,'Missing mounted srcdoc document')
	local nestedPage=assert(assert(childPage.IFrames[1],'Missing nested srcdoc frame').ChildPage,'Missing mounted nested srcdoc document')
	local embeddedProxy
	for _,record in {{Page=childPage,Text='child selection'},{Page=nestedPage,Text='nested selection'}}do
		local current=record.Page;embeddedProxy=drag(current,'copy')
		assert(embeddedProxy.Text==record.Text and framesPage:OwnsSelectionCopyEditor(embeddedProxy),'Containing page must recognize its exact nested native copy editor')
		local keysBefore=current.JavaScriptRuntime.Window.Get('copyKeys')
		key('LeftControl');key('C');key('C',true);key('LeftControl',true)
		assert(current.JavaScriptRuntime.Window.Get('copyKeys')==keysBefore+2 and f.Input:GetFocusedTextBox()==nil,'Embedded copy keyboard events or modifier release were swallowed by the browser shell')
		-- Direct native copy focus -> Tab is this bridge's ownership boundary;
		-- general iframe logical focus after all native focus is gone is separate.
		embeddedProxy=drag(current,'copy')
		key('Tab');key('Tab',true)
		local native=assert(current.FormModel:Resolve(node(current,'field'))).Item.Editor
		local actual=f.Input:GetFocusedTextBox()
		assert(actual==native,'Tab after embedded text copy must reach that document native field: '..record.Text..'; actual='..tostring(actual and actual.Text)..'; expected='..tostring(native.Text))
		key('LeftControl');key('C');key('C',true);key('LeftControl',true)
		assert(f.Input:GetFocusedTextBox()==native and native.Text==(if current==childPage then 'child native'else 'nested native'),'Embedded copy bridge stole its own native form field')
		native:ReleaseFocus(false)
	end
	embeddedProxy=drag(nestedPage,'copy');framesBrowser:SetFocused(false);framesBinding:SetInputActive(false);framesBinding:SetVisible(false)
	assert(f.Input:GetFocusedTextBox()==nil and embeddedProxy.Text=='','Hiding the containing browser must release nested iframe native copy focus')
	framesBrowser:Destroy();framesHost:Destroy();f:Drain()
	assert(not framesPage.Alive and not childPage.Alive and not nestedPage.Alive and embeddedProxy.Destroyed,'Containing document teardown must dispose nested iframe copy ownership')
	-- The same input bridge also works without any JS runtime or Browser module.
	local plainHost=f.Create('Frame',f.Screen,{Size=f.UDim2.fromScale(1,1)})
	local plain=module.mount(plainHost,'<!doctype html><html><body><p id="copy">plain copy</p></body></html>',{JavaScript=false,RenderWorkBudgetMS=0,InputServices={Input=f.Input,PlayerGui=f.PlayerGui,Task=f.Task,Factory=factory}})
	f:Drain();assert(plain.Alive and plain.JavaScriptRuntime==nil)
	local standaloneProxy=drag(plain,'copy');assert(standaloneProxy.Text=='plain copy')
	key('LeftControl');key('C');key('C',true);key('LeftControl',true)
	plain:Destroy();plainHost:Destroy();f:Drain()
	assert(standaloneProxy.Destroyed and f.Input:GetFocusedTextBox()==nil and f:GlobalConnections()==0,'Copy bridge leaked native focus or input connections')
	assert(#diagnostics==0,table.concat(diagnostics,' | '))
	print('SelectionCopyMounted: real controller selection, source text, native focus isolation, keyboard continuity, JS-free copy and cleanup passed (OS clipboard not simulated)')
end
