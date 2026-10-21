--!strict
-- Keep initial texture submission bounded without changing the pixel buffer.
local WorkContext=require(script.Parent.Parent.WorkContext)
local TextureUpload={}
function TextureUpload.write(image: any,size: any,bytes: buffer,current: (() -> boolean)?,submitted: any?,clock: any?,bands: boolean?): boolean
	local now=clock or os.clock
	local width,height=size.X,size.Y
	local rows=if bands~=false and WorkContext.budget()then math.max(1,math.floor(65536/(width*4)))else height
	local scratch
	for y=0,height-1,rows do
		WorkContext.checkpoint()
		if current and not current()then return false end
		local bandHeight=math.min(rows,height-y)
		local pixels=bytes
		if bandHeight~=height then
			local count=width*bandHeight*4
			if not scratch or buffer.len(scratch)~=count then scratch=buffer.create(count)end
			buffer.copy(scratch,0,bytes,y*width*4,count);pixels=scratch
		end
		local before=if submitted then now()else 0
		image:WritePixelsBuffer(Vector2.new(0,y),if bandHeight==height then size else Vector2.new(width,bandHeight),pixels)
		if submitted then submitted((now()-before)*1000)end
	end
	WorkContext.checkpoint()
	return not current or current()
end
return TextureUpload
