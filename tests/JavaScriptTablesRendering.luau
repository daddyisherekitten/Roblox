--!strict
-- Exercise the production HTMLScripts -> DOMReconcile -> retained table grid,
-- not only a data-DOM adapter. Native GUI identities and input state survive.
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
		function gui:Destroy()assert(not self.Destroyed,"Native table GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local html=[=[<!doctype html><html><body><input id="outside" value="outside"><table id="t"><colgroup id="cols"><col id="column"></colgroup><thead id="head"><tr id="h"><th>Title</th><th>Note</th></tr></thead><tbody id="body"><tr id="a"><td id="keep"><input id="note" value="initial"><button type="button" id="button">Keep</button></td><td id="span">A</td></tr><tr id="b"><td>B</td><td>C</td></tr></tbody><tfoot id="foot"><tr id="f"><td>Footer</td><td>End</td></tr></tfoot></table><p id="after">After table.</p><table id="empty"></table><script>globalThis.tableReady=true;</script></body></html>]=]
	local document=Parser.parseDocument(html);local messages={};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,[=[
		table { border-collapse: collapse; width: 400px; } td,th { border: 1px solid #334455; padding: 6px; }
		thead { background: #ddeeff; } tbody { background: #eeeecc; } caption { padding: 8px; } input { width: 90px; }
	]=],nil,nil,nil,nil,nil,"https://example.test/table")
	local events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,DocumentURL="https://example.test/table",BaseURL="https://example.test/table",Root=root,FormModel=model,Events=events,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
	local realm,flushing=nil,false;local viewport={Width=760,Height=900,ClientWidth=760,ClientHeight=900,ScrollWidth=760,ScrollHeight=900,ScrollX=0,ScrollY=0}
	function page:GeometryViewport()return viewport end
	function page:HasPendingLayout()return false end
	local lastTargets;local arrangements=0
	local function arrange(targets)
		arrangements+=1
		tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
		viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		local needed,targets=realm:Flush();if needed then lastTargets=targets;arrange(targets)end;flushing=false
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
	local tableBox=tree.NodeBoxes[node("t")];local afterBox=tree.NodeBoxes[node("after")]
	local note=model:Resolve(node("note"));local outside=model:Resolve(node("outside"));local button=model:Resolve(node("button"))
	local inputGui,buttonGui,outsideGui,tableSurface=note.Item.Gui,button.Item.Gui,outside.Item.Gui,tableBox.Gui
	local function stable()
		assert(model:Resolve(node("note"))==note and note.Item.Gui==inputGui and note.Value=="edited","Table mutation lost native input identity or edited value")
		assert(model:Resolve(node("button"))==button and button.Item.Gui==buttonGui,"Table mutation lost native button identity")
		assert(model:Resolve(node("outside"))==outside and outside.Item.Gui==outsideGui,"Table mutation recreated unrelated control")
		assert(tree.NodeBoxes[node("after")]==afterBox,"Table mutation recreated following block")
	end
	run([=[
	const t=document.getElementById('t'), body=document.getElementById('body');
	const liveRows=t.rows, liveBodies=t.tBodies, liveCells=t.rows[1].cells;
	const check=(value,message)=>{if(!value)throw new Error(message);};
	document.getElementById('note').value='edited';globalThis.clicks=0;document.getElementById('button').onclick=()=>{clicks++;};
	check(liveRows===t.rows && liveBodies===t.tBodies && liveCells===t.rows[1].cells,'collection identity');
	check(t instanceof HTMLTableElement && body instanceof HTMLTableSectionElement && liveRows[0] instanceof HTMLTableRowElement && liveCells[0] instanceof HTMLTableCellElement,'table native interfaces');
	check(Object.getOwnPropertyDescriptor(HTMLTableElement.prototype,'rows').get.call(t)===liveRows,'table prototype live accessor');
	let branded=false;try{HTMLTableElement.prototype.insertRow.call(body);}catch(e){branded=e.name==='TypeError';}check(branded,'table operation receiver brand');
	branded=false;try{Object.getOwnPropertyDescriptor(HTMLTableRowElement.prototype,'cells').get.call(t);}catch(e){branded=e.name==='TypeError';}check(branded,'row accessor receiver brand');
	check(liveRows.length===4 && liveRows[0].id==='h' && liveRows[3].id==='f','table visual row order');
	check(t.caption===null && t.tHead.id==='head' && t.tFoot.id==='foot','section getters');
	check(liveRows[1].rowIndex===1 && liveRows[1].sectionRowIndex===0 && liveCells[1].cellIndex===1,'live indices');
	globalThis.mutations=[];const observer=new MutationObserver(records=>{for(const r of records)mutations.push(r.type);});observer.observe(t,{subtree:true,childList:true,attributes:true});
	const inserted=t.insertRow(2);inserted.id='new';inserted.insertCell().textContent='New';inserted.insertCell(0).textContent='First';
	check(liveRows.length===5 && liveRows[2]===inserted && inserted.cells.length===2,'insert row and cells');
	check(liveRows[3].rowIndex===3 && liveRows[3].sectionRowIndex===2,'indices after insertion');
	]=])
	stable();assert(#tableBox.TableRows==5 and #tableBox.TableGrid.Entries==10,"Production table grid did not add row/cells")
	assert(lastTargets and lastTargets[tableBox],"Local structural mutation must invalidate the shared table tracks")
	run([=[
	const cap=t.createCaption();cap.id='cap';cap.textContent='Project overview';check(t.createCaption()===cap,'createCaption idempotence');
	check(t.firstChild===cap && t.caption===cap,'caption placement');
	document.getElementById('span').colSpan=2;document.getElementById('span').rowSpan=0;
	check(document.getElementById('span').getAttribute('colspan')==='2' && document.getElementById('span').rowSpan===0,'span reflection');
	]=])
	stable();assert(tableBox.TableSurface==tableSurface and #tableBox.TableCaptions==1,"Caption insertion retains the table paint surface")
	local spanEntry;for _,entry in tableBox.TableGrid.Entries do if entry.Cell.Node==node("span")then spanEntry=entry end end
	assert(spanEntry and spanEntry.ColSpan==2 and spanEntry.RowSpan==3 and tableBox.TableGrid.Columns==4,"Live span reflection did not rebuild the grid or skip occupied slots")
	run([=[
	const second=t.createTBody();second.id='second';check(t.tBodies.length===2,'createTBody live view');
	second.appendChild(document.getElementById('a'));check(document.getElementById('a').rowIndex===3 && document.getElementById('a').sectionRowIndex===0,'moved row indices');
	check(liveCells===document.getElementById('a').cells && liveCells[0].id==='keep','cells survive move');
	document.getElementById('button').click();check(clicks===1,'button event retained');
	const isolated=document.createElement('tr');check(isolated.rowIndex===-1 && isolated.sectionRowIndex===-1,'detached row indices');
	const cell=isolated.insertCell();check(cell.cellIndex===0,'detached row cell');isolated.deleteCell(-1);check(cell.cellIndex===-1,'detached cell index');
	]=])
	stable();assert(tree.NodeBoxes[node("a")].Gui.Parent==tree.NodeBoxes[node("second")].Gui,"Moved row GUI retained old section parent")
	run([=[
	t.deleteCaption();check(t.caption===null,'delete caption');t.deleteRow(2);check(liveRows.length===4,'delete row');
	document.getElementById('new').deleteCell(0);check(document.getElementById('new').cells.length===1,'delete cell');
	document.getElementById('span').colSpan=1;document.getElementById('span').rowSpan=1;
	const conversion={valueOf(){const r=body.insertRow();r.id='converted';r.insertCell().textContent='Converted';return body.rows.length;}};
	body.insertRow(conversion).id='after-conversion';check(body.rows[body.rows.length-1].id==='after-conversion','index conversion runs before collection lookup');
	check(t.createTHead()===t.tHead && t.createTFoot()===t.tFoot,'section creators idempotent');
	]=])
	stable();assert(#tableBox.TableCaptions==0 and not tree.NodeBoxes[Node.findById(document,"cap")],"Caption removal kept its layout box")
	run([=[
	const empty=document.getElementById('empty');const e=empty.insertRow();check(empty.tBodies.length===1 && e.parentElement===empty.tBodies[0],'empty table creates tbody');
	check(e.insertCell(undefined).cellIndex===0,'optional undefined index');empty.deleteRow(-1);empty.deleteRow(-1);
	let invalid=0;for(const call of [()=>t.insertRow(-2),()=>body.deleteRow(999),()=>e.deleteCell(),()=>t.tHead=document.createElement('tbody')]){try{call();}catch(error){invalid++;}}
	check(invalid===4,'range and type errors');
	const span=document.getElementById('span');span.colSpan=0;check(span.colSpan===1 && span.getAttribute('colspan')==='1','colSpan clamps zero');
	span.colSpan=-1;check(span.colSpan===1000,'unsigned conversion and clamp');span.colSpan=1;
	span.rowSpan=999999;check(span.rowSpan===65534,'rowSpan clamp');span.rowSpan=1;
	span.setAttribute('colspan','garbage');check(span.colSpan===1,'invalid span getter');span.setAttribute('colspan',' +2junk');check(span.colSpan===2,'HTML unsigned parse');span.colSpan=1;
	check(t.rows.namedItem('a')===document.getElementById('a') && t.rows.a===document.getElementById('a'),'live named rows');
	check(mutations.length>0 && mutations.includes('attributes') && mutations.includes('childList'),'table mutation observers');
	]=])
	stable();assert(tableBox.TableGrid.Columns==2,"Reset spans did not restore column model")
	run([=[
	const replacement=document.createElement('thead');replacement.id='replacement';replacement.insertRow().insertCell().textContent='Replacement';t.tHead=replacement;
	check(t.tHead===replacement && t.rows[0].parentElement===replacement,'replace section');t.deleteTFoot();check(t.tFoot===null,'delete section');
	const col=document.getElementById('column');col.span=2;check(col.span===2 && col.getAttribute('span')==='2','column span reflection');
	t.style.borderCollapse='separate';
	]=])
	stable();assert(not tableBox.CollapsedBorders and not tableBox.TableBorderPaint,"Border mode edit left collapsed-border resources: "..tostring(tableBox.Style.BorderCollapse).."/"..tostring(tableBox.Style.CollapsedBorder).."/"..tostring(tableBox.CollapsedBorders~=nil))
	run("t.style.borderCollapse='collapse';")
	stable();assert(tableBox.CollapsedBorders and tableBox.TableBorderPaint,"Restoring collapsed borders did not rebuild retained paint")
	local beforePaint=arrangements
	run("document.getElementById('second').style.backgroundColor='#123456';document.getElementById('span').headers='title';")
	stable();assert(arrangements==beforePaint,"Row paint and header metadata must not arrange the table")
	for _,cleanup in page.Cleanups do cleanup()end;model:Destroy();events:Destroy();assert(not realm.Alive)
	print("JavaScript tables: live interfaces, Web IDL conversions, shared span/grid/caption/border refresh, retained controls/moves and observers passed")
end
