--!strict
-- InputObject.Position already accounts for GUI inset (Roblox InputObject docs).
-- Translate it into the HTML viewport used by ScriptGeometry.
local EventData={}
local KEYS={Return="Enter",KeypadEnter="Enter",Space=" ",Left="ArrowLeft",Right="ArrowRight",Up="ArrowUp",Down="ArrowDown",Escape="Escape",Backspace="Backspace",Delete="Delete",Tab="Tab",Home="Home",End="End",PageUp="PageUp",PageDown="PageDown",Insert="Insert",LeftShift="Shift",RightShift="Shift",LeftControl="Control",RightControl="Control",LeftAlt="Alt",RightAlt="Alt",LeftMeta="Meta",RightMeta="Meta",CapsLock="CapsLock"}
function EventData.new(page: any,input: any): any
	local buttons,touches,keys=0,{},{};local touchPoints={};local sequence,primary=1,nil;local api={}
	local function held(name)
		return input.IsKeyDown~=nil and input:IsKeyDown(Enum.KeyCode[name])==true
	end
	local function modifiers()
		return {altKey=held("LeftAlt") or held("RightAlt"),ctrlKey=held("LeftControl") or held("RightControl"),metaKey=held("LeftMeta") or held("RightMeta"),shiftKey=held("LeftShift") or held("RightShift"),isTrusted=true,composed=true}
	end
	function api:Pointer(event: any,phase: string): any
		local value=modifiers();local kind=event.UserInputType
		local touch=kind==Enum.UserInputType.Touch
		local button=if kind==Enum.UserInputType.MouseButton1 then 0 elseif kind==Enum.UserInputType.MouseButton2 then 2 elseif kind==Enum.UserInputType.MouseButton3 then 1 elseif touch then 0 else -1
		local bit=if button==0 then 1 elseif button==1 then 4 elseif button==2 then 2 else 0
		value.previousButtons=buttons
		if not touch then if phase=="down" then buttons=bit32.bor(buttons,bit) elseif phase=="up" then buttons=bit32.band(buttons,bit32.bnot(bit))elseif phase=="cancel"then buttons=0 end end
		local position=event.Position;local origin=page.Root and page.Root.AbsolutePosition
		value.screenX,value.screenY=if position then position.X else 0,if position then position.Y else 0
		value.clientX,value.clientY=value.screenX-(if origin then origin.X else 0),value.screenY-(if origin then origin.Y else 0)
		local scroll=page.Root and page.Root.CanvasPosition
		value.pageX,value.pageY=value.clientX+(if scroll then scroll.X else 0),value.clientY+(if scroll then scroll.Y else 0)
		local delta=event.Delta
		value.movementX,value.movementY=if delta then delta.X else 0,if delta then delta.Y else 0
		if touch then
			local id=touches[event]
			if not id then
				if phase~="down"then return nil end
				local first=next(touches)==nil;sequence+=1;id=sequence;touches[event]=id;if first then primary=id end
			end
			value.pointerId,value.pointerType,value.isPrimary=id,"touch",id==primary
			value.buttons=if phase=="up"or phase=="cancel" then 0 else 1
			if phase=="up"or phase=="cancel" then touches[event]=nil;if id==primary then primary=nil end end
		else value.pointerId,value.pointerType,value.isPrimary=1,"mouse",true;value.buttons=buttons end
		value.button=if phase=="move" then -1 else button
		value.width,value.height,value.pressure=1,1,if value.buttons~=0 then .5 else 0
		value.detail=if phase=="click" then 1 else 0
		return value
	end
	function api:Touch(event,phase,target,data)
		local previous=touchPoints[event]
		if phase=="down"then if not target or target.Kind~="Element"then return nil end
		elseif not previous then return nil end
		local point={identifier=data.pointerId,target=if previous then previous.target else target}
		for _,key in {"screenX","screenY","clientX","clientY","pageX","pageY"}do point[key]=data[key]end
		-- Roblox exposes no contact ellipse/force. Touch defaults are zero;
		-- PointerEvent separately uses its specified unknown-pressure fallback.
		touchPoints[event]=if phase=="up"or phase=="cancel"then nil else point
		local values=modifiers();values.touches={};values.targetTouches={};values.changedTouches={point}
		for _,active in touchPoints do table.insert(values.touches,active);if active.target==point.target then table.insert(values.targetTouches,active)end end
		table.sort(values.touches,function(a,b)return a.identifier<b.identifier end)
		table.sort(values.targetTouches,function(a,b)return a.identifier<b.identifier end)
		return point.target,values
	end
	function api:Stationary(previous)
		local data=table.clone(previous);local origin=page.Root and page.Root.AbsolutePosition;local scroll=page.Root and page.Root.CanvasPosition
		data.clientX,data.clientY=data.screenX-(if origin then origin.X else 0),data.screenY-(if origin then origin.Y else 0)
		data.pageX,data.pageY=data.clientX+(if scroll then scroll.X else 0),data.clientY+(if scroll then scroll.Y else 0)
		data.button,data.movementX,data.movementY=-1,0,0
		return data
	end
	function api:Wheel(event)
		local data=self:Pointer(event,"move")
		-- InputObject supplies wheel notches, not OS pixel distances. Express the
		-- engine's three-line mapping in WheelEvent's standard line unit.
		local notch=event.Position and event.Position.Z or event.Delta and event.Delta.Z or 0
		data.deltaX,data.deltaY,data.deltaZ,data.deltaMode=0,-3*notch,0,1
		return data
	end
	function api:TouchCount()local count=0;for _ in touchPoints do count+=1 end;return count end
	function api:CancelTouches()
		local values,groups={},{}
		for _,point in touchPoints do
			local group=groups[point.target]
			if not group then local data=modifiers();data.touches={};data.targetTouches={};data.changedTouches={};group={Target=point.target,Data=data};groups[point.target]=group;table.insert(values,group)end
			table.insert(group.Data.changedTouches,point)
		end
		table.clear(touchPoints);table.clear(touches);primary=nil
		for _,group in values do table.sort(group.Data.changedTouches,function(a,b)return a.identifier<b.identifier end)end
		table.sort(values,function(a,b)return a.Data.changedTouches[1].identifier<b.Data.changedTouches[1].identifier end)
		return values
	end
	function api:Keyboard(event: any,phase: string): any
		local value=modifiers();local native=event.KeyCode;local name=native and native.Name or "Unknown"
		local code=native and native.Value;local key=KEYS[name]
		if not key and input.GetStringForKeyCode then key=input:GetStringForKeyCode(native) end
		if not key or key=="" then key=if name:match("^F%d+$")then name else "Unidentified" end
		if #key==1 and key:match("%a") then key=if value.shiftKey then key:upper() else key:lower() end
		value.key=key
		value.code=if name:match("^[A-Z]$")then "Key"..name elseif type(code)=="number" and code>=48 and code<=57 then "Digit"..string.char(code) elseif name=="Return"then "Enter" elseif name=="Space"then "Space" elseif name=="Left"or name=="Right"or name=="Up"or name=="Down"then "Arrow"..name elseif name:sub(1,4)=="Left"then name:sub(5).."Left" elseif name:sub(1,5)=="Right"then name:sub(6).."Right" else name
		value.location=if name:sub(1,4)=="Left" and #name>4 then 1 elseif name:sub(1,5)=="Right" and #name>5 then 2 elseif name:sub(1,6)=="Keypad"then 3 else 0
		value["repeat"]=phase=="down" and keys[native]==true
		if native then keys[native]=if phase=="down" then true else nil end
		value.isComposing=false
		return value
	end
	function api:Reset()buttons=0;primary=nil;table.clear(touches);table.clear(touchPoints);table.clear(keys)end
	return api
end
return EventData
