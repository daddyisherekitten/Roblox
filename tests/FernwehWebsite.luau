--!strict
-- Mount the delivered website with its real scripts, native controls and SVGs.
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller,HTMLAnimations,html,css,app,svgs,Corners)
 local function signal()
  local entries={};local api={}
  function api:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
  function api:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
  function api:Count()local count=0;for _,entry in entries do if entry[1].Connected then count+=1 end end;return count end
  return api
 end
 local viewportWidth,viewportHeight,time=1280,900,0
 local focused,hitGui;local guis,deferred={},{};local factory={}
 function factory.create(class,parent,props)
  local changes,attributes={},{}
  local values={ClassName=class,Parent=parent,Visible=true,AbsolutePosition=Vector2.new(0,0),Text='',CursorPosition=-1,SelectionStart=-1}
  for key,value in props do values[key]=value end
  if class=='ScrollingFrame'then values.CanvasPosition=Vector2.new(0,0);values.ScrollingEnabled=true end
  local gui=setmetatable({},{__index=function(_,key)
   if key=='AbsoluteSize'and not values.AbsoluteSize then return Vector2.new(viewportWidth,viewportHeight)end
   return values[key]
  end,__newindex=function(_,key,value)local before=values[key];values[key]=value;if before~=value and changes[key]then changes[key]:Fire()end end})
  values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
  function values:GetPropertyChangedSignal(key)if not changes[key]then changes[key]=signal()end;return changes[key]end
  function values:GetAttributeChangedSignal(key)return self:GetPropertyChangedSignal('attribute:'..key)end
  function values:SetAttribute(key,value)attributes[key]=value;if changes['attribute:'..key]then changes['attribute:'..key]:Fire()end end
  function values:GetAttribute(key)return attributes[key]end
  function values:IsA(kind)return kind==class or kind=='GuiObject'end
  function values:IsFocused()return focused==gui end
  function values:CaptureFocus()if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
  function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
  function values:Destroy()
   assert(not values.Destroyed,'FERNWEH native GUI disposed twice');values.Destroyed=true
   for _,child in guis do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil
  end
  table.insert(guis,gui);return gui
 end
 factory.modifier=factory.create
 function factory.createImage(size)
  local image={Size=size,Writes=0}
  function image:WritePixelsBuffer(_,dimensions,pixels)
   assert(dimensions.X==self.Size.X and dimensions.Y==self.Size.Y,'EditableImage dimensions match the retained allocation')
   self.Pixels=pixels;self.Writes+=1
  end
  function image:Destroy()assert(not self.Destroyed,'EditableImage disposed twice');self.Destroyed=true end
  return image
 end
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},
  ['Layout/TextMeasure']={measure=function(value,_,size)return {X=(utf8.len(value)or 0)*size*.45,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
 local document=Parser.parseDocument(html,{ScriptingEnabled=true});assert(#document.Diagnostics==0,'Delivered HTML diagnostics')
 local svgNodes={}
 for reference,source in svgs do
  local parsed=Parser.parse(source);assert(#parsed.Diagnostics==0,'SVG diagnostics: '..reference)
  svgNodes[reference]=assert(Node.findElement(parsed,function(n)return n.Name=='svg'end),'SVG root: '..reference)
 end
 local url='http://localhost:8000/fernweh/index.html';local messages,diagnostics={},{}
 local corners=Corners.new(function(value)table.insert(messages,value)end,factory.createImage)
 local root=factory.create('ScrollingFrame',nil,{AbsoluteWindowSize=Vector2.new(viewportWidth,viewportHeight)})
 local tree=renderer.build(document,root,function(value)table.insert(messages,value)end,function(font)return font end,
  nil,nil,nil,nil,nil,corners,nil,nil,{['styles.css']=css},url,nil,nil,nil,nil,function(reference)
   return svgNodes[reference]or svgNodes[reference:gsub('^http://localhost:8000/fernweh/','')]
  end)
 local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
 function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
 local runService={RenderStepped=signal()}
 local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return if hitGui then {hitGui}else {}end},Factory=factory,
  Clock=function()return time end,RunService=runService,MeasureValidationText=function()return Vector2.new(250,18)end,
  ScriptSources={['http://localhost:8000/fernweh/app.js']=app},
  Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
 local page={Alive=true,Document=document,DocumentURL=url,BaseURL=url,Root=root,Cleanups={},
  ResolveSVG=function(reference)return svgNodes[reference]or svgNodes[reference:gsub('^http://localhost:8000/fernweh/','')]end}
 services.ResourceServices={Task=services.Task}
 function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
 page:AddCleanup(function()corners:Destroy()end)
 local pending,flushing=false,false;local targets={};local realm,cssMotion;local layouts=0;local modes={}
 local function request(_,item,reason)pending=true;if item then targets[item]=reason or true end end
 function page:RequestAnimationLayout(box)request(true,box)end
 function page:HasPendingLayout()return pending end
 function page:GeometryViewport()
  return {Width=viewportWidth,Height=viewportHeight,ClientWidth=viewportWidth,ClientHeight=viewportHeight,
   ScrollWidth=math.max(viewportWidth,tree.LocalRight or 0),ScrollHeight=tree.LocalBottom or tree.OuterHeight or viewportHeight,
   ScrollX=root.CanvasPosition.X,ScrollY=root.CanvasPosition.Y}
 end
 local function arrange(items)
  layouts+=1;tree:SetMediaEnvironment(viewportWidth,viewportHeight);tree.ViewportHeight=viewportHeight
  local stats=Dirty.begin(tree,items);layout.arrange(tree,viewportWidth,0,0,function()return true end);Dirty.finish(tree,true)
  table.insert(modes,stats.Mode)
 end
 function page:FlushScriptLayout()
  if flushing or not realm then return end;flushing=true
  for attempt=1,8 do
   local needed,items=realm:Flush();for item,reason in items or {}do targets[item]=reason end
   if not needed and not pending then break end
   local dirty=targets;targets={};pending=false;arrange(if next(dirty)then dirty else nil)
   if cssMotion then cssMotion:AfterLayout()end;realm:AfterLayout()
   assert(attempt<8 or not pending,'FERNWEH layout did not converge')
  end
  flushing=false
 end
 arrange(nil);Controller.start(page,tree,request,function(value)table.insert(diagnostics,value)end,services)
 cssMotion=HTMLAnimations.start(page,tree,function(value)table.insert(diagnostics,value)end,services,20);cssMotion:AfterLayout()
 root:SetAttribute('Status','ready')
 realm=HTMLScripts.start(page,tree,function()end,function(value)table.insert(diagnostics,value)end,{JavaScriptServices=services},function()page:FlushScriptLayout()end)
 local function healthy()
  assert(#diagnostics==0,table.concat(diagnostics,' | '));assert(#messages==0,table.concat(messages,' | '))
 end
 local function settle()
  for _=1,40 do
   local work=deferred;deferred={};for _,fn in work do fn()end
   page:FlushScriptLayout();realm:AfterLayout();local count=realm:PumpTasks()
   if #deferred==0 and count==0 and not pending and not realm:HasPending()then break end
  end
  page:FlushScriptLayout();healthy()
 end
 local function run(source)realm:Run(source);settle()end
 local function advance(ms)time+=ms/1000;runService.RenderStepped:Fire(ms/1000);settle()end
 local function node(id)return assert(Node.findById(document,id),id)end
 local function box(id)return assert(tree.NodeBoxes[node(id)],'Native box: '..id)end
 local function control(id)return assert(page.FormModel:Resolve(node(id)),'Native control: '..id)end
 local function click(id)run("document.getElementById('"..id.."').click();")end
 local function select(id,value)run("document.getElementById('"..id.."').value='"..value.."';document.getElementById('"..id.."').dispatchEvent(new Event('change',{bubbles:true}));")end
 local function nativeText(id,value)
  local editor=assert(control(id).Item.Editor);editor:CaptureFocus();editor.Text=value;settle();return editor
 end
 local function rows()
  local result={};for _,child in node('saved-body').Children do if child.Kind=='Element'and child.Name=='tr'then table.insert(result,child)end end;return result
 end
 local arrow=assert(Node.findElement(document,function(n)return n.Attributes.class=='round-link'end))
 local function circularBorder(n,size)
  local b=assert(tree.NodeBoxes[n],'Circle owns a retained layout box')
  assert(b.Style.Background==nil and b.OuterWidth==size and b.OuterHeight==size,'Transparent circle preserves CSS dimensions')
  local surface=if b.ImageItem and b.ImageItem.OutputBox then b.ImageItem.OutputBox else b
  assert(surface.ResolvedBorderRadii and surface.ResolvedBorderRadii[1][1]==size/2 and surface.ResolvedBorderRadii[1][2]==size/2,'CSS percentage radius resolves to a circle')
  local border=assert(surface.RasterBorderGui,'Circle has a raster border');assert(border.Visible,'Circle border is visible')
  for index=1,4 do assert(not surface.InsetEdges[index].Visible,'Circle has no rectangular edge strips')end
  local image=border.ImageContent;local row=border.ImageRectOffset.Y
  local function alpha(x,y)return buffer.readu8(image.Pixels,((row+y)*image.Size.X+x)*4+3)end
  local middle=math.floor(size/2)
  assert(alpha(middle,middle)==0 and alpha(0,0)==0 and alpha(middle,0)>200,'Transparent circle paints only its rounded rim')
  return border,image
 end
 local arrowBorder=circularBorder(arrow,35)
 local countBorder=circularBorder(node('saved-count'),28)
 local countItem=control('saved-count').Item
 local noscript=assert(Node.findElement(document,function(n)return n.Name=='noscript'end))
 assert(not tree.NodeBoxes[noscript]and #noscript.Children==1 and noscript.Children[1].Kind=='Text','Enabled JavaScript keeps the no-script notice out of the rendered website')
 assert(not Node.findElement(noscript,function(n)return n.Attributes.class=='noscript-note'end),'No fixed fallback banner element is parsed when JavaScript is enabled')
 assert(countItem.Label.TextXAlignment==Enum.TextXAlignment.Center,'Saved counter is centered horizontally')
 assert(math.abs(countItem.Label.Position[2]-(1+(countItem.ContentHeight-countItem.TextSize)/2))<.001,'Saved counter is centered vertically within its border')
 run("globalThis.fwCheck=(v,m)=>{if(!v)throw new Error(m);};")
 assert(Node.textContent(node('result-count'))=='6'and Node.textContent(node('saved-count'))=='0','Page startup counters')
 assert(Node.textContent(node('booking-summary'))=='504 €','Initial real price')
 assert(#tree.SVGItems>=8,'Delivered SVG artwork must use native image items')
 for _,item in tree.SVGItems do assert(item.SVG and not item.TextFallback,'SVG resources do not use alt-text placeholders')end
 local noteHost=assert(Node.findElement(document,function(n)return n.Name=='fernweh-note'end))
 assert(noteHost.InternalShadowRoot,'Delivered custom element attaches its real Shadow DOM')
 local shadowParagraph=assert(Node.findElement(noteHost.InternalShadowRoot,function(n)return n.Name=='p'end))
 assert(Node.textContent(shadowParagraph)=='Gute Orte brauchen keine lange Packliste. Nur ein bisschen Zeit.')
 assert(tree.NodeStyles[shadowParagraph].Color==Color3.fromRGB(86,103,94),'Scoped custom-element style')

 local searchEditor=nativeText('search','Kein passender Lieblingsort')
 assert(Node.textContent(node('result-count'))=='0'and node('empty-results').Attributes.hidden==nil,
  'Real native search gives empty state: '..Node.textContent(node('result-count'))..' / '..control('search').Value)
 run("fwCheck([...document.querySelectorAll('article[data-stay]')].every(card=>card.hidden),'All unmatched cards hidden');")
 click('reset-filters');assert(control('search').Value==''and control('search').Item.Editor==searchEditor)
 select('region','wald');assert(Node.textContent(node('result-count'))=='2','Region filter')
 run("fwCheck(!document.getElementById('stay-waldlicht').hidden&&document.getElementById('stay-uferhaus').hidden,'Region visibility');")
 click('reset-filters')
 run("document.querySelector('[data-save=\"uferhaus\"]').click();")
 local first=assert(rows()[1]);local firstGui=assert(tree.NodeBoxes[first]).Gui
 run("document.querySelector('[data-save=\"waldlicht\"]').click();")
 assert(circularBorder(node('saved-count'),28)==countBorder,'Counter text updates retain its circular border')
 assert(#rows()==2 and rows()[1]==first and tree.NodeBoxes[first].Gui==firstGui,'Adding saved houses retains existing native table rows')
 run("fwCheck(localStorage.getItem('fernweh:saved:v1')==='[\"uferhaus\",\"waldlicht\"]','Saved IDs persisted');document.getElementById('only-saved').click();")
 assert(Node.textContent(node('result-count'))=='2','Saved filter')
 run("document.querySelector('[data-remove=\"waldlicht\"]').click();")
 assert(#rows()==1 and rows()[1]==first and tree.NodeBoxes[first].Gui==firstGui,'Removal retains unrelated row and controls')
 assert(Node.textContent(node('saved-count'))=='1'and Node.textContent(node('result-count'))=='1','Removal updates both counts')
 click('reset-filters')

 local dialogGui=box('detail-dialog').Gui;local dialogImages={}
 for _,child in node('detail-images').Children do if child.Kind=='Element'and child.Name=='img'then
  dialogImages[child.Attributes['data-detail-region']]={Node=child,Gui=assert(tree.NodeBoxes[child],'Retained dialog image: '..child.Attributes['data-detail-region']).Gui}
 end end
 run("document.querySelector('[data-details=\"waldlicht\"]').click();fwCheck(document.getElementById('detail-dialog').open,'Native dialog opened');")
 assert(Node.textContent(node('detail-title'))=='Waldlicht'and dialogImages.wald.Node.Attributes.hidden==nil
  and dialogImages.see.Node.Attributes.hidden~=nil,'Details use the existing forest artwork')
 click('detail-plan');assert(control('booking-stay').Value=='waldlicht'and box('detail-dialog').Gui==dialogGui,'Plan changes booking while retaining the shared dialog')
 assert(node('detail-dialog').Attributes.open==nil and Node.textContent(node('booking-summary'))=='426 €','Planning closes dialog and recalculates price')
 run("document.querySelector('[data-details=\"bergfenster\"]').click();")
 assert(Node.textContent(node('detail-guests'))=='Bis zu 6 Gäste'and box('detail-dialog').Gui==dialogGui,'One dialog is reused across houses')
 click('detail-close');assert(node('detail-dialog').Attributes.open==nil,'Explicit close')
 run("document.querySelector('[data-details=\"uferhaus\"]').click();document.getElementById('detail-dialog').requestClose();")
 assert(node('detail-dialog').Attributes.open==nil,'Native cancel/requestClose closes shared dialog')
 for _,image in dialogImages do assert(tree.NodeBoxes[image.Node].Gui==image.Gui,'Changing house regions retains native SVG image surfaces')end

 local messageEditor=nativeText('message','Ein Wochenende zum Durchatmen.')
 messageEditor:ReleaseFocus();settle()
 assert(control('message').Value=='Ein Wochenende zum Durchatmen.','Native textarea input reaches real booking controls')
 click('guest-plus');assert(control('guests').Value=='3'and Node.textContent(node('guest-count'))=='3','Stepper synchronizes guest control')
 run("fwCheck(!document.getElementById('guests').checkValidity(),'Small-house capacity validity');")
 click('booking-submit');assert(not control('booking-submit').Disabled,'Invalid form does not start the promise')
 run("fwCheck(!document.getElementById('booking-form').checkValidity(),'Required booking controls');")
 click('guest-minus');nativeText('full-name','Tobias Test');nativeText('email','tobias@example.test')
 select('booking-stay','uferhaus')
 local summary=Node.textContent(node('booking-summary'));local before=layouts
 click('newsletter')
 assert(layouts==before and Node.textContent(node('booking-summary'))==summary,'A newsletter checkbox does not reflow unchanged booking summaries')
 run("fwCheck(document.getElementById('booking-form').checkValidity(),'Complete booking form');")
 click('booking-submit');assert(control('booking-submit').Disabled,'Local preparation disables duplicate submission')
 assert(Node.textContent(node('booking-submit'))=='Wird vorbereitet…','Busy caption')
 click('booking-submit');advance(300)
 assert(control('booking-submit').Disabled,'Promise remains pending before 650 ms')
 local progressBox=box('booking-progress-fill')
 local progressScale=progressBox.Style.Transform[1]
 assert(progressScale and progressScale.Kind=='scale'and progressScale.Value>0 and progressScale.Value<1,
  'RAF advances the mounted progress surface between zero and completion')
 nativeText('message','Eine korrigierte Anfrage.')
 assert(not control('booking-submit').Disabled and Node.textContent(node('booking-status')):find('geändert',1,true),'Editing cancels pending preparation')
 advance(700)
 assert(not Node.textContent(node('booking-status')):find('lokal vorbereitet;',1,true),'Canceled promise never confirms obsolete values')
 click('booking-submit');advance(649);assert(control('booking-submit').Disabled,'650 ms deadline is not shortened')
 advance(2)
 local confirmation=Node.textContent(node('booking-status'))
 for _,part in {'Tobias Test','Uferhaus','3 Nächte','504','Newsletter gewünscht','Die Anfrage wurde lokal vorbereitet; es wurde nichts versendet.'}do
  assert(confirmation:find(part,1,true),'Real local confirmation: '..part)
 end
 assert(not control('booking-submit').Disabled and realm.EventLoop.FrameCount==0,'Completed request releases busy state and RAF')
 -- Silent programmatic correction is caught by the actual submission snapshot.
 click('booking-submit');run("document.getElementById('nights').value='4';");advance(651)
 assert(Node.textContent(node('booking-status')):find('geändert',1,true)and Node.textContent(node('booking-summary'))=='672 €','Snapshot guards edits without input events')

 run("document.getElementById('trip-note').focus();")
 local editing=assert(page.ContentEditableInput);local noteEditor=editing.Editor;local noteGui=box('trip-note').Gui
 assert(editing.Host==node('trip-note')and focused==noteEditor,'Plaintext note uses mounted native editing')
 noteEditor.CursorPosition=1;noteEditor.SelectionStart=-1;noteEditor.Text='Wald, Licht und ein gutes Buch.';settle()
 assert(Node.textContent(node('trip-note'))=='Wald, Licht und ein gutes Buch.','Native note proposal updates actual DOM text')
 run("const fwNote=document.getElementById('trip-note');getSelection().collapse(fwNote.firstChild,fwNote.firstChild.length);")
 editing:Hint(Enum.KeyCode.Return,false,false)
 local noteText='Wald, Licht und ein gutes Buch.\nZeit zum Durchatmen.'
 noteEditor.CursorPosition=#noteText+1;noteEditor.SelectionStart=-1;noteEditor.Text=noteText;settle()
 assert(Node.textContent(node('trip-note'))==noteText and #node('trip-note').Children==1
  and node('trip-note').Children[1].Kind=='Text','Native plaintext Enter keeps the line break in one actual text node')
 run("fwCheck(localStorage.getItem('fernweh:note:v1')===null,'Editing does not auto-save note');")
 click('note-save')
 run("fwCheck(localStorage.getItem('fernweh:note:v1')==='Wald, Licht und ein gutes Buch.\\nZeit zum Durchatmen.','Explicit multiline note storage');")
 assert(Node.textContent(node('note-status'))=='Ihre Notiz wurde auf diesem Gerät gespeichert.')
 nativeText('newsletter-email','leser@example.test')
 run("document.getElementById('newsletter-form').requestSubmit();")
 assert(Node.textContent(node('newsletter-result')):find('leser@example.test',1,true)and Node.textContent(node('newsletter-result')):find('nichts versendet',1,true),'Newsletter confirmation is local and honest')

 local cards={};for _,id in {'uferhaus','waldlicht','gipfelruhe','seeatelier','mooshuette','bergfenster'}do cards[id]=box('stay-'..id).Gui end
 for _,width in {360,800,1280}do
  viewportWidth=width;root.AbsoluteSize=Vector2.new(width,viewportHeight);root.AbsoluteWindowSize=Vector2.new(width,viewportHeight)
  arrange(nil);realm:AfterLayout();settle()
  assert(control('message').Item.Editor==messageEditor and box('trip-note').Gui==noteGui and editing.Editor==noteEditor,'Responsive resize retains native editor identities')
  for id,gui in cards do assert(box('stay-'..id).Gui==gui,'Responsive card retained: '..id)end
  assert(circularBorder(arrow,35)==arrowBorder and circularBorder(node('saved-count'),28)==countBorder,'Responsive resize retains both circular borders')
  local a,b=box('stay-uferhaus'),box('stay-waldlicht')
  assert(if width==360 then b.LayoutY>a.LayoutY else math.abs(a.LayoutY-b.LayoutY)<.001,'Delivered responsive card columns: '..width)
 end
 local modeStart=#modes;local oldNodes={};for n,b in tree.NodeBoxes do oldNodes[n]=b.Gui end
 local _,arrowImage=circularBorder(arrow,35);local arrowWrites=arrowImage.Writes
 local _,arrowLayout=tree:SetCSSState('hover',arrow)
 assert(not arrowLayout,'Arrow color hover does not reflow');settle();advance(250)
 tree:SetCSSState('hover',nil);settle();advance(250)
 local _,retainedArrowImage=circularBorder(arrow,35)
 assert(retainedArrowImage==arrowImage and arrowImage.Writes==arrowWrites,'Glyph hover retains the unchanged circular border image')
 local changed,needsLayout,items=tree:SetCSSState('hover',node('note-save'))
 assert(changed,'Actual delivered button hover rule');if needsLayout then request(true);for item,reason in items or {}do targets[item]=reason end end
 settle();advance(250)
 tree:SetCSSState('hover',nil);settle();advance(250)
 for index=modeStart+1,#modes do assert(modes[index]=='partial','Button paint hover does not request full-page layout')end
 for n,gui in oldNodes do if tree.NodeBoxes[n]then assert(tree.NodeBoxes[n].Gui==gui,'Hover retains native surfaces')end end
 run("globalThis.fwCircleProbe=document.createElement('output');fwCircleProbe.id='circle-probe';fwCircleProbe.style.cssText='display:block;width:28px;height:28px;box-sizing:border-box;border:1px solid red;border-radius:50%';fwCircleProbe.value='0';document.body.appendChild(fwCircleProbe);")
 local _,probeImage=circularBorder(node('circle-probe'),28)
 run("fwCircleProbe.remove();")
 assert(probeImage.Destroyed,'Removing a rounded output releases its raster allocation immediately')
 click('clear-saved');assert(#rows()==0 and Node.textContent(node('saved-count'))=='0','Clear saved houses')
 advance(3000);assert(node('toast').Attributes.hidden~=nil and realm.EventLoop.FrameCount==0 and runService.RenderStepped:Count()==0,'Toast and motion leave no idle frame work')
 for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end;page.Alive=false
 assert(messageEditor:GetPropertyChangedSignal('Text'):Count()==0 and noteEditor.Destroyed and input.InputBegan:Count()==0,'Page cleanup releases native input callbacks')
 healthy()
 print('FERNWEH website: shipped HTML/CSS/external JS/SVG, Shadow DOM, filters, retained saved rows/dialog/editors, prices/validity, local async cancellation/snapshot, notes/newsletter, responsive geometry and paint-only hover passed')
end
