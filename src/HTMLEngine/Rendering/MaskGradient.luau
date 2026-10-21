--!strict
-- Convert the supported one-dimensional CSS mask profile into a Roblox UIGradient.
local BorderGeometry=require(script.Parent.Parent.Layout.BorderGeometry)
local MaskGradient={}

local function interval(style: any,name: string,horizontal: boolean,total: number): (number,number)
	local top,right,bottom,left=BorderGeometry.sizes(style)
	local before,after=if horizontal then left else top,if horizontal then right else bottom
	if name=="content-box" then
		before+=(style.Padding and style.Padding[if horizontal then 4 else 1]) or 0
		after+=(style.Padding and style.Padding[if horizontal then 2 else 3]) or 0
	end
	if name=="border-box" then before,after=0,0 end
	return math.clamp(before,0,total),math.max(math.clamp(before,0,total),total-math.clamp(after,0,total))
end

function MaskGradient.sequence(style: any,mask: any,width: number?,height: number?): any
	local horizontal=mask.Rotation==0 or mask.Rotation==180
	local total=math.max(1,if horizontal then width or 1 else height or 1)
	local originName=(style.MaskOrigins and style.MaskOrigins[1]) or "border-box"
	local clipName=(style.MaskClips and style.MaskClips[1]) or "border-box"
	local originStart,originEnd=interval(style,originName,horizontal,total)
	local clipStart,clipEnd=interval(style,clipName,horizontal,total)
	local originSpan=math.max(0,originEnd-originStart)
	local size=(style.MaskSizes and style.MaskSizes[1]) or {Kind="explicit",X=false,Y=false}
	local length=horizontal and size.X or size.Y
	local maskSpan=if type(length)=="table" and length.Percent then math.clamp(length.Value/100,.02,1)*originSpan else originSpan
	maskSpan=math.max(.0001,maskSpan)
	local position=(style.MaskPositions and style.MaskPositions[1]) or {X={Anchor=0},Y={Anchor=0}}
	local axis=if horizontal then position.X else position.Y
	local start=originStart+(axis.Anchor or 0)*math.max(0,originSpan-maskSpan)
	local repeatValue=(style.MaskRepeats and style.MaskRepeats[1]) or {X="repeat",Y="repeat"}
	local repeating=(if horizontal then repeatValue.X else repeatValue.Y)~="no-repeat" and maskSpan<originSpan-.001
	local points={}
	local function add(pixel: number,value: number)
		local time=math.clamp(pixel/total,0,1)
		if #points>0 and time<=points[#points].Time then time=math.min(1,points[#points].Time+.0001) end
		if #points==0 or time<=1 then table.insert(points,{Time=time,Value=1-math.clamp(value,0,1)}) end
	end
	if clipStart>0 then add(0,0);add(math.max(0,clipStart-.001),0) end
	local drawStart,drawEnd=math.max(start,clipStart),math.min(start+maskSpan,clipEnd)
	if repeating then
		local cursor=start-math.ceil(math.max(0,start-originStart)/maskSpan)*maskSpan
		local cycles=0
		while cursor<clipEnd and cycles<16 do
			local a,b=math.max(clipStart,cursor),math.min(clipEnd,cursor+maskSpan)
			if b>=a then
				add(a,mask.StartAlpha+(mask.EndAlpha-mask.StartAlpha)*math.clamp((a-cursor)/maskSpan,0,1))
				add(b,mask.StartAlpha+(mask.EndAlpha-mask.StartAlpha)*math.clamp((b-cursor)/maskSpan,0,1))
			end
			cursor+=maskSpan;cycles+=1
		end
	elseif drawEnd>=drawStart then
		if drawStart>clipStart then add(clipStart,0);add(math.max(clipStart,drawStart-.001),0) end
		add(drawStart,mask.StartAlpha+(mask.EndAlpha-mask.StartAlpha)*math.clamp((drawStart-start)/maskSpan,0,1))
		add(drawEnd,mask.StartAlpha+(mask.EndAlpha-mask.StartAlpha)*math.clamp((drawEnd-start)/maskSpan,0,1))
		if drawEnd<clipEnd then add(math.min(clipEnd,drawEnd+.001),0);add(clipEnd,0) end
	end
	if clipEnd<total then add(math.min(total,clipEnd+.001),0);add(total,0) end
	if #points==0 then add(0,0);add(total,0) elseif points[1].Time>0 then table.insert(points,1,{Time=0,Value=points[1].Value}) end
	if points[#points].Time<1 then table.insert(points,{Time=1,Value=points[#points].Value}) end
	local ok,sequence=pcall(function()
		local keypoints={};for _,point in points do table.insert(keypoints,NumberSequenceKeypoint.new(point.Time,point.Value)) end
		return NumberSequence.new(keypoints)
	end)
	return if ok then sequence else points
end

function MaskGradient.update(box: any,width: number,height: number)
	if not box.OpacityGroup or not box.OpacityGroup.Mask or not box.MaskDefinition then return end
	box.OpacityGroup.Mask.Transparency=MaskGradient.sequence(box.Style,box.MaskDefinition,width,height)
end

-- A horizontal UIGradient cannot crop the perpendicular axis. Clip the
-- composited descendants in both dimensions, retaining border-box coordinates.
function MaskGradient.clip(box: any,bounds: any)
	local group=box.OpacityGroup
	if not group or not group.MaskClip then return end
	if not box.MaskDefinition or box.MaskDefinition.Kind~='linear'then
		group.MaskClip.ClipsDescendants=false;group.MaskClip.Position=UDim2.fromOffset(0,0);group.Content.Position=UDim2.fromOffset(-math.floor(bounds[1]),-math.floor(bounds[2]));return
	end
	group.MaskClip.ClipsDescendants=true
	local width,height=box.OuterWidth or 0,box.OuterHeight or 0
	local name=(box.Style.MaskClips and box.Style.MaskClips[1]) or "border-box"
	local x,right=interval(box.Style,name,true,width)
	local y,bottom=interval(box.Style,name,false,height)
	group.MaskClip.Position=UDim2.fromOffset(x-math.floor(bounds[1]),y-math.floor(bounds[2]))
	group.MaskClip.Size=UDim2.fromOffset(math.max(0,right-x),math.max(0,bottom-y))
	group.Content.Position=UDim2.fromOffset(-x,-y)
end

return MaskGradient
