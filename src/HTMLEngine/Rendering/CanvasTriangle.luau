--!strict
--!optimize 2
--!native
-- Shared bounded CPU triangle rasterizer for the WebGL and WebGPU subsets.
local Triangle={}
local function byte(value: number): number return math.clamp(math.round(value*255),0,255)end
function Triangle.clear(surface: any,r: number,g: number,b: number,a: number)
	local red,green,blue,alpha=byte(r),byte(g),byte(b),byte(a);local pixels=surface.Pixels;local checkpoint=surface.Checkpoint
	local packed=red+green*256+blue*65536+alpha*16777216
	for y=0,surface.Height-1 do if checkpoint then checkpoint()end;local first=y*surface.Width*4;for offset=first,first+surface.Width*4-4,4 do buffer.writeu32(pixels,offset,packed)end end
	if surface.MarkDirty then surface:MarkDirty(0,0,surface.Width-1,surface.Height-1)else surface.Dirty=true end
end
local function edge(a,b,x,y)return(b.X-a.X)*(y-a.Y)-(b.Y-a.Y)*(x-a.X)end
function Triangle.draw(surface: any,a: any,b: any,c: any)
	local area=edge(a,b,c.X,c.Y);if math.abs(area)<1e-8 then return end
	local left=math.max(0,math.floor(math.min(a.X,b.X,c.X)));local right=math.min(surface.Width-1,math.ceil(math.max(a.X,b.X,c.X)))
	local top=math.max(0,math.floor(math.min(a.Y,b.Y,c.Y)));local bottom=math.min(surface.Height-1,math.ceil(math.max(a.Y,b.Y,c.Y)));if right<left or bottom<top then return end
	local pixels=surface.Pixels;local inverseArea=1/area;local checkpoint=surface.Checkpoint
	local stepAX,stepAY=b.Y-c.Y,c.X-b.X;local stepBX,stepBY=c.Y-a.Y,a.X-c.X
	local rowA=edge(b,c,left+.5,top+.5);local rowB=edge(c,a,left+.5,top+.5)
	for y=top,bottom do if checkpoint then checkpoint()end;local edgeA,edgeB=rowA,rowB;for x=left,right do
		local wa,wb=edgeA*inverseArea,edgeB*inverseArea;local wc=1-wa-wb
		if wa>=-1e-7 and wb>=-1e-7 and wc>=-1e-7 then
			local offset=(y*surface.Width+x)*4;buffer.writeu8(pixels,offset,byte(wa*a.R+wb*b.R+wc*c.R));buffer.writeu8(pixels,offset+1,byte(wa*a.G+wb*b.G+wc*c.G));buffer.writeu8(pixels,offset+2,byte(wa*a.B+wb*b.B+wc*c.B));buffer.writeu8(pixels,offset+3,byte(wa*a.A+wb*b.A+wc*c.A))
		end
		edgeA+=stepAX;edgeB+=stepBX
	end;rowA+=stepAY;rowB+=stepBY end
	if surface.MarkDirty then surface:MarkDirty(left,top,right,bottom)else surface.Dirty=true end
end
return Triangle
