--!strict
-- Private capture handles never become JS objects. Tracks share a native source
-- until their last live clone stops; every realm-owned handle is released on exit.
local MediaStreams={}
function MediaStreams.install(vm,globals,options)
 local VM,U,N=vm.Model,vm.Model.Undefined,vm.Model.Null
 local api={Alive=true};local streams,tracks={},{};local serial=0
 local function fail(message)VM.throw(VM.error('TypeError',message))end
 local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
 local function native(name,length,action)
  local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,self)assert(api.Alive and vm.Alive,'Media streams disposed');return action(args,self)end}
  define(value,'name',{value=name,configurable=true});define(value,'length',{value=length,configurable=true});return value
 end
 local function report(message)if options.Report then options.Report('Media capture: '..tostring(message))end end
 local function attempt(action)local ok,message=pcall(action);if not ok then report(message)end end
 local function queue(action)if api.Alive then options.QueueTask(function()if api.Alive and vm.Alive then action()end end)end end
 local function emit(target,kind)queue(function()options.Events:Dispatch(target,options.Events:NewEvent(kind,{},'Event'),true)end)end
 local function copy(data)
  local result={};for key,value in data or{}do if type(key)=='string'and(type(value)=='string'or type(value)=='number'or type(value)=='boolean')then result[key]=value end end
  return vm.Object(result)
 end
 local eventPrototype=vm.Get(globals.EventTarget,'prototype')
 local streamPrototype=vm.Object({},eventPrototype);local trackPrototype=vm.Object({},eventPrototype)
 local function streamState(value)local state=streams[value];if not state then fail('Illegal MediaStream receiver')end;return state end
 local function trackState(value)local state=tracks[value];if not state then fail('Illegal MediaStreamTrack receiver')end;return state end
 local function announce(stream,kind)
  local active=false;for _,track in stream.Tracks do if not track.Stopped then active=true;break end end
  local changed=stream.Active~=active;stream.Active=active
  for callback in table.clone(stream.Listeners)do if stream.Listeners[callback]then attempt(function()callback(kind,stream)end)end end
  if changed and not active then emit(stream.Value,'inactive')elseif changed then emit(stream.Value,'active')end
 end
 local function notifyTrack(track)
  for stream in track.Streams do announce(stream,'change')end
 end
 local function release(shared)
  if shared.Released or shared.Live>0 then return end;shared.Released=true
  if shared.Cancel then local cleanup=shared.Cancel;shared.Cancel=nil;attempt(cleanup)end
  if type(shared.Descriptor.Stop)=='function'then attempt(shared.Descriptor.Stop)end
  local descriptor=shared.Descriptor
  shared.Descriptor={Kind=descriptor.Kind,Id=descriptor.Id,Label=descriptor.Label,Settings=descriptor.Settings}
 end
 local function stop(track,fromHost)
  if track.Stopped then return end
  track.Stopped=true;track.ReadyState='ended';track.Shared.Live-=1
  notifyTrack(track);track.Source=nil;release(track.Shared)
  -- Calling stop() does not itself dispatch the ended event.
  if fromHost then emit(track.Value,'ended')end
 end
 local function makeTrack(shared,template)
  serial+=1
  local descriptor=shared.Descriptor
  local value=vm.Object({},trackPrototype)
  local track={Value=value,Kind=descriptor.Kind,Id=if template then 'track-'..serial else tostring(descriptor.Id or('track-'..serial)),Label=tostring(descriptor.Label or''),
   Settings=table.clone(descriptor.Settings or{}),Source=descriptor.Source,Enabled=if template then template.Enabled else true,Muted=false,Stopped=shared.Released or template and template.Stopped or false,ReadyState=if shared.Released or template and template.Stopped then'ended'else'live',Shared=shared,Streams={}}
  tracks[value]=track;shared.Tracks[track]=true
  if track.Stopped then track.Source=nil end
  if not track.Stopped then shared.Live+=1 end
  options.Events:WrapTarget(value,{Handlers=true,HandlerNames={onended=true,onmute=true,onunmute=true},Parent=function()return nil end})
  return track
 end
 local function makeStream(items)
  serial+=1;local value=vm.Object({},streamPrototype)
  local stream={Value=value,Id='stream-'..serial,Tracks={},Active=false,Listeners={}}
  stream.Subscribe=function(callback)stream.Listeners[callback]=true;return function()stream.Listeners[callback]=nil end end
  streams[value]=stream
  options.Events:WrapTarget(value,{Handlers=true,HandlerNames={onaddtrack=true,onremovetrack=true},Parent=function()return nil end})
  for _,track in items do if not table.find(stream.Tracks,track)then table.insert(stream.Tracks,track);track.Streams[stream]=true;if not track.Stopped then stream.Active=true end end end
  return value
 end
 function api:Resolve(value)return streams[value]end
 function api:FromCapture(capture)
  assert(type(capture)=='table'and type(capture.Tracks)=='table'and #capture.Tracks>0,'Capture host did not return tracks')
  for _,descriptor in capture.Tracks do assert(type(descriptor)=='table'and(descriptor.Kind=='video'or descriptor.Kind=='audio'),'Capture host returned an invalid track')end
  local items={}
  for _,descriptor in capture.Tracks do
   local shared={Descriptor=descriptor,Tracks={},Live=0,Released=false};table.insert(items,makeTrack(shared))
   if type(descriptor.Subscribe)=='function'then
    local ok,cleanup=pcall(descriptor.Subscribe,function(kind)
     if not api.Alive or shared.Released then return end
     if kind=='ended'or descriptor.Stopped==true or descriptor.ReadyState=='ended'then
      for track in table.clone(shared.Tracks)do stop(track,true)end
     elseif kind=='mute'or kind=='unmute'then
      for track in shared.Tracks do if not track.Stopped then track.Muted=kind=='mute';notifyTrack(track);emit(track.Value,kind)end end
     end
    end)
    if ok and type(cleanup)=='function'then if shared.Released then attempt(cleanup)else shared.Cancel=cleanup end elseif not ok then report(cleanup)end
   end
  end
  return makeStream(items)
 end
 for key in {id=true,active=true}do define(streamPrototype,key,{get=native('get '..key,0,function(_,self)local state=streamState(self);return if key=='id'then state.Id else state.Active end),enumerable=true,configurable=true})end
 for key in {kind=true,id=true,label=true,readyState=true,muted=true,enabled=true}do
  local descriptor={get=native('get '..key,0,function(_,self)local track=trackState(self);return if key=='kind'then track.Kind elseif key=='id'then track.Id elseif key=='label'then track.Label elseif key=='readyState'then track.ReadyState elseif key=='muted'then track.Muted else track.Enabled end),enumerable=true,configurable=true}
  if key=='enabled'then descriptor.set=native('set enabled',1,function(args,self)local track=trackState(self);track.Enabled=VM.truth(args[1]or U);notifyTrack(track);return U end)end
  define(trackPrototype,key,descriptor)
 end
 for _,kind in {'getTracks','getVideoTracks','getAudioTracks'}do define(streamPrototype,kind,{value=native(kind,0,function(_,self)
  local result={};for _,track in streamState(self).Tracks do if kind=='getTracks'or kind=='getVideoTracks'and track.Kind=='video'or kind=='getAudioTracks'and track.Kind=='audio'then table.insert(result,track.Value)end end;return vm.Array(result)
 end),writable=true,enumerable=true,configurable=true})end
 define(streamPrototype,'getTrackById',{value=native('getTrackById',1,function(args,self)
  local stream=streamState(self);if args[1]==nil then fail('getTrackById requires an id')end
  local id=VM.string(vm.ToPrimitive(args[1],'string'));for _,track in stream.Tracks do if track.Id==id then return track.Value end end;return N
 end),writable=true,enumerable=true,configurable=true})
 for _,kind in {'addTrack','removeTrack'}do define(streamPrototype,kind,{value=native(kind,1,function(args,self)
  local stream=streamState(self);local track=trackState(args[1]);local at=table.find(stream.Tracks,track)
  if kind=='addTrack'and not at then table.insert(stream.Tracks,track);track.Streams[stream]=true;announce(stream,'change')
  elseif kind=='removeTrack'and at then table.remove(stream.Tracks,at);track.Streams[stream]=nil;announce(stream,'change')end
  return U
 end),writable=true,enumerable=true,configurable=true})end
 define(streamPrototype,'clone',{value=native('clone',0,function(_,self)local items={};for _,track in streamState(self).Tracks do table.insert(items,makeTrack(track.Shared,track))end;return makeStream(items)end),writable=true,enumerable=true,configurable=true})
 define(trackPrototype,'clone',{value=native('clone',0,function(_,self)local track=trackState(self);return makeTrack(track.Shared,track).Value end),writable=true,enumerable=true,configurable=true})
 define(trackPrototype,'stop',{value=native('stop',0,function(_,self)stop(trackState(self),false);return U end),writable=true,enumerable=true,configurable=true})
 for _,kind in {'getSettings','getConstraints','getCapabilities'}do define(trackPrototype,kind,{value=native(kind,0,function(_,self)local track=trackState(self);return copy(if kind=='getSettings'then track.Settings else nil)end),writable=true,enumerable=true,configurable=true})end
 local streamConstructor=native('MediaStream',0,function()fail("MediaStream must be called with new")end)
 streamConstructor.Construct=function(args)
  local value=args[1];if value==nil or value==U then return makeStream({})end
  local existing=streams[value];if existing then return makeStream(existing.Tracks)end
  if not vm.ObjectModel.IsObject(value)or value==N then fail('MediaStream requires a stream or a track sequence')end
  local length=VM.number(vm.Get(value,'length'));if length~=length or length<0 or length>1024 or length%1~=0 then fail('A bounded track sequence is required')end
  local items={};for index=0,length-1 do table.insert(items,trackState(vm.Get(value,tostring(index))))end;return makeStream(items)
 end
 local trackConstructor=native('MediaStreamTrack',0,function()fail('Illegal MediaStreamTrack constructor')end)
 trackConstructor.Construct=function()fail('Illegal MediaStreamTrack constructor')end
 for _,entry in {{'MediaStream',streamConstructor,streamPrototype},{'MediaStreamTrack',trackConstructor,trackPrototype}}do
  define(entry[2],'prototype',{value=entry[3]});define(entry[3],'constructor',{value=entry[2],writable=true,configurable=true})
  if vm.SymbolToStringTag then define(entry[3],vm.SymbolToStringTag,{value=entry[1],configurable=true})end
  globals[entry[1]]=entry[2];vm.GlobalEnvironment:Define(entry[1],vm.Object({value=entry[2],writable=true,enumerable=false,configurable=true},N),true)
 end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for _,track in tracks do stop(track,false);options.Events:EraseListeners(track.Value)end
  for value,stream in streams do table.clear(stream.Listeners);options.Events:EraseListeners(value)end
  table.clear(streams);table.clear(tracks)
 end
 return api
end
return MediaStreams
