--!strict
-- Exercise the real Controller/TextBox signals and DOM mutation pipeline.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller)
	local function signal()
		local entries={};local s={}
		function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function s:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		function s:Count()local n=0;for _,entry in entries do if entry[1].Connected then n+=1 end end;return n end
		return s
	end
	local focused;local guis,deferred={},{};local factory={}
	function factory.create(class,parent,props)
		local changes,attributes={},{ }
		local values={Parent=parent,ClassName=class,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(520,500),AbsoluteWindowSize=Vector2.new(520,500),Text="",CursorPosition=-1,SelectionStart=-1}
		for key,value in props do values[key]=value end;if class=="ScrollingFrame"then values.CanvasPosition=Vector2.new(0,0)end
		local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)local old=values[key];values[key]=value;if old~=value and changes[key]then changes[key]:Fire()end end})
		values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
		function values:GetPropertyChangedSignal(key)
			assert(class~="ScreenGui"or(key~="AbsolutePosition"and key~="AbsoluteSize"and key~="Visible"),"LayerCollector has no GuiObject geometry signals")
			if not changes[key]then changes[key]=signal()end;return changes[key]
		end
		function values:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function values:SetAttribute(key,value)attributes[key]=value;if changes["attribute:"..key]then changes["attribute:"..key]:Fire()end end
		function values:GetAttribute(key)return attributes[key]end
		function values:IsA(kind)return kind==class or(kind=="GuiObject"and class~="ScreenGui")end
		function values:IsFocused()return focused==gui end
		function values:CaptureFocus()if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
		function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
		function values:Destroy()if values.Destroyed then return end;values.Destroyed=true;for _,child in guis do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument('<!doctype html><html><body><div id="rich" contenteditable="true" style="white-space:pre-wrap">A<strong id="bold">ä😀</strong>Z<span id="locked" contenteditable="false">LOCK</span></div><div id="plain" contenteditable="plaintext-only" style="white-space:pre-wrap">hello</div><p id="after">Unrelated retained content.</p><input id="native" value="control"><script>globalThis.boot=1;</script></body></html>')
	local messages,diagnostics={},{};local layer=factory.create("ScreenGui",nil,{});local root=factory.create("ScrollingFrame",layer,{ClipsDescendants=true})
	local tree=renderer.build(document,root,function(m)table.insert(messages,m)end,function(font)return font end)
	local function arrange(width,items)tree:SetMediaEnvironment(width,500);tree.ViewportHeight=500;Dirty.begin(tree,items);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)end
	arrange(520)
	local page={Alive=true,Document=document,DocumentURL="https://example.test/editing",BaseURL="https://example.test/editing",Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	root:SetAttribute("Status","ready")
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
	local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return {}end},Factory=factory,Clock=function()return 0 end,MeasureValidationText=function()return Vector2.new(200,16)end,
		RunService={RenderStepped=signal()},Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
	Controller.start(page,tree,function()end,error,services)
	local realm,flushing
	function page:HasPendingLayout()return realm and realm:HasPending()or false end
	function page:FlushScriptLayout()if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush();if needed then arrange(520,items)end;flushing=false end
	function page:GeometryViewport()return {Width=520,Height=500,X=0,Y=0}end
	realm=HTMLScripts.start(page,tree,function()end,function(m)table.insert(diagnostics,m)end,{JavaScriptServices=services})
	local function healthy()assert(#diagnostics==0,table.concat(diagnostics," | "));assert(#messages==0,table.concat(messages," | "))end
	local function run(source)realm:Run(source);healthy()end
	local function settle()for _=1,24 do local work=deferred;deferred={};for _,fn in work do fn()end;local tasks=realm:PumpTasks();if #deferred==0 and tasks==0 then break end end;healthy()end
	local function flush()local needed,items=realm:Flush();if needed then arrange(520,items)end;settle();healthy();return needed end
	flush()
	local rich=Node.findById(document,"rich");local plain=Node.findById(document,"plain");local bold=Node.findById(document,"bold")
	local boldText=bold.Children[1];local after=tree.NodeBoxes[Node.findById(document,"after")].Gui
	run([=[
const rich=document.getElementById('rich'),plain=document.getElementById('plain'),bold=document.getElementById('bold'),locked=document.getElementById('locked');
function check(v,m){if(!v)throw new Error(m);}
check(rich.isContentEditable&&bold.isContentEditable&&!locked.isContentEditable&&plain.contentEditable==='plaintext-only','editing state inheritance');
globalThis.events=[];globalThis.lastRange=null;
rich.addEventListener('beforeinput',e=>{events.push('before:'+e.inputType+':'+rich.textContent);let rs=e.getTargetRanges();if(rs.length)lastRange=rs[0];if(e.data==='!')e.preventDefault();});
rich.addEventListener('input',e=>events.push('input:'+e.inputType+':'+rich.textContent+':'+getSelection().focusOffset));
rich.focus();getSelection().setBaseAndExtent(bold.firstChild,1,bold.firstChild,3);
]=])
	settle();local native=page.ContentEditableInput;local editor=native.Editor
	assert(focused==editor and page.FormModel:GetActiveElement()==rich and editor.Text=="Aä😀ZLOCK","Editing host owns native focus with rendered DOM preserved")
	assert(editor.CursorPosition==8 and editor.SelectionStart==4,"Native UTF8 positions map to DOM UTF16 boundaries")
	assert(native.Caret and not native.Caret.Visible,"A noncollapsed DOM selection hides its caret")
	-- Replacing only the selected astral character retains the strong/text nodes.
	editor.CursorPosition=5;editor.SelectionStart=-1;editor.Text="AäXZLOCK";settle();flush()
	assert(bold.Children[1]==boldText and boldText.Text=="äX"and after==tree.NodeBoxes[Node.findById(document,"after")].Gui,"Native edits retain formatted nodes and unrelated boxes")
	assert(native.Caret.Visible and native.Caret.Size[1]==1 and editor.Size[1]==1 and editor.Size[2]==1,"Caret paints the retained fragments without an input overlay covering the host")
	run("check(events.length===2&&events[0]==='before:insertText:Aä😀ZLOCK'&&events[1]==='input:insertText:AäXZLOCK:2','before/input order and updated caret');check(lastRange instanceof StaticRange&&lastRange.startContainer===bold.firstChild&&lastRange.startOffset===1&&lastRange.endOffset===3,'target range is static UTF16 proposal');")
	local previous=editor.Text;editor.Text="Aä!XZLOCK";settle();assert(editor.Text==previous and boldText.Text=="äX","Canceled beforeinput restores native projection")
	-- An uneditable island is never overwritten by a native text proposal.
	editor.Text="AäXZBAD";settle();assert(editor.Text==previous and Node.findById(document,"locked").Children[1].Text=="LOCK")
	run("plain.focus();getSelection().collapse(plain.firstChild,5);");settle()
	assert(native.Editor==editor and editor.Text=="hello","One input source is retained across editing hosts")
	local oldSurface=tree.NodeBoxes[rich].Gui
	assert(oldSurface:GetPropertyChangedSignal("AbsolutePosition"):Count()==0,"Switching host disconnects caret geometry watchers")
	local caretRect=realm.SelectionAdapter:RangeRects(plain.Children[1],5,plain.Children[1],5)[1]
	assert(caretRect and math.abs(native.Caret.Position[1]-caretRect.X-root.AbsolutePosition.X)<.01 and math.abs(native.Caret.Position[2]-caretRect.Y-root.AbsolutePosition.Y)<.01,"Caret geometry follows actual rendered fragments")
	run("getSelection().collapse(plain.firstChild,2);");settle()
	root.Visible=false;assert(not native.Caret.Visible,"A hidden scroll ancestor hides the caret");root.Visible=true
	assert(native.Caret.Visible,"Restoring ancestor visibility restores the caret")
	run("getSelection().collapse(plain.firstChild,5);");settle()
	-- The generic runner represents EnumItems as strings; the mounted keyboard
	-- path needs the native KeyCode.Name/Value shape as well as its identity.
	local originalLeft=Enum.KeyCode.Left;if type(originalLeft)=="string"then Enum.KeyCode.Left={Name="Left",Value=276}end
	local key={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Left}
	input.InputBegan:Fire(key,true);settle();assert(editor.CursorPosition==5,"Keyboard navigation uses the live DOM selection")
	editor.CursorPosition=3;settle();assert(editor.CursorPosition==5,"Native navigation cannot replace the handled DOM caret")
	input.InputEnded:Fire(key,true);run("getSelection().collapse(plain.firstChild,5);");settle()
	native:Hint(Enum.KeyCode.Return,false,false);editor.CursorPosition=8;editor.SelectionStart=-1;editor.Text="hello\nX";settle();flush()
	assert(Node.textContent(plain)=="hello\nX"and #plain.Children==1 and plain.Children[1].Kind=="Text","Plaintext editing inserts raw text, preserving its text node")
	run("plain.focus();getSelection().setBaseAndExtent(plain.firstChild,0,plain.firstChild,5);");settle()
	assert(editor.CursorPosition==6 and editor.SelectionStart==1,"Script changes synchronize the same native editing selection")
	for _,width in {250,640}do arrange(width);realm:AfterLayout(0);settle();assert(native.Editor==editor and editor.Text=="hello\nX","Resize retains native input and DOM selection")end
	run("plain.contentEditable='false';");flush();assert(native.Host==nil and focused==nil,"Changing editability closes the native input source")
	-- Rich Enter splits the DOM block through a Range and retains formatting.
	run("const para=document.createElement('p');para.id='para';para.contentEditable='true';para.style.whiteSpace='pre-wrap';para.innerHTML='ab<strong id=\"tail\">cd</strong>';document.body.append(para);");flush()
	local paragraph=Node.findById(document,"para");local tail=Node.findById(document,"tail")
	run("para.focus();getSelection().collapse(para.firstChild,1);");settle()
	native:Hint(Enum.KeyCode.Return,false,false);editor.CursorPosition=3;editor.SelectionStart=-1;editor.Text="a\nbcd";settle();flush()
	assert(paragraph.Children[1].Text=="a","Rich Enter retains the current paragraph prefix")
	local nextBlock=paragraph.Children[2]
	assert(nextBlock.Name=="div"and Node.textContent(nextBlock)=="bcd"and tail.Parent==nextBlock,"Rich Enter preserves the retained formatted tail")
	-- General validation anchors focus and display feedback without a form record.
	run("para.tabIndex=0;");flush();page:ReportDOMValidity(paragraph,"An anchored validation message")
	assert(page.FormModel:GetActiveElement()==paragraph,"Validation anchors focus editable/non-control elements")
	run("para.setAttribute('inert','');");flush();assert(native.Host==nil and focused==nil,"Inert editing hosts relinquish native focus")
	run("para.removeAttribute('inert');para.focus();");settle();assert(native.Host==paragraph)
	run("para.remove();");flush();assert(native.Host==nil and focused==nil,"Removed editing hosts relinquish native input and caret")
	run("const shell=document.createElement('section');document.body.append(shell);const shadow=shell.attachShadow({mode:'open'});shadow.innerHTML='<div id=\"inside\" contenteditable=\"plaintext-only\" style=\"white-space:pre-wrap\">shadow</div>';const inside=shadow.getElementById('inside');");flush()
	run("inside.focus();getSelection().collapse(inside.firstChild,3);");settle()
	assert(native.Editor==editor and native.Host and native.Host.Attributes.id=="inside"and editor.Text=="shadow","Shadow editing reuses native input and retains its actual tree-scope selection")
	editor.CursorPosition=5;editor.SelectionStart=-1;editor.Text="shaXdow";settle();flush()
	run("check(inside.textContent==='shaXdow'&&shadow.getSelection().focusNode===inside.firstChild&&shadow.getSelection().focusOffset===4,'Native shadow edit preserves scoped DOM/caret');globalThis.cancelKey=0;inside.addEventListener('keydown',e=>{if(e.key==='ArrowLeft'){cancelKey++;e.preventDefault();}});")
	input.InputBegan:Fire(key,true);run("check(cancelKey===1,'Native keydown reaches active shadow editor');");editor.CursorPosition=2;settle();assert(editor.CursorPosition==5,"Canceled keydown protects editing selection as well as text: "..tostring(editor.CursorPosition))
	input.InputEnded:Fire(key,true)
	run("shell.remove();");flush();assert(native.Host==nil and focused==nil,"Removing a shadow host releases its editing descendant")
	run("document.designMode='ON';check(document.designMode==='on'&&document.body.isContentEditable,'DesignMode participates in editing inheritance');document.designMode='off';check(!document.body.isContentEditable,'DesignMode can be disabled');");flush()
	Enum.KeyCode.Left=originalLeft
	for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;page.Alive=false
	assert(editor.Destroyed and editor:GetPropertyChangedSignal("Text"):Count()==0 and editor:GetPropertyChangedSignal("CursorPosition"):Count()==0,"Disposal releases input/selection callbacks")
	assert(native.Caret==nil and page.RefreshDOMFocus==nil and page.ReportDOMValidity==nil,"Disposal clears caret and focus/validation hooks")
	print("Content editing: mounted native input, live inline/Range preservation, UTF16, beforeinput cancellation/static ranges, plaintext/rich breaks, focus, resize and cleanup passed")
end
