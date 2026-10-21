--!strict
-- Compare structural reflow with a fresh render, without losing live controls.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,Controller,demoHTML,demoCSS)
	local function signal()
		local entries={};local s={}
		function s:Connect(fn)
			local connection={Connected=true};function connection:Disconnect()self.Connected=false end
			table.insert(entries,{Connection=connection,Call=fn});return connection
		end
		function s:Fire(...)for _,entry in table.clone(entries) do if entry.Connection.Connected then entry.Call(...) end end end
		function s:Count()local n=0;for _,entry in entries do if entry.Connection.Connected then n+=1 end end;return n end
		return s
	end
	local focused
	local guis={}
	local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.Parent=parent;gui.ClassName=class;gui.Visible=true
		gui.AbsoluteSize=Vector2.new(520,500);gui.AbsolutePosition=Vector2.new(0,0)
		if class=="ScrollingFrame" then gui.CanvasPosition=Vector2.new(0,0) end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal()
		local signals,attributes={},{}
		function gui:GetPropertyChangedSignal(key)if not signals[key] then signals[key]=signal() end;return signals[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return focused==self end
		function gui:CaptureFocus()if focused and focused~=self then focused:ReleaseFocus() end;focused=self;self.Focused:Fire()end
		function gui:ReleaseFocus()if focused==self then focused=nil;self.FocusLost:Fire(false) end end
		function gui:SetAttribute(key,value)attributes[key]=value end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:Destroy()
			assert(not self.Destroyed,"GUI destroyed twice");self.Destroyed=true
			for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy() end end
			self.Parent=nil
		end
		table.insert(guis,gui);return gui
	end}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text) or 0)*size*.45,Y=size}end}}
	local words=loadWordLayout(overrides)
	overrides["Layout/WordLayout"]=words
	local layout=loadBlockLayout(overrides)
	local renderer=loadRenderTree(factory)
	local function arrange(tree,width,items)
		tree:SetMediaEnvironment(width,500);tree.ViewportHeight=500
		local stats=Dirty.begin(tree,items)
		local height=layout.arrange(tree,width,0,0,function()return true end)
		Dirty.finish(tree,true);return height,stats
	end
	local function snapshot(tree)
		local parts={}
		local function add(value)table.insert(parts,if type(value)=="number" then string.format("%.4f",value) else tostring(value))end
		local function visit(box)
			add(box.Kind);add(box.Node and (box.Node.Attributes and box.Node.Attributes.id or box.Node.Name))
			for _,key in {"LayoutX","LayoutY","OuterWidth","OuterHeight","ContentWidth","ContentHeight"} do add(box[key]) end
			for _,item in box.Items or {} do add(item.Text);for _,key in {"X","Y","Width","Height","Baseline"} do add(item[key]) end end
			for _,child in box.Children or {} do visit(child) end
		end
		visit(tree);return table.concat(parts,"|")
	end
	for _,display in {"block","flex","grid"} do
		local css="body{margin:0}.lists{display:"..display..";gap:12px;grid-template-columns:1fr 1fr}.lists>div{flex:1;min-width:0}li{padding:6px}#right{color:red}#scroll{height:60px;overflow:auto}"
		local doc=Parser.parseDocument('<!doctype html><html><body><section id="intro"><p>Unchanged intro</p><input id="existing" value="Before"></section><div class="lists"><div><ol id="left"><li id="a"><p>Alpha</p><input id="edit" value="Keep"></li><li id="b"><p>Beta</p></li></ol></div><div><ol id="right"><li id="c">Gamma</li></ol></div></div><section id="scroll"><p>Scroll remains</p><p>More content</p></section><section id="following"><p>After lists</p></section><script>window.boots=1;</script></body></html>')
		local function build(document)return renderer.build(document,{},error,function(font)return font end,nil,nil,nil,css)end
		local tree=build(doc);local events=Events.new(error)
		local model=FormModel.new(doc,tree.Controls,events,function()end)
		local page={Alive=true,Document=doc,DocumentURL="dom.html",Root=tree.Gui,Events=events,FormModel=model,Cleanups={}}
		function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		function page:SetValue(node,value)model:SetValue(model:Resolve(node),value)end
		local realm=HTMLScripts.start(page,tree,function()end,error)
		local function run(source)realm:Run(source);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n"))end
		local width=520;arrange(tree,width)
		local intro=tree.NodeBoxes[Node.findById(doc,"intro")];local scroll=tree.NodeBoxes[Node.findById(doc,"scroll")]
		scroll.ScrollGui.CanvasPosition=Vector2.new(0,17)
		local editor=model:Resolve(Node.findById(doc,"edit"));model:SetValue(editor,"Typed value")
		local nativeEditor=editor.Item.Editor;local initial=tree.NodeBoxes[Node.findById(doc,"a")]
		local function compare()
			local needed,targets=realm:Flush();assert(needed and next(targets),"Structural edits identify dirty parents")
			local height,stats=arrange(tree,width,targets)
			local fresh=build(Node.cloneNode(doc,true));local expected=arrange(fresh,width)
			assert(height==expected and snapshot(tree)==snapshot(fresh),"Incremental "..display.." DOM layout matches a fresh tree")
			assert(stats.Mode=="partial" and stats.Reused>0,"Unchanged branches reuse layout")
			assert(tree.NodeBoxes[Node.findById(doc,"intro")]==intro and not intro.Gui.Destroyed,"Unrelated boxes survive")
			assert(scroll.ScrollGui.CanvasPosition.Y==17,"Scroll position survives DOM edits")
			assert(realm.VM.Global.Bindings.boots.Value==1 and realm.ScriptsRun==1,"Scripts are not executed again")
		end
		run([=[const left=document.getElementById("left");const right=document.getElementById("right");
const a=document.getElementById("a");const live=left.children;const old=left.querySelectorAll("li");
window.hits=0;a.addEventListener("click",function(){window.hits+=1;});
const added=document.createElement("li");added.id="new";const text=document.createElement("p");text.textContent="New text with several words";
added.appendChild(text);left.insertBefore(added,a);window.liveLength=live.length;window.snapshotLength=old.length;]=]);compare()
		assert(realm.VM.Global.Bindings.liveLength.Value==3 and realm.VM.Global.Bindings.snapshotLength.Value==2)
		run('right.appendChild(a);');compare()
		assert(tree.NodeBoxes[Node.findById(doc,"a")]==initial,"Moved boxes retain identity")
		assert(model:Resolve(editor.Node)==editor and editor.Item.Editor==nativeEditor and editor.Value=="Typed value","Moving preserves native inputs and their values")
		events:Emit(initial.Node,"click");assert(realm.VM.Global.Bindings.hits.Value==1,"Moved listeners fire")
		run('left.appendChild(document.getElementById("new"));document.getElementById("b").remove();');compare()
		run([=[const fragment=document.createDocumentFragment();for(let i=0;i<3;i++){const row=document.createElement("li");row.textContent="Batch "+i;fragment.appendChild(row);}
left.appendChild(fragment);window.emptyFragment=fragment.childNodes.length;]=]);compare();assert(realm.VM.Global.Bindings.emptyFragment.Value==0)
		run('right.removeChild(a);');compare()
		assert(initial.Gui.Destroyed and tree.NodeBoxes[initial.Node]==nil and model:Resolve(editor.Node)==nil,"Removal releases GUI/model indexes")
		assert(not realm.DOM.Wrap(initial.Node).Get("isConnected"))
		run('left.appendChild(a);');compare();events:Emit(initial.Node,"click")
		assert(realm.VM.Global.Bindings.hits.Value==2 and model:Resolve(editor.Node).Value=="Typed value","Reinserted nodes keep JS listeners and current input values")
		run([=[const dynamic=document.createElement("input");dynamic.id="dynamic";dynamic.value="Set before mounting";
const row=document.createElement("li");row.appendChild(dynamic);left.appendChild(row);]=]);compare()
		assert(model:Resolve(Node.findById(doc,"dynamic")).Value=="Set before mounting","Pending input state is rendered")
		run([=[const prepared=document.createElement("button");prepared.id="prepared";prepared.value;prepared.textContent="Caption prepared after reading value";
const unchecked=document.createElement("input");unchecked.id="unchecked";unchecked.setAttribute("type","radio");unchecked.setAttribute("checked","");unchecked.checked=false;unchecked.value="radio value";
document.getElementById("dynamic").parentNode.appendChild(prepared);document.getElementById("dynamic").parentNode.appendChild(unchecked);]=]);compare()
		assert(model:Resolve(Node.findById(doc,"prepared")).Caption=="Caption prepared after reading value","Pending reads do not freeze later DOM defaults")
		assert(not model:Resolve(Node.findById(doc,"unchecked")).Checked,"Preparing a radio value does not reset its explicit unchecked state")
		run('left.insertBefore(a,a);');assert(not realm:HasPending(),"Inserting before itself is a no-op")
		for _,newWidth in {260,800} do width=newWidth;arrange(tree,width);run('left.appendChild(left.firstElementChild);');compare() end
		realm:Destroy();model:Destroy();events:Destroy()
	end
	-- A retained control can cross anonymous inline flow and flex/grid items.
	for _,display in {"flex","grid"} do
		local doc=Parser.parseDocument('<!doctype html><html><body><p id="flow">Before <span id="inline" style="opacity:.5">Middle <input id="moving" value="Keep"></span> after</p><div id="items" style="display:'..display..'"><p>Neighbour</p></div><p id="unchanged">Following</p></body></html>')
		local function build(d)return renderer.build(d,{},error,function(font)return font end)end
		local tree=build(doc);arrange(tree,520)
		local events=Events.new(error);local c=tree.Controls[1];local editor=c.Item.Editor
		local realm=Runtime.new(doc,{Events=events,Diagnostic=error,
			ValidateStructure=function(parent,node,previous)tree:ValidateStructure(parent,node,previous)end,
			ApplyChanges=function(changes)return tree:ApplyDOMChanges(changes)end})
		for _,parent in {"items","inline","items","flow"} do
			realm:Run('document.getElementById("'..parent..'").appendChild(document.getElementById("moving"));')
			local needed,items=realm:Flush();assert(needed)
			local height=arrange(tree,520,items);local fresh=build(Node.cloneNode(doc,true));local expected=arrange(fresh,520)
			local a,b=string.split(snapshot(tree),"|"),string.split(snapshot(fresh),"|")
			local mismatch=""
			for i=1,math.max(#a,#b) do if a[i]~=b[i] then mismatch=" token "..i.." live="..table.concat(a,"|",math.max(1,i-4),math.min(#a,i+4)).." fresh="..table.concat(b,"|",math.max(1,i-4),math.min(#b,i+4));break end end
			assert(height==expected and snapshot(tree)==snapshot(fresh),"Moving between inline and "..display.." flow into "..parent.." matches a fresh tree: "..height.."/"..expected..mismatch)
			assert(c.Item.Editor==editor and not editor.Destroyed,"Inline/block transitions retain the native editor")
		end
		realm:Destroy();events:Destroy()
	end
	-- Exercise the shipped page through the real input controller, including
	-- new TextBox connections, focus order and disconnection on removal.
	do
		local doc=Parser.parseDocument(demoHTML)
		local root=factory.create("ScrollingFrame",nil,{})
		local tree=renderer.build(doc,root,error,function(font)return font end,nil,nil,nil,demoCSS)
		arrange(tree,600)
		local page={Alive=true,Document=doc,DocumentURL="demo.html",Root=root,Cleanups={}}
		function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
		function input:GetFocusedTextBox()return focused end
		function input:IsKeyDown()return false end
		local requested={}
		local picked={}
		Controller.start(page,tree,function(_,item)if item then requested[item]=true end end,error,
			{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return picked end},Factory=factory})
		local realm=HTMLScripts.start(page,tree,function()end,error)
		local function flush()
			local needed,items=realm:Flush()
			if needed then arrange(tree,600,items) end
			assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n"))
			for _,id in {"dom-list","dom-archive-list"} do
				for _,row in Node.findById(doc,id).Children do
					local box=tree.NodeBoxes[row]
					if box and box.Marker then
						assert(box.Marker.Gui.Position[1]+box.Marker.Width==0,"DOM insertion/moves/removal keep card numbering outside its border")
					end
				end
			end
		end
		flush()
		local function click(id)page.FormModel:Activate(page.FormModel:Resolve(id));flush()end
		click("dom-add")
		local list=Node.findById(doc,"dom-list")
		local added=list.Children[#list.Children]
		local newInput=added.Children[2]
		local c=page.FormModel:Resolve(newInput);local editor=c.Item.Editor
		assert(editor:GetPropertyChangedSignal("Text"):Count()==1,"New native editors bind exactly once")
		editor.Text="Native edited value";editor:GetPropertyChangedSignal("Text"):Fire()
		assert(c.Value=="Native edited value","New native input updates its form state")
		page:Focus(newInput);assert(focused==editor,"New input participates in focus")
		root.AbsolutePosition=Vector2.new(20,30)
		picked={c.Item.Gui}
		realm.VM.Global.Bindings.nativeHost={Value=realm.DOM.Wrap(newInput)}
		realm:Run('window.nativeData="";window.nativeKey="";window.mouseDowns=0;const nativeInput=window.nativeHost;nativeInput.addEventListener("pointerdown",function(e){window.nativeData=e.clientX+":"+e.clientY+":"+e.button+":"+e.buttons+":"+e.isTrusted;e.preventDefault();});nativeInput.addEventListener("mousedown",function(){window.mouseDowns+=1;});nativeInput.addEventListener("click",function(e){window.nativeClick=e.clientX+":"+e.clientY+":"+e.isTrusted;});nativeInput.addEventListener("keydown",function(e){window.nativeKey=e.key+":"+e.code+":"+e.repeat+":"+e.isTrusted;e.preventDefault();});')
		local pointerEvent={UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(57,83)}
		input.InputBegan:Fire(pointerEvent,false);input.InputEnded:Fire(pointerEvent)
		assert(realm.VM.Global.Bindings.nativeData.Value=="37:53:0:1:true" and realm.VM.Global.Bindings.nativeClick.Value=="37:53:true",
			"Native pointer/click events preserve viewport coordinates, buttons and trust")
		assert(realm.VM.Global.Bindings.mouseDowns.Value==0,"Canceling pointerdown suppresses compatibility mousedown while preserving click")
		local keyEvent={UserInputType=Enum.UserInputType.Keyboard,KeyCode={Name="A",Value=97}}
		function input:GetStringForKeyCode()return "a"end
		input.InputBegan:Fire(keyEvent,false);input.InputBegan:Fire(keyEvent,false);input.InputEnded:Fire(keyEvent)
		assert(realm.VM.Global.Bindings.nativeKey.Value=="a:KeyA:true:true","Native keyboard events retain key/code/repeat/trust and can prevent defaults")
		picked={};root.AbsolutePosition=Vector2.new(0,0)
		realm:Run('document.getElementById("dom-archive-list").appendChild(document.getElementById("dom-list").lastElementChild);');flush()
		assert(page.FormModel:Resolve(newInput)==c and focused==editor and editor:GetPropertyChangedSignal("Text"):Count()==1,"Moves preserve focus and do not duplicate connections")
		page.FormModel:Activate(page.FormModel:Resolve(added.Children[3]));flush()
		assert(page.FormModel:Resolve(newInput)==nil and editor:GetPropertyChangedSignal("Text"):Count()==0,"Removed editors are disconnected")
		assert(focused==nil,"Removing a focused editor clears focus")
		for _,id in {"dom-prepend","dom-batch","dom-rotate","dom-archive","dom-restore","dom-remove"} do click(id) end
		for i=#page.Cleanups,1,-1 do page.Cleanups[i]() end
		assert(input.InputBegan:Count()==0 and input.InputChanged:Count()==0 and input.InputEnded:Count()==0,"Page destruction releases shared input listeners")
	end
	local doc=Parser.parseDocument('<!doctype html><html><body><div id="one"><p id="child">Child</p></div><div id="two"></div></body></html>')
	local events=Events.new(error);local diagnostics={}
	local realm=Runtime.new(doc,{Events=events,Diagnostic=function(message)table.insert(diagnostics,message)end,ApplyChanges=function()return false end})
	realm:Run([=[const one=document.getElementById("one");const two=document.getElementById("two");const child=document.getElementById("child");
window.path="";child.addEventListener("click",function(){two.appendChild(child);window.path+="child/";});
one.addEventListener("click",function(){window.path+="one";});two.addEventListener("click",function(){window.path+="two";});]=])
	events:Emit(Node.findById(doc,"child"),"click");assert(realm.VM.Global.Bindings.path.Value=="child/one","Bubbling uses the dispatch-time path")
	realm:Flush();realm:Run('child.appendChild(two);')
	assert(#diagnostics==1 and Node.findById(doc,"child").Parent==Node.findById(doc,"two"),"Cycle rejection preserves the old parent")
	realm:Run('one.insertBefore(child,child);')
	assert(#diagnostics==2 and Node.findById(doc,"child").Parent==Node.findById(doc,"two"),"Invalid references cannot detach nodes")
	realm:Run('child.remove();child.remove();');assert(#diagnostics==2,"Removing detached nodes is harmless")
	realm:Destroy();events:Destroy()
	print("JavaScript DOM: live collections, fragments, atomic moves, listener/input identity, local block/flex/grid reflow, resize and cleanup passed")
end
