--!strict
--!optimize 2
--!native
-- CSS filter functions operate on unpremultiplied sRGB channels. Clamp after
-- each function, retain float precision through the chain, quantize on output.
local Pixels={}
local function matrix(step: any): any
	local n,v=step.Name,step.Value
	local m={1,0,0,0,1,0,0,0,1,0,1}
	if n=="opacity" then m[11]=v
	elseif n=="brightness" then m[1],m[5],m[9]=v,v,v
	elseif n=="contrast" then m[1],m[5],m[9],m[10]=v,v,v,.5*(1-v)
	elseif n=="invert" then m[1],m[5],m[9],m[10]=1-2*v,1-2*v,1-2*v,v
	elseif n=="sepia" then
		m={1-.607*v,.769*v,.189*v,.349*v,1-.314*v,.168*v,.272*v,.534*v,1-.869*v,0,1}
	elseif n=="grayscale" or n=="saturate" then
		local s=if n=="grayscale" then 1-v else v
		local r,g,b=.2126*(1-s),.7152*(1-s),.0722*(1-s)
		m={r+s,g,b,r,g+s,b,r,g,b+s,0,1}
	elseif n=="hue-rotate" then
		local c,s=math.cos(math.rad(v%360)),math.sin(math.rad(v%360))
		m={.213+.787*c-.213*s,.715-.715*c-.715*s,.072-.072*c+.928*s,
			.213-.213*c+.143*s,.715+.285*c+.140*s,.072-.072*c-.283*s,
			.213-.213*c-.787*s,.715-.715*c+.715*s,.072+.928*c+.072*s,0,1}
	end
	return m
end
function Pixels.render(source: buffer, filter: any, checkpoint: (() -> boolean)?): buffer?
	assert(buffer.len(source)%4==0,"Invalid RGBA buffer")
	local matrices={}
	for _,step in filter.Steps do table.insert(matrices,matrix(step)) end
	local output=buffer.create(buffer.len(source))
	for offset=0,buffer.len(source)-4,4 do
		if checkpoint and offset%8192==0 and not checkpoint() then return nil end
		local r,g,b,a=buffer.readu8(source,offset)/255,buffer.readu8(source,offset+1)/255,buffer.readu8(source,offset+2)/255,buffer.readu8(source,offset+3)/255
		for _,m in matrices do
			r,g,b=math.clamp(m[1]*r+m[2]*g+m[3]*b+m[10],0,1),math.clamp(m[4]*r+m[5]*g+m[6]*b+m[10],0,1),math.clamp(m[7]*r+m[8]*g+m[9]*b+m[10],0,1)
			a*=m[11]
		end
		buffer.writeu8(output,offset,math.floor(r*255+.5)); buffer.writeu8(output,offset+1,math.floor(g*255+.5))
		buffer.writeu8(output,offset+2,math.floor(b*255+.5)); buffer.writeu8(output,offset+3,math.floor(a*255+.5))
	end
	return output
end
Pixels.matrix=matrix
return Pixels
