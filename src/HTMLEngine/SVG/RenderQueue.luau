--!strict
-- One serial worker; latest request per owner, bounded CPU frames and live textures.
local Queue={}
local WorkContext=require(script.Parent.Parent.WorkContext)
local TextureUpload=require(script.Parent.Parent.Rendering.TextureUpload)
function Queue.new(api: any,raster: any,taskAPI: any,options: any?): any
 options=options or {};local self={Alive=true,Slots={},Cache={},CacheBytes=0,CacheFields=0,Running=false,Sequence=0,Stats={Builds=0,HitBuilds=0,BuildMS=0,BuildActiveMS=0,BuildWaitMS=0,LastBuildMS=0,LastWidth=0,LastHeight=0,Rasters=0,CacheHits=0,Uploads=0,Created=0,Destroyed=0,Live=0,LiveBytes=0,PeakBytes=0,RasterMS=0,LastRasterMS=0,RasterActiveMS=0,RasterWaitMS=0,Yields=0,UploadMS=0,LayerHits=0,LayerBuilds=0,PartialRenders=0,RepaintPixels=0,RetainedBytes=0,Cancelled=0,CacheBytes=0,CacheFields=0,CacheSkipped=0,WarmQueued=0,WarmCompleted=0,WarmPreempted=0,WarmCancelled=0}}
 local loadingPage={LoadingWork=options.LoadingWork}
 local warmWork
 local clock=options.Clock or os.clock;local maxBytes=options.MaxBytes or 16*1024*1024;local cacheLimit=options.CacheBytes or 24*1024*1024;local cacheEntries=options.CacheEntries or 48
 local yieldSeconds=if options.YieldSeconds==nil then .004 else math.max(0,options.YieldSeconds)
 local fieldLimit=options.CacheFields or 1000000
 local entryFieldLimit=math.min(fieldLimit,options.CacheEntryFields or 262144)
 local function find(key)
  for i,v in self.Cache do if v.Key==key then table.remove(self.Cache,i);table.insert(self.Cache,v);self.Stats.CacheHits+=1;return v end end
 end
 local function peek(key)
  for _,value in self.Cache do if value.Key==key then return value end end
 end
 -- Count reachable scene table fields, including DOM/style/source cycles. This
 -- limits retained metadata structure, not exact Lua heap bytes: strings,
 -- immutable resource buffers, functions and metatables are opaque values.
 local function fields(scene)
  local count=0;local pending={};local seen={}
  local function add(value)
   if type(value)=='table' and not seen[value] then seen[value]=true;table.insert(pending,value) end
  end
  add(scene)
  while #pending>0 do
   WorkContext.checkpoint()
   local node=table.remove(pending)
   for key,value in node do
    count+=1;if count>entryFieldLimit then return nil end
    if count%64==0 then WorkContext.checkpoint()end
    add(key);add(value)
   end
  end
  return count
 end
 local function cacheStats()
  self.Stats.CacheBytes=self.CacheBytes;self.Stats.CacheFields=self.CacheFields
 end
 local function evict(index)
  local value=table.remove(self.Cache,index)
  self.CacheBytes-=buffer.len(value.Bytes);self.CacheFields-=value.Fields;value.Cached=false
 end
 local function remember(value)
  local size=buffer.len(value.Bytes)
  local count=fields(value.Scene)
  if not self.Alive or value.Owner.Dead then return end
  if value.Cached then evict(table.find(self.Cache,value)) end
  if not count or size>cacheLimit or cacheEntries<=0 then self.Stats.CacheSkipped+=1;cacheStats();return end
  while #self.Cache>0 and (self.CacheBytes+size>cacheLimit or self.CacheFields+count>fieldLimit or #self.Cache>=cacheEntries) do evict(1) end
  value.Fields=count;value.CountedSnapshot=value.Scene and value.Scene.EmbeddedSnapshot;value.Cached=true
  table.insert(self.Cache,value);self.CacheBytes+=size;self.CacheFields+=count
  cacheStats()
 end
 local function release(slot)
  if slot.Image then slot.Image:Destroy();slot.Image=nil;self.Stats.Live-=1;self.Stats.Destroyed+=1;self.Stats.LiveBytes-=slot.Bytes;slot.Bytes=0 end
 end
 local function installFrame(slot,request,frame,scene)
  local function current()return self.Alive and not slot.Dead and slot.Request==request and request.Generation==slot.Generation end
  if not current()then return end
  local width,height=frame.Width,frame.Height
  self.Stats.LastWidth,self.Stats.LastHeight=width,height
  local size=buffer.len(frame.Bytes)
  if slot.Image and (slot.Image.Size.X~=width or slot.Image.Size.Y~=height) then release(slot) end
  if not current()then return end
  assert(self.Stats.LiveBytes-(slot.Bytes or 0)+size<=maxBytes,'SVG texture memory budget exceeded')
  if not slot.Image then
   -- Native creation may yield or retire/replace this owner before returning.
   local allocated=api:CreateEditableImage({Size=Vector2.new(width,height)});assert(allocated,'EditableImage allocation unavailable')
   self.Stats.Created+=1
   if not current()then allocated:Destroy();self.Stats.Destroyed+=1;return end
   slot.Image=allocated;slot.Bytes=size;self.Stats.Live+=1;self.Stats.LiveBytes+=size;self.Stats.PeakBytes=math.max(self.Stats.PeakBytes,self.Stats.LiveBytes)
  end
  local uploaded=TextureUpload.write(slot.Image,Vector2.new(width,height),frame.Bytes,current,function(milliseconds)self.Stats.UploadMS+=milliseconds end,clock,options.LoadingWork and options.LoadingWork.Active==true or false)
  if not uploaded then return end
  self.Stats.Uploads+=1
  request.Install(slot.Image,scene)
  -- An obsolete frame may first acquire its hit snapshot on a later cache hit.
  if frame.Cached and frame.Scene and frame.CountedSnapshot~=frame.Scene.EmbeddedSnapshot then remember(frame) end
 end
 local function failed(slot,err)
  slot.Failed=true
  if self.Alive and not slot.Dead then release(slot);if options.Report then options.Report(tostring(err)) end end
 end
 local function retainedBytes()
  local bytes=0;for _,slot in self.Slots do if slot.Work then bytes+=slot.Work.RetainedBytes or 0 end end
  self.Stats.RetainedBytes=bytes
 end
 local function slotFor(owner)
  local slot=self.Slots[owner]
  if not slot then slot={Generation=0,Warm={},WarmKeys={}};self.Slots[owner]=slot end
  return slot
 end
 local function removeWarm(slot,request)
  if slot.WarmKeys[request.Key]~=request then return false end
  slot.WarmKeys[request.Key]=nil
  local index=table.find(slot.Warm,request);if index then table.remove(slot.Warm,index) end
  return true
 end
 local function visiblePending(exceptSlot: any?,exceptKey: string?): boolean
  for _,candidate in self.Slots do
   if candidate.Request and candidate.Applied~=candidate.Request then
    if candidate~=exceptSlot or candidate.Request.Key~=exceptKey then return true end
   end
  end
  return false
 end
 local lastVisibleReady=true
 local function visibleChanged()
  if not self.Alive then return end
  local ready=not visiblePending()
  if ready==lastVisibleReady then return end
  lastVisibleReady=ready
  if options.VisibleChanged then options.VisibleChanged(ready) end
 end
 local function run()
  if self.Running then return end;self.Running=true
  taskAPI.defer(function()
   while self.Alive do
    local slot;local request;local warming=false
    -- A continuously updated SVG must not starve other owners waiting to paint.
    for _,v in self.Slots do
     if v.Request and v.Applied~=v.Request and (not slot or v.Request.Sequence<slot.Request.Sequence) then slot=v end
    end
    if slot then request=slot.Request
    else
     for _,v in self.Slots do
      local candidate=v.Warm[1]
      if candidate and (not request or candidate.Sequence<request.Sequence) then slot=v;request=candidate;warming=true end
     end
    end
    if not slot or not request then break end
    local warmFinished=false;local warmPreempted=false
    if warming and options.LoadingWork and not options.LoadingWork.Active and yieldSeconds>0 and not warmWork then
     warmWork=WorkContext.new(math.min(2,yieldSeconds*1000),{Task=taskAPI,Clock=clock,Alive=function()return self.Alive end})
    end
    local jobPage=if warming and not(options.LoadingWork and options.LoadingWork.Active)then {LoadingWork=warmWork}else loadingPage
    local ok,err=pcall(function()return WorkContext.runFor(jobPage,function()
     -- Immutable embedded states can reuse both pixels and their scene before any build.
     local frame=if request.Immutable then find(request.Key) else nil
     local scene=frame and frame.Scene or request.Scene
     if not scene then
      local start=clock();local buildBudget=WorkContext.budget();local beforeWait=if buildBudget then buildBudget.WaitMS else 0
      self.Stats.Builds+=1;scene=request.Build()
      self.Stats.LastBuildMS=(clock()-start)*1000;self.Stats.BuildMS+=self.Stats.LastBuildMS
      local waitMS=if buildBudget then buildBudget.WaitMS-beforeWait else 0
      self.Stats.BuildWaitMS+=waitMS;self.Stats.BuildActiveMS+=math.max(0,self.Stats.LastBuildMS-waitMS)
      if warming then request.Scene=scene end
     end
     if not self.Alive or slot.Dead or request.Generation~=slot.Generation then return end
     local scale=math.min(1,1024/scene.Width,1024/scene.Height)
     local width=math.max(1,math.floor(scene.Width*scale));local height=math.max(1,math.round(scene.Height*width/scene.Width))
     local key=if request.Immutable then request.Key else request.Key..':'..width..'x'..height
     if not request.Immutable then frame=find(key) end
     local newFrame=false
     if not frame then
      if request.Immutable and raster.createWork and not slot.Work then slot.Work=raster.createWork() end
      local hits,layers=if slot.Work then slot.Work.LayerHits or 0 else 0,if slot.Work then slot.Work.LayerBuilds or 0 else 0
      local partial,pixels=if slot.Work then slot.Work.PartialRenders or 0 else 0,if slot.Work then slot.Work.RepaintPixels or 0 else 0
      local start,last=clock(),clock();local waited=0;self.Stats.Rasters+=1
      local loadBudget=WorkContext.budget();local loadWait=if loadBudget then loadBudget.WaitMS else 0;local loadYields=if loadBudget then loadBudget.Yields else 0
      local bytes=raster.render(scene,nil,width,function()
       WorkContext.checkpoint()
       if not WorkContext.budget()and yieldSeconds>0 and clock()-last>=yieldSeconds then
        local before=clock();taskAPI.wait();last=clock();waited+=last-before;self.Stats.Yields+=1
       end
       -- Immutable SVG states are reusable. Finish an already-started state even
       -- when hover has moved on, so rapid pointer changes warm the cache instead
       -- of repeatedly throwing away the same expensive scene and raster work.
       if not self.Alive or slot.Dead or request.Generation~=slot.Generation then return false end
       if warming then
        if slot.WarmKeys[request.Key]~=request then return false end
        return not visiblePending(slot,request.Key)
       end
       return request.Immutable or slot.Request==request
      end,if request.Immutable then slot.Work else nil)
      if loadBudget then waited+=(loadBudget.WaitMS-loadWait)/1000;self.Stats.Yields+=loadBudget.Yields-loadYields end
      self.Stats.LastRasterMS=(clock()-start)*1000;self.Stats.RasterMS+=self.Stats.LastRasterMS
      self.Stats.RasterWaitMS+=waited*1000;self.Stats.RasterActiveMS+=math.max(0,self.Stats.LastRasterMS-waited*1000)
      if slot.Work then self.Stats.LayerHits+=(slot.Work.LayerHits or 0)-hits;self.Stats.LayerBuilds+=(slot.Work.LayerBuilds or 0)-layers end
      local partials=if slot.Work then (slot.Work.PartialRenders or 0)-partial else 0
      self.Stats.PartialRenders+=partials
      self.Stats.RepaintPixels+=if partials>0 then (slot.Work.RepaintPixels or 0)-pixels else width*height
      retainedBytes()
      if not bytes or not self.Alive or slot.Dead or request.Generation~=slot.Generation then
       if warming and self.Alive and not slot.Dead and slot.WarmKeys[request.Key]==request and visiblePending(slot,request.Key) then warmPreempted=true;self.Stats.WarmPreempted+=1
       elseif warming then if removeWarm(slot,request) then self.Stats.WarmCancelled+=1 end
       else self.Stats.Cancelled+=1 end
       return
      end
      frame={Owner=slot,Key=key,Bytes=bytes,Width=width,Height=height,Scene=if request.Immutable then scene else nil};newFrame=true
     end
     if warming then
      if newFrame and self.Alive and not slot.Dead then remember(frame) end
      if removeWarm(slot,request) then self.Stats.WarmCompleted+=1;warmFinished=true end
      -- If the pointer reached the state while it was warming, use the finished
      -- frame for that visible request instead of building the same state twice.
      local visible=slot.Request
      if visible and visible~=slot.Applied and visible.Key==request.Key then installFrame(slot,visible,frame,scene);if slot.Request==visible then slot.Applied=visible end end
     else
      -- A superseded immutable state is now safely cached, but it must never
      -- overwrite the newer visual state requested by the pointer.
      installFrame(slot,request,frame,scene)
      if newFrame and self.Alive and not slot.Dead and request.Generation==slot.Generation then remember(frame) end
     end
    end)end)
    if not ok then
     if warming then if removeWarm(slot,request) then self.Stats.WarmCancelled+=1 end;if self.Alive and options.Report then options.Report(tostring(err)) end
     elseif slot.Request==request then failed(slot,err) end
    end
    if not warming and slot.Request==request then slot.Applied=request end
    visibleChanged()
    if warming and (warmFinished or warmPreempted or not ok) and self.Alive and options.Changed then options.Changed(self.Stats) end
   end
   if warmWork then warmWork:Finish();warmWork=nil end
   self.Running=false;if self.Alive and options.Changed then options.Changed(self.Stats) end
  end)
 end
 function self:Request(owner,key,build,install,immutable)
  if not self.Alive then return end
  local slot=slotFor(owner)
  if slot.Request and slot.Request.Key==key and not slot.Failed then return end
  self.Sequence+=1;slot.Failed=nil
  local request={Key=key,Build=build,Install=install,Immutable=immutable,Sequence=self.Sequence,Generation=slot.Generation};slot.Request=request
  visibleChanged()
  if self.Running and immutable then
   -- Returning to a cached state must not wait behind an unfinished cold state.
   local frame=find(key)
   if frame then
    -- Defer upload to coalesce input events and keep it off the input callback.
    taskAPI.defer(function()
     if not self.Alive or slot.Dead or slot.Request~=request or slot.Applied==request then return end
     local applied,problem=pcall(function()return WorkContext.runFor(loadingPage,installFrame,slot,request,frame,frame.Scene)end)
     if not applied then failed(slot,problem) end
     if slot.Request==request then slot.Applied=request end
     visibleChanged()
     if self.Alive and options.Changed then options.Changed(self.Stats) end
    end)
   end
  end
  run();return true
 end
 function self:Warm(owner,key,build,pixelBytes: number?)
  if not self.Alive then return end
  local slot=slotFor(owner)
  if peek(key) or slot.WarmKeys[key] or (slot.Request and slot.Request.Key==key) then return false end
  self.Sequence+=1
  local request={Key=key,Build=build,Immutable=true,Sequence=self.Sequence,Generation=slot.Generation,PixelBytes=math.max(0,pixelBytes or 0)}
  slot.WarmKeys[key]=request;table.insert(slot.Warm,request);self.Stats.WarmQueued+=1
  run();return true
 end
 function self:WarmCapacity(owner,pixelBytes: number): number
  if pixelBytes<=0 then return 0 end
  local pending,pendingBytes=0,0
  for _,candidate in self.Slots do for _,request in candidate.Warm do pending+=1;pendingBytes+=request.PixelBytes or 0 end end
  local entries=math.max(0,cacheEntries-#self.Cache-pending)
  local pixels=math.max(0,math.floor((cacheLimit-self.CacheBytes-pendingBytes)/pixelBytes))
  local slot=self.Slots[owner];local estimate=0
  if slot then for _,entry in self.Cache do if entry.Owner==slot then estimate=math.max(estimate,entry.Fields or 0) end end end
  local metadata=if estimate>0 then math.max(0,math.floor((fieldLimit-self.CacheFields)/estimate)-pending) else entries
  return math.max(0,math.min(entries,pixels,metadata))
 end
 function self:CancelWarm(owner): number
  local slot=self.Slots[owner];if not slot then return 0 end
  local count=#slot.Warm
  if count>0 then self.Stats.WarmCancelled+=count;table.clear(slot.Warm);table.clear(slot.WarmKeys) end
  return count
 end
 function self:Reset(owner)
  local slot=self.Slots[owner];if not slot then return end
  self:CancelWarm(owner);slot.Generation+=1;slot.Request=nil;slot.Applied=nil;slot.Failed=nil
  if slot.Work and raster.releaseWork then raster.releaseWork(slot.Work) end;slot.Work=nil
  for i=#self.Cache,1,-1 do if self.Cache[i].Owner==slot then evict(i) end end
  cacheStats();retainedBytes()
  visibleChanged()
 end
 function self:Remove(owner)
  local slot=self.Slots[owner]
  if slot then
   self:CancelWarm(owner);slot.Dead=true;slot.Generation+=1;release(slot);self.Slots[owner]=nil
   if slot.Work and raster.releaseWork then raster.releaseWork(slot.Work) end;slot.Work=nil
   for i=#self.Cache,1,-1 do if self.Cache[i].Owner==slot then evict(i) end end
   cacheStats()
   retainedBytes()
   visibleChanged()
  end
 end
 function self:Pending(): number
  local count=0;for _,slot in self.Slots do if slot.Request~=slot.Applied then count+=1 end;count+=#slot.Warm end;return count
 end
 function self:WarmPending(): number
  local count=0;for _,slot in self.Slots do count+=#slot.Warm end;return count
 end
 function self:Destroy()
  if warmWork then warmWork:Finish()end
  if not self.Alive then return end;self.Alive=false
  for owner in self.Slots do self:Remove(owner) end
  table.clear(self.Cache);self.CacheBytes=0;self.CacheFields=0;cacheStats()
 end
 return self
end
return Queue
