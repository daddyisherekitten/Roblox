--!strict
-- Extracted from haha.rbxmx: cascadePosition, Resize.apply, Snap.zoneAt/rectFor.
-- No Windows10 theme, layers, animation, desktop or taskbar dependency.
local Geometry={}
function Geometry.cascadePosition(index,size,area)
	local x=math.round((area.X-size.X)/2)+8;local y=math.round((area.Y-size.Y)/2)+7
	local step=index*22;if x+step+size.X>area.X or y+step+size.Y>area.Y then step=0 end
	return Vector2.new(math.max(0,x+step),math.max(0,y+step))
end
function Geometry.resize(position,size,dx,dy,delta,minimum)
	local x,y,w,h=position.X,position.Y,size.X,size.Y
	if dx==1 then w=math.max(size.X+delta.X,minimum.X)
	elseif dx==-1 then w=math.max(size.X-delta.X,minimum.X);x=position.X+size.X-w end
	if dy==1 then h=math.max(size.Y+delta.Y,minimum.Y)
	elseif dy==-1 then h=math.max(size.Y-delta.Y,minimum.Y);y=position.Y+size.Y-h end
	return Vector2.new(x,y),Vector2.new(w,h)
end
function Geometry.zoneAt(pointer,area,threshold)
	local top=pointer.Y<=area.Y/6;local bottom=pointer.Y>=area.Y*5/6
	if pointer.X<=threshold then return if top then 'topLeft'elseif bottom then 'bottomLeft'else 'left' end
	if pointer.X>=area.X-threshold then return if top then 'topRight'elseif bottom then 'bottomRight'else 'right' end
	if pointer.Y<=threshold then return 'maximize'end
	return nil
end
function Geometry.rectFor(zone,area)
	local halfX,halfY=math.floor(area.X/2),math.floor(area.Y/2)
	if zone=='maximize'then return Vector2.new(0,0),area end
	if zone=='left'then return Vector2.new(0,0),Vector2.new(halfX,area.Y)end
	if zone=='right'then return Vector2.new(halfX,0),Vector2.new(area.X-halfX,area.Y)end
	if zone=='topLeft'then return Vector2.new(0,0),Vector2.new(halfX,halfY)end
	if zone=='topRight'then return Vector2.new(halfX,0),Vector2.new(area.X-halfX,halfY)end
	if zone=='bottomLeft'then return Vector2.new(0,halfY),Vector2.new(halfX,area.Y-halfY)end
	if zone=='bottomRight'then return Vector2.new(halfX,halfY),Vector2.new(area.X-halfX,area.Y-halfY)end
	return nil,nil
end
function Geometry.fit(position,size,minimum,area)
	local w=math.clamp(size.X,math.min(minimum.X,area.X),area.X)
	local h=math.clamp(size.Y,math.min(minimum.Y,area.Y),area.Y)
	return Vector2.new(math.clamp(position.X,0,math.max(0,area.X-w)),math.clamp(position.Y,0,math.max(0,area.Y-h))),Vector2.new(w,h)
end
return Geometry
