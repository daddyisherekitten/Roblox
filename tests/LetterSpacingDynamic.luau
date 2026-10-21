--!strict
-- Dynamic used spacing and retained native owners. Raw browser advances and
-- shaping are kept separate from the engine's frozen line-edge tracking rule.
return function(Parser,Node,Style,InlineWords,SpacingOwners,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local function close(a,b,message)assert(math.abs(a-b)<.001,message..': '..tostring(a)..' != '..tostring(b))end
 local allocations,measures,guis=0,0,{}
 local inspectMeasure
 local function create(class,parent,props)
  allocations+=1;local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent
  function gui:Destroy()self.Destroyed=true;self.Parent=nil end
  table.insert(guis,gui);return gui
 end
 local renderer=loadRenderTree({create=create,modifier=create})
 local face={Family='Spacing fixture',Weight='Regular',Style='Normal'}
 local overrides={['Layout/FontProfiles']={face=function()return face end},['Layout/TextMeasure']={measure=function(text,_,size)
  measures+=1;if inspectMeasure then inspectMeasure()end
  return {X=#require('Layout/LetterSpacing').split(text)*10,Y=size}
 end}}
 local wordsLayout=loadWordLayout(overrides);overrides['Layout/WordLayout']=wordsLayout
 local blockLayout=loadBlockLayout(overrides)
 local function build(source)
  local doc=Parser.parse(source);local tree=renderer.build(doc,{},error,function()return face end)
  return tree,doc
 end
 local function run(owner)return owner.Children[1]end
 local function arrange(flow,width,alive)return wordsLayout.arrange(flow,width or 200,0,0,alive or function()return true end)end
 local function measurePure(flow)
  local context=require('Layout/LayoutMeasurement').new(flow,function()return true end)
  wordsLayout.arrange(context.Root,200,0,0,function()return true end);context:KeepMeasurements()
 end
 local function update(tree,node,value)
  node.Attributes.style=value;local changed,layout,items=tree:RefreshDOMStyles({[node]=true})
  assert(changed and layout,'A real spacing change invalidates geometry')
  return items
 end
 local function word(tree,id)
  local owner=tree.NodeBoxes[Node.findById(tree.Document,id)]
  return run(owner).Items[1]
 end
 -- The internal comparison is exactly the initial tokenizer comparison.
 local base=Style.resolve(Node.element('span',{style='font-size:20px;letter-spacing:0'}),{Font='Inter',FontSize=20,Color=Color3.new(0,0,0)},error,true)
 local other=table.clone(base)
 assert(InlineWords.sameStyle(base,other))
 other.LetterSpacing=2;assert(not InlineWords.sameStyle(base,other))
 local plain={Kind='Word',Text='ABC',Style=base}
 local owner={Children={{Kind='Words',Items={plain}}}}
 assert(not SpacingOwners.needsRefresh(owner))
 base.LetterSpacing=2;assert(SpacingOwners.needsRefresh(owner),'Mode change requires native owner regeneration')
 plain.Glyphs={{Text='A'},{Text='B'},{Text='C'}}
 assert(not SpacingOwners.needsRefresh(owner))
 local snapshot=table.clone(base);snapshot.LetterSpacing=0
 plain.SourceSpans={{SourceStyle=snapshot}}
 assert(SpacingOwners.needsRefresh(owner),'Merged source changes require tokenizer regrouping')
 plain.SourceSpans=nil;base.LetterSpacing=0;base.TabularNums=true
 plain.Text='109';assert(not SpacingOwners.needsRefresh(owner),'Zero-spaced tabular digits keep glyph mode')
 base.TabularNums=nil;assert(SpacingOwners.needsRefresh(owner))
 plain.EmptyInline=true;plain.Glyphs=nil;assert(not SpacingOwners.needsRefresh(owner))
 -- Cooperative inspection remains mutation-only and checks large source maps.
 local checked=0;plain.EmptyInline=nil;plain.Text='ABC';plain.SourceSpans={}
 for i=1,96 do table.insert(plain.SourceSpans,{SourceStyle=base})end
 assert(not SpacingOwners.needsRefresh(owner,function()checked+=1 end)and checked==3)
 local whitespace={Kind='Space',Text='  ',Style=base}
 base.LetterSpacing=2
 assert(not SpacingOwners.glyphs(whitespace)and not SpacingOwners.needsRefresh({Children={{Kind='Words',Items={whitespace}}}}),'Tracked whitespace retains its empty frame')
 snapshot=table.clone(base);snapshot.TabularNums=true
 plain.Glyphs={{Text='A'},{Text='B'},{Text='C'}};plain.SourceSpans={{SourceStyle=snapshot}}
 assert(SpacingOwners.needsRefresh(owner),'Tabular source scopes split an old merged native word')
 -- Relative values follow current CSS font size, not rounded native TextSize.
 local tree,doc=build('<div style="font-size:33.6px;letter-spacing:-.025em"><p id=relative>ABC</p><p id=outside style="letter-spacing:2px">DEF</p></div>')
 tree.Document=doc
 local outer=tree.Children[1];local relative=outer.Children[1];local flow=run(relative)
 arrange(flow);measurePure(flow);local item=flow.Items[1];local gui,glyph,bounds=item.Gui,item.Glyphs[1].Gui,item.NativeGlyphBounds
 local outside=word(tree,'outside');local outsideGui=outside.Gui
 update(tree,outer.Node,'font-size:25.26px;letter-spacing:-.025em');measurePure(flow);arrange(flow)
 close(outer.Style.LetterSpacing,-.6315,'em uses the new CSS font')
 close(item.Style.LetterSpacing,-.6315,'Inherited used value reaches displayed words')
 assert(flow.Items[1]==item and item.Gui==gui and item.Glyphs[1].Gui==glyph and outside.Gui==outsideGui,'Nonzero spacing/font recascade preserves native word owners')
 assert(item.NativeGlyphBounds~=bounds,'A changed native font size gets fresh per-item bounds')
 local measured=measures;bounds=item.NativeGlyphBounds;local allocated=allocations
 update(tree,outer.Node,'font-size:25.26px;letter-spacing:3px');arrange(flow,80)
 assert(flow.Items[1]==item and item.Gui==gui and item.Glyphs[1].Gui==glyph and measures==measured and allocations==allocated and item.NativeGlyphBounds==bounds,'Spacing-only nonzero updates retain glyph labels and native bounds')
 close(item.Glyphs[2].X,13,'Painted grapheme positions use updated spacing')
 local pre=build('<p style="white-space:pre;letter-spacing:2px">AB  CD</p>')
 local preFlow=run(pre.Children[1]);measurePure(preFlow);arrange(preFlow)
 local preA,preSpace,preB=preFlow.Items[1],preFlow.Items[2],preFlow.Items[3]
 local preGui,preBounds=preA.Gui,preA.NativeGlyphBounds;measured=measures;allocated=allocations
 update(pre,pre.Children[1].Node,'white-space:pre;letter-spacing:3px');arrange(preFlow)
 assert(preFlow.Items[1]==preA and preFlow.Items[2]==preSpace and preFlow.Items[3]==preB and preA.Gui==preGui and preA.NativeGlyphBounds==preBounds and measures==measured and allocations==allocated,'Spacing-only preserved whitespace keeps every word/frame and measurement')
 -- reviewed requirement: measurement-cache. The actual preferred-size path
 -- sees new tracking without publishing any provisional painted position.
 local preferred=build('<p style="letter-spacing:2px">ABC</p>');local preferredOwner=preferred.Children[1];local preferredFlow=run(preferredOwner)
 close(blockLayout.intrinsicWidth(preferredOwner,200,function()return true end,'max-content'),34,'Initial tracked max-content width')
 close(blockLayout.intrinsicWidth(preferredOwner,200,function()return true end,'min-content'),34,'Initial tracked min-content width')
 arrange(preferredFlow);local preferredWord=preferredFlow.Items[1];local retainedPosition=preferredWord.Glyphs[2].Gui.Position
 local trackedX=preferredWord.Glyphs[2].X;measured=measures
 update(preferred,preferredOwner.Node,'letter-spacing:3px')
 close(blockLayout.intrinsicWidth(preferredOwner,200,function()return true end,'max-content'),36,'Live tracked max-content width')
 close(blockLayout.intrinsicWidth(preferredOwner,200,function()return true end,'min-content'),36,'Live tracked min-content width')
 assert(measures==measured and preferredWord.Glyphs[2].Gui.Position==retainedPosition and preferredWord.Glyphs[2].X==trackedX,'Preferred-size queries retain native bounds and original paint geometry')
 arrange(preferredFlow);close(preferredWord.Glyphs[2].X,13,'Only arranged publication moves a tracked glyph')
 -- reviewed requirement: live-glyph-mode. Both native label modes are
 -- regenerated only on a zero/nonzero crossing.
 for _,pair in {{'0px','2px'},{'2px','0px'},{'2px','normal'},{'normal','-1px'}}do
  local t,d=build('<p style="letter-spacing:'..pair[1]..'">A&#x308;👩‍💻B</p>')
  local p=t.Children[1];local before=run(p).Items[1];arrange(run(p));local native=before.Gui
  local source=p.Node.Children[1];update(t,p.Node,'letter-spacing:'..pair[2]);local after=run(p).Items[1];arrange(run(p))
  assert(after~=before and after.Gui~=native and native.Destroyed and p.Node.Children[1]==source,'Mode crossings replace rendered words while retaining DOM text')
  local tracked=pair[2]~='0px'and pair[2]~='normal'
  assert((after.Glyphs~=nil)==tracked,'Current used spacing chooses the actual native label mode')
  if tracked then assert(#after.Glyphs==3 and after.Glyphs[1].Text=='Ä'and after.Glyphs[2].Text=='👩‍💻','A combining/ZWJ grapheme remains indivisible')end
  assert(Node.textContent(d)=='Ä👩‍💻B')
 end
 local tabular=build('<p style="font-variant-numeric:tabular-nums;letter-spacing:2px">109</p>')
 local digits=run(tabular.Children[1]).Items[1];local digitGui=digits.Gui
 update(tabular,tabular.Children[1].Node,'font-variant-numeric:tabular-nums;letter-spacing:0');arrange(run(tabular.Children[1]))
 assert(run(tabular.Children[1]).Items[1]==digits and digits.Gui==digitGui and digits.Glyphs,'Digit glyph mode survives a spacing-zero update')
 local digitScopes=build('<p style="letter-spacing:2px"><span>10</span><span>29</span></p>')
 local digitOwner=digitScopes.Children[1];assert(#run(digitOwner).Items==1)
 update(digitScopes,digitOwner.Node.Children[1],'font-variant-numeric:tabular-nums')
 assert(#run(digitOwner).Items==2 and run(digitOwner).Items[1].Style.TabularNums and not run(digitOwner).Items[2].Style.TabularNums,'A new tabular source scope repartitions an existing glyph word')
 -- Distinct native digit widths expose stale tabular caches. Completed pure
 -- measurements publish bounds; an aborted reverse toggle cannot publish.
 local variableMeasures,variableInspect=0,nil
 local variableWords=loadWordLayout({['Layout/FontProfiles']=overrides['Layout/FontProfiles'],['Layout/TextMeasure']={measure=function(text,_,size)
  variableMeasures+=1;if variableInspect then variableInspect()end
  local width=0;for _,g in require('Layout/LetterSpacing').split(text)do width+=if g.Text=='1'then 5 elseif g.Text=='9'then 15 else 10 end
  return {X=width,Y=size}
 end}})
 local varied=build('<p style="letter-spacing:2px">19A</p>');local variedOwner=varied.Children[1];local variedFlow=run(variedOwner);local variedWord=variedFlow.Items[1]
 local variedGui,variedDigit=variedWord.Gui,variedWord.Glyphs[1].Gui
 local function variablePure(alive)
  local live=alive or function()return true end
  local probe=require('Layout/LayoutMeasurement').new(variedFlow,live)
  variableWords.arrange(probe.Root,200,0,0,live);probe:KeepMeasurements();return probe
 end
 variablePure();variableWords.arrange(variedFlow,200,0,0,function()return true end)
 close(variedWord.Glyphs[1].Width,5,'Proportional digit width')
 assert(variedDigit.TextXAlignment==Enum.TextXAlignment.Left)
 update(varied,variedOwner.Node,'letter-spacing:2px;font-variant-numeric:tabular-nums')
 variablePure()
 close(variedWord.NativeGlyphBounds.Bounds[1].Width,15,'Tabular toggle publishes fresh completed cell bounds')
 variableWords.arrange(variedFlow,200,0,0,function()return true end)
 close(variedWord.Glyphs[2].X,17,'Tabular digit placement uses the new equal cell')
 assert(variedFlow.Items[1]==variedWord and variedWord.Gui==variedGui and variedWord.Glyphs[1].Gui==variedDigit and variedDigit.TextXAlignment==Enum.TextXAlignment.Center and variedWord.Glyphs[3].Gui.TextXAlignment==Enum.TextXAlignment.Left,'Tabular toggle retains native glyphs while updating digit-only alignment')
 local variableCount,tabularBounds=variableMeasures,variedWord.NativeGlyphBounds
 update(varied,variedOwner.Node,'letter-spacing:3px;font-variant-numeric:tabular-nums');variableWords.arrange(variedFlow,80,0,0,function()return true end)
 assert(variableMeasures==variableCount and variedWord.NativeGlyphBounds==tabularBounds,'Warm tracking updates retain completed tabular measurements')
 close(variedWord.Glyphs[2].X,18,'Warm tabular placement adopts tracking')
 update(varied,variedOwner.Node,'letter-spacing:2px;font-variant-numeric:normal')
 local variableAlive=true;variableInspect=function()variableAlive=false end
 variablePure(function()return variableAlive end);variableInspect=nil
 assert(not variableAlive and variedWord.NativeGlyphBounds==tabularBounds and variedWord.MeasuredTabular==true,'Aborted reverse toggle cannot publish proportional bounds or cache keys')
 variablePure();variableWords.arrange(variedFlow,200,0,0,function()return true end)
 close(variedWord.Glyphs[1].Width,5,'Reverse toggle restores proportional widths')
 close(variedWord.Glyphs[2].X,7,'Reverse toggle restores proportional placement')
 assert(variedWord.MeasuredTabular==false and variedFlow.Items[1]==variedWord and variedWord.Gui==variedGui and variedWord.Glyphs[1].Gui==variedDigit and variedDigit.TextXAlignment==Enum.TextXAlignment.Left,'Recovered reverse toggle preserves glyph identity and correct alignment')
 variableCount=variableMeasures;variableWords.arrange(variedFlow,70,0,0,function()return true end)
 assert(variableMeasures==variableCount,'Recovered proportional measurements are warm')
 -- reviewed requirement: live-source-groups. A merged word may split;
 -- equal former source styles may merge before any
 -- first layout has populated Joined, without a second grouping algorithm.
 for _,early in {true,false}do
  local t,d=build('<p style="letter-spacing:0"><span style="letter-spacing:0">AB</span><span>CD</span></p>')
  local p=t.Children[1];local sourceA,sourceB=p.Node.Children[1].Children[1],p.Node.Children[2].Children[1]
  local initial=run(p).Items[1];assert(#run(p).Items==1 and #initial.SourceSpans==4)
  if not early then arrange(run(p))end
  update(t,p.Node,'letter-spacing:2px')
  assert(#run(p).Items==2 and run(p).Items[1].Text=='AB'and run(p).Items[2].Text=='CD','Distinct used source spacing splits an old merged word')
  local first=p.Node.Children[1]
  update(t,first,'letter-spacing:2px')
  assert(#run(p).Items==1 and run(p).Items[1].Text=='ABCD'and #run(p).Items[1].SourceSpans==4,'Equal source spacing rejoins the lexical word even before first layout')
  assert(first.Children[1]==sourceA and p.Node.Children[2].Children[1]==sourceB and Node.textContent(d)=='ABCD')
 end
 -- Fonts use the same lexical scope invariant as tracking. Compare distinct
 -- source styles once, with the initial tokenizer's complete comparison.
 for _,case in {{'font-size','20px','30px'},{'font-family','Arial','Courier New'},{'font-weight','400','700'},{'font-style','normal','italic'}}do
  local field,before,after=case[1],case[2],case[3]
  local t,d=build('<p style="letter-spacing:2px;'..field..':'..before..'"><span style="'..field..':'..before..'">AB</span><span>CD</span></p>')
  local parent=t.Children[1];local child=parent.Node.Children[1]
  local sourceA,sourceB=child.Children[1],parent.Node.Children[2].Children[1]
  assert(#run(parent).Items==1)
  update(t,parent.Node,'letter-spacing:2px;'..field..':'..after)
  assert(#run(parent).Items==2 and run(parent).Items[1].Text=='AB'and run(parent).Items[2].Text=='CD',field..' changes split a former equal source group')
  update(t,child,field..':'..after)
  assert(#run(parent).Items==1 and run(parent).Items[1].Text=='ABCD',field..' equality rejoins the existing lexical group')
  assert(child.Children[1]==sourceA and parent.Node.Children[2].Children[1]==sourceB and Node.textContent(d)=='ABCD',field..' regrouping preserves native DOM source nodes')
 end
 local preserved=build('<p style="letter-spacing:0">AB<wbr><span style="letter-spacing:2px">CD</span></p>')
 local p=preserved.Children[1];update(preserved,p.Node.Children[3],'letter-spacing:0')
 assert(#run(p).Items==2 and run(p).Items[2].SoftBefore,'An explicit soft boundary remains distinct')
 -- A canceled cold probe cannot publish half of a new glyph measurement.
 local cold=build('<p style="letter-spacing:0">ABC</p>');p=cold.Children[1]
 update(cold,p.Node,'letter-spacing:2px');local coldItem=run(p).Items[1]
 local alive=true;inspectMeasure=function()alive=false end
 local context=require('Layout/LayoutMeasurement').new(p,function()return alive end)
 blockLayout.arrange(context.Root,200,0,0,function()return alive end)
 inspectMeasure=nil
 assert(not alive and coldItem.NativeGlyphBounds==nil and coldItem.MeasuredSize==nil,'Canceled cold pure measurement never publishes source cache fields')
 context:KeepMeasurements()
 assert(coldItem.NativeGlyphBounds==nil and coldItem.MeasuredSize==nil,'Canceled probe cache publication respects its original alive guard')
 arrange(run(p));local fresh=build('<p style="letter-spacing:2px">ABC</p>');arrange(run(fresh.Children[1]))
 close(coldItem.Width,run(fresh.Children[1]).Items[1].Width,'Fresh recovery after canceled measurement')
 -- Actual mounted controller and JavaScript style/selection paths.
 local function signal()
  local listeners={};local s={}
  function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(listeners,{c,fn});return c end
  function s:Fire(...)for _,v in table.clone(listeners)do if v[1].Connected then v[2](...)end end end
  function s:Count()local n=0;for _,v in listeners do if v[1].Connected then n+=1 end end;return n end
  return s
 end
 local comparisons=0
 -- The runner's selection-prefix adapter measures ASCII at TextSize/2.
 -- Mounted layout uses that same host model; pure cache probes above keep
 -- their fixed 10px grapheme metrics. Neither is a native glyph-shaping proof.
 local mountedOverrides=table.clone(overrides)
 mountedOverrides['Layout/TextMeasure']={measure=function(text,_,size)return {X=#require('Layout/LetterSpacing').split(text)*size/2,Y=size}end}
 mountedOverrides['Layout/WordLayout']=loadWordLayout(mountedOverrides)
 local mountedLayout=loadBlockLayout(mountedOverrides)
 local function mounted(source)
  local focused;local surfaces,deferred={},{};local factory={}
  function factory.create(class,parent,props)
   local changes,attributes={},{}
   local values={Parent=parent,ClassName=class,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(800,600),AbsoluteWindowSize=Vector2.new(800,600),Text='',CursorPosition=-1,SelectionStart=-1}
   for k,v in props do values[k]=v end;if class=='ScrollingFrame'then values.CanvasPosition=Vector2.new(0,0)end
   local gui=setmetatable({},{__index=values,__newindex=function(_,k,v)local before=values[k];values[k]=v;if before~=v and changes[k]then changes[k]:Fire()end end})
   values.Focused,values.FocusLost,values.InputBegan=signal(),signal(),signal()
   function values:GetPropertyChangedSignal(k)if not changes[k]then changes[k]=signal()end;return changes[k]end
   function values:GetAttributeChangedSignal(k)return self:GetPropertyChangedSignal('attribute:'..k)end
   function values:SetAttribute(k,v)attributes[k]=v;if changes['attribute:'..k]then changes['attribute:'..k]:Fire()end end
   function values:GetAttribute(k)return attributes[k]end
   function values:IsA(k)return k==class or(k=='GuiObject'and class~='ScreenGui')end
   function values:IsFocused()return focused==gui end
   function values:CaptureFocus()if focused and focused~=gui then focused:ReleaseFocus()end;focused=gui;gui.CursorPosition=1;self.Focused:Fire()end
   function values:ReleaseFocus()if focused==gui then focused=nil;gui.CursorPosition=-1;gui.SelectionStart=-1;self.FocusLost:Fire(false)end end
   function values:Destroy()if values.Destroyed then return end;values.Destroyed=true;for _,child in surfaces do if child.Parent==gui and not child.Destroyed then child:Destroy()end end;gui.Parent=nil end
   table.insert(surfaces,gui);return gui
  end
  factory.modifier=factory.create
  local doc=Parser.parseDocument(source..'<script>globalThis.spacingFixtureStarted=true</script>');local layer=factory.create('ScreenGui',nil,{})
  local root=factory.create('ScrollingFrame',layer,{ClipsDescendants=true})
  local live=loadRenderTree(factory).build(doc,root,error,function()return face end)
  local realm,flushing
  local function arrange(items)
   live:SetMediaEnvironment(800,600);live.ViewportHeight=600
   -- Match HTMLPage publication: a new container width recascades relative
   -- font/tracking values only after that width has actually been arranged.
   for pass=1,8 do
    Dirty.begin(live,items);mountedLayout.arrange(live,800,0,0,function()return true end);Dirty.finish(live,true)
    local _,needed,targets=live:RefreshContainerSizes()
    if not needed then break end
    assert(pass<8,'Dynamic tracking container styles did not converge');items=targets
   end
   if realm then realm:AfterLayout();if realm.SelectionAdapter then realm.SelectionAdapter:AfterLayout()end end
  end
  arrange();root:SetAttribute('Status','ready')
  local page={Alive=true,Document=doc,DocumentURL='https://example.test/tracking',BaseURL='https://example.test/tracking',Root=root,Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
  function input:GetFocusedTextBox()return focused end;function input:IsKeyDown()return false end
  local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return {}end},Factory=factory,Clock=function()return 0 end,
   RunService={RenderStepped=signal()},Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return {Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
  require('Input/Controller').start(page,live,function()end,error,services)
  function page:HasPendingLayout()return realm and realm:HasPending()or false end
  function page:FlushScriptLayout()if flushing or not realm then return end;flushing=true;local needed,items=realm:Flush();if needed then arrange(items)end;flushing=false end
  function page:GeometryViewport()return {Width=800,Height=600,X=0,Y=0}end
  realm=require('Rendering/HTMLScripts').start(page,live,function()end,error,{JavaScriptServices=services})
  local function flush()
   for _=1,24 do
    local needed,items=realm:Flush();if needed then arrange(items)end
    local work=deferred;deferred={};for _,fn in work do fn()end
    if #deferred==0 and realm:PumpTasks()==0 then break end
   end
  end
  local function execute(code)local ok,err=realm:Run(code);assert(ok,tostring(err));flush()end
  local function dispose()
   for i=#page.Cleanups,1,-1 do page.Cleanups[i]()end;page.Alive=false;layer:Destroy()
   for _,gui in surfaces do if gui.ClassName=='TextBox'then assert(gui.Destroyed and gui:GetPropertyChangedSignal('Text'):Count()==0 and gui:GetPropertyChangedSignal('CursorPosition'):Count()==0,'Disposal releases retained editor and native callbacks')end end
  end
  return {Tree=live,Document=doc,Run=execute,Focused=function()return focused end,
   Copy=function(a,ao,b,bo)return realm.SelectionAdapter:CopyText(a,ao,b,bo,false)end,Dispose=dispose}
 end
 local live=mounted(reference.source)
 live.Run("const editor=document.getElementById('editor');editor.focus();editor.setSelectionRange(1,4);const savedEditor=editor;")
 local originalEditor=live.Focused();assert(originalEditor and originalEditor.ClassName=='TextBox')
 local outsideNode=Node.findById(live.Document,'outside');local outsideItem
 for _,item in live.Tree.TextItems do if item.Kind=='Word'and item.Style.Node==outsideNode then outsideItem=item;break end end
 assert(outsideItem);local retainedOutside=outsideItem.Gui
 local ids={'base','inherited','local','zero','cluster','kern','rem','editor','outside'}
 -- reviewed requirement: live-resolved-values. These independent native
 -- values cover DOM/font/em/rem inheritance and container recascades below.
 for _,state in reference.states do
  local operation=state.operation:gsub('parent.style','document.getElementById("parent").style'):gsub('local.style','document.getElementById("local").style')
  live.Run(operation)
  for _,id in ids do
   local node=Node.findById(live.Document,id);local actual=live.Tree.NodeStyles[node];local expected=state.items[id]
   close(actual.UnadjustedFontSize or actual.FontSize,tonumber(expected.font:match('[%d.]+')),state.name..' '..id..' native CSS font')
   close(actual.LetterSpacing or 0,if expected.spacing=='normal'then 0 else tonumber(expected.spacing:match('[%+%-]?[%d.]+')),state.name..' '..id..' native used spacing')
   if id~='editor'then
    local found=false
    for _,item in live.Tree.TextItems do if item.Kind=='Word'and not item.EmptyInline and item.Style.Node==node then
     found=true;close(item.Style.LetterSpacing or 0,actual.LetterSpacing or 0,state.name..' '..id..' displayed word spacing')
     assert((item.Glyphs~=nil)==SpacingOwners.glyphs(item),state.name..' '..id..' displayed native glyph/label mode')
    end end
    assert(found,state.name..' '..id..' keeps a displayed word owner')
   end
   comparisons+=1
  end
  assert(live.Focused()==originalEditor and not originalEditor.Destroyed,'Spacing/font mutations preserve the active native editor')
  assert(outsideItem.Gui==retainedOutside and not retainedOutside.Destroyed,'A separate text branch retains its native owner through tracking mutations')
  live.Run("if(editor!==savedEditor||document.activeElement!==editor||editor.value!=='ALPHA'||editor.selectionStart!==1||editor.selectionEnd!==4)throw new Error('Spacing changes retained editor selection');")
 end
 live.Dispose()
 -- Class/variable declarations enter the same real CSSOM mutation adapter;
 -- their expected arithmetic is separate from the 24 raw native snapshots.
 live=mounted('<style>html{font-size:16px}body{margin:0}#host{font-size:20px;--tracking:2px;letter-spacing:var(--tracking)}#host.spread{--tracking:3px}#host.tight{--tracking:-.025em}#host.large{font-size:40px}#fixed{letter-spacing:1px}</style><div id=host><p id=target>ABC</p><p id=fixed>DEF</p></div>')
 local trackingNode=Node.findById(live.Document,'target');local fixedNode=Node.findById(live.Document,'fixed');local trackingGui,fixedGui
 for _,item in live.Tree.TextItems do if item.Kind=='Word'then if item.Style.Node==trackingNode then trackingGui=item.Gui elseif item.Style.Node==fixedNode then fixedGui=item.Gui end end end
 assert(trackingGui and fixedGui)
 for _,case in {
  {'',2},{'host.className="spread"',3},{'host.className="tight"',-.5},
  {'host.className="tight large"',-1},{'host.style.setProperty("--tracking","4px")',4},
  {'host.style.removeProperty("--tracking")',-1},{'host.className=""',2},
 }do
  live.Run(case[1]);local actual=live.Tree.NodeStyles[trackingNode]
  close(actual.LetterSpacing,case[2],'Class/variable used tracking')
  live.Run("if(parseFloat(getComputedStyle(document.getElementById('target')).letterSpacing)!=="..tostring(case[2])..")throw new Error('Class/variable tracking CSSOM');")
  close(live.Tree.NodeStyles[fixedNode].LetterSpacing,1,'An explicit child tracking override survives class/variable recascade')
  for _,item in live.Tree.TextItems do if item.Kind=='Word'then
   if item.Style.Node==trackingNode then assert(item.Gui==trackingGui and not trackingGui.Destroyed and item.Glyphs,'Nonzero class/variable tracking retains existing glyph owners')
   elseif item.Style.Node==fixedNode then assert(item.Gui==fixedGui and not fixedGui.Destroyed,'A fixed tracking scope retains its native owner')end
  end end
 end
 live.Dispose()
 live=mounted(reference.groupSource)
 live.Run("const a=document.getElementById('joinedStart').firstChild,b=document.getElementById('joinedEnd').firstChild;const selected=document.createRange();selected.setStart(a,1);selected.setEnd(b,1);getSelection().removeAllRanges();getSelection().addRange(selected);")
 local sourceA=Node.findById(live.Document,'joinedStart').Children[1];local sourceB=Node.findById(live.Document,'joinedEnd').Children[1]
 local expectedOverlays={
  -- text, left advances, width advances, left tracking, width tracking
  initial={{'ABCD',1,2,0,0}},split={{'AB',1,1,0,0},{'CD',0,1,0,2}},
  ['same-nonzero']={{'ABCD',1,2,2,4}},['normal-merged']={{'ABCD',1,2,0,0}},
  negative={{'AB',1,1,0,0},{'CD',0,1,0,-1}},restored={{'ABCD',1,2,0,0}},
 }
 for _,state in reference.grouping do
  local previousOverlays={};for item,overlay in live.Tree.TextSelection.Overlays do previousOverlays[item]=overlay end
  live.Run(state.operation)
  live.Run("if(getSelection().toString()!=='BC'||getSelection().anchorNode!==a||getSelection().anchorOffset!==1||getSelection().focusNode!==b||getSelection().focusOffset!==1)throw new Error('Tracking source split/merge changes selection');")
  assert(live.Copy(sourceA,1,sourceB,1)=='BC','Copy preparation uses unchanged original source offsets after repartition')
  assert(Node.findById(live.Document,'joinedStart').Children[1]==sourceA and Node.findById(live.Document,'joinedEnd').Children[1]==sourceB,'Native source nodes survive every split/merge')
  local active={};for _,item in live.Tree.TextItems do active[item]=true end
  local overlays={};for item,overlay in live.Tree.TextSelection.Overlays do
   assert(active[item]and not item.Gui.Destroyed and not overlay.Frame.Destroyed and overlay.Frame.Parent==(item.TextGui or item.Gui),'Selection paint belongs to a current retained native word')
   assert(live.Tree.TextItemsByGui[overlay.Frame]==item,'Selection hit/source mapping targets the new word owner')
   table.insert(overlays,{item,overlay})
  end
  table.sort(overlays,function(a,b)return (a[1].X or 0)<(b[1].X or 0)end)
  local expected=expectedOverlays[state.name];assert(#overlays==#expected,state.name..' keeps every B/C selection overlay')
  for index,pair in overlays do
   assert(pair[1].Text==expected[index][1],state.name..' selection maps the current lexical grouping')
   local advance=pair[1].TextSize/2
   close(pair[2].Frame.Position[1],expected[index][2]*advance+expected[index][4],state.name..' selected B/C local position')
   close(pair[2].Frame.Size[1],expected[index][3]*advance+expected[index][5],state.name..' selected B/C tracked extent')
  end
  for item,overlay in previousOverlays do if not active[item]then assert(overlay.Frame.Destroyed and live.Tree.TextItemsByGui[overlay.Frame]==nil,'Regrouping retires old selection paint and hit mapping')end end
  for _,id in {'joined','splitCluster'}do
   local n=Node.findById(live.Document,id);local actual=live.Tree.NodeStyles[n];local expected=state.rows[id]
   assert(Node.textContent(n)==expected.text,'Spacing never changes the source grapheme sequence')
   close(actual.LetterSpacing or 0,if expected.spacing=='normal'then 0 else tonumber(expected.spacing:match('[%+%-]?[%d.]+')),state.name..' '..id..' native source-group spacing')
   comparisons+=1
  end
 end
 live.Dispose()
 live=mounted(reference.containerSource)
 for _,state in reference.containers do
  live.Run("document.getElementById('shell').style.width='"..state.width.."px'")
  for _,id in {'relative','parentUnit','inherit','fixed','localUnit','rootUnit'}do
   local actual=live.Tree.NodeStyles[Node.findById(live.Document,id)];local expected=state.items[id]
   close(actual.UnadjustedFontSize or actual.FontSize,tonumber(expected.font:match('[%d.]+')),'Container '..state.width..' '..id..' font')
   close(actual.LetterSpacing or 0,if expected.spacing=='normal'then 0 else tonumber(expected.spacing:match('[%+%-]?[%d.]+')),'Container '..state.width..' '..id..' spacing')
   comparisons+=1
  end
 end
 live.Dispose()
 assert(#reference.states==12 and #reference.grouping==6 and #reference.containers==6 and comparisons==156,'All frozen native spacing states remain covered')
 print('Dynamic letter spacing: 24 raw native states / '..comparisons..' used-value comparisons, zero modes, source regrouping, B/C selection paint, retained glyph/whitespace caches/editor selection and cold abort/recovery passed')
end
