--!strict
return function(Core,Node,Work)
 local checks=0;local function check(value,label)checks+=1;assert(value,label)end
 local function fixture()
  local node=Node.element('audio',{});local a=Node.element('source',{src='a.wav',media='(min-width:0px)',type='audio/wav'});local b=Node.element('source',{src='b.wav'})
  Node.append(node,a);Node.append(node,b)
  local r={Node=node,SelectionEpoch=1,Generation=1,Network=3,Loading=true,Current='',Rate=1.5,Position=5,DefaultStart=7,Plays={{}}}
  local tasks,stable,requests,events={},{},{},{};local core
  local c={Alive=function()return true end,QueueTask=function(fn)table.insert(tasks,fn)end,QueueStable=function(fn)table.insert(stable,fn)end,
   Resolve=function(_,raw)return 'https://media.test/'..raw end,GetViewport=function()return {Width=800,Height=600}end,
   Changed=function()end,Dispatch=function(target,kind)table.insert(events,{Node=target,Kind=kind,Current=r.Current})end,
   CanLoad=function()return nil end,CanRenderSourceType=function()return nil end,Selected=function()end,ShouldDefer=function()return false end,
   Suspend=function()end,DirectFailure=function()error('Unexpected direct failure')end,
   Fetch=function(state)table.insert(requests,state.Raw)end}
  core=Core.new(c)
  local function checkpoint()while #stable>0 do table.remove(stable,1)()end end
  local function drain()while #tasks>0 or #stable>0 do checkpoint();if #tasks>0 then table.remove(tasks,1)()end end end
  return core,c,r,tasks,stable,requests,events,checkpoint,drain,a,b
 end
 -- Existing managed fixtures cover error-listener reentry. These cover the
 -- injected native resolver/capability/scheduler callbacks, before any VM exists.
 for _,stage in {'Alive','GetViewport','Resolve','CanRenderSourceType','Selected','ShouldDefer','CanLoad','Changed'}do
  for _,action in {'destroy','epoch'}do
   local core,c,r,tasks,stable,requests,events,checkpoint,drain=fixture();local original=c[stage];local entered=false
   c[stage]=function(...)
    if not entered then entered=true;if action=='destroy'then core:Destroy()else r.SelectionEpoch+=1;r.Generation+=1;core:Invalidate(r)end end
    return original(...)
   end
   core:Begin(r,1);drain();check(entered and #requests==0,'Injected '..stage..' '..action..' reentry prevents stale native IO')
   check(r.Rate==1.5 and r.Position==5 and r.DefaultStart==7 and #r.Plays==1,'Core cannot reset caller playback state');core:Destroy()
  end
 end
 for _,queue in {'QueueTask','QueueStable'}do
  local core,c,r,tasks,stable,requests,events,checkpoint,drain=fixture();local original=c[queue]
  c[queue]=function(fn)core:Destroy();original(fn)end
  core:Begin(r,1);drain();check(#requests==0 and #events==0,'Injected scheduler disposal suppresses held deliveries and native IO')
 end
 do
  local core,c,r,tasks,stable,requests,events,checkpoint,drain,a=fixture()
  c.GetViewport=function()a.Attributes.media='not all';return {Width=800,Height=600}end
  core:Begin(r,1);drain();check(#requests==1 and requests[1]=='a.wav','Media attribute snapshot precedes injected viewport reentry')
  core:Destroy()
 end
 do
  local core,c,r,tasks,stable,requests,events,checkpoint,drain,a,b=fixture();local changed=false
  c.Fetch=function(state)table.insert(requests,state.Raw);if state.Raw=='a.wav'then core:Fail(state)end end
  core:Begin(r,1)
  Work.with(function()if not changed and r.Phase=='source-error'then changed=true;core:BeforeRemove(r,b);Node.removeChild(r.Node,b)end end,checkpoint)
  check(changed and r.Waiting and r.Gap==1,'Cooperative removal after search test cannot advance gap beyond live end')
  local added=Node.element('source',{src='c.wav'});core:BeforeInsert(r,1,1);Node.append(r.Node,added)
  check(core:ResumeWaiting(r),'Exact-gap append resumes after cooperative removal');drain()
  check(requests[2]=='c.wav'and #requests==2 and r.Gap==2,'New sibling is attempted once from the retained gap');core:Destroy()
 end
 do
  local core,c,r,tasks,stable,requests,events,checkpoint,drain,a,b=fixture()
  c.Fetch=function(state)table.insert(requests,state.Raw);if state.Raw=='a.wav'then core:Fail(state)end end
  core:Begin(r,1);checkpoint()
  check(#requests==2 and requests[1]=='a.wav'and requests[2]=='b.wav','Stable continuation attempts next resource before source error task')
  drain();check(#events==2 and events[1].Kind=='loadstart'and events[2].Node==a and events[2].Current=='https://media.test/b.wav','Captured source error survives ordinary generation increment')
  check(r.SelectionEpoch==1 and r.Generation==2 and r.Gap==2,'Attempt generation is distinct from selection epoch');core:Destroy()
 end
 do
  local core,c,r,tasks,stable,requests,events,checkpoint,drain,a,b=fixture()
  c.ShouldDefer=function()return true end
  c.CanLoad=function()error('Availability must run after None deferral')end
  core:Begin(r,1);drain();check(r.Phase=='deferred'and r.Raw=='a.wav'and #requests==0,'Optional None retains the first resource before availability')
  local text,before=Node.text('between'),Node.comment('before');core:BeforeInsert(r,0,1);Node.insertBefore(r.Node,before,a)
  check(r.Gap==2,'Insertion before the gap shifts every-node count');core:BeforeInsert(r,2,1);Node.insertBefore(r.Node,text,b)
  check(r.Gap==2,'Insertion exactly at gap remains after pointer');core:BeforeRemove(r,a);Node.removeChild(r.Node,a)
  check(r.Gap==1 and r.Candidate==a,'Removed in-flight identity is retained while adjacent-node gap follows remaining nodes');core:Destroy()
 end
 do
  local weak=setmetatable({},{__mode='v'});local keptCore,keptTasks,keptStable
  local function create()
   local core,c,r,tasks,stable=fixture();local page,item={},{}
   c.Page=page;c.Item=item;c.Changed=function()assert(page and item)end
   r.Node.Children[1].Attributes.src='';weak.Page=page;weak.Item=item;weak.State=r;weak.Node=r.Node;weak.Source=r.Node.Children[1];weak.Context=c;weak.Plain={}
   local controlNode=Node.element('audio',{});local controlSource=Node.element('source',{src='control.wav'});Node.append(controlNode,controlSource)
   weak.ControlState={Node=controlNode,Candidate=controlSource};weak.ControlNode=controlNode;weak.ControlSource=controlSource
   core:Start(r,1);check(#tasks==2 and #stable==1,'Held source error plus stable retry are genuinely queued')
   keptCore,keptTasks,keptStable=core,tasks,stable;core:Destroy();core:Destroy()
  end
  create()
  local function collected()return weak.Page==nil and weak.Item==nil and weak.State==nil and weak.Node==nil and weak.Source==nil and weak.Context==nil end
  local function pressure(predicate)
   for _=1,128 do if predicate()then return end;local temporary=table.create(2048);for i=1,2048 do temporary[i]={i,i+1}end end
  end
  local function controlCollected()return weak.ControlState==nil and weak.ControlNode==nil and weak.ControlSource==nil end
  pressure(function()return collected()and weak.Plain==nil and controlCollected()end)
  check(weak.Plain==nil,'Independent core plain weak control before held deliveries')
  check(controlCollected(),'Independent same-shaped state/node/source/parent cyclic control collects before held deliveries')
  print('CORE_OWNERSHIP_BEFORE','page='..tostring(weak.Page==nil),'item='..tostring(weak.Item==nil),'state='..tostring(weak.State==nil),'node='..tostring(weak.Node==nil),'source='..tostring(weak.Source==nil),'context='..tostring(weak.Context==nil))
  check(collected(),'Destroyed core drops Context/Node/Candidate/State while external queues and core API are retained')
  for _,fn in keptStable do fn()end;for _,fn in keptTasks do fn()end;keptCore:Destroy()
 end
 print('MediaSelection core: 18 injected reentry controls, ordering/epoch/None/media-snapshot/cooperative-gap and bounded queued ownership passed; assertions='..checks)
end
