--!strict
return function(Parser,Runtime,Events,VM)
	local function fixture(html,extra)
		local output,imageLoads,fontLoads,cancelled={}, {}, {}, {}
		local events=Events.new(error);local clock=0
		local options={
			URL="https://resources.test/index.html",Events=events,Clock=function()return clock end,
			Schedule=function()end,ApplyChanges=function()return false end,Console=function(_,message)table.insert(output,message)end,
			LoadImage=function(url,complete,spec)local request={URL=url,Complete=complete,Spec=spec};table.insert(imageLoads,request);return function()cancelled[request]=true end end,
			LoadFont=function(spec,complete)local request={Spec=spec,Complete=complete};table.insert(fontLoads,request);return function()cancelled[request]=true end end,
		};for key,value in extra or{}do options[key]=value end
		local realm=Runtime.new(Parser.parseDocument("<!doctype html><html><body>"..(html or"").."</body></html>"),options)
		local function run(source)local ok,message=realm:Run(source);assert(ok,tostring(message))end
		local function pump()for _=1,12 do clock+=.01;realm:PumpTasks();realm.EventLoop:Checkpoint()end end
		local function expect(values)
			assert(#output==#values,"Count: "..table.concat(output," | "))
			for index,value in values do assert(output[index]==value,"Got: "..table.concat(output," | ").." expected "..value)end
		end
		local function destroy()assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n"));realm:Destroy();events:Destroy()end
		realm:Start()
		return realm,run,pump,expect,destroy,imageLoads,fontLoads,cancelled,output
	end
	do
		local realm,run,pump,expect,destroy,images,_,cancelled=fixture('<input id="picture" type="image" src="button.png" srcset="ignored.png 1x">',{ControlAdapter={}})
		pump();assert(#images==1 and images[1].URL=="https://resources.test/button.png")
		run([[var picture=document.getElementById('picture');picture.onload=()=>console.log('button-load');picture.onerror=()=>console.log('button-error');let branded=false;try{Object.getOwnPropertyDescriptor(HTMLImageElement.prototype,'naturalWidth').get.call(picture)}catch(e){branded=e instanceof TypeError}if(!branded||picture.decode!==undefined)throw Error('Input image interface');]])
		images[1].Complete(true,{Width=480,Height=200});pump();expect({"button-load"})
		run([[picture.src='missing.png']]);images[2].Complete(false,"Missing");pump();expect({"button-load","button-error"})
		run([[picture.src='cancel.png']]);run([[picture.type='text';if(picture.getAttribute('type')!=='text')throw Error('Type setter: '+picture.type+' / '+picture.getAttribute('type'));]]);assert(#images==3,"Three input image requests expected: "..#images);assert(cancelled[images[3]],"Changing input type must cancel its image request; type="..tostring(images[3].Spec.Node.Attributes.type).." pending="..realm.ImageResources.Pending.." state="..tostring(images[3].Spec.Node.ImageResourceState and images[3].Spec.Node.ImageResourceState.Status));assert(realm.ImageResources.Pending==0,"Changed input must not block load: "..realm.ImageResources.Pending);destroy()
	end
	do
		local realm,run,pump,expect,destroy,images=fixture()
		run([[var image=new Image(30,20);console.log(image instanceof HTMLImageElement,image instanceof Image,image.complete,image.width,image.height,image.naturalWidth,image.currentSrc);
image.onload=()=>console.log('load',image.complete,image.naturalWidth,image.naturalHeight,image.currentSrc);
image.src='first.png';image.src='second.png';console.log('pending',image.complete,image.naturalWidth);
image.decode().then(()=>console.log('decoded',image.complete));]])
		assert(#images==1 and images[1].URL=="https://resources.test/second.png","Source writes coalesce at the microtask checkpoint")
		images[1].Complete(true,{Width=320,Height=180});pump()
		expect({"true true true 30 20 0 ","pending false 0","decoded true","load true 320 180 https://resources.test/second.png"})
		run([[image.src='third.png';console.log('retained',image.complete,image.naturalWidth,image.currentSrc);image.decode().catch(e=>console.log('decode-failed',e.name));]])
		images[2].Complete(false,"Not found");pump()
		assert(realm.ImageResources.Pending==0)
		destroy()
	end
	do
		local _,run,pump,expect,destroy,images,_,cancelled=fixture()
		run([[var image=new Image();image.onerror=()=>console.log('error',image.complete,image.naturalWidth);image.onload=()=>console.log('load');image.src='old.png';image.decode().catch(e=>console.log('cancelled',e.name));]])
		run([[image.src='new.png';image.decode().then(()=>console.log('decoded'));]])
		assert(cancelled[images[1]],"Changing src cancels the obsolete host request")
		images[1].Complete(true,{Width=50,Height=20});images[2].Complete(true,{Width=90,Height=40});pump()
		expect({"cancelled EncodingError","decoded","load"})
		run([[image.src='';console.log(image.complete,image.naturalWidth,image.currentSrc);image.decode().catch(e=>console.log(e.name));]])
		pump();destroy()
	end
	do
		local realm,run,pump,expect,destroy,images=fixture('<img id="initial" src="initial.png"><script>document.addEventListener("DOMContentLoaded",()=>{console.log("dcl");queueMicrotask(()=>{var late=new Image();late.src="late.png";document.body.append(late);});});window.addEventListener("load",()=>console.log("window-load"));</script>')
		realm:Start();pump();assert(#images==2 and realm.ImageResources.Pending==2)
		images[1].Complete(true,{Width=50,Height=20});pump();expect({"dcl"})
		images[2].Complete(true,{Width=80,Height=30});pump();expect({"dcl","window-load"})
		run([[var final=new Image();final.src='after-complete.png';document.body.append(final);]])
		images[3].Complete(true,{Width=10,Height=10});pump();expect({"dcl","window-load"});destroy()
	end
	do
		local realm,_,pump,expect,destroy,images=fixture('<img src="lazy.png" loading="lazy"><script>window.addEventListener("load",()=>console.log("window-load"));</script>')
		realm:Start();pump();assert(realm.ImageResources.Pending==0 and #images==1);expect({"window-load"})
		images[1].Complete(false,"Missing lazy resource");pump();destroy()
	end
	do
		local realm,run,pump,expect,destroy,_,fonts=fixture()
		run([[console.log(document.fonts.status,document.fonts.size,document.fonts.check('16px Missing'));
var face=new FontFace('Lato','local("Lato")');document.fonts.add(face);console.log(face.status,document.fonts.has(face),document.fonts.check('16px Lato'));
document.fonts.onloading=()=>console.log('loading',document.fonts.status);
document.fonts.onloadingdone=e=>console.log('done',e.fontfaces.length,document.fonts.status);
var p=face.load();console.log(p===face.loaded,face.status,document.fonts.status);face.loaded.then(f=>console.log('font-loaded',f===face));
document.fonts.ready.then(f=>console.log('ready',f===document.fonts));]])
		pump();assert(#fonts==1);fonts[1].Complete(true,{Family="Lato"});pump()
		expect({"loaded 0 true","unloaded true false","true loading loading","loading loading","font-loaded true","ready true","done 1 loaded"})
		run([[document.fonts.load('16px Lato').then(f=>console.log('match',f.length));console.log(document.fonts.check('16px Lato'),[...document.fonts].length,[...document.fonts.entries()][0][0]===face);document.fonts.load('bold 16px Lato').then(f=>{if(f[0]!==face)throw new Error('Closest weight did not select normal face');});]])
		pump();destroy()
	end
	do
		local realm,run,pump,expect,destroy,_,fonts,cancelled=fixture()
		run([[var face=new FontFace('Failure','url("failure.woff2")');document.fonts.add(face);
document.fonts.onloadingdone=e=>console.log('done',e.fontfaces.length);document.fonts.onloadingerror=e=>console.log('failed',e.fontfaces.length);
face.load().catch(e=>console.log('font-error',e.name));document.fonts.ready.then(()=>console.log('ready'));
document.fonts.load('invalid font').catch(e=>console.log('invalid',e.name));]])
		fonts[1].Complete(false,"Host decode unavailable");pump()
		expect({"invalid SyntaxError","font-error NetworkError","ready","done 0","failed 1"})
		run([[var pending=new FontFace('Cancel','local("Cancel")');pending.load().catch(()=>{});]])
		realm:Destroy();assert(cancelled[fonts[2]],"Disposal cancels font requests")
		fonts[2].Complete(true,{});destroy()
	end
	do
		local _,run,_,expect,destroy=fixture()
		run([[var a=new FontFace('A','local("Arial")'),b=new FontFace('B','local("Arial")'),c=new FontFace('C','local("Arial")');
document.fonts.add(a).add(b).add(c);var iterator=document.fonts.values();console.log(iterator.next().value===a);document.fonts.delete(a);console.log(iterator.next().value===b);
document.fonts.clear();document.fonts.add(c);console.log(iterator.next().value===c,iterator.next().done,document.fonts.size);
document.fonts.clear();document.fonts.add(a).add(b);var seen=[];document.fonts.forEach(f=>{seen.push(f.family);if(f===a){document.fonts.clear();document.fonts.add(c);}});console.log(seen.join(','));
var e=new FontFaceSetLoadEvent('loadingdone',{fontfaces:[a],bubbles:true});console.log(e instanceof Event,e instanceof FontFaceSetLoadEvent,e.fontfaces===e.fontfaces,Object.isFrozen(e.fontfaces),e.fontfaces[0]===a,e.bubbles,e.isTrusted);
try{new FontFaceSetLoadEvent('loadingdone',{fontfaces:[{}]});}catch(e){console.log(e.name);}
try{new FontFaceSet([]);}catch(e){console.log(e.name);}]])
		expect({"true","true","true true 1","A,C","true true true true true true false","TypeError","TypeError"});destroy()
	end
	do
		local requests={};local nativeLayoutPending=true
		local realm,run,pump,expect,destroy=fixture('<script src="blocking.js"></script>',{
			FontPreloadPending=true,IsFontLayoutPending=function()return nativeLayoutPending end,
			LoadScript=function(url,complete)requests[url]=complete end,
		})
		run([[var initialReady=document.fonts.ready;initialReady.then(f=>console.log('ready',document.readyState,f===document.fonts));]])
		pump();expect({})
		assert(not realm.FontLoading:NeedsEnvironmentCheck()and realm.EventLoop.TaskCount==0,"Unreleased document/font gates do not request idle environment work")
		run([[document.body.setAttribute('data-before-load','paint');]])
		assert(realm:Flush()==false and realm.EventLoop.TaskCount==0,"A DOM flush cannot schedule a font check while document loading blocks ready")
		requests["https://resources.test/blocking.js"](true,"console.log('external');");pump();expect({"external"})
		realm:FontPreloadCompleted();pump();expect({"external"})
		run([[document.body.setAttribute('data-before-layout','paint');]])
		assert(realm:Flush()==false and realm.EventLoop.TaskCount==0,"A pending native layout waits for its publication rather than scheduling a font check")
		nativeLayoutPending=false;realm:AfterLayout();expect({"external","ready complete true"})
		run([[if(initialReady!==document.fonts.ready)throw new Error('The initial pending ready promise must survive host loading');]])
		destroy()
	end
	do
		local realm,run,pump,expect,destroy=fixture();pump()
		run([[var idleReady=document.fonts.ready;idleReady.then(()=>console.log('idle-ready'));]])
		expect({"idle-ready"});assert(not realm.FontLoading:NeedsEnvironmentCheck())
		for index=1,16 do
			run("document.body.setAttribute('data-idle-paint','"..tostring(index).."');")
			assert(realm:HasPending(),"Every idle-paint regression iteration performs a real DOM mutation")
			assert(realm:Flush()==false and realm.EventLoop.TaskCount==0,"A fulfilled font-ready promise leaves DOM paint batches without font tasks")
		end
		run([[if(idleReady!==document.fonts.ready)throw new Error('Idle DOM batches must preserve the fulfilled ready promise');]])
		destroy()
	end
	do
		local realm,run,pump,expect,destroy,_,fonts=fixture();pump()
		run([[var paintFace=new FontFace('Lato','local("Lato")');document.fonts.add(paintFace);paintFace.load();document.fonts.ready.then(()=>console.log('paint-ready'));document.body.setAttribute('data-change','paint');]])
		fonts[1].Complete(true,{});pump();expect({})
		assert(realm:Flush()==false);pump();expect({"paint-ready"});destroy()
	end
	for _,skipped in {false,true}do
		local needsLayout=true
		local realm,run,pump,expect,destroy,_,fonts=fixture(nil,{
			ApplyChanges=function()return needsLayout end,
			IsFontLayoutPending=function()return false end,
		});pump()
		run([[var layoutFace=new FontFace('Lato','local("Lato")');document.fonts.add(layoutFace);layoutFace.load();var layoutReady=document.fonts.ready;layoutReady.then(()=>console.log('layout-ready'));document.body.setAttribute('data-layout','change');]])
		fonts[1].Complete(true,{});pump();expect({})
		assert(realm:Flush()==true);expect({})
		assert(not realm.FontLoading:NeedsEnvironmentCheck()and realm.EventLoop.TaskCount==0,"A reported layout blocks font-ready before the caller can set its external gate")
		needsLayout=false;run([[document.body.setAttribute('data-later-paint','change');]])
		assert(realm:Flush()==false);pump();expect({})
		assert(not realm.FontLoading:NeedsEnvironmentCheck(),"A later paint batch cannot release the earlier uncompleted layout")
		if skipped then realm:FontLayoutCompleted()else realm:AfterLayout()end
		expect({"layout-ready"});pump()
		run([[if(layoutReady!==document.fonts.ready)throw new Error('Completing layout must preserve the pending ready promise');]])
		realm:FontLayoutCompleted();assert(realm.EventLoop.TaskCount==0,"Repeated completion leaves the released font gate idle")
		destroy()
	end
	do
		local _,run,pump,expect,destroy,images=fixture()
		run([[var absent=new Image();absent.onerror=()=>console.log('unexpected');absent.decode().catch(e=>console.log('absent',e.name));
var empty=new Image();empty.onerror=()=>console.log('empty-error',empty.complete,empty.naturalWidth,empty.currentSrc);empty.src='';empty.decode().catch(e=>console.log('empty-decode',e.name));]])
		pump();expect({'absent EncodingError','empty-decode EncodingError','empty-error true 0 '});assert(#images==0)
		destroy()
	end
	do
		local _,run,pump,expect,destroy=fixture()
		run([[var image=new Image();image.onerror=()=>console.log('obsolete-error');image.src='';image.removeAttribute('src');console.log(image.complete,image.currentSrc);]])
		pump();expect({'true '});destroy()
	end
	do
		local _,run,pump,expect,destroy,images=fixture()
		run([[var image=new Image();image.onerror=()=>console.log('invalid',image.complete,image.naturalWidth,image.currentSrc);image.src='http://[bad';image.decode().catch(e=>console.log(e.name));]])
		pump();expect({'EncodingError','invalid true 0 http://[bad'});assert(#images==0);destroy()
	end
	for _,case in {
		{Message='404'}, {Message='500'}, {Message='Malformed PNG'}, {Message='Malformed SVG'}, {Message='Denied asset'}, {Message='Timeout'},
		{Success=true,Data={}}, {Success=true,Data={Width=0/0,Height=30}}, {Success=true,Data={Width=-1,Height=30}}, {Success=true,Data={Width=math.huge,Height=30}},
	}do
		local _,run,pump,expect,destroy,images=fixture()
		run([[var image=new Image(120,60);image.onerror=()=>console.log('error',image.complete,image.naturalWidth,image.naturalHeight);image.onload=()=>console.log('unexpected');image.src='broken.png';image.decode().catch(e=>console.log('decode',e.name));]])
		images[1].Complete(case.Success==true,case.Data or case.Message);images[1].Complete(true,{Width=300,Height=150});pump()
		expect({'decode EncodingError','error true 0 0'});destroy()
	end
	do
		local _,run,pump,expect,destroy,images=fixture()
		run([[var image=new Image();image.onload=()=>console.log('load',image.naturalWidth,image.naturalHeight);image.onerror=()=>console.log('error');image.src='zero.svg';image.decode().then(()=>console.log('decoded'));]])
		images[1].Complete(true,{Width=0,Height=0});pump();expect({'decoded','load 0 0'})
		run([[image.src='zero.svg';image.decode().then(()=>console.log('retried'));]])
		assert(#images==2,'Assigning the same source starts a fresh browser image request')
		images[2].Complete(true,{Width=0,Height=0});pump();expect({'decoded','load 0 0','retried','load 0 0'});destroy()
	end
	print("JavaScript resources: image metadata, decode, races, empty/invalid sources, failures, zero-sized SVG, retry, load lifecycle, font sets and disposal passed")
end
