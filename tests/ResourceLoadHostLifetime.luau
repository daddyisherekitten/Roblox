--!strict
-- Held native operations and cached tasks must release owner graphs before
-- resume. Run through the compact standalone bundler to bound the GC heap.
return function(ResourceLoadHost)
local failures={}
local function pressure(predicate)
 for _=1,128 do
  if predicate()then return true end
  local temporary=table.create(2048)
  for index=1,2048 do temporary[index]={index,index+1}end
 end
 return predicate()
end
local function callbackFor(page,item,counts)
 return function()assert(page.Alive and not item.Destroyed);counts.Publications+=1 end
end
local function fixture(hold)
 local queue,threads={},{};local counts={NativeCreated=0,NativeReleased=0,EditableCreated=0,EditableReleased=0,Preloads=0,Publications=0}
 local function temporary()
  counts.NativeCreated+=1;local value={}
  function value:Destroy()assert(not self.Destroyed,'Native released twice');self.Destroyed=true;counts.NativeReleased+=1 end
  return value
 end
 local services={Task={defer=function(fn)table.insert(queue,fn)end},AssetFetchSuccess='Success',CreateImageLabel=temporary,CreateTextLabel=temporary,
  ResolveFont=function(family,weight,style)return{Family=family,Weight=weight,Style=style}end,
  ContentProvider={PreloadAsync=function(_,targets,report)
   counts.Preloads+=1;assert(#targets==1)
   if hold then table.insert(threads,coroutine.running());coroutine.yield('native-held')end
   report(targets[1].Image or'font','Success')
  end},
  AssetService={CreateEditableImageAsync=function()
   counts.EditableCreated+=1;local editable={Size={X=40,Y=20}}
   function editable:Destroy()assert(not self.Destroyed,'Editable released twice');self.Destroyed=true;counts.EditableReleased+=1 end
   return editable
  end}}
 local function start()
  assert(#queue>0);local fn=table.remove(queue,1);local thread=coroutine.create(fn);local ok,result=coroutine.resume(thread);assert(ok,tostring(result));return thread
 end
 local function resume()
  local thread=assert(table.remove(threads,1));local ok,result=coroutine.resume(thread);assert(ok,tostring(result));assert(coroutine.status(thread)=='dead');return thread
 end
 return services,queue,counts,start,resume,threads
end
local function markFailure(name,weak,keys)
 local all=true;local fields={}
 for _,key in keys do local collected=weak[key]==nil;table.insert(fields,key..'='..tostring(collected));if not collected then all=false end end
 print('RESOURCE_GC_BEFORE',name,table.concat(fields,','))
 if not all then table.insert(failures,name)end
end
for _,kind in {'raster','font'}do
 local services,queue,counts,start,resume,threads=fixture(true);local weak=setmetatable({},{__mode='v'})
 local function create()
  local page={Alive=true,Root={},Document={Children={}}};local item={Node={},Gui={},Destroyed=false};local tree={Item=item};page.Tree=tree
  local host=ResourceLoadHost.new(page,tree,services);weak.Page=page;weak.Host=host;weak.Item=item;weak.Root=page.Root;weak.Tree=tree;weak.Plain={Independent=true}
  if kind=='raster'then host:LoadRasterDimensions('rbxassetid://123',callbackFor(page,item,counts))else host:LoadFont({Family='Lato',Source='local("Lato")'},callbackFor(page,item,counts))end
  local thread=start();assert(coroutine.status(thread)=='suspended'and #threads==1)
  item.Destroyed=true;page.Alive=false;host:Destroy();host:Destroy();assert(counts.NativeCreated==1 and counts.NativeReleased==1)
 end
 create()
 pressure(function()return weak.Plain==nil and weak.Page==nil and weak.Host==nil and weak.Item==nil and weak.Root==nil and weak.Tree==nil end)
 assert(weak.Plain==nil,'Independent plain-object GC control must collect before resume')
 markFailure('destroy held '..kind,weak,{'Page','Host','Item','Root','Tree'})
 resume();assert(counts.NativeCreated==counts.NativeReleased and counts.NativeReleased==1,'Held native cleanup is exactly once');assert(counts.EditableCreated==0 and counts.Publications==0,'No allocation/publication after destroyed host resumes')
 assert(#queue==0 and #threads==0);pressure(function()return weak.Page==nil and weak.Host==nil and weak.Item==nil end)
 print('RESOURCE_GC_AFTER','destroy held '..kind,'page='..tostring(weak.Page==nil),'host='..tostring(weak.Host==nil),'item='..tostring(weak.Item==nil),'released='..counts.NativeReleased,'published='..counts.Publications)
end
do
 local services,queue,counts,start,resume=fixture(true);local weak=setmetatable({},{__mode='v'});local page={Alive=true};local host=ResourceLoadHost.new(page,{},services);local keptCancel;local second=0
 local function subscribe()
  local cancelled={Destroyed=true};weak.CancelledItem=cancelled;weak.Plain={Independent=true}
  keptCancel=host:LoadRasterDimensions('rbxassetid://123',function()assert(not cancelled.Destroyed);error('Cancelled shared callback fired')end)
  host:LoadRasterDimensions('rbxassetid://123',function(ok,data)assert(ok and data.Width==40);second+=1 end)
  start();keptCancel()
 end
 subscribe();pressure(function()return weak.Plain==nil and weak.CancelledItem==nil end);assert(weak.Plain==nil,'Shared subscription plain-object control')
 markFailure('cancel shared subscriber with retained cancel handle',weak,{'CancelledItem'})
 resume();assert(second==1 and counts.Preloads==1 and counts.NativeReleased==1 and counts.EditableReleased==1,'Cancel one subscriber preserves another and releases both native resources exactly once')
 keptCancel();host:Destroy();page.Alive=false;keptCancel=nil
 print('RESOURCE_GC_AFTER','cancel shared subscriber','otherPublished='..second,'preloads='..counts.Preloads,'released='..counts.NativeReleased)
end
do
 local services,queue,counts,start=fixture(false);local weak=setmetatable({},{__mode='v'})
 local function create()
  local page={Alive=true,Root={}};local item={Destroyed=false};local host=ResourceLoadHost.new(page,{},services);host:LoadRasterDimensions('rbxassetid://123',function(ok)assert(ok)end);start();assert(counts.NativeReleased==1 and counts.EditableReleased==1)
  weak.Page=page;weak.Host=host;weak.Item=item;weak.Root=page.Root;weak.Plain={Independent=true}
  local cancel=host:LoadRasterDimensions('rbxassetid://123',callbackFor(page,item,counts));cancel();item.Destroyed=true;page.Alive=false;host:Destroy()
 end
 create();pressure(function()return weak.Plain==nil and weak.Page==nil and weak.Host==nil and weak.Item==nil end);assert(weak.Plain==nil,'Cached subscription plain-object control')
 markFailure('destroy cancelled cached callback before queued task',weak,{'Page','Host','Item','Root'})
 start();assert(counts.Publications==0 and counts.NativeCreated==1 and counts.NativeReleased==1 and counts.EditableReleased==1)
 print('RESOURCE_GC_AFTER','destroy cancelled cached callback','released='..counts.NativeReleased,'published='..counts.Publications)
end
do
 local services,queue,counts,start=fixture(false);local weak=setmetatable({},{__mode='v'});local page={Alive=true};local host=ResourceLoadHost.new(page,{},services);local keptCancel
 host:LoadRasterDimensions('rbxassetid://123',function(ok)assert(ok)end);start()
 local function subscribe()
  local item={Destroyed=true};weak.CancelledItem=item;weak.Plain={Independent=true}
  keptCancel=host:LoadRasterDimensions('rbxassetid://123',function()assert(not item.Destroyed);error('Cancelled cached callback fired')end);keptCancel()
 end
 subscribe();pressure(function()return weak.Plain==nil and weak.CancelledItem==nil end);assert(weak.Plain==nil,'Live cached subscription plain-object control')
 markFailure('cancel live cached subscriber before queued delivery',weak,{'CancelledItem'});start();assert(counts.Publications==0 and counts.NativeCreated==1 and counts.NativeReleased==1)
 keptCancel();host:Destroy();page.Alive=false;keptCancel=nil
 print('RESOURCE_GC_AFTER','cancel live cached subscriber','released='..counts.NativeReleased,'published='..counts.Publications)
end
do
 local services,queue,counts,start=fixture(false);local page={Alive=true};local host=ResourceLoadHost.new(page,{},services);local first,late=0,0
 host:LoadRasterDimensions('rbxassetid://123',function(ok)assert(ok);first+=1;host:Destroy()end)
 host:LoadRasterDimensions('rbxassetid://123',function()late+=1 end);start()
 assert(first==1 and counts.Preloads==1 and counts.NativeReleased==1 and counts.EditableReleased==1,'Shared completion releases native resources before first callback')
 print('RESOURCE_REENTRANT_AFTER','destroy in first subscriber','first='..first,'late='..late,'released='..counts.NativeReleased)
 if late~=0 then table.insert(failures,'destroy in first subscriber still publishes second')end
end
do
 local services,queue,counts,start=fixture(false);local weak=setmetatable({},{__mode='v'});local held
 services.AssetService.CreateEditableImageAsync=function()
  held=coroutine.running();coroutine.yield('decode-held');counts.EditableCreated+=1
  local editable={Size={X=40,Y=20}};function editable:Destroy()assert(not self.Destroyed);self.Destroyed=true;counts.EditableReleased+=1 end;return editable
 end
 local function create()
  local page={Alive=true,Root={}};local item={Destroyed=false};local host=ResourceLoadHost.new(page,{},services)
  weak.Page=page;weak.Host=host;weak.Item=item;weak.Root=page.Root;weak.Plain={Independent=true}
  host:LoadRasterDimensions('rbxassetid://123',callbackFor(page,item,counts));start();assert(held and coroutine.status(held)=='suspended')
  item.Destroyed=true;page.Alive=false;host:Destroy();assert(counts.NativeReleased==1 and counts.EditableCreated==0)
 end
 create();pressure(function()return weak.Plain==nil and weak.Page==nil and weak.Host==nil and weak.Item==nil end);assert(weak.Plain==nil,'Held native decoder plain-object control')
 markFailure('destroy held native decoder',weak,{'Page','Host','Item','Root'})
 local ok,message=coroutine.resume(held);assert(ok,tostring(message));held=nil
 assert(counts.NativeReleased==1 and counts.EditableCreated==1 and counts.EditableReleased==1 and counts.Publications==0,'Uncancellable decoder result releases exactly once after disposed owner')
 print('RESOURCE_GC_AFTER','destroy held native decoder','released='..counts.NativeReleased,'editableReleased='..counts.EditableReleased,'published='..counts.Publications)
end
do
 local services,queue,counts,start=fixture(false);local page={Alive=true};local host;local calls=0
 services.CreateImageLabel=function()
  counts.NativeCreated+=1;local native={}
  function native:Destroy()
   calls+=1;if self.Destroyed then return end;self.Destroyed=true;counts.NativeReleased+=1
   page.Alive=false;host:Destroy()
  end
  return native
 end
 host=ResourceLoadHost.new(page,{},services);host:LoadRasterDimensions('rbxassetid://123',function()counts.Publications+=1 end);start()
 assert(counts.NativeCreated==1 and counts.NativeReleased==1 and counts.EditableReleased==1 and counts.Publications==0,'Reentrant native release must not publish after owner disposal')
 print('RESOURCE_NATIVE_REENTRANT_AFTER','temporary Destroy calls host.Destroy','destroyCalls='..calls,'released='..counts.NativeReleased,'published='..counts.Publications)
 if calls~=1 then table.insert(failures,'native target reentrant Destroy called twice')end
end
do
 local services,queue,counts,start=fixture(false);local page={Alive=true};local host
 services.CreateImageLabel=function()
  counts.NativeCreated+=1;local native={};function native:Destroy()assert(not self.Destroyed);self.Destroyed=true;counts.NativeReleased+=1 end
  page.Alive=false;host:Destroy();return native
 end
 host=ResourceLoadHost.new(page,{},services);host:LoadRasterDimensions('rbxassetid://123',function()counts.Publications+=1 end);start()
 assert(counts.NativeReleased==1 and counts.EditableCreated==0 and counts.Publications==0,'Target created by reentrant factory is still released exactly once')
 print('RESOURCE_FACTORY_REENTRANT_AFTER','factory calls host.Destroy','preloads='..counts.Preloads,'released='..counts.NativeReleased,'published='..counts.Publications)
 if counts.Preloads~=0 then table.insert(failures,'factory-disposed host starts later native IO')end
end
print('RESOURCE_GC_BASELINE_FAILURES',#failures,table.concat(failures,' | '))
assert(#failures==0,'Destroyed/cancelled ResourceLoadHost wrappers must collect before held native coroutine/cache task resumes')

do
 local services,queue,counts,start=fixture(false);local page={Alive=true};local host=ResourceLoadHost.new(page,{},services);local cancelSecond;local first,second,third=0,0,0
 local weak=setmetatable({},{__mode='v'})
 host:LoadRasterDimensions('rbxassetid://123',function()first+=1;cancelSecond()end)
 local function subscribe()
  local item={};weak.CancelledItem=item;weak.Plain={}
  cancelSecond=host:LoadRasterDimensions('rbxassetid://123',function()assert(item);second+=1 end)
 end
 subscribe();host:LoadRasterDimensions('rbxassetid://123',function()third+=1 end);start()
 assert(first==1 and second==0 and third==1 and counts.Preloads==1,'Cancel during first publication preserves a separate live third subscriber')
 pressure(function()return weak.Plain==nil and weak.CancelledItem==nil end);assert(weak.Plain==nil and weak.CancelledItem==nil,'Cancelled shared callback releases its capture even with retained cancel handle')
 cancelSecond();host:Destroy();print('RESOURCE_ADJACENT','shared reentrant cancellation','first='..first,'third='..third)
end
do
 local services,queue,counts,start=fixture(false);local page={Alive=true};local host=ResourceLoadHost.new(page,{},services);local delivered=0
 host:LoadRasterDimensions('rbxassetid://123',function(ok)assert(ok)end);start()
 local cancel=host:LoadRasterDimensions('rbxassetid://123',function()error('Cancelled cache callback')end)
 host:LoadRasterDimensions('rbxassetid://123',function(ok)assert(ok);delivered+=1 end);cancel();cancel();start();start()
 assert(delivered==1 and counts.Preloads==1 and counts.NativeReleased==1,'Cancelling one cache subscriber keeps another deferred cache publication and never duplicates IO')
 host:Destroy();print('RESOURCE_ADJACENT','cached cancellation with live other','delivered='..delivered)
end
do
 local services,queue,counts,start=fixture(false);local page={Alive=true};local host=ResourceLoadHost.new(page,{},services);local later=0;local weak=setmetatable({},{__mode='v'})
 host:LoadRasterDimensions('rbxassetid://123',function()error('callback marker',0)end)
 local function subscribe()
  local item={};weak.Item=item;weak.Plain={}
  host:LoadRasterDimensions('rbxassetid://123',function()assert(item);later+=1 end)
 end
 subscribe();local ok,message=pcall(start);assert(not ok and tostring(message):find('callback marker',1,true),'Callback error still propagates with its original marker')
 assert(later==0 and counts.NativeReleased==1 and counts.EditableReleased==1,'Throwing completion keeps fail-fast subscriber behavior after native cleanup')
 pressure(function()return weak.Plain==nil and weak.Item==nil end);assert(weak.Plain==nil and weak.Item==nil,'Failed completion drops remaining captured callbacks while host stays alive')
 host:Destroy();print('RESOURCE_ADJACENT','callback throw cleanup and propagation','later='..later)
end
do
 local services,queue,counts,start,resume=fixture(true);local calls={};local weak=setmetatable({},{__mode='v'})
 services.CreateImageLabel=function()
  counts.NativeCreated+=1;local id=counts.NativeCreated;local target={}
  function target:Destroy()calls[id]=(calls[id]or 0)+1;assert(not self.Destroyed);self.Destroyed=true;counts.NativeReleased+=1;if id==1 then error('target marker',0)end end
  return target
 end
 local function create()
  local page={Alive=true};local item={Destroyed=false};local host=ResourceLoadHost.new(page,{},services);weak.Page=page;weak.Host=host;weak.Item=item;weak.Plain={}
  host:LoadRasterDimensions('rbxassetid://123',callbackFor(page,item,counts));host:LoadRasterDimensions('rbxassetid://124',callbackFor(page,item,counts));start();start()
  item.Destroyed=true;page.Alive=false;local ok,message=pcall(function()host:Destroy()end);assert(not ok and tostring(message):find('target marker',1,true),'First native Destroy exception still propagates')
  assert(counts.NativeReleased==2 and calls[1]==1 and calls[2]==1,'Dispose tries every native target before rethrowing the first error');host:Destroy()
 end
 create();pressure(function()return weak.Plain==nil and weak.Page==nil and weak.Host==nil and weak.Item==nil end)
 assert(weak.Plain==nil and weak.Page==nil and weak.Host==nil and weak.Item==nil,'Native destructor exception cannot retain disposed owners before resume')
 resume();resume();assert(counts.NativeReleased==2 and calls[1]==1 and calls[2]==1 and counts.Publications==0 and counts.EditableCreated==0,'Resumed native jobs cannot retry failed cleanup or publish')
 print('RESOURCE_ADJACENT','native throw cleanup and propagation','released='..counts.NativeReleased)
end
do
 local services,queue,counts=fixture(false);local resolutions=0;local page={Alive=true,ResolveImage=function()resolutions+=1;return'rbxassetid://123'end};local host=ResourceLoadHost.new(page,{},services)
 host:Destroy();host:Destroy()
 local cancelA=host:LoadRasterDimensions('rbxassetid://123',function()error('Dead raster callback')end)
 local cancelB=host:LoadImage('photo.png',function()error('Dead image callback')end)
 local cancelC=host:LoadFont({Family='Lato',Source='local("Lato")'},function()error('Dead font callback')end)
 cancelA();cancelA();cancelB();cancelC()
 assert(#queue==0 and resolutions==0 and counts.NativeCreated==0 and counts.Preloads==0,'Dead host registers no callbacks, resolver calls, deferred tasks or native work')
 print('RESOURCE_ADJACENT','early dead registration guard','queue='..#queue)
end
do
 local services,queue,counts,start=fixture(false);local page={Alive=true};local host;local writes=0
 services.CreateTextLabel=function()
  counts.NativeCreated+=1;local target=setmetatable({},{__newindex=function(self,key,value)if key=='FontFace'then writes+=1 end;rawset(self,key,value)end})
  function target:Destroy()assert(not self.Destroyed);self.Destroyed=true;counts.NativeReleased+=1 end
  page.Alive=false;host:Destroy();return target
 end
 host=ResourceLoadHost.new(page,{},services);host:LoadFont({Family='Lato',Source='local("Lato")'},function()error('Disposed font callback')end);start()
 assert(writes==0 and counts.NativeReleased==1 and counts.Preloads==0,'Factory-disposed font target is released before any FontFace assignment or IO')
 print('RESOURCE_ADJACENT','font factory disposal guard','writes='..writes,'released='..counts.NativeReleased)
end
do
 local services,queue,counts,start,resume=fixture(true);local page={Alive=true};local host
 services.CreateImageLabel=function()
  counts.NativeCreated+=1;local target={}
  function target:Destroy()assert(not self.Destroyed);self.Destroyed=true;counts.NativeReleased+=1;error(nil,0)end
  return target
 end
 host=ResourceLoadHost.new(page,{},services);host:LoadRasterDimensions('rbxassetid://123',function()error('Nil-error disposed callback')end);start()
 page.Alive=false;local ok,message=pcall(function()host:Destroy()end)
 assert(not ok and message==nil and counts.NativeReleased==1,'A nil native error is still rethrown after owned cleanup')
 resume();assert(counts.NativeReleased==1 and counts.Publications==0)
 print('RESOURCE_ADJACENT','native nil error preservation','released='..counts.NativeReleased)
end
print('Resource load lifetime: nine preserved red/green cases plus seven shared/cache/exception/dead/factory controls passed')

-- Do not coerce an externally thrown value while releasing its ownership.
-- Invoke the queued callback directly here: the fixture's coroutine driver
-- deliberately stringifies its own diagnostics, which would hide this check.
for index=1,3 do
 local payload=if index==1 then nil elseif index==2 then false else {Marker='original error identity'}
 do
  local services,queue,counts,start,resume=fixture(true);local page={Alive=true};local host
  services.CreateImageLabel=function()
   counts.NativeCreated+=1;local target={}
   function target:Destroy()assert(not self.Destroyed);self.Destroyed=true;counts.NativeReleased+=1;error(payload,0)end
   return target
  end
  host=ResourceLoadHost.new(page,{},services);host:LoadRasterDimensions('rbxassetid://123',function()error('Disposed payload callback')end);start()
  page.Alive=false;local ok,message=pcall(function()host:Destroy()end)
  assert(not ok and message==payload and counts.NativeReleased==1,'Native cleanup preserves nil/false/table error payload identity')
  resume();assert(counts.NativeReleased==1 and counts.Publications==0,'Payload throw cannot cause repeated native cleanup or late publication')
 end
 do
  local services,queue,counts=fixture(false);local page={Alive=true};local host=ResourceLoadHost.new(page,{},services);local later=0
  host:LoadRasterDimensions('rbxassetid://123',function()error(payload,0)end)
  host:LoadRasterDimensions('rbxassetid://123',function()later+=1 end)
  local ok,message=pcall(assert(table.remove(queue,1)))
  assert(not ok and message==payload and later==0,'Fail-fast subscriber cleanup preserves nil/false/table error payload identity')
  assert(counts.NativeReleased==1 and counts.EditableReleased==1,'Callback payload throw occurs after exact-once native cleanup');host:Destroy()
 end
end
print('Resource load lifetime: six additional native/callback nil/false/table payload controls passed')

end
