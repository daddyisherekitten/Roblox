--!strict
return function(PointerCapture,Node,EventData)
	local document=Node.document();local body=Node.element('body',{});Node.append(document,body)
	local a,b=Node.element('div',{id='a'}),Node.element('div',{id='b'});Node.append(body,a);Node.append(body,b)
	local log={};local callback
	local api=PointerCapture.new(document,function(node,kind,data,options)
		table.insert(log,{Node=node,Type=kind,Data=data,Options=options})
		return if callback then callback(node,kind,data)else {DefaultPrevented=false}
	end)
	local function data(id,kind,buttons)return {pointerId=id,pointerType=kind,buttons=buttons,isPrimary=id~=3,composed=true}end
	local function types()local out={};for _,event in log do if event.Type:find('capture')or event.Type=='pointerdown'or event.Type=='pointermove'or event.Type=='pointerup'then table.insert(out,event.Node.Attributes and event.Node.Attributes.id or '#document');table.insert(out,event.Type)end end;return table.concat(out,'|')end
	assert(api:Set(a,9)=='NotFoundError'and api:Release(a,9)=='NotFoundError'and not api:Has(a,9))
	api:Dispatch('pointermove',a,data(1,'mouse',0));assert(api:Set(b,1)==nil and not api:Has(b,1),'A hover-only pointer is active but has no active buttons to capture')
	callback=function(node,kind)if kind=='pointerdown'then assert(api:Set(b,1)==nil and api:Has(b,1));assert(not api:Record(1).Captured)end;return {DefaultPrevented=false}end
	table.clear(log);api:Dispatch('pointerdown',a,data(1,'mouse',1));callback=nil
	assert(types()=='a|pointerdown','Setting pending capture does not synchronously dispatch gotpointercapture')
	table.clear(log);local routed=api:Dispatch('pointermove',a,data(1,'mouse',1))
	assert(routed==b and types()=='b|gotpointercapture|b|pointermove','The next pointer event first commits pending capture then uses its target')
	assert(log[1].Options.Cancelable==false and log[1].Options.Bubbles and log[1].Options.Composed)
	assert(api:Release(a,1)==nil and api:Has(b,1),'Release by a different element has no effect')
	assert(api:Release(b,1)==nil and not api:Has(b,1));table.clear(log)
	api:Dispatch('pointermove',a,data(1,'mouse',1));assert(types()=='b|lostpointercapture|a|pointermove')
	api:Set(b,1);api:Dispatch('pointermove',a,data(1,'mouse',1));Node.removeChild(body,b);table.clear(log)
	api:Dispatch('pointermove',a,data(1,'mouse',1));assert(types()=='#document|lostpointercapture|a|pointermove','A removed active capture target releases at the document')
	assert(api:Set(b,1)=='InvalidStateError');Node.append(body,b)
	api:Set(b,1);api:Dispatch('pointermove',a,data(1,'mouse',1));api:BeforeRemove(b,false);Node.removeChild(body,b);Node.append(body,b);table.clear(log)
	assert(not api:Has(b,1),'Removal immediately clears pending capture even when the node is reinserted before the next native event')
	api:Dispatch('pointermove',a,data(1,'mouse',1));assert(types()=='#document|lostpointercapture|a|pointermove','Reinsertion must not revive capture cleared by ordinary removal')
	api:Set(b,1);api:Dispatch('pointermove',a,data(1,'mouse',1));api:BeforeRemove(b,true);Node.removeChild(body,b);Node.append(body,b);table.clear(log)
	assert(api:Has(b,1));api:Dispatch('pointermove',a,data(1,'mouse',1));assert(types()=='b|pointermove','A state-preserving move must keep pointer capture without got/lost events')
	api:Release(b,1);api:Dispatch('pointermove',a,data(1,'mouse',1));table.clear(log)
	local stationary=data(1,'mouse',1);stationary.clientX,stationary.clientY=11,12
	api:Refresh(b,stationary)
	assert(types()==''and log[1].Type=='pointerout'and log[1].Data.clientX==11,'A layout/scroll hit change dispatches fresh boundary coordinates without a pointermove')
	api:Set(b,1);api:Dispatch('pointermove',a,data(1,'mouse',1));table.clear(log)
	local target,_,record=api:Dispatch('pointerup',a,data(1,'mouse',0))
	assert(target==b and record.UpCapture==b and types()=='b|pointerup|b|lostpointercapture','Pointerup keeps the captured click target while implicitly releasing capture')
	assert(api:IsActive(1)and not api:Has(b,1),'A hovering mouse remains known after pointerup')
	callback=function(node,kind,d)
		if kind=='pointerdown'and d.pointerType=='touch'then assert(api:Has(node,d.pointerId),'Touch implicit capture is visible inside pointerdown')end
		return {DefaultPrevented=kind=='pointerdown'}
	end
	local _,_,first=api:Dispatch('pointerdown',a,data(2,'touch',1));local _,_,second=api:Dispatch('pointerdown',b,data(3,'touch',1));callback=nil
	assert(first.Suppressed and not second.Suppressed,'Only cancellation of the primary pointer suppresses compatibility mouse events')
	assert(api:Dispatch('pointermove',b,data(2,'touch',1))==a and api:Dispatch('pointermove',a,data(3,'touch',1))==b,'Simultaneous touch captures are independent')
	api:Dispatch('pointerup',b,data(2,'touch',0));assert(not api:IsActive(2)and api:IsActive(3))
	assert(api:Release(a,2)=='NotFoundError');api:CancelAll();assert(not api:IsActive(1)and not api:IsActive(3))
	local contact=data(4,'touch',1);contact.pressure=.65;contact.width=8;contact.clientX,contact.pageY=21,33
	api:Dispatch('pointerdown',a,contact);table.clear(log)
	local cancellation=data(4,'touch',0);cancellation.pressure=0;cancellation.width=1;cancellation.clientX,cancellation.pageY=100,200
	api:Dispatch('pointercancel',b,cancellation)
	local cancel;for _,event in log do if event.Type=='pointercancel'then cancel=event end end
	assert(cancel and cancel.Node==a and cancel.Data.pressure==.65 and cancel.Data.width==8 and cancel.Data.clientX==21 and cancel.Data.pageY==33 and not cancel.Options.Cancelable,'Cancellation preserves the last dispatched contact geometry, pressure and coordinates')
	api:Dispatch('pointermove',b,data(1,'mouse',0));api:BeforeRemove(b,false);Node.removeChild(body,b);table.clear(log)
	api:Refresh(body,data(1,'mouse',0))
	assert(#log==2 and log[1].Node==body and log[1].Type=='pointerover'and log[2].Type=='mouseover','Disconnected previous targets repair to the connected ancestor and require over without events at the detached node')
	Node.append(body,b)
	api:Destroy();assert(not api:Has(a,2))
	if EventData then
		local native=EventData.new({Root={AbsolutePosition=Vector2.new(10,20),CanvasPosition=Vector2.new(3,4)}},{IsKeyDown=function()return false end})
		local t1,t2={UserInputType=Enum.UserInputType.Touch,Position=Vector2.new(30,50)},{UserInputType=Enum.UserInputType.Touch,Position=Vector2.new(40,60)}
		local d1=native:Pointer(t1,'down');local _,start=native:Touch(t1,'down',a,d1)
		local d2=native:Pointer(t2,'down');native:Touch(t2,'down',b,d2)
		assert(d1.pointerId~=d2.pointerId and d1.isPrimary and not d2.isPrimary)
		t1.Position=Vector2.new(80,90);local move=native:Pointer(t1,'move');local original,init=native:Touch(t1,'move',b,move)
		assert(original==a and init.changedTouches[1].target==a and #init.touches==2 and #init.targetTouches==1)
		assert(init.changedTouches[1].clientX==70 and init.changedTouches[1].pageY==74 and start.changedTouches[1].clientX==20,'Touch snapshots preserve original coordinates while later positions update')
		local relocated=native:Stationary(move);assert(relocated.clientX==70 and relocated.pageY==74 and relocated.movementX==0)
		local up=native:Pointer(t1,'up');local _,ended=native:Touch(t1,'up',b,up)
		assert(#ended.touches==1 and #ended.targetTouches==0 and #ended.changedTouches==1 and ended.changedTouches[1].identifier==d1.pointerId)
		assert(not native:Pointer(t2,'move').isPrimary,'An existing secondary contact is not promoted when the primary ends')
		assert(native:Pointer(t1,'move')==nil,'A released InputObject cannot create a ghost touch')
		assert(#native:CancelTouches()==1 and native:TouchCount()==0);native:Reset()
		for _,event in {t1,t2}do local point=native:Pointer(event,'down');native:Touch(event,'down',a,point)end
		local canceled=native:CancelTouches();assert(#canceled==1 and #canceled[1].Data.changedTouches==2 and #canceled[1].Data.touches==0 and #canceled[1].Data.targetTouches==0,'A simultaneous cancellation snapshots all removed contacts before dispatch, grouped by their original target')
		assert(native:Pointer(t1,'move')==nil);native:Reset()
	end
	print('Native pointer capture: pending/active routing, implicit release, removal, independent touches and immutable touch snapshots passed')
end
