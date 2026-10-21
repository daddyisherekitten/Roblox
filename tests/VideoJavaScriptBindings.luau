--!strict
-- New BUILD controls; no archived source test or browser fixture is rewritten.
return function(Parser,Runtime,Events,VideoState)
 local inventory={"currentSrc","duration","paused","ended","seeking","readyState","networkState","error","buffered","seekable","played","muted","volume","currentTime","playbackRate","defaultPlaybackRate","play","pause","load","fastSeek","canPlayType"}
 local seen={};local checks=0;local audioOpen=0
 assert(#inventory==21)
 for _,name in inventory do assert(seen[name]==nil,"Duplicate member "..name);seen[name]=false end
 local events=Events.new(error)
 local adapter={CanLoad=function()return false end,Open=function()audioOpen+=1;error("VIDEO must never enter AudioAdapter.Open")end,Destroy=function()end}
 local realm=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),{URL='https://video.test/base/index.html',Events=events,AudioAdapter=adapter,Schedule=function()end,ApplyChanges=function()return false end})
 local function pump()for _=1,12 do realm:PumpTasks();realm.EventLoop:Checkpoint()end end
 local function run(code)local ok,message=realm:Run(code);assert(ok,tostring(message));pump();assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
 local function check(code,label)run('window.control=Boolean('..code..')');checks+=1;assert(realm.Window.Get('control')==true,label)end
 realm:Start();pump()
 run('window.v=document.createElement("video");window.p=HTMLMediaElement.prototype;')
 local cases={
  currentSrc='Object.getOwnPropertyDescriptor(p,"currentSrc").get.call(v)===""',
  duration='Number.isNaN(Object.getOwnPropertyDescriptor(p,"duration").get.call(v))',
  paused='Object.getOwnPropertyDescriptor(p,"paused").get.call(v)===true',
  ended='Object.getOwnPropertyDescriptor(p,"ended").get.call(v)===false',
  seeking='Object.getOwnPropertyDescriptor(p,"seeking").get.call(v)===false',
  readyState='Object.getOwnPropertyDescriptor(p,"readyState").get.call(v)===0',
  networkState='Object.getOwnPropertyDescriptor(p,"networkState").get.call(v)===0',
  error='Object.getOwnPropertyDescriptor(p,"error").get.call(v)===null',
  buffered='Object.getOwnPropertyDescriptor(p,"buffered").get.call(v) instanceof TimeRanges && v.buffered.length===0 && v.buffered!==v.buffered',
  seekable='Object.getOwnPropertyDescriptor(p,"seekable").get.call(v) instanceof TimeRanges && v.seekable.length===0 && v.seekable!==v.seekable',
  played='Object.getOwnPropertyDescriptor(p,"played").get.call(v) instanceof TimeRanges && v.played.length===0 && v.played!==v.played',
  muted='Object.getOwnPropertyDescriptor(p,"muted").get.call(v)===false',
  volume='Object.getOwnPropertyDescriptor(p,"volume").get.call(v)===1',
  currentTime='Object.getOwnPropertyDescriptor(p,"currentTime").get.call(v)===0',
  playbackRate='Object.getOwnPropertyDescriptor(p,"playbackRate").get.call(v)===1',
  defaultPlaybackRate='Object.getOwnPropertyDescriptor(p,"defaultPlaybackRate").get.call(v)===1',
  play='typeof p.play==="function" && window.validPlay instanceof Promise && window.playFailure==="NotSupportedError"',
  pause='p.pause.call(v)===undefined && v.paused===true',
  load='p.load.call(v)===undefined && v.defaultPlaybackRate===1',
  fastSeek='p.fastSeek.call(v,5)===undefined && v.currentTime===5',
  canPlayType='p.canPlayType.call(v,"video/unknown")===""'
 }
 run('window.playFailure="pending";window.validPlay=p.play.call(v);validPlay.catch(e=>playFailure=e.name);')
 for _,name in inventory do check(cases[name],"Installed shared member accepts genuine VIDEO: "..name);seen[name]=true end
 for _,name in inventory do assert(seen[name],"Lost member "..name)end
 check('(v.muted=true,v.volume=.25,v.muted===true && v.volume===.25)','IDL volume setter preserves mute preference')
 check('(v.defaultMuted=true,v.defaultMuted=false,v.muted===true)','defaultMuted reflection does not replace live mute')
 check('(v.defaultPlaybackRate=1.5,v.currentTime=5,v.load(),v.defaultPlaybackRate===1.5 && v.playbackRate===1.5 && v.currentTime===5)','Default start/default rate data survive bounded detached load')
 check('(v.playbackRate=4,v.playbackRate===4)','UI speed interval is not applied to detached canonical data')
 check('(v.unrelated={value:9},v.unrelated.value===9)','Unrelated VIDEO expando does not use numeric media conversion')
 run([=[
window.invalidBrands=0;window.converted=0;
const conversion={valueOf(){converted++;return .25},toString(){converted++;return 'video/unknown'}};
for(const key of ['muted','volume','currentTime','playbackRate','defaultPlaybackRate']){
 try{Object.getOwnPropertyDescriptor(p,key).set.call({},conversion)}catch(e){if(e instanceof TypeError)invalidBrands++}
}
window.brandPromise=p.play.call({});window.brandOutcome='pending';brandPromise.catch(e=>brandOutcome=e instanceof TypeError);
window.volumeFailure='',finiteFailure='';try{v.volume=2}catch(e){volumeFailure=e.name}try{v.currentTime=Infinity}catch(e){finiteFailure=e.name}
window.foreign=document.createElementNS('urn:foreign','video');window.foreignFailure='';try{Object.getOwnPropertyDescriptor(p,'paused').get.call(foreign)}catch(e){foreignFailure=e.name}
window.expanded=document.createElementNS('http://www.w3.org/1999/xhtml','h:video');window.expandedPaused=Object.getOwnPropertyDescriptor(p,'paused').get.call(expanded);
]=])
 check('invalidBrands===5 && converted===0','Brand before primitive conversion on all mutable descriptors')
 check('brandPromise instanceof Promise && brandOutcome===true','Invalid play receiver rejects a Promise instead of sync throwing')
 check('volumeFailure==="IndexSizeError" && finiteFailure==="TypeError" && v.volume===.25','Failed conversions preserve state')
 check('foreignFailure==="TypeError" && expandedPaused===true','Expanded-name VIDEO brand excludes foreign namespace')
 check('typeof Object.getOwnPropertyDescriptor(p,"loading").get==="function" && typeof Object.getOwnPropertyDescriptor(p,"loading").set==="function" && v.loading==="eager"','Installed loading IDL has live accessors and the default eager state')
 check('(v.loading="lazy",v.getAttribute("loading")==="lazy" && v.loading==="lazy")','Loading setter reflects the known lazy state')
 check('(v.setAttribute("loading","LAZY"),v.loading==="lazy")','Loading getter normalizes the attribute keyword')
 check('(v.loading="unknown",v.getAttribute("loading")==="unknown" && v.loading==="eager")','Invalid loading values retain raw reflection and use the eager state')
 check('Object.getOwnPropertyDescriptor(p,"srcObject").get.call(v)===null && ["preservesPitch","getStartDate","audioTracks","videoTracks","textTracks","addTextTrack"].every(k=>Object.getOwnPropertyDescriptor(p,k)===undefined)','Stream srcObject is installed; the six remaining missing IDL members stay separate')
 local node=realm.DOM.Unwrap(realm.Window.Get('v'));local state=VideoState.ensure(node)
 assert(node.AudioResourceState==nil and node.AudioController==nil and node.AudioHostSession==nil and audioOpen==0,'No audio owner/Sound path')
 run('document.body.appendChild(v);v.remove();document.body.appendChild(v);')
 assert(VideoState.ensure(node)==state and state.Volume==.25 and state.Muted and state.DefaultRate==1.5,'Node canonical state survives detach/reinsert without a native backend')
 realm:Destroy();events:Destroy();assert(next(state.Subscribers)==nil,'Realm facade subscription released')
 print('VideoJavaScriptBindings SOURCE-only prepared inventory',#inventory,'executed assertions',checks)
end
