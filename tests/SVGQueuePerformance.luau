--!strict
return function(Queue)
 local jobs,shown,errors={},{},{};local now=0;local live,works=0,0
 local taskAPI={defer=function(fn) table.insert(jobs,coroutine.create(fn)) end,wait=function() now+=.016;coroutine.yield() end}
 local function step()
  local co=table.remove(jobs,1);if not co then return end
  local ok,err=coroutine.resume(co);assert(ok,err)
  if coroutine.status(co)~='dead' then table.insert(jobs,co) end
 end
 local function drain() local n=0;while #jobs>0 do n+=1;assert(n<1000);step() end end
 local api={CreateEditableImage=function(_,options)
  live+=1;local image={Size=options.Size}
  function image:WritePixelsBuffer(_,_,bytes) self.Pixels=bytes end
  function image:Destroy() assert(not self.Dead);self.Dead=true;live-=1 end
  return image
 end}
 local raster={
  createWork=function() works+=1;return {} end,
  releaseWork=function(work) assert(not work.Dead);work.Dead=true;works-=1 end,
  render=function(scene,_,width,check,work)
   assert(work)
   for _=1,8 do now+=.005;if not check() then return nil end end
   local bytes=buffer.create(width*scene.Height*4);buffer.writeu8(bytes,0,scene.Value);return bytes
  end,
 }
 local q=Queue.new(api,raster,taskAPI,{Clock=function()return now end,Report=function(err)table.insert(errors,err)end})
 local owner={};local builds=0
 local function request(who,key,value,fail)
  return q:Request(who,key,function()
   builds+=1;now+=.002;if fail then error('expected failure') end
   return {Width=8,Height=8,Value=value}
  end,function(image) table.insert(shown,{Owner=who,Value=buffer.readu8(image.Pixels,0)}) end,true)
 end
 request(owner,'base',1);drain();assert(#shown==1 and works==1)
 request(owner,'cold',2);step()
 request(owner,'base',1);step();step()
 assert(#shown==2 and shown[2].Value==1 and q.Running,'Cached visual bypasses unfinished cold raster')
 drain();assert(#shown==2 and q.Stats.Cancelled==0 and q:Pending()==0,'Stale completion never overwrites or repeats latest upload')
 local count=builds
 request(owner,'cold',2);drain();assert(builds==count and shown[#shown].Value==2,'Completed superseded state remains reusable')
 local second={}
 request(owner,'busy1',3);request(second,'other',4);step();request(owner,'busy2',5);drain()
 assert(shown[#shown-1].Owner==second and shown[#shown].Value==5,'Repeated updates do not starve another SVG')
 request(owner,'retry',6,true);drain();assert(#errors==1)
 assert(request(owner,'retry',6));drain();assert(shown[#shown].Value==6,'Same key retries after failure')
 assert(q.Stats.RasterActiveMS>0 and q.Stats.RasterWaitMS>0 and q.Stats.Yields>0)
 local bytes=q.CacheBytes;q:Remove(second)
 assert(q.CacheBytes<bytes and works==1,'Removed owner releases cached frames and retained raster work')

 local shownBeforeWarm=#shown;local buildsBeforeWarm=builds
 assert(q:Warm(owner,'warm-a',function()builds+=1;return {Width=8,Height=8,Value=8}end))
 drain()
 assert(#shown==shownBeforeWarm and q.Stats.WarmQueued==1 and q.Stats.WarmCompleted==1,'Background warm caches pixels without displaying them')
 assert(q:WarmCapacity(owner,8*8*4)>0,'Warm capacity reflects remaining cache budget')
 request(owner,'warm-a',8);drain()
 assert(builds==buildsBeforeWarm+1 and shown[#shown].Value==8,'First visible use of a warmed state skips build and raster')

 local third={};local preempted=q.Stats.WarmPreempted;local warmBuilds=0
 assert(q:Warm(owner,'warm-slow',function()warmBuilds+=1;return {Width=8,Height=8,Value=9}end));step()
 request(third,'visible-first',10);drain()
 assert(q.Stats.WarmPreempted>preempted and warmBuilds==1,'Visible rendering preempts warm raster work without rebuilding its scene')
 assert(shown[#shown].Owner==third and shown[#shown].Value==10 and q.Stats.WarmCompleted==2,'Warm completion never replaces the visible frame')
 assert(q:Warm(owner,'cancelled',function()return {Width=8,Height=8,Value=11}end))
 assert(q:CancelWarm(owner)==1 and q:WarmPending()==0,'Warm jobs can be cancelled during resize or teardown')
 q:Remove(third)
 request(owner,'dispose',7);step();q:Destroy();drain()
 assert(live==0 and works==0 and q.CacheBytes==0,'In-flight teardown releases all owner resources')
 local reservations=Queue.new(api,raster,taskAPI,{Clock=function()return now end,CacheBytes=512,CacheEntries=3,Report=error})
 assert(reservations:Warm({},'reserved-a',function()return {Width=8,Height=8,Value=1}end,256))
 assert(reservations:WarmCapacity({},256)==1,'Pending warm pixels and entries reserve shared cache capacity')
 assert(reservations:Warm({},'reserved-b',function()return {Width=8,Height=8,Value=2}end,256))
 assert(reservations:WarmCapacity({},256)==0,'Warm scheduling cannot overcommit the shared pixel budget')
 reservations:Destroy();drain();assert(live==0 and works==0)
 local bounded=Queue.new(api,raster,taskAPI,{Clock=function()return now end,CacheFields=20,Report=error})
 local firstOwner,secondOwner={},{};local lastValue
 local huge={};for i=1,30 do huge[i]=i end
 local function boundedRequest(who,key,value,large,lateSnapshot)
  bounded:Request(who,key,function()
   local shared=if large then huge else {a=1,b=2}
   local scene={Width=8,Height=8,Value=value,Data=shared,Alias=shared};scene.Self=scene
   return scene
  end,function(image,scene)
   lastValue=buffer.readu8(image.Pixels,0)
   if lateSnapshot then scene.EmbeddedSnapshot={Details=huge} end
  end,true)
 end
 boundedRequest(firstOwner,'one',1);drain()
 assert(bounded.CacheFields==8,'Metadata counts shared fields once and terminates on source cycles')
 boundedRequest(secondOwner,'two',2);drain()
 boundedRequest(firstOwner,'three',3);drain()
 assert(bounded.CacheFields==16 and #bounded.Cache==2 and bounded.Cache[1].Key=='two','Aggregate metadata limit evicts the oldest frame independently of pixel bytes')
 boundedRequest(firstOwner,'huge',4,true);drain()
 assert(lastValue==4 and bounded.Stats.CacheSkipped==1 and bounded.CacheFields==16,'Oversized metadata still renders and preserves useful cached frames')
 bounded:Remove(secondOwner)
 assert(bounded.CacheFields==8 and bounded.Stats.CacheFields==8,'Owner removal reclaims structural accounting')
 boundedRequest(firstOwner,'late',5,false,true);step()
 boundedRequest(firstOwner,'three',3);drain()
 assert(bounded.CacheFields==16,'Superseded state can be admitted before it has a hit snapshot')
 boundedRequest(firstOwner,'late',5,false,true);drain()
 assert(lastValue==5 and bounded.CacheFields==8 and bounded.Stats.CacheSkipped==2,'First cached install rechecks metadata added by hit preparation')
 bounded:Destroy();drain()
 assert(bounded.CacheFields==0 and bounded.Stats.CacheFields==0 and live==0 and works==0,'Teardown clears scene metadata accounting')
 local disposing=Queue.new(api,raster,taskAPI,{Clock=function()return now end,Report=error})
 disposing:Request({},'dispose-on-install',function()return {Width=8,Height=8,Value=7}end,function()disposing:Destroy()end,true)
 drain();assert(#disposing.Cache==0 and disposing.CacheFields==0 and live==0 and works==0,'An install callback may dispose its owner without readmitting its finished frame')
 print('SVG queue performance: cached preemption, stale completion, fairness, failure retry, timing and cache teardown passed')
end
