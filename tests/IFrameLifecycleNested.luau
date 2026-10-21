--!strict
-- Real IFrameRuntime with controlled child objects and scheduler. No HTMLPage,
-- PageSession/native transport/VM collection or full iframe load parity claim.
return function(loadIFrameRuntime,Node)
 local expected={'Remove nested Destroy nil','Remove nested Destroy false','Remove nested Destroy table','Destroy nested Remove nil','Destroy nested Remove false','Destroy nested Remove table'}
 local checks,completed=0,0;local seen={}
 local function check(value,label)checks+=1;assert(value,label)end
 local function mark(name)check(table.find(expected,name)and not seen[name],'Exact Frame lifecycle case '..name);seen[name]=true;completed+=1;print('IFRAME_LIFECYCLE_CONTROL',name)end
 local function setup(settings)
  settings=settings or{};local h={Jobs={},Children={},Cleanups={},Items={},Mounts=0,Wakes=0,Events=0,Armed=false,FirstChosen=false}
  local document=Node.document();document.URL='https://frame.test/root/index.html'
  local page={Alive=true,Document=document,DocumentURL=document.URL,BaseURL=document.URL}
  function page:AddCleanup(fn)table.insert(h.Cleanups,fn)end
  function page:DocumentResourcesChanged()h.Wakes+=1;if h.Armed and settings.NotifyThrows then error(settings.NotifyPayload,0)end end
  page.Events={Emit=function()h.Events+=1 end}
  h.Page=page
  for i=1,2 do
   local node=Node.element('iframe',{srcdoc='<p>child'..i..'</p>'});node.OwnerDocument=document;Node.append(document,node)
   table.insert(h.Items,{Node=node,ContentGui={SetAttribute=function()end},FallbackGui={}})
  end
  local tasks={defer=function(fn)table.insert(h.Jobs,fn)end}
  local runtime=loadIFrameRuntime(tasks)
  local function mount(_,_,options)
   h.Mounts+=1
   local child={Alive=true,Ready=false,DestroyCalls=0,DocumentURL=options.DocumentURL,BaseURL=options.FallbackBaseURL,Root={SetAttribute=function()end},Callback=options.DocumentLoadStateChanged}
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
  function h.Start(items)return runtime.start(page,{IFrameItems=items or h.Items},error,mount,{Task=tasks})end
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
  local payload=if kind=='nil'then nil elseif kind=='false'then false else{Original='nested '..operation}
  local entered=false;local settings
  if operation=='Remove'then
   settings={ChildThrows=true,Payload=payload,OnDestroy=function(h)
    if entered then return end;entered=true
    check(h.Items[1].ChildPage==nil and h.Items[2].ChildPage~=nil,'Outer single Remove retires first lease before nested Destroy owns remaining child')
    h.API:Destroy();check(h.Page.IFrameRuntime==nil and h.API:PendingCount()==0,'Same-owner nested Destroy retires all remaining leases before returning')
   end}
  else
   settings={ChildThrows=true,Payload={Secondary='outer child'},NotifyThrows=true,NotifyPayload=payload,OnDestroy=function(h)
    if entered then return end;entered=true
    check(h.Page.IFrameRuntime==nil and h.API:PendingCount()==0,'Outer Destroy takes whole old batch and page slot before nested Remove')
    h.API:Remove(h.Items)
   end}
  end
  local h=setup(settings);local old=table.clone(h.Children);h.Armed=true
  local result=table.pack(pcall(function()if operation=='Remove'then h.API:Remove({h.Items[1]})else h.API:Destroy()end end))
  check(entered and result[1]==false and result[2]==payload,'Exact first nested '..kind..' payload survives different later outer errors')
  oldClosed(h,old);retired(h);stale(h,old);check(h.Page.IFrameRuntime==nil,'Same old owner remains fully stopped after nested closure')
  h.Armed=false;h.API:Destroy();oldClosed(h,old)
  mark(operation..' nested '..(if operation=='Remove'then 'Destroy'else 'Remove')..' '..kind)
 end end
 check(completed==6 and #expected==6,'Exact six same-owner nested lifecycle controls');for _,name in expected do check(seen[name],'Missing nested case '..name)end
 print('IFRAME_LIFECYCLE_NESTED_SUMMARY','cases='..completed,'assertions='..checks)
end
