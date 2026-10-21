--!strict
return function(Parser,Node,Runtime,Events,PointerCapture,fixtures)
	for _,fixture in fixtures or {}do
		local values,diagnostics={},{};local doc=Parser.parseDocument('<html><body><div id="a"></div><div id="b"></div></body></html>')
		local runtime=Runtime.new(doc,{MaxSteps=200000,Console=function(_,text)table.insert(values,text)end,Diagnostic=function(text)table.insert(diagnostics,text)end})
		runtime:Run('function record(v){console.log(String(v));}\n'..fixture.source)
		assert(#diagnostics==0,fixture.name..': '..table.concat(diagnostics,' | '));assert(#values==#fixture.expected,fixture.name..': output count')
		for i,text in values do assert(text==fixture.expected[i],fixture.name..' ['..i..'] '..text..' ~= '..fixture.expected[i])end
		runtime:Destroy()
	end
	local diagnostics={};local doc=Parser.parseDocument('<html><body><div id="a"></div><div id="b"></div></body></html>')
	local events=Events.new(error);local captures=PointerCapture.new(doc,function(node,kind,data,opts)return events:Emit(node,kind,data,opts)end)
	local runtime=Runtime.new(doc,{Events=events,PointerCaptureAdapter=captures,MaxSteps=200000,Diagnostic=function(text)table.insert(diagnostics,text)end})
	local function run(source)runtime:Run(source);assert(#diagnostics==0,table.concat(diagnostics,' | '))end
	local a,b=Node.findById(doc,'a'),Node.findById(doc,'b')
	local function data(id,buttons)return {pointerId=id,pointerType='mouse',buttons=buttons,isPrimary=true,pressure=if buttons>0 then .5 else 0,isTrusted=true,composed=true,clientX=24,clientY=30}end
	run([[const a=document.getElementById('a'),b=document.getElementById('b');globalThis.log=[];
	 a.onpointerdown=e=>{if(!(e instanceof PointerEvent)||!(e instanceof MouseEvent)||!e.isTrusted)throw new Error('Native PointerEvent');b.setPointerCapture(e.pointerId);log.push('down:'+b.hasPointerCapture(e.pointerId));};
	 b.ongotpointercapture=e=>log.push('got:'+e.pointerId);b.onpointermove=e=>log.push('move:'+e.target.id);b.onpointerup=e=>log.push('up:'+e.buttons);b.onlostpointercapture=e=>log.push('lost:'+e.pointerId);]])
	captures:Dispatch('pointerdown',a,data(1,1));captures:Dispatch('pointermove',a,data(1,1));captures:Dispatch('pointerup',a,data(1,0))
	run([[if(log.join('|')!=='down:true|got:1|move:b|up:0|lost:1')throw new Error(log.join('|'));
	 if(b.hasPointerCapture(1))throw new Error('Released pending capture');
	 function fails(fn,name){try{fn();}catch(e){if(e.name===name)return;throw e;}throw new Error('Expected '+name);}
	 fails(()=>a.setPointerCapture(99),'NotFoundError');fails(()=>a.releasePointerCapture(99),'NotFoundError');
	 fails(()=>a.setPointerCapture(),'TypeError');fails(()=>a.hasPointerCapture(Symbol()),'TypeError');fails(()=>a.hasPointerCapture(1n),'TypeError');
	 if(a.hasPointerCapture(4294967297))throw new Error('Long wraps to inactive capture');]])
	-- Native TouchLists are snapshots with one shared Touch per contact across lists.
	run([[a.ontouchmove=e=>{if(!(e instanceof TouchEvent)||!(e instanceof UIEvent)||!e.isTrusted)throw new Error('Native touch class');
	 if(e.touches.length!==2||e.targetTouches.length!==1||e.changedTouches[0]!==e.touches[0]||e.changedTouches[0].target!==a||e.touches[1].target!==b)throw new Error('Touch lists');globalThis.snapshot=e.touches;
	 e.preventDefault();};]])
	local first={identifier=2,target=a,clientX=31,clientY=32};local second={identifier=3,target=b,clientX=51,clientY=52}
	local canceled=events:Emit(a,'touchmove',{touches={first,second},targetTouches={first},changedTouches={first},isTrusted=true,composed=true},{Cancelable=true})
	assert(canceled.DefaultPrevented,'Touch cancellation reaches the native default-action adapter')
	run([[if(snapshot[0].clientX!==31||snapshot.item(8)!==null||[...snapshot].length!==2)throw new Error('Immutable native snapshot');]])
	-- Closed shadow roots retarget individual Touch targets at the listener boundary.
	run([[const host=document.createElement('div');host.id='host';document.body.append(host);const shadow=host.attachShadow({mode:'closed'});const inner=document.createElement('span');inner.id='inner';shadow.append(inner);
	 globalThis.inside=0;globalThis.outside=0;
	 inner.ontouchstart=e=>{if(e.touches[0].target!==inner||e.target!==inner)throw new Error('Inside touch target');inside++;};
	 host.ontouchstart=e=>{if(e.touches[0].target!==host||e.target!==host||e.composedPath().includes(inner))throw new Error('Closed-root touch target');outside++;};
	 const contact=new Touch({identifier:5,target:inner});inner.dispatchEvent(new TouchEvent('touchstart',{bubbles:true,composed:true,touches:[contact],targetTouches:[contact],changedTouches:[contact]}));
	 if(inside!==1||outside!==1)throw new Error('Composed touch dispatch');]])
	assert(runtime.EventLoop.TaskCount==0 and runtime.EventLoop.FrameCount==0,'Capture and touch need no idle tasks or animation frame loops')
	runtime:Destroy();captures:Destroy();events:Destroy()
	print('JavaScript pointer/touch: '..#(fixtures or {})..' native-browser fixtures, capture hooks, native event conversion, cancellation and closed-root retargeting passed')
end
