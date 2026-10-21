--!strict
local Range=require(script.Parent.Parent.Controls.RangeValue)
local RangeView=require(script.Parent.Parent.Controls.RangeView)
local Drag={}
function Drag.new(model: any,alive: any): any
	local active,pointer,initial,offset=nil,nil,"",0
	local drag={}
	local function update(position: any)
		if not active or not alive() then return end
		local x,_,travel,diameter=RangeView.geometry(active.Item)
		if travel <= 0 then return end
		local localX=position.X-active.Item.BoxGui.AbsolutePosition.X-x-diameter/2-offset
		model:SetValue(active,Range.at(active.Range,localX/travel),true)
	end
	function drag:Begin(c: any,event: any)
		if c.Type ~= "range" or c.Disabled or not alive() then return end
		active,pointer,initial,offset=c,event,c.Value,0
		local x,_,travel,diameter=RangeView.geometry(c.Item)
		local center=c.Item.BoxGui.AbsolutePosition.X+x+diameter/2+travel*Range.ratio(c)
		local delta=event.Position.X-center
		-- Grabbing the edge of the thumb must not move its center on pointer-down.
		if math.abs(delta) <= diameter/2 then offset=delta end
		update(event.Position)
	end
	function drag:Move(event: any): boolean
		if not active then return false end
		if event == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1 and event.UserInputType == Enum.UserInputType.MouseMovement) then update(event.Position) end
		return true
	end
	function drag:Finish(event: any?): boolean
		if not active then return false end
		if event then update(event.Position) end
		local c,before=active,initial
		active,pointer=nil,nil
		if alive() and not c.Disabled and c.Value ~= before then model:Emit(c,"change",{Value=c.Value}) end
		return true
	end
	function drag:Cancel(c:any?):boolean
		if not active or c and active~=c then return false end
		active,pointer=nil,nil;return true
	end
	return drag
end
return Drag
