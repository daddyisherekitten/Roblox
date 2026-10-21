--!strict
-- Pending capture is processed before the next native pointer event, never by
-- a frame loop. DOM removal releases capture at the document on that event.
local PointerCapture={}
local CANCEL_SNAPSHOT={"width","height","pressure","tangentialPressure","tiltX","tiltY","twist","altitudeAngle","azimuthAngle","pointerType","isPrimary","screenX","screenY","clientX","clientY","pageX","pageY","movementX","movementY"}
local function parent(node)return node.Parent or (if node.Kind=="ShadowRoot"then node.Host else nil)end
function PointerCapture.new(document,emit)
	local api={Alive=true};local pointers={}
	local function connected(node)
		while node and node~=document do node=parent(node)end;return node==document
	end
	local function fire(node,kind,data,cancelable,bubbles,composed)
		if not api.Alive or not node then return nil end
		local record=pointers[data.pointerId];if record and kind:find("pointer",1,true)then record.LastData=table.clone(data)end
		return emit(node,kind,data,{Cancelable=cancelable==true,Bubbles=bubbles~=false,Composed=composed~=false})
	end
	local function process(record,data)
		if record.Pending and not connected(record.Pending)then record.Pending=nil end
		if record.Captured and not connected(record.Captured)then record.Captured=document end
		local pending=record.Pending;local captured=record.Captured
		if captured==pending then return end
		-- Listener mutations affect the next processing pass, not this snapshot.
		record.Captured=nil
		if captured then fire(captured,"lostpointercapture",data,false)end
		if not api.Alive then return end
		if pending and connected(pending)then record.Captured=pending;fire(pending,"gotpointercapture",data,false)end
	end
	local function boundary(record,target,data)
		local old=record.Over
		if old==target then
			if record.NeedsOver and target then local to=table.clone(data);to.relatedTarget=nil;record.NeedsOver=false;fire(target,"pointerover",to,true);if data.pointerType=="mouse"then fire(target,"mouseover",to,true)end end
			return
		end
		record.Over=target;record.NeedsOver=false
		local from=table.clone(data);from.relatedTarget=target
		local to=table.clone(data);to.relatedTarget=old
		local oldPath,newPath={},{};local n=old
		while n do oldPath[n]=true;n=parent(n)end;n=target
		while n do newPath[n]=true;n=parent(n)end
		if old then
			fire(old,"pointerout",from,true)
			n=old;while n and not newPath[n]do fire(n,"pointerleave",from,false,false,false);n=parent(n)end
			if data.pointerType=="mouse"then
				fire(old,"mouseout",from,true)
				n=old;while n and not newPath[n]do fire(n,"mouseleave",from,false,false,false);n=parent(n)end
			end
		end
		if target then
			fire(target,"pointerover",to,true)
			local enters={};n=target;while n and not oldPath[n]do table.insert(enters,n);n=parent(n)end
			for i=#enters,1,-1 do fire(enters[i],"pointerenter",to,false,false,false)end
			if data.pointerType=="mouse"then fire(target,"mouseover",to,true);for i=#enters,1,-1 do fire(enters[i],"mouseenter",to,false,false,false)end end
		end
	end
	function api:IsActive(id)return self.Alive and pointers[id]~=nil end
	function api:Has(node,id)local record=pointers[id];return self.Alive and record~=nil and record.Pending==node end
	function api:Set(node,id)
		local record=pointers[id];if not record then return "NotFoundError"end
		if not connected(node)then return "InvalidStateError"end
		if record.Data.buttons~=0 then record.Pending=node end
	end
	function api:Release(node,id)
		local record=pointers[id];if not record then return "NotFoundError"end
		if record.Pending==node then record.Pending=nil end
	end
	function api:Record(id)return pointers[id]end
	function api:BeforeRemove(root,preservingMove)
		if not self.Alive or preservingMove then return end
		local function within(node)
			while node do if node==root then return true end;node=parent(node)end
			return false
		end
		for _,record in pointers do
			if record.Pending and within(record.Pending)then record.Pending=nil end
			if record.Captured and within(record.Captured)then record.Captured=document end
			if record.Over and within(record.Over)then record.Over=parent(root);record.NeedsOver=true end
		end
	end
	function api:Refresh(physical,data)
		local record=self.Alive and pointers[data.pointerId]
		if not record or data.pointerType~="mouse"then return physical end
		record.Data=data;process(record,data)
		local target=record.Captured or physical;boundary(record,target,data)
		return target
	end
	function api:Dispatch(kind,physical,data)
		if not self.Alive then return physical,nil end
		local id=data.pointerId;local record=pointers[id]
		if not record then
			if data.pointerType=="touch"and kind~="pointerdown"then return nil,nil end
			assert(next(pointers)==nil or (function()local count=0;for _ in pointers do count+=1 end;return count<64 end)(),"Native pointer session budget exceeded")
			record={Data=data,Suppressed=false};pointers[id]=record
		end
		if kind=="pointercancel"then
			-- Cancel snapshots the last dispatched contact, including pressure;
			-- a later host Cancel position is not a new pointer movement.
			local last=record.LastData or record.Data;data=table.clone(data)
			for _,key in CANCEL_SNAPSHOT do data[key]=last[key]end
		end
		record.Data=data;process(record,data)
		if kind=="pointerdown"then
			record.Down=physical;record.Suppressed=false;record.CancelClick=false;record.UpCapture=nil
		end
		local target=record.Captured or physical
		if kind~="pointercancel"then boundary(record,target,data)end
		if kind=="pointerdown"and data.pointerType=="touch"and physical and physical.Kind=="Element"then record.Pending=physical end
		local event=fire(target,kind,data,kind~="pointercancel")
		if kind=="pointerdown"and data.isPrimary then record.Suppressed=event and event.DefaultPrevented==true or false end
		if kind=="pointerup"or kind=="pointercancel"then
			if kind=="pointercancel"then boundary(record,nil,data)end
			record.UpCapture=record.Captured;record.Pending=nil;process(record,data)
			if data.pointerType=="touch"or kind=="pointercancel"then boundary(record,nil,data);pointers[id]=nil
			else boundary(record,physical,data)end
		end
		return target,event,record
	end
	function api:CancelAll()
		local snapshot=table.clone(pointers)
		for id,record in snapshot do if pointers[id]==record then
			local data=table.clone(record.Data);data.buttons=0
			if record.Data.buttons~=0 then self:Dispatch("pointercancel",record.Over,data)
			else boundary(record,nil,data);pointers[id]=nil end
		end end
	end
	function api:Destroy()self.Alive=false;table.clear(pointers)end
	return api
end
return PointerCapture
