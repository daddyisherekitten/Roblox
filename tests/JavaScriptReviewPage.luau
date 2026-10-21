--!strict
-- Execute the exact shipped review HTML/CSS and option-supplied module.
-- Native controls/layout/paint are retained; Canvas uses its CPU adapter.
return function(Parser,Node,Runtime,VM,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,Surface,html,css,pageOptions)
	local function signal()
		local listeners={};local api={}
		function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
		function api:Fire(...)for _,entry in table.clone(listeners)do if entry[1].Connected then entry[2](...)end end end
		return api
	end
	local guis={};local factory={create=function(class,parent,properties)
		local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true;gui.AbsolutePosition=Vector2.new(0,0);gui.AbsoluteSize=Vector2.new(960,900)
		if class=="ScrollingFrame"then gui.CanvasPosition=Vector2.new(0,0)end
		gui.Focused,gui.FocusLost,gui.InputBegan=signal(),signal(),signal();local attributes,signals={},{ }
		function gui:GetPropertyChangedSignal(key)if not signals[key]then signals[key]=signal()end;return signals[key]end
		function gui:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal("attribute:"..key)end
		function gui:SetAttribute(key,value)attributes[key]=value;if signals["attribute:"..key]then signals["attribute:"..key]:Fire()end end
		function gui:GetAttribute(key)return attributes[key]end
		function gui:IsA(kind)return kind==class or kind=="GuiObject"end
		function gui:IsFocused()return false end
		function gui:Destroy()assert(not self.Destroyed,"Native GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end}
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	overrides["Layout/WordLayout"]=loadWordLayout(overrides);local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument(html);local renderMessages={};local root=factory.create("ScrollingFrame",nil,{})
	local tree=renderer.build(document,root,function(message)table.insert(renderMessages,message)end,function(font)return font end,nil,nil,nil,css)
	local events=Events.new(error);local model=FormModel.new(document,tree.Controls,events,function()end)
	local page={Alive=true,Document=document,DocumentURL="http://localhost:8000/javascript-tests/index.html",BaseURL="http://localhost:8000/javascript-tests/index.html",Root=root,FormModel=model,Events=events,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	function page:SetValue(node,value)model:SetValue(model:Resolve(node),value,false)end
	local surfaces={};local nativeCanvas={Alive=true}
	function nativeCanvas:Surface(node,create)local value=surfaces[node];if not value and create~=false then value=Surface.new(tonumber(node.Attributes.width)or 300,tonumber(node.Attributes.height)or 150);surfaces[node]=value end;return value end
	function nativeCanvas:Reset(node,w,h)local value=Surface.new(w,h);surfaces[node]=value;for _,item in tree.CanvasItems do if item.Node==node then item.CanvasSurface=value;item.IntrinsicWidth,item.IntrinsicHeight=w,h end end;return value end
	function nativeCanvas:Publish()end
	function page:EnsureCanvasRuntime()
		if not self.CanvasRuntime then self.CanvasRuntime=nativeCanvas;self:AddCleanup(function()nativeCanvas.Alive=false;table.clear(surfaces)end)end;return nativeCanvas
	end
	local now,realm,flushing=0,nil,false;local viewport={Width=960,Height=900,ClientWidth=960,ClientHeight=900,ScrollWidth=960,ScrollHeight=900,ScrollX=0,ScrollY=0}
	function page:GeometryViewport()return viewport end
	function page:HasPendingLayout()return false end
	local function arrange(targets)
		tree:SetMediaEnvironment(viewport.Width,viewport.Height);tree.ViewportHeight=viewport.Height;Dirty.begin(tree,targets)
		viewport.ScrollHeight=layout.arrange(tree,viewport.Width,0,0,function()return true end);Dirty.finish(tree,true)
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		local needed,targets=realm:Flush();if needed then arrange(targets)end
		flushing=false
	end
	arrange();root:SetAttribute("Status","ready")
	local options={JavaScriptServices=table.clone(pageOptions.JavaScriptServices or {})};options.JavaScriptServices.Clock=function()return now end
	options.JavaScriptServices.Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}
	options.JavaScriptServices.RunService={RenderStepped=signal()}
	local diagnostics={};realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,options)
	local function healthy()assert(#diagnostics==0,table.concat(diagnostics," | "))end
	local function settle()
		for _=1,24 do
			page:FlushScriptLayout();realm:AfterLayout();local tasks=realm:PumpTasks()
			if not realm:HasPending()and tasks==0 then break end
		end;page:FlushScriptLayout();healthy()
	end
	local function node(id)local result=Node.findById(document,id);assert(result,id);return result end
	local function text(id)return Node.textContent(node(id))end
	local function expected(id,value)
		assert(text(id)==value,id.." expected="..value.." actual="..text(id))
		local owner=tree.NodeBoxes[node(id)];local painted={}
		for _,item in tree.TextItems do if item.TextOwner==owner then
			local gui=item.TextGui or item.Gui;assert(gui and not gui.Destroyed,"Visible result owns a live native text object")
			if gui.Visible~=false then if item.Glyphs then for _,glyph in item.Glyphs do table.insert(painted,glyph.Gui.Text)end else table.insert(painted,gui.Text)end end
		end end
		assert(table.concat(painted):gsub("%s+","")==value:gsub("%s+",""),id.." native paint differs from its DOM text: "..table.concat(painted).." / "..value)
	end
	local function click(id)model:Activate(assert(model:Resolve(node(id))),nil,true);settle()end
	local function input(id,value)local c=model:Resolve(node(id));model:SetValue(c,value,true);settle()end
	local function run(code)realm:Run(code);settle()end
	local function advance(seconds)now+=seconds;realm:PumpTasks();settle()end
	settle();healthy();expected("js-status","Bereit · 13 Experimente · derselbe HTML-/CSS-/JavaScript-Code")
	run('for(const cursor of [document.createTreeWalker(document),document.createNodeIterator(document)]){let blocked=false;try{structuredClone(cursor)}catch(e){blocked=e.name==="DataCloneError"}if(!blocked)throw new Error("Traversal cannot be structured cloned");}');healthy()
	click('iterator-next');expected('iterator-result','Treffer: 4\nQuelle: 1 → 2')
	click('iterator-next');expected('iterator-result','Treffer: 16\nQuelle: 1 → 2 → 3 → 4')
	click('iterator-next');expected('iterator-result','Fertig.\nQuelle: 1 → 2 → 3 → 4 → geschlossen')
	click('iterator-reset');click('iterator-next');click('iterator-close');expected('iterator-result','Abgebrochen.\nQuelle: 1 → 2 → geschlossen')
	click('traversal-walker');expected('traversal-result','TreeWalker: Holz → Licht')
	click('traversal-iterator');expected('traversal-result','NodeIterator: Holz → Licht → Stein')
	click('traversal-remove');expected('traversal-result','NodeIterator: Holz → Licht')
	click('matrix-transform');expected('matrix-result','P: 120, 40 · transformiert\nQuadrat: 16 × 16 px.')
	assert(node('matrix-dot').Attributes.style:find('translate%(120px, 40px%)'),'Pure matrix transform paints the calculated point')
	click('matrix-inverse');expected('matrix-result','P: 15, 15 · zurück am Ausgangspunkt\nQuadrat: 16 × 16 px.')
	click('matrix-clone');expected('matrix-result','P: 150, 40 · Original e: 90; Kopie e: 120\nQuadrat: 16 × 16 px.')
	assert(#Runtime.scripts(document)==1,"The exact shipped classic script initializes once")
	local euro=utf8.char(160).."€"
	expected("data-result",'3 Treffer: Haus am Hang, Gartenhaus, Atelier\nMaterialien: Holz, Stein, Glas\nSumme: 2.340,00'..euro..' · Wortsuche: false\nJSON: {"names":["Haus am Hang","Gartenhaus","Atelier"],"count":3}')
	input("project-search","Haus");expected("data-result",'2 Treffer: Haus am Hang, Gartenhaus\nMaterialien: Holz, Stein, Glas\nSumme: 1.889,00'..euro..' · Wortsuche: true\nJSON: {"names":["Haus am Hang","Gartenhaus"],"count":2}')
	input("project-search","xyz");expected("data-result",'0 Treffer: keine\nMaterialien: keine\nSumme: 0,00'..euro..' · Wortsuche: false\nJSON: {"names":[],"count":0}')
	click('json-precise');expected('json-result','Quelle: {"number":9007199254740993}\nExakter Wert: 9007199254740993\nAusgabe: {"number":9007199254740993}\nIdentisch: true · rawJSON: true')
	input("contact-name","Ada");click("contact-news");expected("dom-result","Name: Ada · Neuigkeiten: ja")
	run("document.getElementById('contact-form').requestSubmit()");expected("dom-result","FormData: name=Ada · news=ja")
	run("document.getElementById('contact-form').reset()");expected("dom-result","Name: Mira · Neuigkeiten: nein")
	click("add-note");click("add-note");local notes=node("notes");assert(#notes.Children==2)
	expected('queries-result','Lebende Abfragen: 2 mit Notizname · 2 HTML-Eingaben.')
	click('queries-name');expected('queries-result','Lebende Abfragen: 1 mit Notizname · 2 HTML-Eingaben.')
	click('queries-name');expected('queries-result','Lebende Abfragen: 2 mit Notizname · 2 HTML-Eingaben.')
	local first=notes.Children[1];local editorNode=first.Children[2];local editor=model:Resolve(editorNode);local editorGui=editor.Item.Editor
	model:SetValue(editor,"Behalten",true);click("move-note");assert(notes.Children[2]==first and model:Resolve(editorNode)==editor and editor.Item.Editor==editorGui and editor.Value=="Behalten")
	expected("dom-result","Derselbe Knoten ans Ende verschoben: Entwurf 1")
	model:Activate(model:Resolve(first.Children[3]),nil,true);settle();assert(#notes.Children==1 and editorGui.Destroyed);expected("dom-result","Notiz entfernt.")
	click('queries-read');expected('queries-result','Lebende Abfragen: 1 mit Notizname · 1 HTML-Eingaben.')
	click("task-start");expected("time-result","A und B laufen …");advance(.3);expected("time-result","A und B laufen …");advance(.3);expected("time-result","Fertig: A, B")
	click("task-start");click("task-stop");expected("time-result","Abgebrochen: Vom Benutzer beendet");advance(.7);expected("time-result","Abgebrochen: Vom Benutzer beendet")
	click("task-start");click("task-start");advance(.6);expected("time-result","Fertig: A, B")
	click("task-order");expected("time-result","synchron → Microtask → Promise → Timer")
	for index=1,3 do click("generator-next");expected("language-result","Wert: "..index.." · Entwurf #"..index)end
	click("language-inspect");expected("language-result","Proxy liest: value · dynamische Funktion: 14 · eigene Schlüssel: value")
	click("language-dispose");expected("language-result","geöffnet → benutzt → geschlossen → weiter")
	click("file-read");expected("files-result","Grüße 🌿\n12 Bytes · erstes Byte: 71 · entwurf.txt\nhttps://example.org/entwurf?text=Gr%C3%BC%C3%9Fe+%F0%9F%8C%BF")
	click("file-abort");expected("files-result","abort → loadend; result: null")
	click("stream-start");expected("network-result","HALLO STREAM WELT · 3 Stücke · Fetch-Status: 200")
	click("response-start");expected("network-result",'{"project":"Mira","count":3} = {"project":"Mira","count":3}\nBody benutzt: true, true')
	click("geometry-read");expected("geometry-result","Außen: 120 × 44 px · CSS: 120px · clientWidth: 116")
	click("geometry-size");expected("geometry-result","Außen: 180 × 64 px · CSS: 180px · clientWidth: 176")
	expected("observer-result","Style-Mutationen: 2 · Resize-Inhalt: 176 × 46 px")
	click("geometry-size");expected("observer-result","Style-Mutationen: 4 · Resize-Inhalt: 116 × 26 px")
	local bitmap=surfaces[node("lab-canvas")];assert(bitmap.Width==260 and bitmap.Height==96 and buffer.readu8(bitmap.Pixels,(48*260+65)*4)==237,"Initial exact page Canvas contains the circle")
	click("canvas-redraw");assert(surfaces[node("lab-canvas")]~=bitmap and buffer.readu8(surfaces[node("lab-canvas")].Pixels,(48*260+195)*4)==237)
	assert(text("graphics-result"):find("Pixel oben links: ",1,true))
	local animationBox=tree.NodeBoxes[node("animation-box")];local animationGui=animationBox.Gui
	local function visualX(gui)local p=gui.Position;return (if p.X then p.X.Offset else p[1])-(gui.AnchorPoint and gui.AnchorPoint.X or 0)*animationBox.OuterWidth end
	local animationX=visualX(animationGui)
	click("animation-start");expected("graphics-result","Animation läuft …");realm:PumpFrame();advance(.701);realm:PumpFrame();settle()
	expected("graphics-result","Fertig · Endposition: 120 px. Abbrechen stellt den CSS-Ausgangszustand wieder her.")
	assert(animationBox.Gui==animationGui and not animationGui.Destroyed and realm.EventLoop.FrameCount==0,"Finished script paint retains native identity without idle animation frames")
	assert(math.abs(visualX(animationGui)-animationX-120)<.0001,"The retained native square reaches the page's 120px endpoint")
	click("animation-cancel");expected("graphics-result","Abgebrochen · Ausgangsposition.")
	assert(math.abs(visualX(animationGui)-animationX)<.0001,"Cancel restores the native square's author position")
	input("stored-text","Mein Test")
	click("history-step");expected("state-result",'Hash: #labor-1 · state: {"step":1,"project":"Mein Test"}')
	run("history.back()");expected("state-result","Zurück / vorwärts · state: null")
	click("module-start");expected("modules-result","Hallo, Mira! · exportierte Version: 1")
	click("message-start");expected("modules-result","Kanal: 42 · Map: Mira · ursprünglicher Wert: 7")
	click("clone-start");expected("modules-result","Original: 0 Bytes · Kopie: 4 Bytes · erstes Byte: 42")
	click("storage-save");expected("state-result","Gelesen: Mein Test")
	click("storage-clear");expected("state-result","Gelöscht · getItem: null")
	healthy();assert(options.MaxSteps==nil and options.JavaScriptServices.MaxSteps==nil,"The review page uses the production step budget")
	-- Unchanged native rendering publications must own independent execution
	-- budgets. Geometry still measures the observed element on every round, even
	-- when ResizeObserver has no changed-size callback to enter the VM.
	run("let reviewBudgetWork=0;for(let index=0;index<1000;index++){reviewBudgetWork+=index;}if(reviewBudgetWork!==499500)throw new Error('budget warmup');")
	for _=1,10000 do realm:AfterLayout()end
	healthy();assert(realm.VM.Steps<128 and not realm:IsExecuting(),"Independent page layout publications do not accumulate the preceding script or earlier frame budgets")
	expected("observer-result","Style-Mutationen: 4 · Resize-Inhalt: 116 × 26 px")
	local succeeded=realm:Run("while(true){}")
	assert(not succeeded and #diagnostics>0 and table.concat(diagnostics," | "):find("instruction budget exceeded",1,true),"An endless script remains bounded by the production budget")
	table.clear(diagnostics);realm:AfterLayout();healthy()
	assert(realm.VM.Steps<128,"An unchanged observer publication starts fresh after an exhausted script")
	page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;model:Destroy();events:Destroy()
	assert(not realm.Alive and realm.EventLoop.FrameCount==0 and not nativeCanvas.Alive and next(surfaces)==nil,"Review page destroys its realm and timer/frame/CPU bitmap ownership")
	print("JavaScript review page: exact shipped startup and thirteen cards pass with native DOM/control/layout identity, Canvas pixels, geometry/observers/animations, options modules and disposal")
end
