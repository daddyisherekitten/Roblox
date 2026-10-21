--!strict
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local CornerRadii={}
local PROPERTIES={"TopLeftRadius","TopRightRadius","BottomRightRadius","BottomLeftRadius"}

-- UICorner supports independent circular corners, but CSS also permits an
-- independent horizontal and vertical radius. Keep those elliptical cases on
-- the raster path, as well as cases where UICorner cannot clip the contents.
function CornerRadii.native(style: any): boolean
	if style.CornerShape and style.CornerShape~="round" then return false end
	if not style.BorderRadii or style.BorderRadius~=0 or style.BorderUniform==false then return false end
	if style.BorderStyle~="solid" and style.BorderStyle~="none" then return false end
	if style.OverflowX=="hidden" or style.OverflowY=="hidden" or style.OverflowX=="scroll" or style.OverflowY=="scroll" then return false end
	for _,image in style.BackgroundImages or {} do if image.Kind~="none" then return false end end
	for _,corner in style.BorderRadii do
		if corner.X.Percent or corner.Y.Percent or corner.X.Value~=corner.Y.Value then return false end
	end
	return #style.BorderRadii==4
end

function CornerRadii.resolve(style: any,width: number,height: number): any?
	local result={}
	for index,corner in style.BorderRadii or {} do
		result[index]={math.max(0,LengthExpression.resolve(corner.X,width)),math.max(0,LengthExpression.resolve(corner.Y,height))}
	end
	if #result~=4 then return nil end
	local factor=math.min(1,
		width/math.max(1,result[1][1]+result[2][1]),width/math.max(1,result[4][1]+result[3][1]),
		height/math.max(1,result[1][2]+result[4][2]),height/math.max(1,result[2][2]+result[3][2]))
	for _,corner in result do corner[1]*=factor;corner[2]*=factor end
	return result
end

function CornerRadii.apply(corner: any,resolved: any)
	for index,property in PROPERTIES do
		local value=UDim.new(0,math.min(resolved[index][1],resolved[index][2]))
		if corner[property]~=value then corner[property]=value end
	end
end

return CornerRadii
