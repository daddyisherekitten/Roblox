--!strict
return function(VM: any, Runtime: any, Parser: any, Node: any, Events: any, loadRenderTree: any, HTMLScripts: any, FormModel: any, demoHTML: string, demoCSS: string)
	local values={}
	local vm=VM.new({record=function(args)table.insert(values,args[1])end})
	vm:Run([=[
record(typeof missing);
record("😀".length);
record("😀".charCodeAt(0));
record("abcdef".slice(1, 4));
record("HELLO".toLowerCase().includes("ell"));
var list = [1, 2]; list.push(3); list[5] = 6;
record(list.length); record(list.join("/")); list.length = 2;
record(list.map(function(x) { return x * 3; }).join(","));
function Box(value) { this.value = value; }
Box.prototype.read = function() { return this.value; };
const instance = new Box(7);
record(instance.read());
const counter = {value: 2, increment: function() { this.value += 1; return this.value; }};
record(counter.increment());
record(hoisted); var hoisted = 4;
var callbacks = []; for (let i = 0; i < 3; i++) { callbacks.push(function() { return i; }); }
record(callbacks[0]()); record(callbacks[2]());
]=])
	assert(values[1]=="undefined" and values[2]==2 and values[3]==55357)
	assert(values[4]=="bcd" and values[5]==true)
	assert(values[6]==6 and values[7]=="1/2/3///6" and values[8]=="3,6")
	assert(values[9]==7 and values[10]==3 and values[11]==VM.Undefined and values[12]==0 and values[13]==2)
	assert(not pcall(function()vm:Run("const unavailable = unavailable;")end),"Lexical initialization must not read itself")
	assert(not pcall(function()vm:Run("while (true) {}")end),"Runaway scripts must be bounded")
	vm:Run("record(9);");assert(values[#values]==9,"An error must not poison the next script")
	vm:Run([[record(null == 0);record("\uD83D\uDE00".length);record("😀".charAt(0)+"😀".charAt(1)==="😀");record("ÄÖÜ ẞ".toLowerCase());record(String(Infinity));]])
	assert(values[#values-4]==false and values[#values-3]==2 and values[#values-2]==true and values[#values-1]=="äöü ß" and values[#values]=="Infinity")
	vm:Destroy();assert(not pcall(function()vm:Run("record(0);")end))

	local guiCount,destroyed=0,0
	local factory={create=function(_,parent,properties)
		local gui=table.clone(properties);gui.Parent=parent;guiCount+=1
		function gui:Destroy()assert(not self.Destroyed,"Destroy once");self.Destroyed=true;destroyed+=1 end
		return gui
	end}
	local warnings,queue={},{ }
	local document=Parser.parseDocument([=[<!doctype html><html><head><style>
.highlight { color: red; } .card { display: block; } .card[hidden] { display: none; }
#scope:has(.highlight) .sibling { color: green; }
</style></head><body><main id="scope">
<button id="button" type="button">Count</button><p id="count">0</p>
<input id="search"><p id="matches">3 Treffer</p>
<div class="card" data-name="Alpha">Alpha</div><div class="card" data-name="Beta">Beta</div><div class="card" data-name="Gamma">Gamma</div>
<p class="sibling">Sibling <span id="inline">before</span></p>
<section id="panel" hidden><p>Inside</p></section>
</main><script>
window.runs = 1;
let count = 0;
const button = document.getElementById("button");
const countText = document.getElementById("count");
button.addEventListener("click", function() { count += 1; countText.textContent = String(count); });
const search = document.getElementById("search");
search.addEventListener("input", function(event) {
  const query = event.target.value.trim().toLowerCase();
  const cards = document.querySelectorAll(".card");
  let found = 0;
  cards.forEach(function(card) { card.hidden = !card.getAttribute("data-name").toLowerCase().includes(query); if (!card.hidden) { found += 1; } });
  document.getElementById("matches").textContent = found + " Treffer";
});
document.addEventListener("DOMContentLoaded", function() { window.ready = document.readyState; });
</script></body></html>]=])
	local root={AbsoluteSize=Vector2.new(600,600)}
	local tree=loadRenderTree(factory).build(document,root,function(message)table.insert(warnings,message)end)
	local events=Events.new(function(message)error(message)end)
	local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,DocumentURL="test.html",Root=root,Events=events,FormModel=model,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:SetValue(node,value)self.FormModel:SetValue(self.FormModel:Resolve(node),value)end
	local runtime=HTMLScripts.start(page,tree,function()table.insert(queue,true)end,function(message)table.insert(warnings,message)end)
	assert(runtime and runtime.ScriptsRun==1 and #runtime.Diagnostics==0,table.concat(runtime and runtime.Diagnostics or {},"\n"))
	runtime:PumpTasks() -- DOMContentLoaded is a document task after script execution.
	assert(runtime.Window.Get("runs")==1 and runtime.Window.Get("ready")=="interactive")
	assert(runtime.Window.Get("count").DOMNode==Node.findById(document,"count")and runtime.Window.GetOwnPropertyDescriptor("count")==nil,"Element IDs are inherited Window names; top-level let does not create an own property")
	assert(runtime:Run('window.lexicalCountForTest=count')and runtime.Window.Get('lexicalCountForTest')==0,"Lexical count still shadows the named element")
	runtime:Start();assert(runtime.ScriptsRun==1,"Starting/layouting twice does not reexecute scripts")
	local countNode=Node.findById(document,"count")
	local countBox=tree.NodeBoxes[countNode]
	local untouched=tree.NodeBoxes[Node.findById(document,"matches")].Children[1].Items[1].Gui
	model:Activate(model:Resolve("button"))
	assert(Node.textContent(countNode)=="1" and runtime:HasPending(),"DOM changes are synchronous")
	assert(countBox.Children[1].Items[1].Text=="0","Presentation waits for the batch")
	local countLayout,countItems=runtime:Flush()
	assert(countLayout and countItems[countBox] and countBox.Children[1].Items[1].Text=="1")
	assert(not untouched.Destroyed and tree.NodeBoxes[countNode]==countBox,"Keep unrelated GUI and box identity")
	local firstCountGui=countBox.Children[1].Items[1].Gui
	for _=1,15 do model:Activate(model:Resolve("button"));runtime:Flush() end
	assert(firstCountGui.Destroyed and Node.textContent(countNode)=="16")
	local retained=0;for _,item in tree.TextItems do if item.TextOwner==countBox then retained+=1 end end
	assert(retained==1,"Replaced text labels must leave selection/hit indexes")
	local search=model:Resolve("search")
	model:SetValue(search,"  beta ",true)
	assert(runtime:Flush())
	local cards={};for node,style in tree.NodeStyles do if node.Attributes and node.Attributes.class=="card" then table.insert(cards,{node,style}) end end
	local visible=0;for _,card in cards do if not card[2].Hidden then visible+=1;assert(card[1].Attributes["data-name"]=="Beta")end end
	assert(visible==1 and Node.textContent(Node.findById(document,"matches"))=="1 Treffer")
	model:SetValue(search,"nothing matches",true);runtime:Flush()
	for _,card in cards do assert(card[2].Hidden) end
	model:SetValue(search,"",true);runtime:Flush()
	for _,card in cards do assert(not card[2].Hidden) end
	runtime:Run([=[document.getElementById("count").classList.add("highlight");]=])
	assert(runtime:Flush()==false,"Color-only class changes must not request layout")
	assert(countBox.Style.Color==Color3.fromRGB(255,0,0))
	for node,style in tree.NodeStyles do if node.Attributes and node.Attributes.class=="sibling" then assert(style.Color==Color3.fromRGB(0,128,0),":has updates other elements") end end
	runtime:Run([=[document.getElementById("inline").textContent = "after more words"; document.getElementById("panel").hidden = false;]=])
	assert(runtime:Flush());assert(Node.textContent(Node.findById(document,"inline"))=="after more words")
	assert(not tree.NodeBoxes[Node.findById(document,"panel")].Style.Hidden)
	runtime:Run([=[document.getElementById("count").style.setProperty("color", "blue", "important");]=])
	assert(not runtime:Flush() and countBox.Style.Color==Color3.fromRGB(0,0,255))
	runtime:Run([=[document.getElementById("count").style.color = "invalid-color";]=])
	assert(not runtime:HasPending(),"Invalid CSSOM writes preserve the declaration")
	local oldFailures=#runtime.Diagnostics
	-- Ordinary textContent replacement now has a structural renderer route.
	-- Keep the original atomic-negative assertion for a genuinely forbidden
	-- Document insertion; it must still reject before removing any controls.
	runtime:Run([=[document.getElementById("scope").appendChild(document);]=])
	assert(#runtime.Diagnostics==oldFailures+1 and Node.findById(document,"button"),"Reject unsupported structural edits before changing the DOM")
	local eventOrder={}
	local target=Node.findById(document,"button")
	events:On(document,"sample",function(e)table.insert(eventOrder,"capture");assert(e.Phase==1)end,true)
	events:On(target,"sample",function(e)table.insert(eventOrder,"target");e:PreventDefault()end)
	events:On(document,"sample",function(e)table.insert(eventOrder,"bubble");assert(e.Phase==3)end)
	assert(events:Emit(target,"sample").DefaultPrevented and table.concat(eventOrder,",")=="capture,target,bubble")
	runtime:Run([=[
window.onceCount = 0; window.thisOK = false;
function onceListener() { window.onceCount += 1; window.thisOK = this === button; }
button.addEventListener("custom", onceListener, {once: true});
]=])
	events:Emit(target,"custom");events:Emit(target,"custom")
	assert(runtime.Window.Get("onceCount")==1 and runtime.Window.Get("thisOK")==true)
	runtime:Run([=[button.addEventListener("custom", onceListener); button.removeEventListener("custom", onceListener);]=])
	events:Emit(target,"custom");assert(runtime.Window.Get("onceCount")==1)
	local detached=runtime.DOM.Wrap(countNode)
	runtime:Destroy();events:Emit(target,"click")
	assert(not runtime:HasPending() and not pcall(function()detached.Get("id")end))
	events:Destroy();model:Destroy()
	assert(destroyed>0 and guiCount>destroyed)
	local demoDocument=Parser.parseDocument(demoHTML)
	local demoWarnings={}
	local demoTree=loadRenderTree(factory).build(demoDocument,root,function(m)table.insert(demoWarnings,m)end,nil,nil,nil,nil,demoCSS)
	local demoEvents=Events.new(error)
	local demoModel=FormModel.new(demoDocument,demoTree.Controls,demoEvents,function()end)
	local demoPage={Alive=true,Document=demoDocument,Root=root,Events=demoEvents,FormModel=demoModel}
	function demoPage:AddCleanup()end
	function demoPage:SetValue(node,value)demoModel:SetValue(demoModel:Resolve(node),value)end
	local demoRuntime=HTMLScripts.start(demoPage,demoTree,function()end,function(m)table.insert(demoWarnings,m)end)
	demoRuntime:PumpTasks()
	local function read(id)return Node.textContent(Node.findById(demoDocument,id))end
	local function click(id)demoModel:Activate(demoModel:Resolve(id));demoRuntime:Flush()end
	demoRuntime:Flush()
	assert(#demoRuntime.Diagnostics==0,table.concat(demoRuntime.Diagnostics,"\n"))
	assert(read("js-status"):find("JavaScript aktiv",1,true))
	click("increment");click("increment");assert(read("count")=="2")
	click("toggle");assert(not demoTree.NodeBoxes[Node.findById(demoDocument,"details")].Style.Hidden);assert(Node.findById(demoDocument,"details").Attributes.hidden==nil and read("toggle")=="Details schließen")
	click("toggle");assert(Node.findById(demoDocument,"details").Attributes.hidden~=nil and read("toggle")=="Details öffnen")
	demoModel:SetValue(demoModel:Resolve("search"),"HOLZ",true);demoRuntime:Flush();assert(read("matches")=="2 Projekte")
	local labelsBefore=guiCount
	demoModel:SetValue(demoModel:Resolve("search"),"HOL",true)
	assert(not demoRuntime:HasPending() and guiCount==labelsBefore,"Identical search results need no DOM/render work")
	demoModel:SetValue(demoModel:Resolve("search"),"xyz",true);demoRuntime:Flush();assert(read("matches")=="0 Projekte")
	assert(Node.findById(demoDocument,"empty").Attributes.hidden==nil and not demoTree.NodeBoxes[Node.findById(demoDocument,"empty")].Style.Hidden)
	click("color");click("class-toggle")
	demoModel:Activate(demoModel:Resolve("news"))
	local newsLayout,newsItems=demoRuntime:Flush()
	local selectionBox=demoTree.NodeBoxes[Node.findById(demoDocument,"selection")]
	assert(newsLayout and newsItems[selectionBox] and read("selection")=="Neuigkeiten: ja")
	local newsTargets=0;for _ in newsItems do newsTargets+=1 end
	assert(newsTargets==1,"Checkbox caption only invalidates its paragraph")
	demoRuntime:Run([=[
document.getElementById("news").addEventListener("click", function(event) {
  window.checkedDuringClick = event.target.checked;
  event.preventDefault();
}, { once: true });
]=])
	click("news");assert(demoRuntime.Window.Get("checkedDuringClick")==false)
	assert(demoModel:Resolve("news").Checked and read("selection")=="Neuigkeiten: ja","Cancelled click restores check without change event")
	demoModel:SetValue(demoModel:Resolve("name"),"Alex",true)
	demoModel:Submit(Node.findById(demoDocument,"contact"));demoRuntime:Flush();assert(read("form-result")=="Danke, Alex. Lokal bestätigt.")
	click("once");click("once");assert(read("once-result")=="Genau einmal ausgelöst.")
	assert(#demoRuntime.Diagnostics==0,table.concat(demoRuntime.Diagnostics,"\n"))
	assert(#demoWarnings==0,table.concat(demoWarnings,"\n"))
	demoRuntime:Destroy();demoEvents:Destroy();demoModel:Destroy()
	print("JavaScript: shared VM, UTF-16, closures/this, DOM identity, event phases, filtering, batching, live CSS/text, cleanup and bounded execution passed")
end
