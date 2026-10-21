--!strict
-- Real IFrameRuntime with controlled child objects and scheduler. No HTMLPage,
-- PageSession/native transport/VM collection or full iframe load parity claim.
return function(loadIFrameRuntime,Node)
 local expected={'Remove first nil','Remove first false','Remove first table','Destroy first nil','Destroy first false','Destroy first table','Remove re-add same item','Destroy preserves new owner','Remove stale queued callback','Destroy stale queued callback'}
 local checks,completed=0,0;local seen={}
 local function check(value,label)checks+=1;assert(value,label)end
 local function mark(name)check(table.find(expected,name)and not seen[name],'Exact Frame lifecycle case '..name);seen[name]=true;completed+=1;print('IFRAME_LIFECYCLE_CONTROL',name)end
 local function setup(settings)
  settings=settings or{};local h={Jobs={},Children={},Cleanups={},Items={},Mounts=0,Wakes=0,Events=0,Armed=false,FirstChosen=false}
  local document=Node.document();document.URL='https://frame.test/root/index.html'
  local page={Alive=true,Document=document,DocumentURL=document.URL,BaseURL=document.URL}
  function page:AddCleanup(fn)table.insert(h.Cleanups,fn)end
  function page:DocumentResourcesChanged()h.Wakes+=1;if h.Armed and settings.NotifyThrows then error({Secondary='notify'},0)end end
  page.Events={Emit=function()h.Events+=1 end}
  h.Page=page
  for i=1,2 do
   local node=Node.element('iframe',{srcdoc='<p>child'..i..'</p>',sandbox=settings.Sandbox and settings.Sandbox[i]});node.OwnerDocument=document;Node.append(document,node)
   table.insert(h.Items,{Node=node,ContentGui={SetAttribute=function()end},FallbackGui={}})
  end
  local tasks={defer=function(fn)table.insert(h.Jobs,fn)end}
  local runtime=loadIFrameRuntime(tasks)
  local function mount(_,_,options)
   h.Mounts+=1
   local child={Alive=true,Ready=false,DestroyCalls=0,DocumentURL=options.DocumentURL,BaseURL=options.FallbackBaseURL,Root={SetAttribute=function()end},Callback=options.DocumentLoadStateChanged,Options=options,Visibility={}}
   function child:SetVisible(show)table.insert(self.Visibility,show)end
   function child:IsDocumentComplete()return self.Ready end
   function child:ScrollToFragment()end
   function child:Destroy()
    if not self.Alive then return end
    -- Match PageSession's stop-before-cleanups ownership contract.
    self.Alive=false;self.DestroyCalls+=1
    if settings.OnDestroy then settings.OnDestroy(h,self)end
    if h.Armed and settings.ChildThrows then
     if not h.FirstChosen then h.FirstChosen=true;error(settings.Payload,0)end
     error({Secondary='later child'},0)
    end
   end
   table.insert(h.Children,child);return child
  end
  function h.Drain()
   for _=1,30 do if #h.Jobs==0 then return end;local fn=table.remove(h.Jobs,1);local ok,value=pcall(fn);check(ok,tostring(value))end
   error('Frame lifecycle queue did not converge')
  end
  function h.Start(items)return runtime.start(page,{IFrameItems=items or h.Items},error,mount,{Task=tasks,JavaScriptServices=settings.ParentServices})end
  h.API=h.Start();h.Drain();check(h.Mounts==2 and h.API:PendingCount()==2,'Two actual registered controlled child documents before lifecycle operation')
  return h
 end
 local function oldClosed(h,old)
  for _,child in old do check(not child.Alive and child.DestroyCalls==1,'Every captured old child closes exactly once before failure escapes')end
 end
 local function stale(h,old)
  local events,wakes,mounts=h.Events,h.Wakes,h.Mounts
  for _,child in old do child.Ready=true;local ok,value=pcall(child.Callback,'complete');check(ok,tostring(value))end
  h.Drain();check(h.Events==events and h.Wakes==wakes and h.Mounts==mounts,'Old committed notifications and queued callbacks remain inactive after retirement')
 end
 local function retired(h)
  check(h.API:PendingCount()==0,'All old registry load contributions retired')
  for _,item in h.Items do
   check(item.ChildPage==nil and item.Loading==false,'All old item child/loading slots cleared')
   local accepted=pcall(h.API.Reload,h.API,item);check(not accepted,'Old registration no longer accepted by Reload')
   local jobs=#h.Jobs;h.API:Mutation({Type='attributes',Target=item.Node,AttributeName='srcdoc'},h.Page.BaseURL);check(#h.Jobs==jobs,'Old by-node mapping no longer schedules same-value source processing')
  end
 end
 for _,operation in {'Remove','Destroy'}do for _,kind in {'nil','false','table'}do
  local payload=if kind=='nil'then nil elseif kind=='false'then false else{Original=operation}
  local h=setup({ChildThrows=true,NotifyThrows=true,Payload=payload});local old=table.clone(h.Children);h.Armed=true
  local result=table.pack(pcall(function()if operation=='Remove'then h.API:Remove(h.Items)else h.API:Destroy()end end))
  check(result[1]==false and result[2]==payload,'Exact first child '..kind..' error survives later child/notification errors')
  oldClosed(h,old);retired(h);stale(h,old)
  if operation=='Destroy'then check(h.Page.IFrameRuntime==nil,'Stopped owner removed from page before callbacks')else check(h.Page.IFrameRuntime==h.API,'Live Remove preserves its reusable owner')end
  h.Armed=false;local ok,value=pcall(h.API.Destroy,h.API);check(ok,tostring(value));oldClosed(h,old);check(h.Page.IFrameRuntime==nil,'Later Destroy is complete and does not close a child twice')
  mark(operation..' first '..kind)
 end end
 do
  local entered=false;local replacement
  local h=setup({OnDestroy=function(h)
   if entered then return end;entered=true
   for _,item in h.Items do check(item.ChildPage==nil and item.Loading==false,'Whole old Remove batch is retired before first callback')end
   check(h.API:PendingCount()==0 and not pcall(h.API.Reload,h.API,h.Items[2]),'All old registrations retired before reentrant Add')
   h.API:Add({h.Items[1]});h.Drain();replacement=h.Items[1].ChildPage
  end});local old=table.clone(h.Children);h.API:Remove(h.Items)
  oldClosed(h,old);check(entered and replacement and replacement.Alive and h.Items[1].ChildPage==replacement and h.API:PendingCount()==1,'Same-item new registration/child survives captured old child cleanup')
  check(h.Items[2].ChildPage==nil and h.Page.IFrameRuntime==h.API,'Unreplaced item remains retired and owner reusable');stale(h,old)
  h.API:Destroy();check(not replacement.Alive and replacement.DestroyCalls==1,'Replacement child closes once during final owner stop');mark('Remove re-add same item')
 end
 do
  local entered=false;local nextOwner,replacement
  local h=setup({OnDestroy=function(h)
   if entered then return end;entered=true
   check(h.Page.IFrameRuntime==nil,'Old owner taken before child Destroy hook')
   for _,item in h.Items do check(item.ChildPage==nil and item.Loading==false,'Old owner retired whole batch before replacement owner')end
   nextOwner=h.Start({h.Items[1]});h.Drain();replacement=h.Items[1].ChildPage
  end});local old=table.clone(h.Children);h.API:Destroy()
  oldClosed(h,old);check(entered and h.Page.IFrameRuntime==nextOwner and replacement and replacement.Alive and h.Items[1].ChildPage==replacement,'Conditional old-owner cleanup preserves newly published owner/child')
  check(h.API:PendingCount()==0 and nextOwner:PendingCount()==1,'Only new owner counts its active child');stale(h,old);h.API:Destroy();check(h.Page.IFrameRuntime==nextOwner,'Retained old receiver cannot clear replacement owner')
  replacement.Ready=true;replacement.Callback('complete');check(h.Events==1 and nextOwner:PendingCount()==0,'Only current new owner publishes child completion')
  nextOwner:Destroy();check(not replacement.Alive and replacement.DestroyCalls==1 and h.Page.IFrameRuntime==nil,'New owner final teardown owns exactly one child close');mark('Destroy preserves new owner')
 end
 for _,operation in {'Remove','Destroy'}do
  local h=setup();local old=table.clone(h.Children);h.Items[1].Node.Attributes.srcdoc='<p>new queued source</p>';h.API:Mutation({Type='attributes',Target=h.Items[1].Node,AttributeName='srcdoc'},h.Page.BaseURL)
  check(#h.Jobs==1 and h.Items[1].Loading==true,'Genuine old source request queued before lifecycle stop')
  if operation=='Remove'then h.API:Remove(h.Items)else h.API:Destroy()end
  oldClosed(h,old);retired(h);stale(h,old);check(h.Mounts==2 and #h.Jobs==0,'Queued obsolete source cannot mount after batch retirement');h.API:Destroy();mark(operation..' stale queued callback')
 end
 check(completed==10 and #expected==10,'Exact ten future lifecycle controls');for _,name in expected do check(seen[name],'Missing lifecycle case '..name)end
 do
  local inheritedCalls=0;local allowAncestor=true
  local services={Visible=false,WindowHost={},RuntimeCreated=function()inheritedCalls+=1 end,SimpleDialogHost={},ConfirmLeave=function()return true end,ModalsAllowed=function()return allowAncestor end}
  local h=setup({ParentServices=services,Sandbox={'allow-scripts','allow-scripts allow-modals'}})
  for _,child in h.Children do
   local inherited=child.Options.JavaScriptServices
   check(inherited~=services and type(inherited.RuntimeCreated)=='function'and inherited.RuntimeCreated~=services.RuntimeCreated and inherited.WindowHost==nil,'Nested realms own their pending mount callback without inheriting parent realm/window ownership hooks')
   check(inherited.SimpleDialogHost==services.SimpleDialogHost and inherited.Visible==false and child.Visibility[1]==false,'Nested UI providers survive and start with actual parent visibility')
  end
  check(not h.Children[1].Options.JavaScriptServices.ModalsAllowed()and h.Children[2].Options.JavaScriptServices.ModalsAllowed(),'Only sandbox allow-modals permits child dialogs')
  allowAncestor=false;check(not h.Children[2].Options.JavaScriptServices.ModalsAllowed(),'A nested allow-modals cannot override a blocked ancestor')
  check(services.RuntimeCreated~=nil and services.WindowHost~=nil and inheritedCalls==0,'Child service isolation must not mutate parent services')
  h.API:SetVisible(true);h.API:SetVisible(false)
  for _,child in h.Children do check(#child.Visibility==3 and child.Visibility[2]and not child.Visibility[3],'Actual parent visibility propagates to every retained child')end
  h.API:Reload(h.Items[1]);h.Drain();local replacement=h.Items[1].ChildPage
  check(replacement.Options.JavaScriptServices.Visible==false and replacement.Visibility[1]==false,'A replacement child inherits latest parent visibility')
  replacement.RequestLeave=function()return false end
  check(not h.API:RequestLeave({PromptState={Shown=false}})and replacement.Alive,'A descendant cancellation preserves its document')
  local sibling=h.Items[2].ChildPage
  sibling.RequestLeave=function()check(sibling.Alive,'A retired child guard cannot run');return true end
  replacement.RequestLeave=function()h.API:Remove({h.Items[2]});return true end
  check(h.API:RequestLeave({PromptState={Shown=false}})and not sibling.Alive,'Reentrant child removal invalidates only captured obsolete leases')
  replacement.CommitLeave=function()h.API:Remove({h.Items[1]})end
  h.API:CommitLeave();check(not replacement.Alive and h.API:PendingCount()==0,'A child unloading may retire itself without repeating disposal')
  h.API:Destroy();local calls=#replacement.Visibility;h.API:SetVisible(true);check(#replacement.Visibility==calls,'Disposed frame runtimes cannot change child visibility')
 end
 do
  local h=setup();local item=h.Items[1];local previous=item.ChildPage
  previous.RequestLeave=function()return coroutine.yield('held-child-leave')end
  local waiter=coroutine.create(function()h.API:Reload(item)end)
  local ok,state=coroutine.resume(waiter);check(ok and state=='held-child-leave','A child leave guard may await native confirmation')
  previous.RequestLeave=function()return true end
  item.Node.Attributes.srcdoc='<p>Newer request</p>';h.API:Mutation({Type='attributes',Target=item.Node,AttributeName='srcdoc'},h.Page.BaseURL);h.Drain()
  local replacement=item.ChildPage;check(replacement~=previous and replacement.Alive and not previous.Alive,'A newer source can replace a document while the old leave request waits')
  check(coroutine.resume(waiter,true)and item.ChildPage==replacement and replacement.Alive,'A stale accepted leave result cannot destroy the newer iframe realm')
  h.API:Destroy()
 end
 print('IFRAME_LIFECYCLE_SUMMARY','cases='..completed,'assertions='..checks)
end
