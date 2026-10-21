--!strict
-- Separately named frozen/WebIDL + native brand5 counterpart, Root authorized.
-- Original production expression and synchronous expectation are retained below.
-- Every other original operation/assertion remains unchanged.
local originalExpression=[=[try{HTMLMediaElement.prototype.play.call({})}catch(e){console.log(e.name)}]=]
local originalSynchronousExpected="TypeError"
local originalSourceSHA256="06cf4dbb1fb6f3f305fdd3c5ef178c2318fbe28ae38e2a703562adec447a8fd0"

return function(Parser,Runtime,Events)
	local function fixture(html)
		local output,requests,handles={}, {}, {}
		local clock=0;local events=Events.new(error);local adapter={Alive=true}
		function adapter:CanLoad(raw)return raw~="missing.ogg"end
		function adapter:CanPlayType()return ""end
		function adapter:Open(node,notify)
			local h={Node=node,Notify=notify,Position=0,Duration=12,PlayCalls=0,PauseCalls=0,Settings={}}
			function h:Load(url,raw,generation)
				self.Generation=generation;self.Position=0
				table.insert(requests,{Handle=self,URL=url,Raw=raw,Generation=generation})
			end
			function h:Reset(generation)self.Generation=generation;self.Position=0 end
			function h:Snapshot()return {Position=self.Position,Duration=self.Duration}end
			function h:Set(key,value)self.Settings[key]=value;if key=="currentTime"then self.Position=value end end
			function h:Play(intent)self.PlayCalls+=1;self.Notify({Kind="playing",Generation=self.Generation,Intent=intent})end
			function h:Pause()self.PauseCalls+=1 end
			table.insert(handles,h);return h
		end
		function adapter:Destroy()self.Alive=false end
		local realm=Runtime.new(Parser.parseDocument('<!doctype html><html><body>'..(html or '')..'</body></html>'),{
			URL="https://audio.test/app/index.html",Events=events,AudioAdapter=adapter,Clock=function()return clock end,
			Schedule=function()end,ApplyChanges=function()return false end,Console=function(_,message)table.insert(output,message)end,
		})
		local function run(source)local ok,message=realm:Run(source);assert(ok,tostring(message))end
		local function pump()for _=1,16 do clock+=.01;realm:PumpTasks();realm.EventLoop:Checkpoint()end end
		local function expect(values)
			assert(#output==#values,"Count: "..table.concat(output," | "))
			for i,value in values do assert(output[i]==value,"Got: "..table.concat(output," | ").." expected "..value)end
		end
		local function complete(index,success)
			local request=requests[index];request.Handle.Notify({Kind=if success==false then"error"else"loaded",Generation=request.Generation,Duration=12,Code=4});pump()
		end
		local function destroy()assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n"));realm:Destroy();events:Destroy();assert(not adapter.Alive)end
		realm:Start();pump()
		return realm,run,pump,expect,complete,destroy,requests,handles,output
	end
	do
		local realm,run,pump,expect,_,destroy,requests=fixture()
		run([[var a=new Audio();console.log(a instanceof Audio,a instanceof HTMLAudioElement,a instanceof HTMLMediaElement,a instanceof HTMLElement,a.tagName,a.preload,a.paused,a.volume,a.muted,a.currentTime,a.readyState,a.networkState,Number.isNaN(a.duration),a.error===null);
console.log(Audio().tagName,a.NETWORK_NO_SOURCE,HTMLMediaElement.HAVE_ENOUGH_DATA,a.buffered instanceof TimeRanges,a.buffered.length);
try{new HTMLMediaElement()}catch(e){console.log(e.name)}
HTMLMediaElement.prototype.play.call({}).catch(e=>console.log('PromiseBrand',e.name));
try{a.volume=2}catch(e){console.log(e.name)}
try{a.volume=NaN}catch(e){console.log(e.name)}
try{a.playbackRate=3}catch(e){console.log(e.name)}
try{a.buffered.start(0)}catch(e){console.log(e.name)}
a.volume=.4;a.muted=true;a.playbackRate=1.5;console.log(a.defaultMuted,a.getAttribute('muted'),a.volume,a.muted,a.playbackRate,a.canPlayType('audio/ogg'));
a.defaultMuted=true;a.defaultMuted=false;console.log(a.muted,a.defaultMuted);
var result='pending';a.play().then(()=>result='played',e=>result=e.name);]])
		pump();run([[console.log(result,a.paused,a.networkState);a.pause();]]);pump();run([[console.log(result,a.paused);]])
		expect({"true true true true AUDIO auto true 1 false 0 0 0 true true","AUDIO 3 4 true 0","TypeError","IndexSizeError","TypeError","NotSupportedError","IndexSizeError","false null 0.4 true 1.5 ","true false","PromiseBrand TypeError","pending false 0","AbortError true"})
		assert(#requests==0 and next(realm.Pending)==nil,"Detached value changes cannot allocate a load or invalidate layout");destroy()
	end
	do
		local realm,run,pump,expect,complete,destroy,requests,handles=fixture()
		run([[var a=new Audio('tone.ogg');var sequence=[];a.onplay=()=>sequence.push('play');a.onwaiting=()=>sequence.push('waiting');a.onloadedmetadata=()=>sequence.push('metadata');a.onplaying=()=>{sequence.push('playing');queueMicrotask(()=>sequence.push('playing-micro'));};a.play().then(()=>sequence.push('resolved'));console.log(a.src,a.paused,a.readyState);]])
		assert(#requests==1 and requests[1].URL=="https://audio.test/app/tone.ogg")
		complete(1);run([[console.log(sequence.join(','),a.duration,a.readyState,a.networkState,a.paused,a.currentSrc);]])
		local h=handles[1];h.Position=2
		run([[var ranges=a.played;console.log(ranges.length,ranges.start(0),ranges.end(0),a.buffered.end(0));a.play().then(()=>console.log('again'));]])
		pump();assert(h.PlayCalls==1,"Repeated play cannot restart the native Sound")
		run([[a.currentTime=5;a.volume=.25;a.muted=true;a.playbackRate=1.5;console.log(a.currentTime,a.seeking);]])
		pump();h.Position=7
		run([[console.log(a.played.length,a.played.start(1),a.played.end(1),ranges.end(0),a.seeking);a.pause();console.log(a.paused);]])
		pump()
		expect({"https://audio.test/app/tone.ogg false 0","play,waiting,metadata,playing,playing-micro,resolved 12 4 1 false https://audio.test/app/tone.ogg","1 0 2 12","again","5 true","2 5 7 2 false","true"})
		assert(h.Settings.volume==.25 and h.Settings.muted and h.Settings.playbackRate==1.5 and next(realm.Pending)==nil);destroy()
	end
	do
		local _,run,pump,expect,complete,destroy,requests,handles=fixture()
		run([[var a=new Audio('first.ogg');var first='pending',second='pending';a.play().then(()=>first='played',e=>first=e.name);a.pause();a.play().then(()=>second='played',e=>second=e.name);]])
		complete(1);run([[console.log(first,second,a.paused);a.play().then(()=>console.log('old-resolved'),e=>console.log('old',e.name));a.src='next.ogg';var next='pending';a.play().then(()=>next='played',e=>next=e.name);]])
		assert(#requests==2)
		requests[1].Handle.Notify({Kind="error",Generation=requests[1].Generation,Code=4});pump();complete(2)
		run([[console.log(next,a.currentSrc,a.error===null);a.src='missing.ogg';a.play().catch(e=>console.log('bad',e.name));]])
		complete(3,false);run([[console.log(a.error instanceof MediaError,a.error.code,a.readyState,a.networkState);a.play().catch(e=>console.log('retry',e.name));a.src='good.ogg';a.play().then(()=>console.log('recovered'));]])
		complete(4);pump()
		expect({"AbortError played false","old-resolved","played https://audio.test/app/next.ogg true","bad NotSupportedError","true 4 0 3","retry NotSupportedError","recovered"})
		assert(#handles==1,"Source changes keep one native owner");destroy()
	end
	do
		local realm,run,pump,expect,complete,destroy,requests,handles=fixture('<audio id="a" preload="none" src="tone.ogg"></audio>')
		assert(#requests==0 and realm.AudioElements.Pending==0)
		run([[var a=document.getElementById('a');a.volume=.3;a.muted=true;a.playbackRate=1.5;a.loop=true;var result='pending';a.play().then(()=>result='played');]])
		pump();assert(#requests==1 and handles[1].Settings.volume==.3 and handles[1].Settings.muted and handles[1].Settings.playbackRate==1.5 and handles[1].Settings.loop)
		complete(1);run([[console.log(result,a.paused);a.remove();a.pause();a.preload='auto';a.load();]])
		pump();assert(realm.AudioElements.Pending==0,"A detached load cannot block the document");complete(2)
		run([[console.log(a.duration,a.paused);a.currentTime=99;console.log(a.currentTime);]])
		expect({"played false","12 true","12"});destroy()
	end
	do
		local realm,run,pump,expect,complete,destroy,requests=fixture('<audio id="a" autoplay src="tone.ogg"></audio><script>window.onload=()=>console.log("window-load");</script>')
		assert(realm.AudioElements.Pending==1);run([[var a=document.getElementById('a');a.pause();console.log(document.readyState);]])
		complete(1);run([[console.log(a.paused,document.readyState);]])
		expect({"interactive","window-load","true complete"})
		run([[a.src='other.ogg';a.play().then(()=>console.log('playing'));]])
		complete(2);run([[a.currentTime=11;]]);pump()
		requests[2].Handle.Position=12;requests[2].Handle.Notify({Kind="ended",Generation=requests[2].Generation});pump()
		run([[console.log(a.ended,a.paused,a.currentTime);a.play().then(()=>console.log('restarted',a.currentTime));]])
		pump();assert(realm.AudioElements.Pending==0);destroy()
	end
	do
		local _,run,pump,expect,complete,destroy,requests=fixture('<audio id="a"><source src="missing.ogg"><source src="good.ogg"></audio>')
		assert(#requests==1 and requests[1].Raw=="good.ogg");complete(1)
		run([[var a=document.getElementById('a');console.log(a.currentSrc);a.src='';a.play().catch(e=>console.log(e.name));]])
		pump();assert(#requests==1);expect({"https://audio.test/app/good.ogg","NotSupportedError"});destroy()
	end
	do
		local _,run,pump,expect,complete,destroy,_,handles=fixture()
		run([[var a=new Audio('tone.ogg');a.defaultPlaybackRate=1.25;a.playbackRate=1.5;]])
		pump();run([[var rateChanges=0;a.onratechange=()=>rateChanges++;a.load();a.currentTime=99;]])
		complete(2);run([[console.log(a.currentTime,a.playbackRate,rateChanges);]])
		expect({'12 1.25 1'});assert(handles[1].Settings.currentTime==12 and handles[1].Settings.playbackRate==1.25);destroy()
	end
	print("JavaScript audio: real DOM identity, descriptors, native state, promises/events, races, preload, seek/ranges, failures, source changes, load lifecycle and disposal passed")
end
