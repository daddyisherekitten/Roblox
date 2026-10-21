--!strict
local Names=require(script.Parent.Parent.DOM.ElementNames)
local VideoState=require(script.Parent.Parent.HTML.VideoState)
local VideoElements={}
-- Binding/Promise facade only. The existing renderer owns selection and IO.
function VideoElements.install(vm,options)
 local VM,U,N=vm.Model,vm.Model.Undefined,vm.Model.Null
 local origin,adapter,streams=options.Origin,options.Adapter,options.Streams
 local api={Alive=true};local records=setmetatable({},{__mode="k"});local settlements={}
 local function problem(name,message)VM.throw(options.Events:DOMException(message,name))end
 local function alive()return api.Alive and vm.Alive and origin.Alive end
 local function scalar(value)
  local primitive=vm.ToPrimitive(value,"string")
  if type(primitive)=="table"and primitive.Kind=="symbol"then VM.throw(VM.error("TypeError","Cannot convert Symbol to DOMString"))end
  return VM.string(primitive)
 end
 local function finite(value)
  local number=VM.number(vm.ToPrimitive(value,"number"))
  if number~=number or math.abs(number)==math.huge then VM.throw(VM.error("TypeError","Media values must be finite"))end
  return number
 end
 local function settleTokens(tokens,name,message)
  if #tokens==0 then return end
  local ok,result=pcall(function()if origin.Settle then origin.Settle(tokens,name,message)end end)
  if not ok then
   -- The failed external hook must not leave its capabilities in the origin.
   -- Cleanup cannot replace the exact first nil/false/table payload.
   pcall(function()if origin.Drop then origin.Drop(tokens)end end)
   error(result,0)
  end
 end
 local function settle(record,name,message)
  local tokens=record.Plays;record.Plays={};settleTokens(tokens,name,message)
 end
 local function queued(record,name,message)
  local waiting=record.Plays;record.Plays={}
  if #waiting==0 then return end
  local entry={Tokens=waiting};settlements[entry]=true
  local function finish()
   local tokens=entry.Tokens;entry.Tokens=nil;settlements[entry]=nil
   if not tokens then return end
   if alive()then settleTokens(tokens,name,message)
   elseif origin.Drop then origin.Drop(tokens)end
  end
  local ok,accepted=pcall(function()return origin.QueueTask(finish)end)
  if not ok or accepted==false then
   local tokens=entry.Tokens;entry.Tokens=nil;settlements[entry]=nil
   if tokens and origin.Drop then
    -- Finish may have consumed this entry synchronously. Never Drop(nil).
    -- Preserve the first scheduler payload even if token cleanup also throws.
    if not ok then pcall(origin.Drop,tokens)else origin.Drop(tokens)end
   end
  end
  if not ok then error(accepted,0)end
 end
 local function ensure(node)
  assert(Names.html(node,"video"),"Video facade receiver")
  local record=records[node]
  if record then if adapter and adapter.Bind then adapter:Bind(node,record.State)end;return record end
  local state=VideoState.ensure(node);record={State=state,Plays={}};records[node]=record
  record.Cancel=VideoState.subscribe(state,function(kind)
   if not alive()then return end
   if kind=="playing"then queued(record)
   elseif kind=="pause"or kind=="removed"or(kind=="reset"and state.ResetRejectPlay)then queued(record,"AbortError","Video playback was interrupted")
   elseif kind=="error"then queued(record,"NotSupportedError","Video source could not be played")end
  end)
  if adapter and adapter.Bind then adapter:Bind(node,state)end
  return record
 end
 api.Ensure=ensure
 function api:Get(node,key)
  local record=ensure(node);local state=record.State
  if adapter and adapter.Snapshot then adapter:Snapshot(node,state)end
  if key=='srcObject'then return record.SourceObject or N end
  if key=="error"then return if state.Error then origin.MaterializeError(state,state.Error)else N end
  if key=="buffered"or key=="seekable"or key=="played"then return origin.MaterializeRange(VideoState.ranges(state,key))end
  local value=VideoState.get(state,key);if value~=nil then return value end
  if key=="play"then return function()
   local promise,token=origin.Create()
   if not token then problem("InvalidStateError","Original media realm is unavailable")end
   table.insert(record.Plays,token)
   if state.Error then queued(record,"NotSupportedError","Video source could not be played");return promise end
   if not adapter or not adapter.Command or not state.Backend then
    queued(record,"NotSupportedError","Detached video playback is not supported by this bounded host profile");return promise
   end
   local ok,result=pcall(adapter.Command,adapter,node,state,"play")
   if not ok then settle(record,"AbortError","Video host operation failed");error(result,0)end
   if not alive()then return promise end
   if result then queued(record,result.Name,result.Message)
   elseif state.Error then queued(record,"NotSupportedError","Video source could not be played")
   elseif state.Playing then queued(record)end
   return promise
  end
  elseif key=="pause"or key=="load"or key=="fastSeek"then return function(args)
   if key=="fastSeek"then
    if args[1]==nil then VM.throw(VM.error("TypeError","fastSeek requires a time"))end
    self:Set(node,"currentTime",args[1]);return U
   end
   if adapter and adapter.Command and state.Backend then
    local result=adapter:Command(node,state,key);if result then problem(result.Name,result.Message)end
   elseif key=="pause"then state.Paused=true;VideoState.notify(state,"pause")
   else
    -- Detached resource selection is explicitly outside the current adapter.
    state.Rate=state.DefaultRate;state.Position=0;state.Ready=0;state.Network=0;state.Duration=0/0
    state.Current="";state.Error=nil;state.Ended=false;VideoState.notify(state,"reset")
   end
   return U
  end
  elseif key=="canPlayType"then return function(args)
   if args[1]==nil then VM.throw(VM.error("TypeError","canPlayType requires a media type"))end
   local value=scalar(args[1])
   return if adapter and adapter.CanPlayType then adapter:CanPlayType(value)else ""
  end end
  return nil
 end
 function api:Set(node,key,value)
  local record=ensure(node);local state=record.State
  if key=='srcObject'then
   if value==U then value=N end
   local source
   if value~=N then
    source=streams and streams:Resolve(value)
    if not source then VM.throw(VM.error('TypeError','srcObject requires a MediaStream or null'))end
   end
   if record.SourceObject==value or not record.SourceObject and value==N then return true end
   record.SourceObject=if value==N then nil else value;record.Source=source
   node.MediaStreamSource=source
   if adapter and adapter.SetSource then
    local result=adapter:SetSource(node,state,source);if result then problem(result.Name,result.Message)end
   end
   return true
  end
  local converted=if key=="muted"then VM.truth(value)else finite(value)
  if not alive()then problem("InvalidStateError","Video realm disposed during conversion")end
  local result
  if adapter and adapter.Set and state.Backend then result=adapter:Set(node,state,key,converted)
  else result=VideoState.localSet(state,key,converted)end
  if result then problem(result.Name,result.Message)end
  return true
 end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  local hadError=false;local firstError
  local function attempt(operation)
   local ok,result=pcall(operation);if not ok and not hadError then hadError=true;firstError=result end
  end
  for node,record in records do
   if record.SourceObject then
    record.SourceObject=nil
    if node.MediaStreamSource==record.Source then
     node.MediaStreamSource=nil
     if adapter and adapter.SetSource then attempt(function()adapter:SetSource(node,record.State,nil)end)end
    end
    record.Source=nil
   end
   local cancel=record.Cancel;record.Cancel=nil;record.State=nil
   if cancel then attempt(cancel)end
   attempt(function()settle(record,"AbortError","Video realm was disposed")end)
  end
  for entry in settlements do
   local tokens=entry.Tokens;entry.Tokens=nil;settlements[entry]=nil
   if tokens then attempt(function()if origin.Drop then origin.Drop(tokens)end end)end
  end
  table.clear(settlements);table.clear(records);adapter=nil
  if hadError then error(firstError,0)end
 end
 return api
end
return VideoElements
