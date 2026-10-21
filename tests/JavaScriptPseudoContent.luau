--!strict
-- Native computed-value references intentionally retain counter functions;
-- rendered counter digits and attribute text are checked independently.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,fixtures)
 local factory={}
 function factory.create(class,parent,properties)
  local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent
  function gui:Destroy()self.Destroyed=true;self.Parent=nil end
  return gui
 end
 factory.modifier=factory.create
 local renderer=loadRenderTree(factory)
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*8,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local failures={}
 for _,case in fixtures do
  assert(#case.expected>0,case.name..': native reference has not been captured')
  local expected=case.engineExpected or case.expected
  local document=Parser.parseDocument('<html><head></head><body>'..case.markup..'<div id="outside">Retained</div></body></html>')
  local messages,diagnostics,values={},{},{}
  local tree=renderer.build(document,{AbsoluteSize=Vector2.new(600,800)},function(message)table.insert(messages,message)end,nil,nil,nil,nil,case.css)
  local function arrange(targets)Dirty.begin(tree,targets);layout.arrange(tree,600,0,0,function()return true end);Dirty.finish(tree,true)end
  arrange(nil)
  local runtime;local flushing=false
  local function flush()
   if flushing then return end;flushing=true
   local needed,targets=runtime:Flush();if needed then arrange(targets)end
   runtime:AfterLayout();flushing=false
  end
  local events=Events.new(error)
  runtime=Runtime.new(document,{Events=events,Clock=function()return 0 end,
   Diagnostic=function(message)table.insert(diagnostics,message)end,Console=function(_,value)table.insert(values,value)end,
   GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return {Width=600,Height=800}end,
    HasPending=function()return runtime:HasPending()end,Flush=flush},
   ApplyChanges=function(changes)return tree:ApplyDOMChanges(changes)end})
  local outside=tree.NodeBoxes[Node.findById(document,'outside')];local retained=outside.Gui
  runtime:Run("function record(value){console.log(String(value));}const box=document.getElementById('box');\n"..case.source)
  flush();runtime:PumpTasks();flush()
  if #diagnostics>0 or #messages>0 then table.insert(failures,case.name..': '..table.concat(diagnostics,' | ')..' / '..table.concat(messages,' | '))end
  if #values~=#expected then table.insert(failures,case.name..': native value count '..#values..' ~= '..#expected)
  else for i,value in values do if value~=expected[i]then table.insert(failures,case.name..' ['..i..']: '..value..' ~= '..expected[i])end end end
  if case.name=='counter serialization does not resolve displayed digits'then
   local generated='';local owner=Node.findById(document,'box')
   for _,item in tree.TextItems do if item.Style and item.Style.Node==owner then generated..=item.Text or''end end
   if not generated:find('4.',1,true)or not generated:find('IV',1,true)then table.insert(failures,case.name..': native digits were not rendered')end
  end
  if outside.Gui~=retained then table.insert(failures,case.name..': content reads replaced an unrelated GUI')end
  runtime:Destroy();events:Destroy()
  assert(runtime.EventLoop.FrameCount==0 and runtime.EventLoop.TaskCount==0,'Disposed pseudo reads retain frames or tasks')
 end
 for _,failure in failures do print('Pseudo computed-content mismatch: '..failure)end
 assert(#failures==0,'Pseudo computed-content fixture failures: '..#failures)
 local profiles=0;for _,case in fixtures do if case.engineExpected then profiles+=1 end end
 print('JavaScript pseudo computed content: '..(#fixtures-profiles)..' native references, '..profiles..' explicit CSS/WPT conformance difference, live attributes, string escaping, symbolic counters, normal/none and retained rendering passed')
end
