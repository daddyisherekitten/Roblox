--!strict
local WorkContext=require(script.Parent.Parent.WorkContext)
local Stroke={}
-- Standard SVG caps and joins; the miter limit falls back to a bevel.
-- Separate consistently wound pieces form a union under nonzero filling.
function Stroke.build(points: any,closed: boolean,width: number,options: any?): any
	options=options or {}
	local cap,join,limit=options.LineCap or 'butt',options.LineJoin or 'miter',options.MiterLimit or 4
	local clean={}
	for _,p in points do local last=clean[#clean];if not last or last[1]~=p[1] or last[2]~=p[2] then table.insert(clean,p) end end
	if closed and #clean>1 and clean[1][1]==clean[#clean][1] and clean[1][2]==clean[#clean][2] then table.remove(clean) end
	if #clean==0 or width<=0 then return {} end
	local contours,normals={},{}
	local vertices=0
	local half=width/2
	local function add(polygon: any)
		WorkContext.checkpoint()
		vertices+=#polygon;assert(vertices<=262144,'SVG stroke vertex budget exceeded')
		local area=0;for i,p in polygon do local q=polygon[i%#polygon+1];area+=p[1]*q[2]-q[1]*p[2] end
		if area<0 then local reversed={};for i=#polygon,1,-1 do table.insert(reversed,polygon[i]) end;polygon=reversed end
		table.insert(contours,polygon)
	end
	local function disk(p: any)
		local radius=half*(options.Scale or 1)
		local n=math.max(16,math.ceil(2*math.pi*math.sqrt(radius)))
		n=math.ceil(n/4)*4
		assert(n<=2048,'SVG round stroke budget exceeded')
		local polygon={}
		for i=0,n-1 do local angle=2*math.pi*i/n;table.insert(polygon,{p[1]+half*math.cos(angle),p[2]+half*math.sin(angle)}) end
		add(polygon)
	end
	local function square(p: any,dx: number,dy: number)
		local nx,ny=-dy,dx
		add({{p[1]+half*(dx+nx),p[2]+half*(dy+ny)},{p[1]+half*(dx-nx),p[2]+half*(dy-ny)},
			{p[1]-half*(dx+nx),p[2]-half*(dy+ny)},{p[1]-half*(dx-nx),p[2]-half*(dy-ny)}})
	end
	if #clean==1 then
		if #points>1 or closed then
			if cap=='round' then disk(clean[1])
			elseif cap=='square' then
				local direction=options.Direction or {1,0};local n=math.sqrt(direction[1]^2+direction[2]^2)
				square(clean[1],if n>0 then direction[1]/n else 1,if n>0 then direction[2]/n else 0)
			end
		end
		return contours
	end
	for i=1,if closed then #clean else #clean-1 do
		local a,b=clean[i],clean[i%#clean+1];local dx,dy=b[1]-a[1],b[2]-a[2]
		local distance=math.sqrt(dx*dx+dy*dy);local nx,ny=-dy/distance,dx/distance
		normals[i]={nx,ny}
		add({{a[1]+nx*half,a[2]+ny*half},{b[1]+nx*half,b[2]+ny*half},{b[1]-nx*half,b[2]-ny*half},{a[1]-nx*half,a[2]-ny*half}})
	end
	for i=if closed then 1 else 2,if closed then #clean else #clean-1 do
		local p=clean[i];local before,after=normals[(i-2)%#clean+1],normals[i]
		if join=='round' then disk(p);continue end
		local divisor=1+before[1]*after[1]+before[2]*after[2]
		local turn=before[1]*after[2]-before[2]*after[1]
		-- Segment rectangles already cover the inner corner. Extending its
		-- miter could protrude beyond the ends of short, sharply bent segments.
		if turn~=0 then
			local side=if turn>0 then -1 else 1
			local a={p[1]+before[1]*half*side,p[2]+before[2]*half*side}
			local b={p[1]+after[1]*half*side,p[2]+after[2]*half*side}
			local mx,my=0,0
			if divisor>1e-12 then mx,my=(before[1]+after[1])*half*side/divisor,(before[2]+after[2])*half*side/divisor end
			if join=='miter' and divisor>1e-12 and mx*mx+my*my<=(limit*half)^2 then add({p,a,{p[1]+mx,p[2]+my},b}) else add({p,a,b}) end
		end
	end
	if not closed then
		if cap=='round' then disk(clean[1]);disk(clean[#clean])
		elseif cap=='square' then
			local first,last=normals[1],normals[#normals]
			square(clean[1],first[2],-first[1]);square(clean[#clean],last[2],-last[1])
		end
	end
	return contours
end
return Stroke
