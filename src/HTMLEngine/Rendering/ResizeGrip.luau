--!strict
local Grip={Size=12,Color=Color3.fromRGB(102,102,102)}
local points={}
for i=0,6 do table.insert(points,table.freeze({4+i,10-i})) end
for i=0,2 do table.insert(points,table.freeze({8+i,10-i})) end
Grip.Points=table.freeze(points)
function Grip.new(diagnostic: any,createImage: any?): any
	local image,content=nil,nil
	local alive,attempted=true,false
	local cache={}
	function cache:Get(): any?
		if not alive or attempted then return content end
		attempted=true
		local ok,result=pcall(function()
			local size=Vector2.new(12,12)
			image=if createImage then createImage(size) else game:GetService("AssetService"):CreateEditableImage({Size=size})
			assert(image,"EditableImage allocation unavailable")
			if not alive then return nil end
			local pixels=buffer.create(12*12*4)
			for _,point in points do
				local offset=(point[2]*12+point[1])*4
				for channel=0,2 do buffer.writeu8(pixels,offset+channel,102) end
				buffer.writeu8(pixels,offset+3,255)
			end
			image:WritePixelsBuffer(Vector2.new(0,0),size,pixels)
			if not alive then return nil end
			return Content.fromObject(image)
		end)
		if not alive then
			if image then image:Destroy(); image=nil end
			return nil
		end
		if not ok then
			if image then image:Destroy(); image=nil end
			diagnostic("Textarea resize grip: "..tostring(result).."; using pixel frames.")
			return nil
		end
		content=result
		return content
	end
	function cache:Destroy()
		alive=false
		if image then image:Destroy(); image=nil end
		content=nil
	end
	return cache
end
return Grip
