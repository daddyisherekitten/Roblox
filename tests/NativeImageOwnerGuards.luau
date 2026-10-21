--!strict
-- Pure actual NativeImageResources/DOM guard controls. No HTMLPage mount claim.
return function(Owner,Node)
 local checks,completed=0,0
 local function check(v,label)checks+=1;assert(v,label)end
 local expected={'Changed nil','Changed false','Changed table','Emit nil','Emit false','Emit table','Load owner stop','Load new generation','Scheduler nil','Scheduler false','Scheduler table','Stopped owner never legacy retry','Zero intrinsic resource succeeds',"Notify nil","Notify false","Notify table","Changed owner stop","Changed new generation","Emit owner stop","Emit new generation","Notify owner stop","Notify new generation","Viewport owner stop","Viewport new generation"}
 local seen={};local function mark(name)check(table.find(expected,name)and not seen[name],'Literal owner guard '..name);seen[name]=true;completed+=1;print('NATIVE_IMAGE_OWNER_GUARD',name)end
 local function setup(settings)
  settings=settings or{};local jobs,results={},{};local changed,emits,cancelled,notified=0,0,0,0
  local document=Node.document();document.URL='https://image.test/index.html';local body=Node.element('body',{});body.OwnerDocument=document;Node.append(document,body)
  local img=Node.element('img',settings.ImageAttrs or{src='one.png'});img.OwnerDocument=document;Node.append(body,img)
  if settings.Second then local other=Node.element('img',{src='two.png'});other.OwnerDocument=document;Node.append(body,other)end
  local cleanups={};local page={Alive=true,Document=document,DocumentURL=document.URL,Root={AbsoluteSize=Vector2.new(800,600)},ScriptInitializationPending=true}
  function page:AddCleanup(fn)table.insert(cleanups,fn)end
  function page:DocumentResourcesChanged()notified+=1;if settings.Notify then settings.Notify(self)end end
  local api
  local tasks={defer=function(fn)
   if settings.Scheduler then settings.Scheduler(api)end
   table.insert(jobs,fn)
  end}
  api=Owner.new(page,{Task=tasks,ScriptingEnabled=false,GetViewport=function()if settings.Viewport then settings.Viewport(api,img)end;return{Width=800,Density=1}end,Changed=function(node,ok,data)changed+=1;if settings.Changed then settings.Changed(api,node,ok,data)end end,
   Emit=function(node,event)emits+=1;if settings.Emit then settings.Emit(api,node,event)end end,
   LoadImage=function(url,finish,spec)
    local entry={URL=url,Callback=finish};table.insert(results,entry)
    if settings.Load then settings.Load(api,spec.Node,entry)end
    return function()cancelled+=1;entry.Callback=nil;if settings.Cancel then settings.Cancel()end end
   end})
  local function step()local fn=table.remove(jobs,1);check(fn~=nil,'Actual owner queued task');return pcall(fn)end
  local function drain()for _=1,100 do if #jobs==0 then return end;local ok,value=step();check(ok,tostring(value))end;error('Owner task queue did not converge')end
  return {Page=page,Node=img,Owner=api,Results=results,Jobs=jobs,Step=step,Drain=drain,Counts=function()return changed,emits,cancelled,notified end}
 end
 for _,hook in {'Changed','Emit'}do for _,kind in {'nil','false','table'}do
  local payload=if kind=='nil'then nil elseif kind=='false'then false else{Original=hook};local settings={Second=true,Cancel=function()error({Cleanup='must not mask'},0)end}
  settings[hook]=function()error(payload,0)end
  local h=setup(settings);h.Owner:Start();h.Drain();check(#h.Results==2 and h.Owner.Pending==2,'Two actual queued owner requests')
  assert(h.Results[1].Callback)(true,{Width=21,Height=13});local ok,value=h.Step()
  check(not ok and value==payload,'Exact first '..hook..' '..kind..' exception identity after cleanup')
  local changed,emits,cancelled=h.Counts();check(not h.Owner.Alive and h.Owner.Pending==0 and h.Node.ImageResourceState==nil and cancelled==1,'Other subscription cancelled and owner graph retired despite cleanup throw')
  check(changed==1 and emits==(if hook=='Changed'then 0 else 1),'No later terminal publication after first hook failure');h.Drain();mark(hook..' '..kind)
 end end
 do
  local h=setup({Load=function(api)api:Destroy()end});h.Owner:Start();h.Drain();local _,emits,cancelled=h.Counts()
  check(not h.Owner.Alive and h.Owner.Pending==0 and #h.Results==1 and cancelled==1 and emits==0 and h.Node.ImageResourceState==nil,'Late LoadImage result handle is disposed exactly once after reentrant owner stop');mark('Load owner stop')
 end
 do
  local once=false;local h=setup({Load=function(api,node)if not once then once=true;node.Attributes.src='second.png';api:AttributeChanged(node,'src',nil)end end});h.Owner:Start();h.Drain()
  local _,emits,cancelled=h.Counts();check(#h.Results==2 and h.Results[1].Callback==nil and cancelled==1 and h.Owner.Pending==1 and emits==0,'Reentrant new source cancels old returned handle without releasing current reservation')
  assert(h.Results[2].Callback)(true,{Width=31,Height=17});h.Drain();check(h.Node.ImageResourceState.Raw=='second.png'and h.Node.ImageResourceState.Width==31 and h.Owner.Pending==0,'Only latest source terminal publishes');h.Owner:Destroy();mark('Load new generation')
 end
 for _,kind in {'nil','false','table'}do
  local payload=if kind=='nil'then nil elseif kind=='false'then false else{Original='scheduler'}
  local h=setup({Scheduler=function(api)api:Destroy();error(payload,0)end});local ok,value=pcall(h.Owner.Start,h.Owner)
  check(not ok and value==payload and not h.Owner.Alive and h.Owner.Pending==0 and h.Node.ImageResourceState==nil and #h.Results==0,'Exact scheduler '..kind..' error with no resurrected requests');mark('Scheduler '..kind)
 end
 do
  local h=setup();h.Owner:Destroy();check(h.Owner:Manages(h.Node)and not h.Owner:Owns(h.Node),'Stopped page image ownership remains a legacy preload guard, not an active request');h.Owner:Refresh(h.Node,true);h.Owner:Visit(h.Page.Document);h.Owner:Start();h.Drain();check(#h.Results==0 and h.Owner.Pending==0,'Stopped owner cannot resurrect through retained APIs');mark('Stopped owner never legacy retry')
 end
 do
  local h=setup();h.Owner:Start();h.Drain();assert(h.Results[1].Callback)(true,{Width=0,Height=0,SVG={BoundedTest=true}});h.Drain()
  check(h.Node.ImageResourceState.Status=='loaded'and h.Node.ImageResourceState.Width==0 and h.Node.ImageResourceState.Height==0 and h.Owner.Pending==0,'Finite zero intrinsic geometry is not a failed resource')
  local _,emits=h.Counts();check(emits==1,'Zero intrinsic resource emits one successful terminal task');h.Owner:Destroy();mark('Zero intrinsic resource succeeds')
 end
 for _,kind in {'nil','false','table'}do
  local armed=false;local payload=if kind=='nil'then nil elseif kind=='false'then false else{Original='notify'}
  local h=setup({Second=true,Notify=function()if armed then error(payload,0)end end,Cancel=function()error({Cleanup='must not mask'},0)end});h.Owner:Start();h.Drain();armed=true
  assert(h.Results[1].Callback)(true,{Width=21,Height=13});local ok,value=h.Step()
  check(not ok and value==payload,'Direct Notify '..kind..' preserves first error identity despite later cancellation/notification failures')
  local changed,emits,cancelled=h.Counts();check(not h.Owner.Alive and h.Owner.Pending==0 and h.Owner.DiscoveryDepth==0 and h.Node.ImageResourceState==nil and cancelled==1,'Direct Notify failure retires all state/subscriptions before original payload')
  check(changed==1 and emits==1,'Notify error follows exactly one terminal publication/event and no later dispatch');h.Drain();mark('Notify '..kind)
 end
 for _,hook in {'Changed','Emit','Notify'}do for _,action in {'owner stop','new generation'}do
  local armed=false;local h
  local settings={Second=action=='owner stop'}
  local function reenter(api,node)
   if not armed then return end;armed=false
   local owner=api or h.Owner;local target=if hook=='Notify'then h.Node else node
   if action=='owner stop'then owner:Destroy()else target.Attributes.src='third.png';owner:AttributeChanged(target,'src',nil)end
  end
  if hook=='Notify'then settings.Notify=function()reenter(nil,nil)end else settings[hook]=reenter end
  h=setup(settings);h.Owner:Start();h.Drain();local state=h.Node.ImageResourceState;local generation=state.Generation;armed=true
  assert(h.Results[1].Callback)(true,{Width=21,Height=13});h.Drain()
  if action=='owner stop'then
   local changed,emits,cancelled=h.Counts();check(not h.Owner.Alive and h.Owner.Pending==0 and h.Node.ImageResourceState==nil and cancelled==1,'Reentrant '..hook..' stop retires the other subscription exactly once')
   check(changed==1 and emits==(if hook=='Changed'then 0 else 1),'No post-stop publication after '..hook)
  else
   check(h.Node.ImageResourceState==state and state.Generation==generation+1 and state.Raw=='third.png'and h.Owner.Pending==1 and #h.Results==2,'Reentrant '..hook..' replacement retains canonical state and one current request')
   assert(h.Results[2].Callback)(true,{Width=31,Height=17});h.Drain();local _,emits,cancelled=h.Counts()
   check(state.Status=='loaded'and state.Width==31 and h.Owner.Pending==0 and cancelled==0 and emits==(if hook=='Changed'then 1 else 2),'Only expected current terminal events follow '..hook..' replacement');h.Owner:Destroy()
  end
  mark(hook..' '..action)
 end end
 for _,action in {'owner stop','new generation'}do
  local armed=false;local h=setup({ImageAttrs={src='one.png',srcset='one.png 1x, two.png 2x'},Viewport=function(api,node)
   if not armed then return end;armed=false
   if action=='owner stop'then api:Destroy()else node.Attributes.src='third.png';node.Attributes.srcset=nil;api:AttributeChanged(node,'src',nil)end
  end});h.Owner:Start();h.Drain();assert(h.Results[1].Callback)(true,{Width=21,Height=13});h.Drain();local state=h.Node.ImageResourceState;local generation=state.Generation;armed=true
  h.Owner:ViewportChanged();h.Drain()
  if action=='owner stop'then
   check(not h.Owner.Alive and h.Owner.Pending==0 and h.Node.ImageResourceState==nil and #h.Results==1,'Viewport getter stop cannot copy or reserve the retired record')
  else
   check(h.Node.ImageResourceState==state and state.Generation==generation+1 and state.Raw=='third.png'and #h.Results==2 and h.Owner.Pending==1,'Viewport getter replacement wins over stale same-candidate comparison')
   assert(h.Results[2].Callback)(true,{Width=31,Height=17});h.Drain();check(state.Width==31 and h.Owner.Pending==0,'Only the replacement generation publishes after viewport reentry');h.Owner:Destroy()
  end
  mark('Viewport '..action)
 end
 check(completed==24 and #expected==24,'Exact owner guard inventory');for _,name in expected do check(seen[name],'Missing owner guard '..name)end
 print('NATIVE_IMAGE_OWNER_SUMMARY','cases='..completed,'assertions='..checks)
end
