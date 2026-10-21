--!strict
-- The remaining Chromium fixtures need mounted controls and rendered copying.
-- Each case owns a fresh native controller, Runtime and document.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,HTMLScripts,Controller,fixtures)
 -- Existing Chromium capture: javascript-r04-input-browser.json, report
 -- "control combining selection". No simulated/native expectation is used.
 fixtures=table.clone(fixtures)
 table.insert(fixtures,{name='control combining selection',
  source="const control=document.createElement('input');control.value='A\\u0308B';document.body.append(control);control.focus();const s=getSelection(),values=[];for(const [a,b]of [[0,1],[1,2],[0,2],[2,3]]){control.setSelectionRange(a,b);values.push(a+':'+b+':'+s.toString())}record(values.join('|'));",
  expected={'0:1:Ä|1:2:|0:2:Ä|2:3:B'}})
 -- The same capture also covers combining marks, supplementary scalars and
 -- a family ZWJ grapheme together. Password copying masks each grapheme.
 for _,kind in {'text','password'}do
  local selected=if kind=='text'then {'Ä😀👩‍👩‍👧‍👦Z','Ä','😀','👩‍👩‍👧‍👦',''}else {'••••','•','•','•',''}
  local expected={}
  for index,pair in {{0,16},{0,2},{2,4},{4,15},{3,4}}do
   table.insert(expected,kind..'|'..pair[1]..'|'..pair[2]..'|backward|'..selected[index])
  end
  table.insert(fixtures,{name='control complex graphemes '..kind,
   source="const control=document.createElement('input');control.type='"..kind.."';control.value='A\\u0308😀👩‍👩‍👧‍👦Z';document.body.appendChild(control);control.focus();for(const [a,b]of [[0,control.value.length],[0,2],[2,4],[4,15],[3,4]]){control.setSelectionRange(a,b,'backward');record(control.type+'|'+control.selectionStart+'|'+control.selectionEnd+'|'+control.selectionDirection+'|'+String(getSelection()));}",
   expected=expected})
 end
 local failures={}
 for _,fixture in fixtures do
  local function signal()
   local entries={};local result={}
   function result:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(entries,{c,fn});return c end
   function result:Fire(...)for _,entry in table.clone(entries)do if entry[1].Connected then entry[2](...)end end end
   function result:Count()local count=0;for _,entry in entries do if entry[1].Connected then count+=1 end end;return count end
   return result
  end
  local focused;local guis,deferred={},{}
  local factory={}
  function factory.create(class,parent,props)
   local changes,attributes={},{}
   local values={Parent=parent,ClassName=class,Visible=true,AbsolutePosition=Vector2.new(0,0),AbsoluteSize=Vector2.new(520,500),Text='',CursorPosition=-1,SelectionStart=-1}
   for key,value in props do values[key]=value end
   if class=='ScrollingFrame'then values.CanvasPosition=Vector2.new(0,0)end
   local gui=setmetatable({},{__index=values,__newindex=function(_,key,value)local old=values[key];values[key]=value;if old~=value and changes[key]then changes[key]:Fire()end end})
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
    assert(not values.Destroyed);values.Destroyed=true
    for _,child in guis do if child.Parent==gui and not child.Destroyed then child:Destroy()end end
    gui.Parent=nil
   end
   table.insert(guis,gui);return gui
  end
  factory.modifier=factory.create
  local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=(utf8.len(text)or 0)*size*.45,Y=size}end}}
  overrides['Layout/WordLayout']=loadWordLayout(overrides)
  local layout=loadBlockLayout(overrides);local renderer=loadRenderTree(factory)
  local document=Parser.parseDocument('<!doctype html><html><head></head><body><script>globalThis.inventoryBoot=1;</script></body></html>')
  local diagnostics,messages,output={},{},{}
  local root=factory.create('ScrollingFrame',nil,{})
  local tree=renderer.build(document,root,function(message)table.insert(messages,message)end,function(font)return font end)
  local function arrange(items)
   tree:SetMediaEnvironment(520,500);tree.ViewportHeight=500
   Dirty.begin(tree,items);layout.arrange(tree,520,0,0,function()return true end);Dirty.finish(tree,true)
  end
  arrange();root:SetAttribute('Status','ready')
  local page={Alive=true,Document=document,DocumentURL='https://example.test/r04-mounted',BaseURL='https://example.test/r04-mounted',Root=root,Cleanups={}}
  function page:AddCleanup(fn)table.insert(self.Cleanups,fn)end
  function page:GeometryViewport()
   local size,position=root.AbsoluteSize,root.CanvasPosition
   return{Width=size.X,Height=size.Y,ClientWidth=size.X,ClientHeight=size.Y,ScrollX=position.X,ScrollY=position.Y,
    ScrollWidth=math.max(size.X,tree.LocalRight or tree.OuterWidth or 0),ScrollHeight=math.max(size.Y,tree.LocalBottom or tree.OuterHeight or 0)}
  end
  local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
  function input:GetFocusedTextBox()return focused end
  function input:IsKeyDown()return false end
  local services={Input=input,PlayerGui={GetGuiObjectsAtPosition=function()return{}end},Factory=factory,Clock=function()return 0 end,
   RunService={RenderStepped=signal()},Task={defer=function(fn)table.insert(deferred,fn)end,delay=function(_,fn)return{Callback=fn}end,cancel=function(ticket)ticket.Canceled=true end}}
  local realm,flushing
  function page:HasPendingLayout()return realm and realm:HasPending()or false end
  function page:FlushScriptLayout()
   if not realm or flushing then return end;flushing=true
   local needed,items=realm:Flush();if needed then arrange(items)end
   flushing=false
  end
  Controller.start(page,tree,function()end,error,services)
  realm=assert(HTMLScripts.start(page,tree,function()end,function(message)table.insert(diagnostics,message)end,{JavaScriptServices=services}),'Mounted fixture Runtime')
  local function settle()
   for _=1,24 do
    page:FlushScriptLayout();realm:AfterLayout()
    local pending=deferred;deferred={};for _,fn in pending do fn()end
    local tasks=realm:PumpTasks()
    if #deferred==0 and tasks==0 and not realm:HasPending()then return end
   end
   error('Mounted selection fixture did not settle')
  end
  local ok,message=pcall(function()
   settle()
   -- A trusted record function avoids intercepting print or modifying the
   -- mounted adapter's console behavior. Authored fixture code is unchanged.
   realm.VM.GlobalEnvironment:Write('record',function(args)table.insert(output,realm.VM.Model.string(args[1]))end,true)
   realm:Run(fixture.source);settle()
   assert(#diagnostics==0,table.concat(diagnostics,' | '));assert(#messages==0,table.concat(messages,' | '))
   assert(#output==#fixture.expected,'record count '..#output..' versus '..#fixture.expected)
   for i,expected in fixture.expected do assert(output[i]==expected,'record '..i..': '..tostring(output[i])..' versus '..expected)end
   if fixture.name:find('control ',1,true)or fixture.name:find('password ',1,true)then
    assert(focused and focused.ClassName=='TextBox'and not focused.Destroyed,'Control fixture uses an actual mounted TextBox')
    assert(focused:GetPropertyChangedSignal('CursorPosition'):Count()==1 and focused:GetPropertyChangedSignal('SelectionStart'):Count()==1,'One native selection binding per active editor')
   end
   if fixture.name=='control combining selection'then
    -- A native backwards selection supplies UTF8 byte positions. Its DOM
    -- extent must remain UTF16 while rendered copying selects the grapheme.
    focused.CursorPosition=1;focused.SelectionStart=4;settle()
    realm:Run("if(control.selectionStart!==0||control.selectionEnd!==2||control.selectionDirection!=='backward'||String(s)!=='A\\u0308')throw new Error('Native combining selection');")
    assert(#diagnostics==0,table.concat(diagnostics,' | '))
   end
  end)
  page.Alive=false;for index=#page.Cleanups,1,-1 do page.Cleanups[index]()end
  assert(not realm.Alive and input.InputBegan:Count()==0,'Mounted reference disposal releases Runtime and input callbacks')
  for _,gui in guis do if gui.ClassName=='TextBox'then
   assert(gui:GetPropertyChangedSignal('Text'):Count()==0 and gui:GetPropertyChangedSignal('CursorPosition'):Count()==0 and gui:GetPropertyChangedSignal('SelectionStart'):Count()==0,'Mounted reference disposal releases editor callbacks')
  end end
  if not ok then table.insert(failures,fixture.name..': '..tostring(message))end
 end
 for _,failure in failures do print('R04 mounted mismatch: '..failure)end
 assert(#failures==0,'R04 mounted reference failures: '..#failures)
 print('R04 mounted Selection: '..#fixtures..' Chromium 154 control/password/copying/navigation reference cases passed')
end
