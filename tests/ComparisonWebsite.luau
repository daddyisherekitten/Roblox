--!strict
-- Actual delivered routes, scripts, native controls and responsive retained layout.
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,FormModel,Controller,pages)
 local storageArea=require("JavaScript/Storage").createArea()
 for _,pageData in pages do
 local html,css,app=pageData.html,pageData.css,pageData.app
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
		function gui:CaptureFocus()self.Focused:Fire()end
		function gui:ReleaseFocus()self.FocusLost:Fire(false)end
		function gui:Destroy()assert(not self.Destroyed,"GUI disposed twice");self.Destroyed=true;for _,child in guis do if child.Parent==self and not child.Destroyed then child:Destroy()end end;self.Parent=nil end
		table.insert(guis,gui);return gui
	end
	factory.modifier=factory.create
	local effectImages={}
	function factory.createImage(size)
		local image={Size=size};function image:WritePixelsBuffer(_,_,pixels)self.Pixels=pixels end
		function image:Destroy()assert(not self.Destroyed);self.Destroyed=true end
		table.insert(effectImages,image);return image
	end
	local textMeasurements=0;local inspectPending
	local overrides={["Layout/FontProfiles"]={face=function(font)return font end},["Layout/TextMeasure"]={measure=function(text,_,size)textMeasurements+=1;if inspectPending then inspectPending()end;return {X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
	local words=loadWordLayout(overrides);overrides["Layout/WordLayout"]=words;local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
	local document=Parser.parseDocument(html,{ScriptingEnabled=true});assert(#document.Diagnostics==0,table.concat(document.Diagnostics," | "))
	local svgNodes={};for name,source in pageData.svgs or {} do svgNodes[name]=assert(Node.findElement(Parser.parse(source),function(n)return n.Name=="svg"end))end
	local url="http://localhost:8000/"..pageData.folder.."/index.html";local messages={}
	local root=factory.create("ScrollingFrame",nil,{})
	local function svg(reference)return svgNodes[reference]or svgNodes[reference:match("([^/]+)$")]end
	local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end,nil,nil,nil,nil,nil,nil,nil,nil,{["styles.css"]=css},url,nil,nil,nil,nil,svg)
	local events,model
	local page={Alive=true,Document=document,DocumentURL=url,BaseURL=url,Root=root,Cleanups={}}
	function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
	function page:RefreshDOMControls()model:RefreshControls()end
	local width=1000;local arrangements,realm,flushing=0,nil,false;local lastLayoutStats;local pending=false;local pendingTargets={}
	function page:GeometryViewport()return {Width=width,Height=900,ClientWidth=width,ClientHeight=900,ScrollWidth=width,ScrollHeight=tree.OuterHeight or 900,ScrollX=0,ScrollY=0}end
	function page:HasPendingLayout()return pending end
	local function arrange(targets)
		arrangements+=1;tree:SetMediaEnvironment(width,900);tree.ViewportHeight=900
		for pass=1,8 do
			lastLayoutStats=Dirty.begin(tree,targets);layout.arrange(tree,width,0,0,function()return true end);Dirty.finish(tree,true)
			local _,needed,items=tree:RefreshContainerSizes();if not needed then break end;targets=items;assert(pass<8,'Container styles did not converge')
		end
	end
	function page:FlushScriptLayout()
		if flushing or not realm then return end;flushing=true
		local needed,targets=realm:Flush()
		if pending then needed=true;targets=targets or{};for item in pendingTargets do targets[item]=true end;pending=false;table.clear(pendingTargets)end
		if needed then
			local remaining={};for item,reason in targets or {}do
				if not tree:CanKeepTextLayout(item,words.arrange,function()return true end)then remaining[item]=reason end
			end
			if next(remaining)then arrange(remaining)else tree:PublishContentVisibility()end
		end
		flushing=false
	end
	local callbacks={};local clock=0;
	local services={Clock=function()return clock end,RunService={RenderStepped=signal()},Task={delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Cancelled=true end},
		ScriptSources={[url:gsub("index.html$","app.js")]=app},GetStorageArea=function()return storageArea end,
		LoadImage=function(reference,complete,spec)
			table.insert(callbacks,function()local asset=svg(spec.Source or reference);if asset then complete(true,{Width=320,Height=200})else complete(false,"Missing image")end end)
		end,
		LoadFont=function(_,complete)table.insert(callbacks,function()complete(true,{Family="arial"})end)end}
	if pageData.folder~='comparison-motion'then arrange();root:SetAttribute("Status","ready")end
	tree:EnablePendingPresentation()
	local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
	function input:GetFocusedTextBox()return nil end;function input:IsKeyDown()return false end;function input:GetStringForKeyCode(key)return key.Name end
	local stop=Controller.start(page,tree,function(_,item)pending=true;if item then pendingTargets[item]=true end end,function(message)table.insert(messages,message)end,{Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=function()return clock end,PickerLayout=layout,Task={defer=function(fn)table.insert(callbacks,fn);return{}end,cancel=function()end}})
	model,events=page.FormModel,page.Events
	if pageData.folder=='comparison-motion'then
		page.MotionRuntime=require('Rendering/HTMLAnimations').start(page,tree,error,{Clock=function()return clock end,RunService={Heartbeat=signal()}},0)
	end
	realm=HTMLScripts.start(page,tree,function()end,function(message)table.insert(messages,message)end,{JavaScriptServices=services})
	if pageData.folder=='comparison-motion'then arrange();page.MotionRuntime:AfterLayout();realm:AfterLayout();root:SetAttribute('Status','ready')end
	local function settle()
		if not realm then return end
		for attempt=1,40 do
			local pending=callbacks;callbacks={};for _,complete in pending do complete()end
			page:FlushScriptLayout();realm:AfterLayout();clock+=.01;local tasks=realm:PumpTasks()
			if #callbacks==0 and tasks==0 and not realm:HasPending()then break end
			assert(attempt<40,"Website tasks did not converge")
		end
		page:FlushScriptLayout()
	end
	local function node(id)return assert(Node.findById(document,id),id)end
	local function text(id)return Node.textContent(node(id))end
	local function run(source)local ok,err=realm:Run(source);assert(ok,tostring(err));settle();assert(#messages==0,table.concat(messages,' | '));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
	local function click(id)run("document.getElementById('"..id.."').click();")end
	settle()

 local function cleanMessages()assert(#messages==0,pageData.folder..": "..table.concat(messages," | "))end
 local function color(id,key,r,g,b)
  local style=assert(tree.NodeStyles[node(id)],id);local value=style[if key=='BackgroundColor'then 'Background'else key]
  assert(value and math.abs(value.R-r/255)<.0001 and math.abs(value.G-g/255)<.0001 and math.abs(value.B-b/255)<.0001,id.." "..key)
 end
 local function change(id,value,kind)
  run("document.getElementById('"..id.."')."..(kind=='check'and'checked' or'value').."="..string.format('%q',value)..";document.getElementById('"..id.."').dispatchEvent(new Event('"..(kind=='input'and'input' or'change').."'));")
 end
 assert((if realm then realm.ScriptsRun else 0)==(if app==''then 0 else 1),pageData.folder.." actual defer script")
 local folder=pageData.folder
 if folder=='comparison-markup'then
  local first=Node.findElement(node('orders'),function(n)return n.Name=='td'end)
  local retainedNote=page.FormModel:Resolve(node('retained-input')).Item.Gui
  local ok,err=realm:Run("document.getElementById('row-add').click();");assert(ok,tostring(err))
  local needed,targets=realm:Flush();assert(needed,'A new table row requires geometry')
  local addedWord;for _,item in tree.TextItems do if item.Text=='Bleistift'then addedWord=item end end;assert(addedWord,'Actual inserted row text is mounted')
  assert(addedWord.Gui.Parent.Name=='WordPaintHost'and addedWord.Gui.Parent.Visible==false,'New row text remains hidden before layout')
  local suspendedChecks=0
  inspectPending=function()
   suspendedChecks+=1;assert(addedWord.Gui.Parent.Visible==false,'Native text measurement cannot expose new text at its temporary origin')
   assert(page.FormModel:Resolve(node('retained-input')).Item.Gui==retainedNote and retainedNote.Visible~=false,'An unrelated editor remains visible and retained')
  end
  local now=0;local stats=Dirty.begin(tree,targets)
  local passed,result=require('Rendering/LayoutJob').run(page,tree,1,function()return true end,function(alive)return layout.arrange(tree,width,0,0,alive)end,{wait=function()inspectPending();now+=.016 end},function()now+=.0002;return now end)
  inspectPending=nil;Dirty.finish(tree,passed);assert(passed,tostring(result));assert(suspendedChecks>0 and addedWord.Gui.Parent.Visible==true,'A completed root layout publishes new text after the parent geometry')
  settle();assert(text('row-count')=='2 Positionen');assert(Node.findElement(node('orders'),function(n)return n.Name=='td'end)==first)
  click('row-remove');assert(text('row-count')=='1 Positionen')
  click('note-add');assert(text('notes'):find('Aus dem Template eingefügt.',1,true))
  click('note-move');assert(node('notes').Children[#node('notes').Children].Kind=='Element')
  run("const replacement=document.createElement('div');replacement.id='replacement-probe';const child=document.createElement('input');child.id='replacement-input';child.value='before';replacement.appendChild(child);document.getElementById('notes').parentNode.appendChild(replacement);")
  local removedEditor=page.FormModel:Resolve(node('replacement-input')).Item.Editor
  local retainedInput=page.FormModel:Resolve(node('retained-input')).Item.Editor
  run("document.getElementById('replacement-probe').textContent='Replacement text';")
  assert(text('replacement-probe')=='Replacement text'and Node.findById(document,'replacement-input')==nil,'Structural textContent replaces ordinary controls with text')
  assert(removedEditor.Destroyed and page.FormModel:Resolve(node('retained-input')).Item.Editor==retainedInput,'Replacing controls releases their editor and retains unrelated editors')
  run("document.getElementById('retained-input').value='Unverändert';document.getElementById('open-demo').open=true;")
  color('open-demo','BackgroundColor',223,233,255);assert(page.FormModel:Resolve(node('retained-input')).Value=='Unverändert')
 elseif folder=='comparison-forms'then
  run("document.getElementById('guest-name').value='Tobias';document.getElementById('guest-email').value='t@example.com';document.getElementById('booking').dispatchEvent(new Event('submit',{cancelable:true}));")
  assert(text('form-status')=='Tobias | t@example.com | 2 Personen')
  change('form-range','75','input');assert(text('range-value')=='75');assert(tree.NodeStyles[node('form-bar')].Width.Value==75 and tree.NodeStyles[node('form-bar')].Width.Percent)
  local slider=model:Resolve(node('form-range'));local retainedThumb=slider.Item.RangeThumb;local retainedBar=tree.NodeBoxes[node('form-bar')].Gui
  local drag=require('Input/RangeDrag').new(model,function()return page.Alive end)
  local x,_,travel,diameter=require('Controls/RangeView').geometry(slider.Item);local left=slider.Item.BoxGui.AbsolutePosition.X+x+diameter/2
  local function position(value)return Vector2.new(left+travel*(value-slider.Range.Min)/(slider.Range.Max-slider.Range.Min),10)end
  local pointer={UserInputType=Enum.UserInputType.MouseButton1,Position=position(75)}
  tree.LayoutInProgress=true;drag:Begin(slider,pointer)
  for _,value in {10,100,15,95,10,90,20,80,30,70,40,60,55}do
   drag:Move({UserInputType=Enum.UserInputType.MouseMovement,Position=position(value)})
   assert(slider.Value==tostring(value)and text('range-value')==tostring(value),'Fast pointer input still executes the delivered author handler: '..value..', native='..slider.Value..', text='..text('range-value')..', diagnostics='..table.concat(realm.Diagnostics,' | '))
  end
  assert(not pending,'Value-only range defaults must not invalidate a suspended page layout before the queued DOM batch')
  pointer.Position=position(55);drag:Finish(pointer);tree.LayoutInProgress=false;settle()
  assert(tree.NodeStyles[node('form-bar')].Width.Value==55 and slider.Item.RangeThumb==retainedThumb and tree.NodeBoxes[node('form-bar')].Gui==retainedBar,'The latest fast input reaches the retained bar and thumb')
  change('form-color','#dc654c','input');color('form-bar','BackgroundColor',220,101,76)
 elseif folder=='comparison-selectors'then
  color('scope-root','BackgroundColor',255,255,255)
  click('scope-toggle');color('scope-root','BackgroundColor',223,233,255)
  click('scope-toggle');color('scope-root','BackgroundColor',255,255,255)
  run("document.getElementById('has-check').checked=true;document.getElementById('has-check').dispatchEvent(new Event('change'));")
  color('has-card','BackgroundColor',238,243,255)
 elseif folder=='comparison-cascade'then
  color('layer-sample','BackgroundColor',49,92,196);color('variable-sample','Color',40,89,60)
  run("document.getElementById('layer-check').checked=true;document.getElementById('layer-check').dispatchEvent(new Event('change'));document.getElementById('variable-check').checked=true;document.getElementById('variable-check').dispatchEvent(new Event('change'));")
  color('layer-sample','BackgroundColor',220,101,76);color('variable-sample','Color',49,92,196)
 elseif folder=='comparison-layout'then
  change('container-width','300','input');assert(text('container-value')=='300')
  assert(tree.NodeBoxes[node('query-container')].OuterWidth==300)
  change('container-width','600','input');assert(text('container-value')=='600')
  assert(tree.NodeBoxes[node('query-container')].OuterWidth==600)
 elseif folder=='comparison-text'then
  click('counter-add');assert(text('counter-list'):find('Ein weiterer Punkt',1,true))
  change('direction','rtl');assert(node('direction-text').Attributes.dir=='rtl')
 elseif folder=='comparison-effects'then
  local imageBox=tree.NodeBoxes[node('effect-image')];local kept=imageBox.Gui
  run("document.getElementById('clip-check').checked=true;document.getElementById('clip-check').dispatchEvent(new Event('change'));document.getElementById('mask-check').checked=true;document.getElementById('mask-check').dispatchEvent(new Event('change'));")
  assert(imageBox.Style.ClipPath and imageBox.Style.MaskImage and imageBox.Gui==kept)
  change('blur-range','2','input');assert(text('blur-value')=='2')
  for _,mode in {'multiply','screen','difference'}do change('blend-mode',mode);assert(tree.NodeStyles[node('blend-front')].MixBlendMode==mode)end
  click('flip-card');assert(node('flip-card').Attributes['aria-pressed']=='true');click('flip-card');assert(node('flip-card').Attributes['aria-pressed']=='false')
 elseif folder=='comparison-motion'then
  local compositionBox=tree.NodeBoxes[node('composition-box')]
  assert(math.abs(compositionBox.TransformBaseX-compositionBox.PaintX-(compositionBox.OpacityBounds[1]or 0))<.001 and math.abs(compositionBox.TransformBaseY-compositionBox.PaintY-(compositionBox.OpacityBounds[2]or 0))<.001,'The initial animation retains its positioned paint base')
  local target=require('Rendering/BoxTransform').target(compositionBox)
  assert(math.abs(target.Position[1]-43.6)<.001 and math.abs(target.Position[2]-50)<.001,'The sampled native surface is inside its positioned stage: '..target.Position[1]..','..target.Position[2]..' base='..compositionBox.TransformBaseX..','..compositionBox.TransformBaseY)
  change('composition-mode','add');change('composition-progress','75','input');assert(text('composition-value')=='75')
  change('composition-mode','accumulate');change('composition-mode','replace')
  click('size-start');assert(text('size-status')=='Läuft …');click('size-reset');assert(text('size-status')=='Bereit.')
  click('transition-toggle');assert(node('transition-box').Attributes.class=='changed')
 elseif folder=='comparison-canvas'then
  local field=node('notes');local control=page.FormModel:Resolve(field);local editor=control.Item.Editor
  run('document.getElementById("notes").value="Behalten 😀";')
  click('switch');assert(document.Children[#document.Children].Attributes.class=='root-paint','Delivered owner control switches the actual document root')
  change('alpha','25','input');assert(text('alpha-value')=='25%')
  click('grow');assert(Node.findById(document,'growth')and node('grow').Attributes['aria-expanded']=='true')
  click('grow');assert(not Node.findById(document,'growth')and node('grow').Attributes['aria-expanded']=='false')
  assert(page.FormModel:Resolve(field)==control and control.Item.Editor==editor and control.Value=='Behalten 😀','Canvas demo retains the edited native control across background and structural changes')
 elseif folder=='comparison-script'then
  local keptNote=page.FormModel:Resolve(node('saved-note')).Item.Gui
  for _=1,3 do click('loop-start');assert(text('loop-results')=='1. synchron2. Promise3. Timer',text('loop-results'));assert(page.FormModel:Resolve(node('saved-note')).Item.Gui==keptNote,'Clearing old list children retains unrelated native controls')end
  click('dialog-modal');assert(node('request-dialog').Attributes.open~=nil);click('dialog-close');assert(node('request-dialog').Attributes.open==nil)
  click('dialog-normal');assert(node('request-dialog').Attributes.open~=nil);click('dialog-close')
  run("document.getElementById('saved-note').value='Meine Notiz';")
  click('note-save');assert(text('storage-status')=='Notiz gespeichert.');click('note-clear');assert(text('storage-status')=='Notiz gelöscht.')
 end
 for _,viewport in {390,1000}do
  width=viewport;arrange();settle();assert(tree.OuterHeight>200 and tree.OuterHeight<12000,pageData.folder..' finite height')
  local content=tree.NodeBoxes[node('inhalt')];assert(content.OuterWidth<=viewport+.01,pageData.folder..' viewport fit')
 end
 cleanMessages()
 if realm then realm:Destroy()end;stop();for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end
 model:Destroy();events:Destroy();if tree.VisualEffects then tree.VisualEffects:Destroy()end;root:Destroy()
 for _,image in effectImages do assert(image.Destroyed,'Composition images released on route exit')end
 print(pageData.folder..': delivered script, interactions and two engine layouts passed')
 end
end
