--!strict
-- Actual public adapter and pure VideoState/MediaBox; native hooks are deliberate fault/reentry seams.
return function(VideoServices,VideoState,MediaBox,Node)
 local checks,cases=0,0
 local function check(value,message)checks+=1;assert(value,message)end
 local function fixture(modern)
  local node=Node.element('video',{});local state=VideoState.ensure(node)
  state.Ready=2;state.Duration=12
  local item={Node=node,MediaKind='video',UsingVideoPlayer=modern,ShowPoster=true,PosterReady=true,Poster='poster',PosterWidth=120,PosterHeight=240,VideoWidth=80,VideoHeight=40,VideoFrameAvailable=true,CurrentTime=0,Duration=12,Muted=false,Volume=1,PlaybackRate=1,RateSupported=true,Style={}}
  local r={Generation=1,SelectionEpoch=1,ReadyGeneration=1,Network=1,Item=item,PublicState=state};local owner={};local live=true;local position=0;local onWrite,onPresent;local presents,writes,notifications=0,0,0;local jobs,events={},{ }
  local object={TimeLength=12,IsPlaying=false,Playing=false}
  setmetatable(object,{__index=function(_,k)if k=='TimePosition'then return position end end,__newindex=function(self,k,v)if k=='TimePosition'then writes+=1;if onWrite then onWrite(v)end;position=v else rawset(self,k,v)end end})
  if modern then item.VideoPlayer=object else item.VideoGui=object end
  local service=VideoServices.new({Owner=owner,Lookup=function()if live then return item,r end;return nil,nil end,
   Current=function(lease,stamp)return live and lease.Registration==r and lease.Item==item and stamp.Epoch==r.SelectionEpoch and stamp.Generation==r.Generation and stamp.Object==object end,
   Queue=function(fn)table.insert(jobs,fn)end,Emit=function(_,kind)table.insert(events,kind)end,
   Present=function(current)presents+=1;check(current==item,'Current presentation item');check(not item.ShowPoster,'Poster cleared before presentation');MediaBox.natural(item);MediaBox.paint(item);if onPresent then onPresent()end end})
  service:VideoBind(node,state);MediaBox.natural(item)
  local cancel=VideoState.subscribe(state,function(kind)if kind=='seeking'then notifications+=1;check(item.ShowPoster==false and item.IntrinsicWidth==80 and item.IntrinsicHeight==40 and presents>0,'Synchronous seeking subscriber observes changed representation before notification')end end)
  local h={Item=item,Node=node,State=state,Object=object,Service=service,Jobs=jobs,Events=events}
  function h:Set(v)return service:VideoSet(node,state,'currentTime',v)end
  function h:Hooks(write,present)onWrite=write;onPresent=present end
  function h:Stats()return writes,presents,notifications end
  function h:Drain()while #jobs>0 do table.remove(jobs,1)()end end
  function h:BeforeMetadata(v)
   state.Ready=0;item.VideoFrameAvailable=false;item.VideoWidth=0;item.VideoHeight=0;MediaBox.natural(item)
   check(self:Set(v)==nil,'Pre-metadata setter accepted');check(state.DefaultStart==v and state.Position==0 and item.ShowPoster and item.IntrinsicWidth==120,'HAVE_NOTHING stores only default start and retains poster');check(writes==0 and presents==0 and notifications==0 and #jobs==0,'Pre-metadata setter has no native/presentation/event work')
  end
  function h:Metadata()
   item.VideoFrameAvailable=true;item.VideoWidth=80;item.VideoHeight=40;service:Signal(item,'metadata')
  end
  function h:Replace(kind)
   if kind=='generation'then r.Generation+=1;r.ReadyGeneration=nil
   elseif kind=='epoch'then r.SelectionEpoch+=1
   elseif kind=='registration'then r={Generation=1,SelectionEpoch=1,ReadyGeneration=nil,Network=0,Item=item,PublicState=state};state.Backend=nil
   elseif kind=='owner'then state.Backend={Media={},Registration=r,Item=item}
   elseif kind=='destroy'then live=false;service:Destroy()
   else error('Unknown reentry kind')end
   state.Ready=0;state.Position=0;state.Seeking=false;state.DefaultStart=0;item.ShowPoster=true;item.VideoFrameAvailable=false;item.CurrentTime=0;MediaBox.natural(item)
  end
  function h:Close()cancel();service:Destroy();check(#jobs==0,'All queued checks drained or absent')end
  return h
 end
 for _,modern in {true,false}do
  for _,value in {3,0,99,-2}do
   cases+=1;local h=fixture(modern);check(h:Set(value)==nil,'Ready setter accepted');local position=math.clamp(value,0,12);local writes,presents,notifications=h:Stats()
   check(writes==1 and presents==1 and notifications==1,'One accepted native seek/presentation/synchronous notification');check(h.State.Position==position and h.Item.CurrentTime==position and not h.Item.ShowPoster,'Ready seek commits clamped position and represented video');check(h.Item.IntrinsicWidth==80 and h.Item.IntrinsicHeight==40,'Ready seek switches intrinsic geometry');h:Drain();check(#h.Events==2 and h.Events[1]=='seeking'and h.Events[2]=='seeked'and not h.State.Seeking,'Existing bounded event pair remains ordered');h:Close()
  end
  for _,value in {3,0,99,-2}do
   cases+=1;local h=fixture(modern);h:BeforeMetadata(value);h:Metadata();local writes,presents,notifications=h:Stats()
   if value>0 then check(writes==1 and presents==1 and notifications==0 and h.State.Position==math.min(value,12)and h.Item.CurrentTime==math.min(value,12),'Positive default start applies once when metadata arrives');check(not h.Item.ShowPoster and h.Item.IntrinsicWidth==80,'Applied default start clears represented poster')
   else check(writes==0 and presents==0 and notifications==0 and h.State.Position==0 and h.Item.ShowPoster and h.Item.IntrinsicWidth==120,'Zero/negative stored start does not trigger metadata seek')end
   check(h.State.DefaultStart==0 and #h.Jobs==0,'Metadata clears default start without expanding event timing profile');h:Close()
  end
  for _,boundary in {'native','present'}do for _,kind in {'generation','epoch','registration','owner','destroy'}do
   cases+=1;local h=fixture(modern);local fn=function()h:Replace(kind)end;h:Hooks(if boundary=='native'then fn else nil,if boundary=='present'then fn else nil);h:Set(3);local _,presents,notifications=h:Stats()
   check(presents==(if boundary=='native'then 0 else 1)and notifications==0 and #h.Jobs==0,'Stale '..boundary..' '..kind..' blocks old continuation');check(h.Item.ShowPoster and h.Item.IntrinsicWidth==120 and h.State.Position==0,'Replacement/reset state survives obsolete setter');h:Close()
  end end
  for _,kind in {'generation','epoch','registration','owner','destroy'}do
   cases+=1;local h=fixture(modern);h:BeforeMetadata(3);h:Hooks(nil,function()check(h.State.DefaultStart==0 and h.State.Position==3,'Reentrant getter sees cleared default and committed position');h:Replace(kind)end);h:Metadata();check(h.State.Ready==0 and h.State.Position==0 and h.Item.ShowPoster and #h.Jobs==0,'Metadata Present '..kind..' stops obsolete continuation');h:Close()
  end
  for _,boundary in {'native','present','notify','default-native','default-present'}do for _,kind in {'nil','false','table'}do
   cases+=1;local h=fixture(modern);local payload=if kind=='false'then false elseif kind=='table'then {Fault=boundary}else nil;local fault=function()error(payload,0)end;local cancellation
   if boundary=='notify'then cancellation=VideoState.subscribe(h.State,function(event)if event=='seeking'then check(h.Item.IntrinsicWidth==80 and not h.Item.ShowPoster,'Throwing subscriber also sees published presentation');fault()end end)
   elseif boundary=='native'or boundary=='default-native'then h:Hooks(fault,nil)else h:Hooks(nil,fault)end
   if boundary:sub(1,8)=='default-'then h:BeforeMetadata(3)end
   local result=table.pack(pcall(function()if boundary:sub(1,8)=='default-'then h:Metadata()else h:Set(3)end end));check(result[1]==false and result[2]==payload,'Exact first raw '..kind..' '..boundary..' fault');check(#h.Jobs==0 and #h.Events==0,'Failed callback queues no downstream seek tasks')
   local _,presents,notifications=h:Stats();if boundary=='native'or boundary=='default-native'then check(presents==0 and notifications==0 and h.Item.ShowPoster,'Failed native write retains poster')else check(presents==1 and not h.Item.ShowPoster and h.Item.IntrinsicWidth==80,'Completed native seek keeps committed presentation on later callback failure')end
   if cancellation then cancellation()end;h:Close()
  end end
  do cases+=1;local h=fixture(modern);h.State.Ready=0;h:Replace('destroy');check(h:Set(4)==nil and h.State.DefaultStart==4 and h.Item.ShowPoster,'Detached HAVE_NOTHING remains local default start');h:Close()end
 end
 check(cases==78,'Literal bounded control inventory');print('VIDEO_SEEK_PRESENTATION_SUMMARY','cases='..cases,'assertions='..checks,'sameSourceNestedSeekCoalescing=open')
end
