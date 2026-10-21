--!strict
-- Run the delivered browser script against mounted DOM/CSS/control surfaces.
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,html,css,app,svgs)
	local function signal()
		local entries={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local guis={};local factory={}
	function factory.create(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true
		gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(1120,900)
		if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{}
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,"GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	local words=loadWordLayout(overrides);overrides["Layout/WordLayout"]=words;local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument(html,{ScriptingEnabled=true});assert(#document.Diagnostics==0,table.concat(document.Diagnostics," | "))
	local svgNodes={};for name,source in svgs do svgNodes[name]=assert(Node.findElement(Parser.parse(source),function(n)return n.Name=="svg"end))end
	local url="http://localhost:8000/browser-foundations/index.html";local messages={}
	local root=factory.create("ScrollingFrame",nil,{})
	local function svg(reference)return svgNodes[reference]or svgNodes[reference:gsub("^http://localhost:8000/browser%-foundations/","")]end
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{["styles.css"]=css},url,nil,nil,nil,nil,svg)
	local events=require("Input/Events").new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,DocumentURL=url,BaseURL=url,Root=root,Events=events,FormModel=model,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	local width=1120;local arrangements,realm,flushing=0,nil,false
	function page:GeometryViewport()return {Width=width,Height=900,ClientWidth=width,ClientHeight=900,ScrollWidth=width,ScrollHeight=tree.OuterHeight or 900,ScrollX=0,ScrollY=0}end
	function page:HasPendingLayout()return false end
	local function arrange(targets)
		arrangements+=1;tree:SetMediaEnvironment(width,900);tree.ViewportHeight=900
		Dirty.begin(tree,targets);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		local needed,targets=realm:Flush()
		if needed then
			local remaining={};for item,reason in targets or {}do
				if not tree:CanKeepTextLayout(item,words.arrange,function()return true end)then remaining[item]=reason end
			end
			if next(remaining)then arrange(remaining)end
		end
		flushing=false
	end
	local callbacks={};local clock=0;local storageArea=require("JavaScript/Storage").createArea()
	local services={Clock=function()return clock end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Cancelled=true end},
		ScriptSources={[url:gsub("index.html$","app.js")]=app},GetStorageArea=function()return storageArea end,
		LoadImage=function(reference,complete,spec)
			table.insert(callbacks,function()local asset=svg(spec.Source or reference);if asset then complete(true,{Width=480,Height=240})else complete(false,"Missing image")end end)
		end,
		LoadFont=function(_,complete)table.insert(callbacks,function()complete(true,{Family="arial"})end)end}
	arrange();root:SetAttribute("Status","ready")
	realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(messages,message)end,{JavaScriptServices=services})
	local function settle()
		for attempt=1,40 do
			local pending=callbacks;callbacks={};for _,complete in pending do complete()end
			page:FlushScriptLayout();realm:AfterLayout();clock+=.01;local tasks=realm:PumpTasks()
			if #callbacks==0 and tasks==0 and not realm:HasPending()then break end
			assert(attempt<40,"Website tasks did not converge")
		end
		page:FlushScriptLayout();assert(#messages==0,table.concat(messages," | "))
	end
	local function node(id)return assert(Node.findById(document,id),id)end
	local function text(id)return Node.textContent(node(id))end
	local function run(source)local ok,err=realm:Run(source);assert(ok,tostring(err));settle()end
	local function click(id)run("document.getElementById('"..id.."').click();")end
	settle();assert(text("image-result")=="Dekodiert: 480 × 240 px. complete: true.")
	local noteControl=assert(model:Resolve(node("note-input")));local retainedEditor=noteControl.Item.Editor
	local imageItem=assert(tree:FindImageItem(node("landscape")));local retainedImageGui=imageItem.Gui
	click("style-switch");assert(text("style-result")=="Variante: Sonne. Zusatzregel: aus.")
	click("rule-switch");assert(text("style-result")=="Variante: Sonne. Zusatzregel: an.")
	local nestedRule=false
	for _,item in tree.TextItems do if item.Style.Node==node("design-sample")and item.Style.PseudoElement=="before"and (item.Text or ""):find("✓",1,true)then nestedRule=true end end
	assert(nestedRule,"Nested CSSOM pseudo declarations paint real generated content")
	click("data-check")
	assert(text("unicode-result")=="NFC: Café (5 → 4 UTF-16-Einheiten). NFKC: ABC 1.")
	assert(text("url-result")=="https://xn--bcher-kva.example/atelier?q=Caf%C3%A9")
	assert(text("date-before")=="29.03.2026, 01:30"and text("date-after")=="29.03.2026, 03:30")
	assert(text("date-english")=="29 Mar 2026, 01:30")
	click("font-load");assert(text("font-result")=="FontFace: loaded. FontFaceSet: loaded. Prüfung: true.")
	click("image-switch");assert(text("image-result")=="Dekodiert: 480 × 240 px. complete: true.")
	assert(tree:FindImageItem(node("landscape"))==imageItem and imageItem.Gui==retainedImageGui,"Source switch retains native box")
	click("image-error");assert(text("image-result"):find("EncodingError",1,true),text("image-result"))
	assert(imageItem.BoxWidth>0 and math.abs(imageItem.BoxWidth/imageItem.BoxHeight-2)<.001,"Broken image keeps its responsive CSS box and aspect ratio")
	assert(imageItem.ErrorGui.Visible and imageItem.AltGui.Visible and imageItem.FallbackGui.Visible,"Broken landscape shows its icon and alt inside the retained box")
	run([[var photo=document.getElementById('landscape');photo.style.cssText='width:120px;height:60px;padding:4px;border:2px solid black;box-sizing:border-box';if(photo.width!==108||photo.height!==48)throw new Error('Image dimensions must flush pending CSS and exclude padding/borders');]])
	run([[document.getElementById('landscape').style.cssText='';]])
	click("image-switch");assert(text("image-result")=="Dekodiert: 480 × 240 px. complete: true.")
	run("document.getElementById('note-input').value='Ein Café für später.';")
	click("note-save");run("document.getElementById('note-input').value='';");click("note-read")
	assert(noteControl.Value=="Ein Café für später."and noteControl.Item.Editor==retainedEditor)
	local before=arrangements;local resultBox=tree.NodeBoxes[node("note-result")];local beforeHeight,beforeWidth=resultBox.OuterHeight,resultBox.OuterWidth
	click("note-remove");click("note-read");assert(arrangements==before,"Storage status work: "..before.." -> "..arrangements.."; dimensions "..beforeWidth.."x"..beforeHeight.." -> "..resultBox.OuterWidth.."x"..resultBox.OuterHeight)
	run("document.getElementById('note-result').textContent='A'.repeat(220);")
	assert(resultBox.OuterHeight>beforeHeight and arrangements>before,"A genuinely fragmented word must propagate its new height")
	run("document.getElementById('note-result').textContent='Eine kurze Notiz.';")
	assert(resultBox.OuterHeight==beforeHeight,"Shrinking a wrapped result restores the following geometry")
	width=420;root.AbsoluteSize=Vector2.new(width,900);arrange();realm:AfterLayout();settle()
	local designBox=tree.NodeBoxes[node("gestaltung")];local resourceBox=tree.NodeBoxes[node("ressourcen")]
	assert(resourceBox.LayoutY>=designBox.LayoutY+designBox.OuterHeight-1,"Mobile media rule stacks the cards")
	assert(imageItem.BoxWidth<=width,"Image scales with the mobile card")
	assert(noteControl.Item.Editor==retainedEditor and imageItem.Gui==retainedImageGui,"Resize retains surfaces")
	page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;model:Destroy();events:Destroy();root:Destroy()
	print("Browser foundations website: native scripts, nested CSS/pseudo, image decode/source/error, fonts, Unicode/URL/DST, storage, mobile layout and retained controls passed")
end
