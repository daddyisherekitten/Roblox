--!strict
-- BUILD-only strict controls against the real IFrameRuntime. These are host
-- cleanup-failure controls, not a browser exception or native-pixel reference.
return function(loadIFrameRuntime,Node)
 local checks,completed=0,0;local failures={};local expected={};local seen={}
 local function check(value,label)checks+=1;assert(value,label)end
 local function payload(kind,label)return if kind=='nil'then nil elseif kind=='false'then false else{Original=label}end
 local function setup(settings)
  settings=settings or{};local h={Jobs={},Children={},Items={},Cleanups={},Wakes=0,Events=0,Mounts=0,Diagnostics={},Armed=false,Entered=false}
  local document=Node.document();document.URL='https://frame.test/root/index.html'
  local page={Alive=true,Document=document,DocumentURL=document.URL,BaseURL=document.URL};h.Page=page
  function page:AddCleanup(fn)table.insert(h.Cleanups,fn)end
  function page:DocumentResourcesChanged()h.Wakes+=1;if settings.OnWake then settings.OnWake(h)end;if h.Armed and settings.WakeThrows and h.Old and not h.Old.Alive then error({Secondary='wake'},0)end end
  page.Events={Emit=function(_,node)h.Events+=1;h.LastEvent=node;if h.Armed and settings.LoadEventThrows then error({Secondary="load dispatch"},0)end end}
  for i=1,2 do local node=Node.element('iframe',{srcdoc='<p>child'..i..'</p>'});node.OwnerDocument=document;Node.append(document,node)
   table.insert(h.Items,{Node=node,ContentGui={Attributes={},SetAttribute=function(self,k,v)self.Attributes[k]=v end},FallbackGui={}})
  end
  local tasks={defer=function(fn)table.insert(h.Jobs,fn)end};local runtime=loadIFrameRuntime(tasks)
  function h.Drain()
   for _=1,60 do if #h.Jobs==0 then return end;local fn=table.remove(h.Jobs,1);local ok,value=pcall(fn);check(ok,tostring(value))end
   error('Single child queue did not converge')
  end
  local function mount(_,source,options)
   h.Mounts+=1;local child={Alive=true,Ready=h.Armed and settings.ReadyNew==true,DestroyCalls=0,DocumentURL=options.DocumentURL,BaseURL=options.FallbackBaseURL,Source=source,Root={SetAttribute=function()end},Callback=options.DocumentLoadStateChanged}
   function child:IsDocumentComplete()return self.Ready end
   function child:ScrollToFragment()end
   function child:Destroy()
    if not self.Alive then return end;self.Alive=false;self.DestroyCalls+=1
    if h.Armed and settings.OnDestroy then settings.OnDestroy(h,self)end
    if h.Armed and settings.ThrowChild==self then error(settings.Payload,0)end
    if h.Armed and settings.ThrowSibling==self then error(settings.SiblingPayload,0)end
   end
   table.insert(h.Children,child);if settings.OnMount then settings.OnMount(h,child)end;return child
  end
  function h.Start()return runtime.start(page,{IFrameItems=h.Items},function(message)table.insert(h.Diagnostics,message);if h.Armed and settings.DiagnosticThrows then error({Secondary="diagnostic"},0)end end,mount,{Task=tasks,IFrameResolver=function()return nil end})end
  h.API=h.Start();h.Drain();check(h.Mounts==2 and h.API:PendingCount()==2,'Initial actual controlled child leases are pending')
  h.Old,h.Neighbor=h.Items[1].ChildPage,h.Items[2].ChildPage;settings.ThrowChild=h.Old
  function h.Run(operation)
   if operation=='replace'then return table.pack(pcall(h.API.Reload,h.API,h.Items[1]))end
   h.Items[1].Node.Attributes.srcdoc=nil;h.Items[1].Node.Attributes.src='missing.html'
   h.API:Mutation({Type='attributes',Target=h.Items[1].Node,AttributeName='src'},page.BaseURL)
   check(#h.Jobs==1,'Unavailable source is a real deferred mutation request')
   local fn=table.remove(h.Jobs,1);return table.pack(pcall(fn))
  end
  function h.Stale()
   local events,wakes,mounts=h.Events,h.Wakes,h.Mounts;h.Old.Ready=true;h.Old.Callback('complete');h.Drain()
   check(h.Events==events and h.Wakes==wakes and h.Mounts==mounts,'Retired old document callback cannot load, wake, or mount')
  end
  function h.Finish()
   h.Armed=false;local owner=page.IFrameRuntime
   if owner then owner:Destroy()end;h.API:Destroy();h.Drain()
   for _,child in h.Children do check(not child.Alive and child.DestroyCalls==1,'Every owned old/new controlled child closes exactly once')end
   check(page.IFrameRuntime==nil and h.API:PendingCount()==0,'Final owner closure releases all slots')
  end
  return h
 end
 local function case(name,fn)
  table.insert(expected,name);local ok,value=pcall(fn)
  if ok then check(not seen[name],'No duplicate single-child control');seen[name]=true;completed+=1;print('IFRAME_SINGLE_CHILD_CONTROL',name)
  else table.insert(failures,{Name=name,Value=tostring(value)});print('IFRAME_SINGLE_CHILD_FAILED',name,tostring(value))end
 end
 local function base(operation,kind,wakeThrows)
  local original=payload(kind,operation);local h=setup({Payload=original,WakeThrows=wakeThrows});h.Armed=true
  local wakes=h.Wakes;local result=h.Run(operation)
  check(result[1]==false and result[2]==original,'Exact first '..kind..' payload survives cleanup and later wake failure')
  check(not h.Old.Alive and h.Old.DestroyCalls==1 and h.Neighbor.Alive,'Only captured target child closes during single replacement')
  check(h.Items[1].Loading==false,'Current target no longer owns an unfinishable Loading contribution')
  check(h.Wakes>=wakes+2,'Source reservation and final state both attempt parent wake')
  if operation=='replace'then
   local nextChild=h.Items[1].ChildPage;check(nextChild and nextChild~=h.Old and nextChild.Alive and h.Mounts==3,'Replacement mounts and publishes despite old child cleanup exception')
   check(h.API:PendingCount()==2 and h.Items[1].Error==nil and h.Items[1].ContentGui.Attributes.Status=='ready','Only genuine incomplete new/neighbor documents remain pending')
  else
   check(h.Items[1].ChildPage==nil and h.API:PendingCount()==1 and h.Mounts==2,'Unavailable target retires load contribution without touching neighbor')
   check(h.Items[1].Error~=nil and h.Items[1].FallbackGui.Visible==true and h.Items[1].ContentGui.Attributes.Status=='error'and #h.Diagnostics==1,'Unavailable state and diagnostic still publish after old child close failure')
  end
  h.Armed=false;h.Stale();local current=h.Items[1].ChildPage
  if current then current.Ready=true;current.Callback('complete');check(h.Events==1,'Current replacement has one genuine load event');current.Callback('complete');check(h.Events==1,'Current replacement load is not repeated')end
  h.Neighbor.Ready=true;h.Neighbor.Callback('complete');check(h.API:PendingCount()==0 and h.Events==(if current then 2 else 1),'Current child readiness clears final pending state with no obsolete frame load')
  h.Finish()
 end
 for _,operation in {'replace','unavailable'}do for _,kind in {'nil','false','table'}do
  case(operation..' '..kind,function()base(operation,kind,false)end)
  case(operation..' first error before wake '..kind,function()base(operation,kind,true)end)
 end end
 for _,operation in {'replace','unavailable'}do for _,mode in {'source','re-add','new owner'}do for _,kind in {'nil','false','table'}do
  case(operation..' reentry '..mode..' '..kind,function()
   local original=payload(kind,mode);local settings={Payload=original}
   settings.OnDestroy=function(h,child)
    if child~=h.Old or h.Entered then return end;h.Entered=true
    check(h.Items[1].ChildPage==nil,'Captured old child slot is taken before external Destroy hook')
    h.Items[1].Node.Attributes.srcdoc='<p>newest</p>';h.Items[1].Node.Attributes.src=nil
    if mode=='new owner'then h.API:Destroy();h.NextAPI=h.Start()
    elseif mode=='re-add'then h.API:Remove({h.Items[1]});h.API:Add({h.Items[1]})
    else h.Items[1].Node.Attributes.srcdoc='<p>newest</p>';h.API:Mutation({Type='attributes',Target=h.Items[1].Node,AttributeName='srcdoc'},h.Page.BaseURL)end
    h.Drain();h.Replacement=h.Items[1].ChildPage
   end
   local h=setup(settings);h.Armed=true;local result=h.Run(operation)
   check(h.Entered and result[1]==false and result[2]==original,'First original error survives current owner/source reentry')
   check(h.Replacement and h.Replacement.Alive and h.Items[1].ChildPage==h.Replacement and h.Items[1].Loading==false,'Reentrant newer child survives obsolete outer request')
   check(h.Items[1].Error==nil and h.Items[1].ContentGui.Attributes.Status=='ready','Obsolete unavailable path does not publish an error over newer ready state')
   if mode=='new owner'then check(h.Page.IFrameRuntime==h.NextAPI and h.API:PendingCount()==0,'New owner remains published and old registry is stopped')else check(h.Page.IFrameRuntime==h.API,'Same reusable owner remains current')end
   h.Armed=false;h.Stale();local owner=h.Page.IFrameRuntime;h.Replacement.Ready=true;h.Replacement.Callback('complete');check(h.Events==1,'Only reentrant current target publishes its load')
   check(owner:PendingCount()==1,'Only the genuine incomplete neighbor remains pending after current target completes');h.Finish()
  end)
 end end end
 for _,operation in {'replace','unavailable'}do for _,nested in {'Remove','Destroy'}do for _,kind in {'nil','false','table'}do
  case(operation..' nested '..nested..' first '..kind,function()
   local first=payload(kind,nested);local settings={Payload={Secondary='outer'},SiblingPayload=first}
   settings.OnDestroy=function(h,child)
    if child~=h.Old or h.Entered then return end;h.Entered=true;settings.ThrowSibling=h.Neighbor
    if nested=='Destroy'then h.API:Destroy()else h.API:Remove({h.Items[2]})end
   end
   local h=setup(settings);h.Armed=true;local result=h.Run(operation)
   check(h.Entered and result[1]==false and result[2]==first,'Nested first '..kind..' exception precedes later outer cleanup failure')
   check(not h.Old.Alive and not h.Neighbor.Alive and h.Old.DestroyCalls==1 and h.Neighbor.DestroyCalls==1,'Nested old-owner cleanup attempts both captured children once')
   if nested=='Destroy'then check(h.Page.IFrameRuntime==nil and h.API:PendingCount()==0 and h.Items[1].ChildPage==nil,'Nested Destroy invalidates pending outer replacement')
   elseif operation=='replace'then check(h.Items[1].ChildPage and h.Items[1].ChildPage.Alive and h.API:PendingCount()==1,'Nested sibling Remove preserves current replacement')
   else check(h.Items[1].ChildPage==nil and h.API:PendingCount()==0 and h.Items[1].Loading==false,'Nested sibling Remove permits terminal unavailable completion')end
   h.Armed=false;h.Stale();h.Finish()
  end)
 end end end
 for _,kind in {'nil','false','table'}do
  case('unavailable first error before diagnostic '..kind,function()
   local original=payload(kind,'diagnostic');local h=setup({Payload=original,DiagnosticThrows=true});h.Armed=true;local wakes=h.Wakes;local result=h.Run('unavailable')
   check(result[1]==false and result[2]==original,'Exact original child cleanup error survives later diagnostic failure')
   check(h.Items[1].Loading==false and h.Items[1].ChildPage==nil and h.API:PendingCount()==1,'Unavailable terminal target contribution is released before diagnostic failure')
   check(h.Items[1].ContentGui.Attributes.Status=='error'and h.Items[1].FallbackGui.Visible and #h.Diagnostics==1,'Unavailable terminal presentation and one diagnostic are attempted')
   check(h.Wakes==wakes+2,'Reservation and terminal parent wake are both attempted after diagnostic failure')
   h.Armed=false;h.Stale();h.Neighbor.Ready=true;h.Neighbor.Callback('complete');check(h.API:PendingCount()==0 and h.Events==1,'Released unavailable target cannot block genuine remaining neighbor completion');h.Finish()
  end)
  case('replace first error before load dispatch '..kind,function()
   local original=payload(kind,'load dispatch');local h=setup({Payload=original,ReadyNew=true,LoadEventThrows=true});h.Armed=true;local wakes=h.Wakes;local result=h.Run('replace')
   check(result[1]==false and result[2]==original,'Exact original child cleanup error survives later synchronous load dispatch failure')
   local child=h.Items[1].ChildPage;check(child and child.Alive and child.Ready and h.Items[1].Loading==false and h.API:PendingCount()==1,'Already-ready replacement publishes and only genuine neighbor remains pending')
   check(h.Events==1 and h.Items[1].ContentGui.Attributes.Status=='ready'and h.Wakes==wakes+2,'One terminal load dispatch and parent wake are attempted after child cleanup failure')
   h.Armed=false;h.Stale();child.Callback('complete');check(h.Events==1,'Already-completed replacement load is not repeated after failed dispatch');h.Neighbor.Ready=true;h.Neighbor.Callback('complete');check(h.API:PendingCount()==0 and h.Events==2,'Remaining current child completion releases last barrier');h.Finish()
  end)
 end
 for _,kind in {'nil','false','table'}do
  case('interleaved yielded replacement '..kind,function()
   local first=payload(kind,'B old child');local cError={Original='C independent wake'};local settings={Payload=first};local h=setup(settings);h.Armed=true
   local bThread,cThread;local bChild,cChild
   settings.OnMount=function(owner,child)
    if not owner.Armed then return end
    if child.Source=='<p>B</p>'then bChild=child;coroutine.yield('B mount held')end
    if child.Source=='<p>C</p>'then cChild=child end
   end
   settings.OnWake=function(owner)
    if owner.Armed and coroutine.running()==cThread and cChild and owner.Items[1].ChildPage==cChild and owner.Items[1].Loading==false then error(cError,0)end
   end
   h.Items[1].Node.Attributes.srcdoc='<p>B</p>'
   bThread=coroutine.create(function()h.API:Reload(h.Items[1])end)
   local bStart=table.pack(coroutine.resume(bThread));check(bStart[1]and bStart[2]=='B mount held'and coroutine.status(bThread)=='suspended','Actual replacement B yields inside the real mount boundary')
   check(not h.Old.Alive and h.Old.DestroyCalls==1 and h.Items[1].ChildPage==nil and h.Items[1].Loading==true,'B owns an incomplete mount and its captured old cleanup failure')
   h.Items[1].Node.Attributes.srcdoc='<p>C</p>';h.API:Mutation({Type='attributes',Target=h.Items[1].Node,AttributeName='srcdoc'},h.Page.BaseURL)
   check(#h.Jobs==1,'Newer C has a separate genuine deferred request')
   cThread=coroutine.create(table.remove(h.Jobs,1));local cResult=table.pack(coroutine.resume(cThread))
   check(cResult[1]==false and cResult[2]==cError,'Independent coroutine C reports its own original raw wake exception')
   check(cChild and cChild.Alive and h.Items[1].ChildPage==cChild and h.Items[1].Loading==false,'Independent newer C publishes its own current child before reporting its error')
   local bResult=table.pack(coroutine.resume(bThread));check(bResult[1]==false and bResult[2]==first,'Resumed obsolete B reports only its own first nil/false/table failure')
   check(bChild and not bChild.Alive and bChild.DestroyCalls==1 and cChild.Alive and h.Items[1].ChildPage==cChild,'Obsolete yielded B result closes once and cannot replace current C')
   h.Armed=false;h.Stale();cChild.Ready=true;cChild.Callback('complete');h.Neighbor.Ready=true;h.Neighbor.Callback('complete');check(h.API:PendingCount()==0 and h.Events==2,'Current C and neighbor complete without an obsolete B event')
   local dError={Original='later independent close'};settings.ThrowChild=cChild;settings.Payload=dError;settings.OnMount=nil;settings.OnWake=nil;h.Armed=true
   local later=table.pack(pcall(h.API.Reload,h.API,h.Items[1]));check(later[1]==false and later[2]==dError,'Later scope reports its own failure after both completed coroutine collectors were restored')
   check(h.Items[1].ChildPage~=cChild and h.Items[1].ChildPage.Alive,'Later independent scope still mounts a functional replacement');h.Armed=false;h.Finish()
  end)
 end
 print('IFRAME_SINGLE_CHILD_SUMMARY','cases='..completed..'/'..#expected,'assertions='..checks,'failures='..#failures)
 check(#expected==51 and completed==51 and #failures==0,'All 51 strict single-child controls pass')
 for _,name in expected do check(seen[name],'Missing single-child control '..name)end
end
