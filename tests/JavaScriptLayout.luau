--!strict
-- Compare mutation/reflow with an independently built tree of the final DOM.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,demoHTML,demoCSS)
	local factory={create=function(_,parent,properties)
		local gui=table.clone(properties);gui.Parent=parent
		function gui:Destroy()self.Destroyed=true end
		return gui
	end}
	local measureCalls={}
	local nativeWidths={}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},
		["Layout/TextMeasure"]={measure=function(text,_,size)
			measureCalls[text]=(measureCalls[text] or 0)+1
			return {X=(nativeWidths[text] or (utf8.len(text) or 0)*.45)*size,Y=size}
		end}}
	local words=loadWordLayout(overrides)
	local wordCalls={}
	overrides["Layout/WordLayout"]={arrange=function(run,...)
		wordCalls[run]=(wordCalls[run] or 0)+1
		return words.arrange(run,...)
	end,paintFragments=words.paintFragments}
	local renderer,layout=loadRenderTree(factory),loadBlockLayout(overrides)
	local css=".cards {display:grid;grid-template-columns:1fr 1fr;gap:12px}.card {padding:8px} [hidden]{display:none!important}"
	local document=Parser.parseDocument('<!doctype html><html><body><section id="intro"><h1>Unchanged heading</h1><p>Unchanged introductory content</p></section><div class="cards"><div class="card" id="a"><p id="text">Before <span id="span" style="opacity:.5">inline</span> after.</p></div><div id="b" class="card">Second card</div><div id="c" class="card">Third card</div></div><section id="following"><p>Following paragraph</p></section></body></html>')
	local function build(doc,styles)return renderer.build(doc,{},error,function(font)return font end,nil,nil,nil,styles or css)end
	local tree=build(document)
	local function arrange(t,width,items)
		t:SetMediaEnvironment(width,500);t.ViewportHeight=500
		local stats=Dirty.begin(t,items);local height=layout.arrange(t,width,0,0,function()return true end);Dirty.finish(t,true)
		return height,stats
	end
	local function snapshot(t)
		local parts={}
		local function add(v)table.insert(parts,if type(v)=="number" then string.format("%.4f",v) else tostring(v))end
		local function walk(box)
			if box.Style and box.Style.Hidden then add("hidden");return end
			add(box.Kind);add(box.Node and ((box.Node.Attributes and box.Node.Attributes.id) or box.Node.Name) or "anonymous");for _,key in {"LayoutX","LayoutY","OuterWidth","OuterHeight","ContentWidth","ContentHeight","LocalRight","LocalBottom","UnclippedRight","UnclippedBottom"} do add(box[key]) end
			for _,item in box.Items or {} do add(item.Text);for _,key in {"X","Y","Width","Height","Baseline"} do add(item[key]) end end
			for _,child in box.Children or {} do walk(child) end
		end
		walk(t);return table.concat(parts,"|")
	end
	local function mismatch(live,reference)
		local a,b=string.split(snapshot(live),"|"),string.split(snapshot(reference),"|")
		local result={}
		for i=1,math.max(#a,#b) do if a[i]~=b[i] then
			table.insert(result," token "..i.." live="..table.concat(a,"|",math.max(1,i-2),math.min(#a,i+2)).." fresh="..table.concat(b,"|",math.max(1,i-2),math.min(#b,i+2)))
		end end
		return table.concat(result,"\n",math.max(1,#result-4),#result)
	end
	local probeDoc=Parser.parseDocument('<!doctype html><html><body><p id="probe">ProbeUnique WordUnique</p></body></html>')
	local probeTree=build(probeDoc)
	local probeBox=probeTree.NodeBoxes[Node.findById(probeDoc,"probe")]
	layout.naturalWidth(probeBox.Children[1],320,function()return true end,true)
	layout.naturalWidth(probeBox.Children[1],320,function()return true end,false)
	for _,item in probeBox.Children[1].Items do assert(item.X==nil and item.Y==nil,"Intrinsic probes do not assign painted positions") end
	arrange(probeTree,320)
	assert(measureCalls.ProbeUnique==1 and measureCalls.WordUnique==1,"Min/max/final layout reuse each item's native bounds")
	-- Equal character counts do not prove equal bounds in a proportional font.
	nativeWidths["1"],nativeWidths["8"] = .3,.7
	local localDoc=Parser.parseDocument('<!doctype html><html><body><div style="display:grid;grid-template-columns:auto 1fr"><p id="count">1</p><p>Neighbour</p></div></body></html>')
	local localTree=build(localDoc)
	local localRealm=Runtime.new(localDoc,{Diagnostic=error,Schedule=function()end,
		ValidateText=function(node)localTree:ValidateTextMutation(node)end,
		ApplyChanges=function(changes)return localTree:ApplyDOMChanges(changes)end})
	arrange(localTree,420)
	local localBox=localTree.NodeBoxes[Node.findById(localDoc,"count")]
	localRealm:Run('document.getElementById("count").textContent="8";')
	local localNeeded,localItems=localRealm:Flush()
	assert(localNeeded and localBox.PendingTextLayout,"Single words are eligible for a local measurement")
	assert(not localTree:CanKeepTextLayout(localBox,words.arrange,function()return true end),"Different glyph bounds require normal track layout")
	arrange(localTree,420,localItems)
	local localFresh=build(Node.cloneNode(localDoc,true));arrange(localFresh,420)
	assert(snapshot(localTree)==snapshot(localFresh),"Proportional digit changes match a full grid layout")
	localRealm:Run('document.getElementById("count").textContent="1";document.getElementById("count").style.fontSize="24px";')
	localNeeded,localItems=localRealm:Flush()
	assert(localNeeded and not localBox.PendingTextLayout,"A mixed geometry/style batch bypasses the local text shortcut")
	arrange(localTree,420,localItems)
	localFresh=build(Node.cloneNode(localDoc,true));arrange(localFresh,420)
	assert(snapshot(localTree)==snapshot(localFresh),"Mixed text/style changes match a full layout")
	localRealm:Destroy();nativeWidths["1"],nativeWidths["8"]=nil,nil
	-- The local path requires an unchanged inline structure. Removing an <i>
	-- wrapper also changes font metrics and must use the normal dirty reflow.
	local rankDoc=Parser.parseDocument('<!doctype html><html><body><div style="position:relative"><div id="count"><p>Before</p></div><div id="word">2</div></div></body></html>')
	local rankTree=build(rankDoc);arrange(rankTree,420)
	local rankBox=rankTree.NodeBoxes[Node.findById(rankDoc,"word")]
	local oldRank=rankBox.Children[1].Items[1].Gui.ZIndex
	local rankRealm=Runtime.new(rankDoc,{Diagnostic=error,Schedule=function()end,
		ValidateText=function(node)rankTree:ValidateTextMutation(node)end,
		ApplyChanges=function(changes)return rankTree:ApplyDOMChanges(changes)end})
	rankRealm:Run('document.getElementById("word").textContent="3";')
	rankRealm:Flush()
	assert(rankTree:CanKeepTextLayout(rankBox,words.arrange,function()return true end),"A replacement word can keep unchanged local geometry")
	assert(rankBox.Children[1].Items[1].Gui.ZIndex==oldRank,"Local text replacements preserve positioned paint ranking")
	rankRealm:Destroy()
	-- A wider word fitting an ordinary block changes neither sibling positions
	-- nor fixed/fr grid sizing. Intrinsic layouts and overflow still propagate.
	local capacityCases={
		{HTML='<p id="word">Neuigkeiten: nein</p><p>Below</p>',Text="Neuigkeiten: ja",Local=true},
		{HTML='<p id="word">Neuigkeiten: ja</p><p>Below</p>',Text="Neuigkeiten: nein",Local=true},
		{HTML='<p id="word">Neuigkeiten: <strong>nein</strong></p><p>Below</p>',Text="Neuigkeiten: ja",Local=false},
		{HTML='<p id="word" style="width:60px">alpha beta gamma delta</p><p>Below</p>',Text="alpha theta gamma delta",Local=true},
		{HTML='<p id="word" style="width:60px">alpha beta gamma delta</p><p>Below</p>',Text="alpha beta gamma delta extra",Local=false},
		{HTML='<p id="word" style="width:60px">alpha beta gamma delta</p><p>Below</p>',Text="short answer",Local=false},
		{HTML='<div style="opacity:.5"><p id="word">Neuigkeiten: nein</p></div><p>Below</p>',Text="Neuigkeiten: ja",Local=false},
		{HTML='<div><p id="word" style="text-align:center">9</p><p>Below</p></div>',Local=true},
		{HTML='<div><p id="word" style="text-align:right">9</p><p>Below</p></div>',Local=true},
		{HTML='<div style="display:grid;grid-template-columns:150px 1fr"><div><p id="word">9</p></div><p>Side</p></div>',Local=true},
		{HTML='<div style="display:grid;grid-template-columns:minmax(0,1fr) 1fr"><div><p id="word">9</p></div><p>Side</p></div>',Local=true},
		{HTML='<div style="display:grid;grid-template-columns:auto 1fr"><div><p id="word">9</p></div><p>Side</p></div>',Local=false},
		{HTML='<div style="display:grid;grid-template-columns:minmax(max-content,1fr) 1fr"><div style="min-width:0"><p id="word">9</p></div><p>Side</p></div>',Local=false},
		{HTML='<div style="display:flex"><div><p id="word">9</p></div><p>Side</p></div>',Local=false},
		{HTML='<p id="word" style="display:inline-block">9</p><p>Below</p>',Local=false},
		{HTML='<div style="position:relative"><p id="word" style="position:absolute;right:0">9</p><p>Below</p></div>',Local=false},
		{HTML='<div style="width:20px"><p id="word" style="font-size:64px">9</p><p>Below</p></div>',Local=false},
	}
	for _,case in capacityCases do
		local doc=Parser.parseDocument('<!doctype html><html><body>'..case.HTML..'</body></html>')
		local live=build(doc);local height=arrange(live,420)
		local target=live.NodeBoxes[Node.findById(doc,"word")]
		local realm=Runtime.new(doc,{Diagnostic=error,Schedule=function()end,
			ValidateText=function(node)live:ValidateTextMutation(node)end,
			ApplyChanges=function(changes)return live:ApplyDOMChanges(changes)end})
		realm:Run('document.getElementById("word").textContent="'..(case.Text or "10")..'";')
		local needed,items=realm:Flush();assert(needed)
		local kept=live:CanKeepTextLayout(target,words.arrange,function()return true end)
		assert(kept==case.Local,"Unexpected capacity decision: "..case.HTML)
		if kept and target.Children[1].CachedLayout then
			assert(target.Children[1].CachedLayout.Width==target.Children[1].LocalRight,"The text-run cache stores its new horizontal extent")
		end
		if not kept then height=arrange(live,420,items) end
		local fresh=build(Node.cloneNode(doc,true));local freshHeight=arrange(fresh,420)
		assert(height==freshHeight and snapshot(live)==snapshot(fresh),"Capacity shortcut matches full layout: "..case.HTML..mismatch(live,fresh))
		-- A later dirty pass may reuse the updated text-run cache.
		height=arrange(live,420,{[live.NodeBoxes[Node.findById(doc,"word").Parent]]=true})
		assert(height==freshHeight and snapshot(live)==snapshot(fresh),"Later partial layout retains the new word bounds")
		realm:Destroy()
	end
	local events=Events.new(error)
	local runtime=Runtime.new(document,{Events=events,Diagnostic=error,Schedule=function()end,
		ValidateText=function(node)tree:ValidateTextMutation(node)end,
		ApplyChanges=function(changes)return tree:ApplyDOMChanges(changes)end})
	arrange(tree,600)
	for _,width in {600,280,850} do
		arrange(tree,width) -- Resize deliberately invalidates the previous width.
		local context,generation=tree.DirtyContext,tree.DirtyContext.Generation
		for _,text in {"A much longer inline value that must wrap across several lines", "x", "", "Restored"} do
			local previousItems=table.clone(tree.TextItems)
			local previousCalls=table.clone(wordCalls)
			runtime:Run('document.getElementById("span").textContent = "'..text..'"; document.getElementById("b").hidden = '..(if text=="x" then 'true' else 'false')..';')
			local needed,items=runtime:Flush()
			assert(needed and items[tree.NodeBoxes[Node.findById(document,"text")]],"Text updates identify their layout owner")
			assert(tree.DirtyContext==context and context.Generation==generation,"Mutations preserve the dirty generation")
			for _,item in previousItems do if item.TextOwner==tree.NodeBoxes[Node.findById(document,"text")] then assert(context.Owners[item]==nil,"Drop obsolete text ownership") end end
			local height,stats=arrange(tree,width,items)
			local targetNames={};for item,reason in items do table.insert(targetNames,((item.Node and ((item.Node.Attributes and item.Node.Attributes.id) or item.Node.Name)) or "root")..":"..tostring(reason)) end
			assert(stats.Mode=="partial" and stats.Reused>0,"Live DOM uses actual subtree cache hits: "..width.." "..text.." "..stats.Mode.." "..stats.Reused.." "..table.concat(targetNames,","))
			for _,id in {"intro","following"} do
				for _,child in tree.NodeBoxes[Node.findById(document,id)].Children do
					if child.Kind=="Words" then assert(wordCalls[child]==previousCalls[child],"Unchanged branches only move, without text layout") end
					for _,run in child.Children or {} do if run.Kind=="Words" then assert(wordCalls[run]==previousCalls[run],"Unchanged nested paragraphs keep measured lines") end end
				end
			end
			local independent=build(Node.cloneNode(document,true))
			local freshHeight=arrange(independent,width)
			assert(height==freshHeight and snapshot(tree)==snapshot(independent),"Live text/grid updates must match a fresh layout at width "..width)
			for _,item in tree.TextItems do assert(not item.Gui or not item.Gui.Destroyed,"No dead selection labels") end
		end
	end
	local sameNode=Node.findById(document,"span").Children[1]
	runtime:Run('document.getElementById("span").textContent = "Restored";')
	assert(not runtime:HasPending(),"Identical plain text does not schedule rendering")
	assert(sameNode.Parent==nil and Node.findById(document,"span").Children[1]~=sameNode,"DOM text-node replacement remains browser-like")
	local beforeColor=#tree.TextItems
	runtime:Run('document.getElementById("span").style.color = "red";')
	assert(not runtime:Flush() and #tree.TextItems==beforeColor,"Inline color changes do not rebuild text or request layout")
	local coloredItem=tree.NodeBoxes[Node.findById(document,"text")].Children[1].Items[2]
	for _,item in tree.TextItems do if item.Text=="Restored" then coloredItem=item;break end end
	local coloredGui=coloredItem.TextGui or coloredItem.Gui
	runtime:Run('document.getElementById("span").style.color = "blue";document.querySelector("#following p").textContent="Changed lower paragraph";')
	local mixedNeeded,mixedItems=runtime:Flush()
	assert(mixedNeeded and coloredGui.TextColor3==Color3.fromRGB(0,0,255),"Mixed paint/layout batches repaint cached siblings")
	assert(not mixedItems[tree.NodeBoxes[Node.findById(document,"text")]],"Pure inline color is not a dirty geometry target")
	arrange(tree,850,mixedItems)
	-- Changing geometry in preceding siblings through :has still invalidates them.
	local variants={
		'<div style="display:flex;flex-wrap:wrap;gap:7px"><div><p id="text"><span id="span">Initial</span></p></div><div id="b"><p>Other item</p></div></div>',
		'<div style="display:grid;grid-template-columns:auto 1fr;gap:7px"><div><p id="text"><span id="span">Initial</span></p></div><div id="b"><p>Other item</p></div></div>',
		'<div style="position:relative"><p id="text"><span id="span">Initial</span></p><div id="b" style="position:absolute;right:0;bottom:0">Pinned</div></div>',
		'<div style="opacity:.5"><p id="text"><span id="span">Initial</span></p><div id="b">Group</div></div>',
		'<div style="width:150px;height:40px;overflow:auto"><p id="text"><span id="span">Initial</span></p><div id="b">Scrolling content</div></div>',
		'<div style="column-count:2"><p id="text"><span id="span">Initial</span></p><div id="b">Column content</div></div>',
		'<div><div id="b" style="float:left;width:50px;height:40px">Float</div><p id="text"><span id="span">Initial</span></p></div>',
	}
	for _,fragment in variants do
		local doc=Parser.parseDocument('<!doctype html><html><head><style>body:has(.grown) #before {font-size:22px}</style></head><body><p id="before">Before</p>'..fragment..'<p>After</p></body></html>')
		local live=build(doc)
		local bus=Events.new(error)
		local realm=Runtime.new(doc,{Events=bus,Diagnostic=error,Schedule=function()end,ValidateText=function(node)live:ValidateTextMutation(node)end,ApplyChanges=function(changes)return live:ApplyDOMChanges(changes)end})
		arrange(live,420)
		for _,text in {"A longer string that wraps across several lines", "x", "", "Initial"} do
			realm:Run('document.getElementById("span").textContent="'..text..'";document.getElementById("span").className="'..(if text=="x" then "grown" else "")..'";document.getElementById("b").hidden='..(if text=="" then "true" else "false")..';')
			local needed,items=realm:Flush();assert(needed)
			local height,stats=arrange(live,420,items)
			local independent=build(Node.cloneNode(doc,true));local freshHeight=arrange(independent,420)
			assert(stats.Mode=="partial" and height==freshHeight and snapshot(live)==snapshot(independent),"Partial/full mismatch ("..text.."): "..fragment..mismatch(live,independent))
		end
		realm:Destroy();bus:Destroy()
	end
	-- A startup script may synchronously dispose its page or realm through a
	-- host callback. Neither case may continue into retained-control refresh.
	for _,mode in {"parsed","parser"}do for _,target in {"page","runtime","both"}do
		local source='<script>throw new Error("startup lifecycle boundary")</script><p>After</p>'
		local parser=if mode=="parser"then Parser.newDocument(source,{ScriptingEnabled=true})else nil
		local first=if parser then parser:Advance()else nil
		local doc=if parser then parser.Document else Parser.parseDocument(source)
		local live=build(doc)
		local bus=Events.new(error)
		local model=FormModel.new(doc,live.Controls,bus,function()end)
		local page={Alive=true,Document=doc,Root={},Events=bus,FormModel=model,Cleanups={},ParserSession=parser,ParserFirstScript=first}
		local refreshes,callbacks=0,0
		function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
		function page:RefreshDOMControls()refreshes+=1 end
		local returned=HTMLScripts.start(page,live,function()end,function(message)
			callbacks+=1
			assert(string.find(message,"startup lifecycle boundary",1,true))
			assert(page.JavaScriptRuntime and page.JavaScriptRuntime.Started,"Disposal occurs inside the real Runtime.Start script execution")
			if target~="runtime"then page.Alive=false end
			if target~="page"then page.JavaScriptRuntime:Destroy()end
		end)
		assert(callbacks==1 and returned==nil and refreshes==0,"Disposed "..mode.." "..target.." must not publish a runtime or refresh controls after Start")
		assert(page.JavaScriptRuntime.Alive==(target=="page"),"The page-only case independently exercises the page guard")
		for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end
		assert(not page.JavaScriptRuntime.Alive,"Registered cleanup still releases the page-only realm")
		model:Destroy();bus:Destroy()
	end end
	-- The actual browser/Studio page goes through the mounted-page JS adapter.
	local demoDoc=Parser.parseDocument(demoHTML)
	local demo=build(demoDoc,demoCSS)
	local demoEvents=Events.new(error)
	local demoModel=FormModel.new(demoDoc,demo.Controls,demoEvents,function()end)
	local demoPage={Document=demoDoc,Root={},Events=demoEvents,FormModel=demoModel}
	local demoRefreshes=0
	function demoPage:AddCleanup()end
	function demoPage:SetValue(node,value)demoModel:SetValue(demoModel:Resolve(node),value)end
	function demoPage:RefreshDOMControls()demoRefreshes+=1 end
	local demoRealm=HTMLScripts.start(demoPage,demo,function()end,error)
	assert(demoPage.Alive==nil and demoRealm and demoRealm.Alive and demoRefreshes==1,"A legacy page adapter without an Alive flag still starts and refreshes its controls")
	demoRealm:Flush()
	for _,width in {1000,560,320} do
		arrange(demo,width)
		local function verify(action,expected,expectedLocal,forceReflow)
			local prior=table.clone(wordCalls)
			local priorMeasures=table.clone(measureCalls)
			local context,generation=demo.DirtyContext,demo.DirtyContext.Generation
			action()
			local needed,items=demoRealm:Flush()
			if expected~=nil then assert(needed==expected,"Unexpected demo layout request") end
			if needed then
				assert(items and next(items),"Demo mutations retain dirty targets")
				local remaining={}
				local localDebug={}
				for item in items do
					if forceReflow then item.PendingTextLayout=nil end
					local saved=item.PendingTextLayout
					if saved then table.insert(localDebug,"independent="..tostring(saved.IndependentWidth).." available="..saved.Width) end
					if not demo:CanKeepTextLayout(item,overrides["Layout/WordLayout"].arrange,function()return true end) then remaining[item]=items[item] end
				end
				if expectedLocal~=nil then assert((next(remaining)==nil)==expectedLocal,"Unexpected counter layout at width "..width.." "..table.concat(localDebug,",")) end
				local height=demo.OuterHeight
				if next(remaining) then
					local stats; height,stats=arrange(demo,width,remaining)
					assert(stats.Mode=="partial" and stats.Reused>0,"Demo interactions reuse actual branches")
					if forceReflow then
						assert(stats.Recomputed<20,"Even a failed text preflight keeps checkbox reflow local ("..stats.Recomputed.." calls)")
						print(string.format("JavaScript checkbox fallback at %d px: %d layout calls, %d retained branches, %d retained measurements",width,stats.Recomputed,stats.Reused,stats.MeasurementReused or 0))
					end
				else
					for run,calls in prior do assert(wordCalls[run]==calls,"Local text changes never reflow existing runs") end
					assert(measureCalls["Neuigkeiten:"]==priorMeasures["Neuigkeiten:"],"The unchanged checkbox prefix reuses its native text bounds")
				end
				local fresh=build(Node.cloneNode(demoDoc,true),demoCSS)
				local freshHeight=arrange(fresh,width)
				assert(height==freshHeight and snapshot(demo)==snapshot(fresh),"Demo dirty/full mismatch: "..mismatch(demo,fresh))
			end
			assert(demo.DirtyContext==context and context.Generation==generation,"Demo interactions never invalidate the whole generation")
			for _,child in demo.NodeBoxes[Node.findById(demoDoc,"js-status")].Children do
				if child.Kind=="Words" then assert(wordCalls[child]==prior[child],"Intro status text is never laid out again for another section") end
			end
			assert(#demoRealm.Diagnostics==0,table.concat(demoRealm.Diagnostics,"\n"))
		end
		local function click(id)demoModel:Activate(demoModel:Resolve(id))end
		verify(function()click("increment")end,true,true)
		for _,value in {"2","3","4","5","6","7","8","9"} do
			verify(function()demoRealm:Run('document.getElementById("count").textContent="'..value..'";')end,true,true)
		end
		verify(function()demoRealm:Run('document.getElementById("count").textContent="10";')end,true,true)
		verify(function()demoRealm:Run('document.getElementById("count").textContent="99";')end,true,true)
		verify(function()demoRealm:Run('document.getElementById("count").textContent="100";')end,true,true)
		verify(function()click("reset")end,true,true)
		verify(function()demoRealm:Run('document.getElementById("count").textContent="123456789012345678901234567890";')end,true,false)
		verify(function()click("reset")end,true,false)
		verify(function()click("news")end,true,true)
		verify(function()click("news")end,true,true)
		verify(function()click("news")end,true,false,true)
		verify(function()click("news")end,true,false,true)
		verify(function()click("toggle")end,true)
		verify(function()click("toggle")end,true)
		verify(function()demoModel:SetValue(demoModel:Resolve("search"),"HOLZ",true)end,true)
		verify(function()demoModel:SetValue(demoModel:Resolve("search"),"HOL",true)end,false)
		verify(function()demoModel:SetValue(demoModel:Resolve("search"),"kein Treffer",true)end,true)
		verify(function()demoModel:SetValue(demoModel:Resolve("search"),"weiterhin kein Treffer",true)end,false)
		verify(function()demoModel:SetValue(demoModel:Resolve("search"),"",true)end,true)
		verify(function()click("color")end,false)
		verify(function()click("class-toggle")end,false)
	end
	demoRealm:Destroy();demoModel:Destroy();demoEvents:Destroy()
	-- Many siblings expose accidental whole-grid/flex probing. Retained cards
	-- must move with their row/flow without any word layout or native remeasurement.
	for _,display in {
		'display:block',
		'display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px',
		'display:grid;grid-template-columns:repeat(3,minmax(0,1fr));align-items:start;gap:9px',
		'display:flex;flex-wrap:wrap;align-items:flex-start;gap:9px',
		'display:flex;flex-direction:column;align-items:stretch;gap:9px',
	} do
		local cards={}
		for index=1,36 do
			table.insert(cards,'<article id="card-'..index..'" style="min-width:0;width:120px;padding:3px;border:1px solid black"><p id="value-'..index..'">Card'..index..'</p><p>Retained'..index..'</p></article>')
		end
		local doc=Parser.parseDocument('<!doctype html><html><body><p id="before">BeforeUnchanged</p><section id="collection" style="'..display..'">'..table.concat(cards)..'</section><div id="after">AfterUnchanged</div></body></html>')
		local live=build(doc);local _,initialStats=arrange(live,420)
		local target=live.NodeBoxes[Node.findById(doc,"value-1")]
		local realm=Runtime.new(doc,{Diagnostic=error,Schedule=function()end,
			ValidateText=function(node)live:ValidateTextMutation(node)end,
			ApplyChanges=function(changes)return live:ApplyDOMChanges(changes)end})
		for _,text in {"A longer paragraph that needs several lines below", "short", "", "Card1"} do
			local callsBefore=table.clone(wordCalls);local boundsBefore=table.clone(measureCalls)
			realm:Run('document.getElementById("value-1").textContent="'..text..'";')
			local needed,items=realm:Flush();assert(needed and items[target]=="text")
			local retained=live:CanKeepTextLayout(target,overrides["Layout/WordLayout"].arrange,function()return true end)
			local height,stats=live.OuterHeight,nil
			if not retained then
				height,stats=arrange(live,420,items)
				assert(stats.Mode=="partial" and stats.Recomputed<20,"Changed text must not reflow the whole collection: "..display.." calls="..stats.Recomputed)
				if text=="A longer paragraph that needs several lines below" then
					print(string.format("Incremental collection (%s): %d full / %d changed layout calls, %d measurement hits",display,initialStats.Recomputed,stats.Recomputed,stats.MeasurementReused or 0))
				end
			end
			for index=4,36 do
				local card=live.NodeBoxes[Node.findById(doc,"card-"..index)]
				for _,paragraph in card.Children do for _,run in paragraph.Children or {} do
					assert(wordCalls[run]==callsBefore[run],"Unchanged cards retain their line layout: "..display.." "..index)
				end end
				assert(measureCalls["Card"..index]==boundsBefore["Card"..index] and measureCalls["Retained"..index]==boundsBefore["Retained"..index],"Unchanged cards reuse intrinsic bounds")
			end
			local after=live.NodeBoxes[Node.findById(doc,"after")].Children[1]
			assert(wordCalls[after]==callsBefore[after],"Following anonymous text only changes paint position")
			local fresh=build(Node.cloneNode(doc,true));local freshHeight=arrange(fresh,420)
			assert(height==freshHeight and snapshot(live)==snapshot(fresh),"Collection reflow/full mismatch: "..display..mismatch(live,fresh))
		end
		realm:Destroy()
	end
	runtime:Destroy();events:Destroy()
	print("JavaScript layout: counter and checkbox paragraph updates without parent layout, unchanged-word bounds reuse, stable multiline reflow, alignment/cache preservation, height/intrinsic-sizing/overflow fallback and dirty geometry match independent full layouts")
end
