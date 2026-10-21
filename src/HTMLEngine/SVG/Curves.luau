--!strict
--!optimize 2
--!native
-- Flatten at render scale, so enlarging a viewport also refines its curves.
local Arc=require(script.Parent.Arc)
local WorkContext=require(script.Parent.Parent.WorkContext)
local Curves={}
local function midpoint(a: any,b: any): any return {(a[1]+b[1])/2,(a[2]+b[2])/2} end
local function distance(p: any,a: any,b: any): number
	local dx,dy=b[1]-a[1],b[2]-a[2]
	local length=dx*dx+dy*dy
	local t=if length==0 then 0 else math.clamp(((p[1]-a[1])*dx+(p[2]-a[2])*dy)/length,0,1)
	return (p[1]-a[1]-t*dx)^2+(p[2]-a[2]-t*dy)^2
end
function Curves.flatten(parts: any,scale: number,check: any?): any?
	assert(scale>0 and scale<math.huge,'Invalid SVG curve scale')
	local tolerance=(.125/scale)^2
	local result,total,steps={},0,0
	local function append(points: any,p: any)
		total+=1;assert(total<=16384,'SVG curve point budget exceeded')
		if total%64==0 then WorkContext.checkpoint()end
		table.insert(points,p)
	end
	local function cubic(points: any,a: any,b: any,c: any,d: any,depth: number): boolean
		steps+=1;if steps%64==0 then WorkContext.checkpoint();if check and not check()then return false end end
		-- Distance to the finite chord also catches collinear reversals and loops.
		if math.max(distance(b,a,d),distance(c,a,d))<=tolerance then append(points,d);return true end
		assert(depth<20,'SVG curve subdivision budget exceeded')
		local ab,bc,cd=midpoint(a,b),midpoint(b,c),midpoint(c,d)
		local abc,bcd=midpoint(ab,bc),midpoint(bc,cd)
		local middle=midpoint(abc,bcd)
		return cubic(points,a,ab,abc,middle,depth+1) and cubic(points,middle,bcd,cd,d,depth+1)
	end
	for _,part in parts do
		if check and not check() then return nil end
		local points={}
		for i,p in part.Points do
			local curve=part.Curves and part.Curves[i]
			if not curve then append(points,p);continue end
			local a=part.Points[i-1]
			if curve.Kind=='A' then
				local arc=Arc.resolve(a,p,curve)
				if arc.Mode=='empty' then continue end
				if arc.Mode=='line' then append(points,p);continue end
				-- Linear interpolation error <= max-radius * angle-step^2 / 8.
				local count=math.max(1,math.ceil(math.abs(arc.Delta)*math.sqrt(math.max(arc.RX,arc.RY)*scale)))
				assert(total+count<=16384,'SVG curve point budget exceeded')
				for step=1,count do
					if check and step%64==0 and not check() then return nil end
					append(points,if step==count then p else Arc.point(arc,arc.Start+arc.Delta*step/count))
				end
				continue
			end
			local b,c=curve.Control1,curve.Control2
			if curve.Kind=='Q' then
				c={p[1]+2/3*(b[1]-p[1]),p[2]+2/3*(b[2]-p[2])}
				b={a[1]+2/3*(b[1]-a[1]),a[2]+2/3*(b[2]-a[2])}
			end
			if not cubic(points,a,b,c,p,0) then return nil end
		end
		table.insert(result,{Points=points,Closed=part.Closed})
	end
	return result
end
return Curves
