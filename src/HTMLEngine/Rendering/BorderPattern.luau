--!strict
-- Shared straight-edge paint for borders, outlines and column rules.
local Geometry=require(script.Parent.Parent.Layout.BorderGeometry)
local Pattern={}
local function write(gui,key,value)
	if gui[key]~=value then gui[key]=value end
end
function Pattern.draw(pool: any,factory: any,host: any,kind: string,length: number,thickness: number,horizontal: boolean,offset: number,colorFor: any)
	pool.Offset=offset
	if pool.Length~=length or pool.Thickness~=thickness or pool.Kind~=kind then
		pool.Length,pool.Thickness,pool.Kind=length,thickness,kind
		pool.Parts=if kind=='hidden' then {} else Geometry.pattern(kind,length,thickness)
	end
	pool.Corners=pool.Corners or {}
	for ordinal,part in pool.Parts do
		local segment=pool[ordinal]
		local color,alpha=colorFor(ordinal)
		if not segment then
			segment=factory.create('Frame',host,{Name='BorderSegment_'..ordinal})
			pool[ordinal]=segment
		end
		if kind=='dotted' and not pool.Corners[ordinal] then
			pool.Corners[ordinal]=factory.modifier('UICorner',segment,{CornerRadius=UDim.new(.5,0)})
		end
		local corner=pool.Corners[ordinal]
		if corner then write(corner,'CornerRadius',UDim.new(if kind=='dotted' then .5 else 0,0)) end
		write(segment,'Position',UDim2.fromOffset(if horizontal then part[1]-offset else part[2],if horizontal then part[2] else part[1]-offset))
		write(segment,'Size',UDim2.fromOffset(if horizontal then part[3] else part[4],if horizontal then part[4] else part[3]))
		write(segment,'BackgroundColor3',color);write(segment,'BackgroundTransparency',1-alpha)
		write(segment,'Visible',true)
	end
	for ordinal=#pool.Parts+1,#pool do write(pool[ordinal],'Visible',false) end
end
return Pattern
