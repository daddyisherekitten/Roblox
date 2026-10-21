--!strict
return function(Parser,DOM,Disclosure,Dirty,Controller,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts)
	local function signal()
		local entries={}; local s={}
		function s:Connect(fn)
			local c={Connected=true}; function c:Disconnect() self.Connected=false end
			table.insert(entries,{fn,c}); return c
		end
		function s:Fire(...) for _,e in table.clone(entries) do if e[2].Connected then e[1](...) end end end
		function s:Count() local n=0; for _,e in entries do if e[2].Connected then n+=1 end end; return n end
		return s
	end
	local nativeFocus=nil
	local created=0
	local createdObjects={}
	local factory={}
	function factory.create(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		created+=1
		local g={Parent=parent,Visible=true,Active=false,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(400,500)}
		for k,v in props do g[k]=v end
		function g:IsA(kind) return kind == class or (kind == 'GuiObject' and class ~= 'UIStroke') end
		local signals={}
		function g:GetPropertyChangedSignal(k) signals[k]=signals[k] or signal(); return signals[k] end
		g.Focused,g.FocusLost=signal(),signal()
		function g:IsFocused() return nativeFocus == self end
		function g:CaptureFocus() if nativeFocus and nativeFocus ~= self then nativeFocus:ReleaseFocus() end; nativeFocus=self; self.Focused:Fire() end
		function g:ReleaseFocus() if nativeFocus == self then nativeFocus=nil; self.FocusLost:Fire(false) end end
		function g:Destroy() self.Destroyed=true end
		if class == 'Frame' then
			local function check(key)
				assert(key ~= 'TextColor3' and key ~= 'TextTransparency',key..' is not a valid member of Frame '..(props.Name or ''))
			end
			setmetatable(g,{__index=function(_,key)check(key);return nil end,__newindex=function(target,key,value)check(key);rawset(target,key,value)end})
		end
		table.insert(createdObjects,g)
		return g
	end
	factory.modifier=factory.create
	local root=factory.create('ScrollingFrame',nil,{})
	local doc=Parser.parse('<style>details[open]{background:#e5ecff}details:open>summary{color:blue}</style><form id="f"><div id="before" style="height:10px"></div><details id="d"><p id="intro">Before title in DOM</p><summary id="s">More <strong>information</strong></summary><input id="field" name="field" value="Keep"><details id="nested" open><summary id="ns">Nested</summary><p>Inner content</p></details><summary id="extra">Ordinary summary</summary></details><button id="after" type="button">After</button></form>')
	local diagnostics={}
	local renderer=loadRenderTree(factory)
	local tree=renderer.build(doc,root,function(message) table.insert(diagnostics,message) end,function(font) return font end)
	assert(#diagnostics == 0)
	local dn=DOM.findById(doc,'d'); local d=tree.Disclosures[dn]
	local nested=tree.Disclosures[DOM.findById(doc,'nested')]
	assert(#dn.Children == 5 and dn.Children[1].Name == 'p','Anonymous content must not mutate the source DOM')
	assert(not d.Open and not d.Body.Gui.Visible and #d.Box.Children == 1 and d.Box.Children[1].Node.Attributes.id == 's')
	assert(nested.Open and nested.Body.Gui.Visible and Disclosure.hidden(nested.SummaryNode,tree.Disclosures))
	assert(#tree.Controls == 4 and tree.Controls[1].Type == 'summary' and tree.Controls[2].Node.Attributes.id == 'field')
	assert(not tree.Controls[1].Form,'Summary is not a successful form control')
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	local blocks=loadBlockLayout(overrides)
	local function layout(items)
		local stats=Dirty.begin(tree,items)
		blocks.arrange(tree,400,0,0,function() return true end)
		Dirty.finish(tree,true)
		return stats
	end
	layout(nil)
	local field=tree.Controls[2]
	local savedEditor=field.Item.Editor
	local closedHeight=d.Box.Gui.Size[2]
	local before=d.Box.LayoutParent.Children[1].Gui.Position[2]
	assert(d.Marker.Width > 0 and d.Marker.Gui.Rotation == 0)
	local closedBackground=d.Box.Gui.BackgroundColor3
	local closedAlpha=d.Box.Gui.BackgroundTransparency
	local closedSummary=d.Summary.Style.Color
	local function openPaint()
		assert(d.Box.Style.Background==Color3.fromRGB(229,236,255) and d.Box.Gui.BackgroundColor3==Color3.fromRGB(229,236,255)
			and d.Box.Gui.BackgroundTransparency==0,'Native activation must repaint details[open] backgrounds')
		assert(d.Summary.Style.Color==Color3.fromRGB(0,0,255),':open must update descendant styles too')
	end
	local hits={}; local reverse=false
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox() return nativeFocus end
	function input:IsKeyDown(key) return reverse and key == Enum.KeyCode.LeftShift end
	local page={Alive=true,Document=doc,Root=root}
	function page:AddCleanup(fn) self.Cleanup=fn end
	local layouts=0
	local cleanup=Controller.start(page,tree,function(force,item)
		assert(force == false and (item == d.Box or item == nested.Box))
		layouts+=1
		assert(layout({[item]=true}).Mode == 'partial','Disclosure toggles must use partial layout')
	end,error,{Input=input,Factory=factory,PlayerGui={GetGuiObjectsAtPosition=function() return hits end}})
	local function key(code)
		local e={UserInputType=Enum.UserInputType.Keyboard,KeyCode=code}
		input.InputBegan:Fire(e,false); input.InputEnded:Fire(e,false)
	end
	local function click(gui,kind)
		hits={gui}
		local e={UserInputType=kind or Enum.UserInputType.MouseButton1,Position=Vector2.new(5,5)}
		input.InputBegan:Fire(e,false); input.InputEnded:Fire(e,false)
	end
	page:Focus('field'); assert(not nativeFocus,'Closed content cannot receive programmatic focus')
	page:Focus('s'); key(Enum.KeyCode.Tab); assert(tree.Controls[4].Focused,'Tab skips all closed descendants')
	reverse=true; key(Enum.KeyCode.Tab); reverse=false; assert(tree.Controls[1].Focused)
	assert(d.Control.Item.FocusStroke.Enabled,'Tab gives summary a visible focus indicator')
	local cancel=page:On('s','click',function(e) e:PreventDefault() end)
	click(d.Summary.Gui); assert(not d.Open and layouts == 0); cancel:Disconnect()
	click(d.Summary.Gui)
	assert(not d.Control.Item.FocusStroke.Enabled,'Pointer activation removes the keyboard focus indicator')
	assert(d.Open and dn.Attributes.open ~= nil and d.Body.Gui.Visible and layouts == 1)
	openPaint()
	assert(d.Box.Gui.Size[2] > closedHeight and d.Marker.Gui.Rotation == 90)
	assert(d.Box.LayoutParent.Children[1].Gui.Position[2] == before,'Content before the disclosure must stay in place')
	assert(field.Item.Editor == savedEditor)
	page:SetValue('field','Saved'); page:Focus('field'); assert(nativeFocus == savedEditor)
	page:Focus('s'); key(Enum.KeyCode.Space)
	assert(not d.Open and dn.Attributes.open == nil and not nativeFocus and layouts == 2)
	assert(d.Box.Gui.BackgroundColor3==closedBackground and d.Box.Gui.BackgroundTransparency==closedAlpha and d.Summary.Style.Color==closedSummary,
		'Closing a disclosure restores its background and dependent styles')
	assert(d.Box.Gui.Size[2] == closedHeight and page:GetValue('field') == 'Saved')
	local data=page:GetFormData('f'); assert(#data == 1 and data[1].Value == 'Saved','Closed content remains part of form data')
	key(Enum.KeyCode.Return); assert(d.Open and nested.Open and layouts == 3)
	click(nested.Summary.Gui,Enum.UserInputType.Touch); assert(not nested.Open and layouts == 4)
	click(d.Summary.Gui); click(d.Summary.Gui)
	openPaint()
	assert(d.Open and not nested.Open and field.Item.Editor == savedEditor,'Outer toggles preserve inner state and editors')
	local partialHeight=d.Box.Gui.Size[2]
	layout(nil); assert(d.Box.Gui.Size[2] == partialHeight,'Partial and full layout must agree')
	page:Reset('f'); assert(d.Open and not nested.Open and field.Value == 'Keep','Form reset does not toggle disclosures')
	local count=layouts
	local fallbackTree=renderer.build(Parser.parse('<details open="false"><p>Fallback body</p></details><summary>Standalone</summary>'),root,error,function(font) return font end)
	assert(#fallbackTree.Controls == 1 and fallbackTree.Controls[1].Disclosure.Open,'open is a boolean attribute, even with value false')
	assert(DOM.textContent(fallbackTree.Controls[1].Node) == 'Details')
	cleanup(); cleanup(); assert(input.InputBegan:Count() == 0)
	click(d.Summary.Gui); assert(layouts == count)
	-- Dynamic paint also runs before the first layout during viewport setup.
	local styledDoc=Parser.parse([=[<style>
		summary {color:rgba(10,20,30,.8)}
		summary:hover {color:rgba(30,60,90,.4)}
		summary:active {visibility:hidden}
		a:hover {color:red}
		@media (max-width:300px) {summary {color:rgba(90,60,30,.6)}}
	</style><details><summary id="styled-summary">Closed</summary><p>Body</p></details>
	<details open><summary>Open</summary><p>Body</p></details><a id="other" href="#styled-summary">Other</a>]=])
	local styledTree=renderer.build(styledDoc,{AbsoluteSize={X=400,Y=500}},error,function(font)return font end)
	local styledNode=DOM.findById(styledDoc,'styled-summary')
	local markers={}
	for _,disclosure in styledTree.Disclosures do
		local pixels={}
		for _,object in createdObjects do if object.Parent==disclosure.Marker.Gui then
			table.insert(pixels,{Gui=object,Coverage=1-object.BackgroundTransparency})
		end end
		assert(#pixels>0)
		table.insert(markers,{Disclosure=disclosure,Pixels=pixels})
	end
	local allocated=created
	local function markerColors(color,alpha)
		for _,entry in markers do
			local marker=entry.Disclosure.Marker
			assert(marker.Gui.BackgroundTransparency==1,'Disclosure container must remain transparent')
			assert(marker.Gui.Rotation==(if entry.Disclosure.Open then 90 else 0))
			for _,pixel in entry.Pixels do
				assert(pixel.Gui.BackgroundColor3==color,'Dynamic color must reach arrow pixels')
				assert(math.abs(pixel.Gui.BackgroundTransparency-(1-pixel.Coverage*alpha))<.00001,'Retain arrow antialiasing and CSS alpha')
			end
		end
	end
	assert(styledTree:SetMediaEnvironment(240,500))
	markerColors(Color3.fromRGB(90,60,30),.6)
	assert(styledTree:SetMediaEnvironment(400,500))
	markerColors(Color3.fromRGB(10,20,30),.8)
	blocks.arrange(styledTree,400,0,0,function()return true end)
	assert(styledTree:SetCSSState('hover',styledNode))
	local styledMarker=styledTree.NodeBoxes[styledNode].Marker
	for _,entry in markers do if entry.Disclosure.Marker==styledMarker then for _,pixel in entry.Pixels do
		assert(pixel.Gui.BackgroundColor3==Color3.fromRGB(30,60,90))
		assert(math.abs(pixel.Gui.BackgroundTransparency-(1-pixel.Coverage*.4))<.00001)
	end end end
	assert(styledTree:SetCSSState('active',styledNode) and not styledMarker.Gui.Visible)
	assert(styledTree:SetCSSState('active',nil) and styledMarker.Gui.Visible)
	assert(styledTree:SetCSSState('hover',DOM.findById(styledDoc,'other')))
	markerColors(Color3.fromRGB(10,20,30),.8)
	assert(styledTree:SetCSSState('hover',nil))
	assert(created==allocated,'CSS state/media repaint must reuse disclosure frames')
	-- Pages with JavaScript take the same attribute/observer/batched paint path
	-- for native summary activation and author writes to details.open.
	local scriptDoc=Parser.parse([=[<style>
		.open-demo[open]{background:#e5ecff}
		.open-demo:open>summary{color:blue}
		#scope:has(>details[open]){color:green}
		details[open]+p{height:30px;background:red}
	</style><div id="scope"><details id="script-details" class="open-demo"><summary>More</summary><input value="Keep"></details><p id="following">After</p></div>
	<script>window.mutations=0;window.oldOpen="";var panel=document.getElementById("script-details");
	new MutationObserver(function(records){window.mutations+=records.length;window.oldOpen=String(records[0].oldValue);}).observe(panel,{attributes:true,attributeFilter:["open"],attributeOldValue:true});</script>]=])
	local scriptTree=renderer.build(scriptDoc,root,error,function(font)return font end)
	local scriptPage={Alive=true,Document=scriptDoc,DocumentURL='details.html',Root=root,Cleanups={}}
	function scriptPage:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	local scheduleCount=0
	local stop=Controller.start(scriptPage,scriptTree,function()scheduleCount+=1 end,error,
		{Input=input,Factory=factory,PlayerGui={GetGuiObjectsAtPosition=function()return hits end}})
	local realm=HTMLScripts.start(scriptPage,scriptTree,function()scheduleCount+=1 end,error)
	assert(realm);realm:Flush()
	local sn=DOM.findById(scriptDoc,'script-details');local sd=scriptTree.Disclosures[sn]
	local following=scriptTree.NodeBoxes[DOM.findById(scriptDoc,'following')]
	local scope=scriptTree.NodeBoxes[DOM.findById(scriptDoc,'scope')]
	local scriptEditor=scriptTree.Controls[2].Item.Editor
	local function arrangeScript(items)
		local stats=Dirty.begin(scriptTree,items);blocks.arrange(scriptTree,400,0,0,function()return true end);Dirty.finish(scriptTree,true);return stats
	end
	arrangeScript(nil)
	local summaryColor=sd.Summary.Style.Color
	local function flushScript(open)
		local needed,items=realm:Flush()
		assert(needed and items[sd.Box],'Changing open identifies the retained disclosure as a geometry target')
		assert(items[following],'Geometry from a related sibling selector must also be invalidated')
		assert(arrangeScript(items).Mode=='partial')
		assert(sd.Open==open and sd.Body.Gui.Visible==open)
		if open then
			assert(sd.Box.Gui.BackgroundColor3==Color3.fromRGB(229,236,255) and sd.Box.Gui.BackgroundTransparency==0)
			assert(sd.Summary.Style.Color==Color3.fromRGB(0,0,255) and scope.Style.Color==Color3.fromRGB(0,128,0),
				'Open-state CSS reaches descendants, siblings and :has ancestors')
			assert(following.ContentHeight==30)
		else
			assert(sd.Box.Gui.BackgroundTransparency==1 and sd.Summary.Style.Color==summaryColor)
		end
		assert(scriptTree.Controls[2].Item.Editor==scriptEditor,'Native and author toggles retain live editors')
		local height=sd.Box.OuterHeight;local afterY=following.LayoutY
		arrangeScript(nil);assert(sd.Box.OuterHeight==height and following.LayoutY==afterY,'Partial disclosure layout matches a full pass')
	end
	local scheduledBefore=scheduleCount
	click(sd.Summary.Gui)
	assert(sn.Attributes.open~=nil and realm:HasPending() and scheduleCount>scheduledBefore,'Native default action schedules its DOM batch')
	assert(realm.VM.Global.Bindings.mutations.Value==1 and realm.VM.Global.Bindings.oldOpen.Value=='null',
		'Native summary activation produces the normal open attribute mutation')
	flushScript(true)
	realm:Run('panel.open=false;if(panel.open!==false||panel.hasAttribute("open"))throw new Error("details.open reflects attribute presence");');flushScript(false)
	realm:Run('panel.setAttribute("open","false");if(panel.open!==true)throw new Error("details.open reflects attribute presence");');flushScript(true)
	click(sd.Summary.Gui,Enum.UserInputType.Touch);flushScript(false)
	assert(realm.VM.Global.Bindings.mutations.Value==4,'Touch and author attribute changes each notify observers once')
	for i=#scriptPage.Cleanups,1,-1 do scriptPage.Cleanups[i]() end
	stop();assert(input.InputBegan:Count()==0)
	local delayedDoc=Parser.parse('<style>details[open]{background:#e5ecff}</style><details id="delayed"><summary>More</summary><p>Body</p></details>')
	local delayedTree=renderer.build(delayedDoc,root,error,function(font)return font end)
	local delayedPage={Alive=true,Document=delayedDoc,Root=root}
	function delayedPage:AddCleanup(fn)self.Cleanup=fn end
	local delayed=delayedTree.Disclosures[DOM.findById(delayedDoc,'delayed')]
	local deferredRequests=0
	local delayedStop=Controller.start(delayedPage,delayedTree,function(force,item)
		assert(not force and item==delayed.Box);deferredRequests+=1
	end,error,{Input=input,Factory=factory,PlayerGui={GetGuiObjectsAtPosition=function()return hits end}})
	delayedTree.LayoutInProgress=true
	click(delayed.Summary.Gui)
	assert(delayed.Node.Attributes.open~=nil and not delayed.Open and not delayed.Body.Gui.Visible and deferredRequests==1,
		'Activation during layout updates DOM and queues paint without mutating active render geometry')
	assert(not delayedTree:FlushCSSStates() and delayedTree.PendingDisclosureChanges)
	delayedTree.LayoutInProgress=false;delayedTree.LayoutNeedsRecovery=true
	assert(not delayedTree:FlushCSSStates() and delayedTree.PendingDisclosureChanges,'Canceled layout retains the pending open state')
	delayedTree.LayoutNeedsRecovery=false
	local updated,needed,targets=delayedTree:FlushCSSStates()
	assert(updated and needed and targets[delayed.Box] and delayed.Open and delayed.Body.Gui.Visible and not delayedTree.PendingDisclosureChanges)
	assert(delayed.Box.Gui.BackgroundColor3==Color3.fromRGB(229,236,255) and delayed.Box.Gui.BackgroundTransparency==0)
	delayedStop();assert(input.InputBegan:Count()==0)
	local groupDoc=Parser.parseDocument('<!doctype html><details name="n" id="first" open><summary>First</summary><input value="Keep"></details><details name="n" id="second"><summary>Second</summary><input value="Stay"></details>')
	local groupTree=renderer.build(groupDoc,root,error,function(font)return font end)
	blocks.arrange(groupTree,400,0,0,function()return true end)
	local groupPage={Alive=true,Document=groupDoc,Root=root}
	function groupPage:AddCleanup(fn)self.Cleanup=fn end
	local jobs,targets={},{ }
	local groupStop=Controller.start(groupPage,groupTree,function(force,item)assert(not force);targets[item]=true end,error,
		{Input=input,Factory=factory,PlayerGui={GetGuiObjectsAtPosition=function()return hits end},Task={
			defer=function(fn)local job={Callback=fn};table.insert(jobs,job);return job end,
			cancel=function(job)job.Callback=nil end}})
	local first=groupTree.Disclosures[DOM.findById(groupDoc,'first')]
	local second=groupTree.Disclosures[DOM.findById(groupDoc,'second')]
	local retained=first.Body.Gui
	for _,job in jobs do if job.Callback then local fn=job.Callback;job.Callback=nil;fn()end end
	local toggleEvents={}
	groupPage.Events:On(first.Node,'toggle',function(e)table.insert(toggleEvents,e);assert(not e.Bubbles and not e.Cancelable)end)
	click(second.Summary.Gui)
	assert(not first.Open and second.Open and first.Body.Gui==retained and targets[first.Box] and targets[second.Box],
		'Native grouped activation updates both retained disclosures in the same batch')
	assert(#toggleEvents==0,'Native toggles are deferred')
	for _,job in jobs do if job.Callback then local fn=job.Callback;job.Callback=nil;fn()end end
	assert(#toggleEvents==1 and toggleEvents[1].Data.oldState=='open' and toggleEvents[1].Data.newState=='closed')
	groupTree.LayoutInProgress=true;table.clear(targets);click(first.Summary.Gui)
	assert(not first.Open and second.Open and first.Node.Attributes.open~=nil and second.Node.Attributes.open==nil,
		'Grouped DOM updates are immediate while active render geometry remains untouched')
	assert(targets[first.Box] and targets[second.Box] and groupTree.PendingDisclosureChanges[first.Node] and groupTree.PendingDisclosureChanges[second.Node])
	groupTree.LayoutInProgress=false;groupTree:FlushCSSStates()
	assert(first.Open and not second.Open and first.Body.Gui==retained)
	groupStop();assert(input.InputBegan:Count()==0)
	print('Details: native/author open CSS, observer records, related selectors, retained input, partial layout and cleanup passed')
end
