--!strict
return function(Parser,Runtime,Events)
 local checks=0
 local function make(capture,extra)
  local events=Events.new(error)
  local opts={URL='https://capture.test/index.html',Events=events,Schedule=function()end,ApplyChanges=function()return false end,
   PermissionHost={Query=function()return 'granted'end},MediaCaptureHost=capture}
  opts.PermissionHost.Request=function()error('Persisted grants must not prompt')end
  for key,value in extra or{}do opts[key]=value end
  local realm=Runtime.new(Parser.parseDocument('<!doctype html><video id="live" autoplay></video>'),opts)
  local function pump()for _=1,8 do realm:PumpTasks();realm.EventLoop:Checkpoint()end end
  local function run(source)local ok,message=realm:Run(source);assert(ok,tostring(message));pump();assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
  local function check(source,label)run('var checked=Boolean('..source..')');checks+=1;assert(realm.Window.Get('checked')==true,label)end
  return realm,events,run,check,pump
 end
 local stops,subscribers,captures=0,{},{}
 local source={Mount=function()error('JS facade must never mount native sources')end}
 local descriptor={Kind='video',Id='roblox-camera',Label='Study camera',Settings={width=640,height=360,frameRate=20,deviceId='roblox-camera'},Source=source,
  Stop=function()stops+=1 end,Subscribe=function(callback)subscribers[callback]=true;return function()subscribers[callback]=nil end end}
 local capture={Capture=function(_,request)table.insert(captures,request);if request.Constraints.audio~=false then return nil,{Name='NotFoundError',Message='No microphone configured'}end;return{Tracks={descriptor}}end}
 local sourceWrites={}
 local adapter={Bind=function()end,Snapshot=function()end,SetSource=function(_,node,state,value)table.insert(sourceWrites,{Node=node,State=state,Value=value})end}
 local realm,events,run,check,pump=make(capture,{VideoAdapter=adapter})
 run([=[
  var stream,track,errorName='',statusChanges=[];
  navigator.mediaDevices.getUserMedia({video:{width:{ideal:640},height:360,frameRate:{max:20}},audio:false}).then(s=>{stream=s;track=s.getVideoTracks()[0];}).catch(e=>errorName=e.name);
 ]=])
 assert(#captures==1 and captures[1].Origin=='https://capture.test'and captures[1].URL=='https://capture.test/index.html')
 assert(captures[1].Constraints.video.width.ideal==640 and captures[1].Constraints.video.height==360 and captures[1].Constraints.video.frameRate.max==20)
 check('stream instanceof MediaStream && stream instanceof EventTarget && track instanceof MediaStreamTrack && track instanceof EventTarget && errorName===""','Granted configured camera returns branded EventTargets')
 check('Object.prototype.toString.call(stream)==="[object MediaStream]" && Object.prototype.toString.call(track)==="[object MediaStreamTrack]"','Media brands')
 check('stream.active && stream.getTracks().length===1 && stream.getAudioTracks().length===0 && stream.getVideoTracks()[0]===track && stream.getTrackById(track.id)===track && stream.getTrackById("none")===null','Track selection and identity')
 check('track.kind==="video" && track.label==="Study camera" && track.readyState==="live" && track.enabled && !track.muted','Initial video track properties')
 check('track.getSettings().width===640 && track.getSettings().height===360 && track.getSettings()!==track.getSettings() && Object.keys(track.getConstraints()).length===0','Copied native settings never expose source')
 check('track.Source===undefined && stream.Tracks===undefined && track.Stop===undefined','Native handles remain private')
 run('var live=document.getElementById("live");live.srcObject=stream;var same=live.srcObject===stream;')
 local node=realm.DOM.Unwrap(realm.Window.Get('live'))
 local native=realm.MediaStreams:Resolve(realm.Window.Get('stream'))
 assert(realm.Window.Get('same')and node.MediaStreamSource==native and sourceWrites[#sourceWrites].Value==native)
 assert(native.Tracks[1].Source==source and native.Tracks[1].Settings.width==640)
 local notifications=0;local unsubscribe=native.Subscribe(function()notifications+=1 end)
 check('(track.enabled=false,!track.enabled)','Track enabled toggles without stopping source')
 assert(not native.Tracks[1].Enabled and notifications==1 and stops==0)
 check('(track.enabled=true,track.enabled)','Enabled can recover')
 run('var bad=0;for(const x of [{},"camera",false]){try{live.srcObject=x}catch(e){if(e.name==="TypeError")bad++}}')
 check('bad===3 && live.srcObject===stream','Invalid srcObject leaves former source attached')
 run('var clone=track.clone(),copy=new MediaStream(stream),clonedStream=stream.clone();track.onended=()=>statusChanges.push("ended");track.stop();track.stop();')
 assert(stops==0 and native.Tracks[1].Stopped and native.Tracks[1].ReadyState=='ended')
 check('!stream.active && !copy.active && clone.readyState==="live" && clonedStream.active && statusChanges.length===0','Stopping original leaves clones live and sends no ended event')
 check('(copy.removeTrack(track),copy.getTracks().length===0 && copy.getTrackById(track.id)===null)','Track removal updates membership')
 check('(copy.addTrack(clone),copy.addTrack(clone),copy.active && copy.getTracks().length===1)','Adding duplicate track is idempotent')
 check('(track.clone().readyState==="ended")','Cloning a stopped track remains stopped')
 run('clone.stop();clonedStream.getTracks().forEach(t=>t.stop());')
 assert(stops==1 and not native.Active)
 check('(live.srcObject=null,live.srcObject===null)','Source can be detached without unsupported conversion')
 assert(node.MediaStreamSource==nil and sourceWrites[#sourceWrites].Value==nil)
 check('(live.srcObject=undefined,live.srcObject===null)','Nullable srcObject converts undefined to null')
 run('navigator.mediaDevices.getUserMedia({audio:true,video:true}).catch(e=>errorName=e.name);')
 check('errorName==="NotFoundError"','Combined unsupported audio rejects atomically')
 assert(#captures==2 and stops==1)
 unsubscribe();realm:Destroy();realm:Destroy();events:Destroy();assert(stops==1 and next(subscribers)==nil)
 -- Native device loss ends the track and notifies attached video subscribers.
 stops=0;table.clear(subscribers)
 realm,events,run,check,pump=make(capture)
 run('var stream,track,ended=0;navigator.mediaDevices.getUserMedia({video:true}).then(s=>{stream=s;track=s.getTracks()[0];track.onended=()=>ended++;});')
 for callback in table.clone(subscribers)do callback('ended')end;pump()
 check('!stream.active && track.readyState==="ended" && ended===1','External source loss produces ended event')
 assert(stops==1 and next(subscribers)==nil)
 realm:Destroy();events:Destroy();assert(stops==1)
 -- Realm teardown releases still-live captures once and cancels subscriptions.
 stops=0;realm,events,run,check,pump=make(capture)
 run('var stream;navigator.mediaDevices.getUserMedia({video:true}).then(s=>stream=s);')
 assert(stops==0 and next(subscribers)~=nil)
 realm:Destroy();events:Destroy();assert(stops==1 and next(subscribers)==nil)
 -- A reentrant/yielding host may return after the document becomes inactive or
 -- dies. Late native results must be stopped before JS wrappers can be made.
 for _,action in {'hide','destroy'}do
  stops=0
  local lateHost={Capture=function()
   if action=='hide'then realm:SetVisible(false)else realm:Destroy()end
   return {Tracks={descriptor}}
  end}
  realm,events,run,check,pump=make(lateHost)
  local ok,message=realm:Run('var lateResult="pending";navigator.mediaDevices.getUserMedia({video:true}).then(s=>lateResult="captured").catch(e=>lateResult=e.name);');assert(ok,tostring(message));pump()
  assert(stops==1 and next(subscribers)==nil,action..' late capture must stop once; got '..stops..'; diagnostics '..table.concat(realm.Diagnostics,' | '))
  if action=='hide'then assert(realm.Window.Get('lateResult')=='AbortError')end
  realm:Destroy();events:Destroy();assert(stops==1)
 end
 -- Capture failure and malformed native tracks stay distinct from permission denial.
 for _,case in {{Capture=function()error('native source failure')end},{Capture=function()return {Tracks={}}end},{Capture=function()return nil,{Name='OverconstrainedError',Message='width'}end}}do
  realm,events,run,check,pump=make(case,{Report=function()end})
  local ok,message=realm:Run('var captureError;navigator.mediaDevices.getUserMedia({video:true}).catch(e=>captureError=e.name);');assert(ok,tostring(message));pump()
  local name=realm.Window.Get('captureError');assert(name=='NotReadableError'or name=='OverconstrainedError')
  realm:Destroy();events:Destroy()
 end
 print('MediaStreamCapture',checks,'assertions: native capture, constraints, identity, video binding, clones, stop and teardown passed')
end
