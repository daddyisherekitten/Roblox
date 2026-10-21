--!strict
-- SVG endpoint-to-center conversion, with corrected radii and signed sweep.
local Arc={}
local function hypot(x: number,y: number): number
	local m=math.max(math.abs(x),math.abs(y))
	return if m==0 then 0 else m*math.sqrt((x/m)^2+(y/m)^2)
end
function Arc.resolve(a: any,b: any,curve: any): any
	if a[1]==b[1] and a[2]==b[2] then return {Mode='empty'} end
	local rx,ry=math.abs(curve.RX),math.abs(curve.RY)
	if rx==0 or ry==0 then return {Mode='line'} end
	local phi=math.rad(curve.Rotation%360);local cos,sin=math.cos(phi),math.sin(phi)
	local dx,dy=(a[1]-b[1])/2,(a[2]-b[2])/2
	local xp,yp=cos*dx+sin*dy,-sin*dx+cos*dy
	local u,v=xp/rx,yp/ry
	local correction=hypot(u,v)
	assert(correction>0 and correction<math.huge,'SVG arc numeric budget exceeded')
	local corrected=correction>1
	if corrected then rx*=correction;ry*=correction;u=xp/rx;v=yp/ry end
	assert(rx<1e12 and ry<1e12,'SVG arc radius budget exceeded')
	local norm=hypot(u,v)
	local offset=if corrected then 0 else math.sqrt(math.max(0,1-norm*norm))*(if curve.Large==curve.Sweep then -1 else 1)
	local cxp,cyp=rx*(v/norm)*offset,-ry*(u/norm)*offset
	local ux,uy=(xp-cxp)/rx,(yp-cyp)/ry
	local vx,vy=(-xp-cxp)/rx,(-yp-cyp)/ry
	local start=math.atan2(uy,ux)
	local delta=math.atan2(ux*vy-uy*vx,ux*vx+uy*vy)
	if curve.Sweep==0 and delta>0 then delta-=2*math.pi elseif curve.Sweep==1 and delta<0 then delta+=2*math.pi end
	return {Mode='arc',RX=rx,RY=ry,Cos=cos,Sin=sin,CX=cos*cxp-sin*cyp+(a[1]+b[1])/2,CY=sin*cxp+cos*cyp+(a[2]+b[2])/2,Start=start,Delta=delta}
end
function Arc.point(arc: any,angle: number): any
	local x,y=arc.RX*math.cos(angle),arc.RY*math.sin(angle)
	return {arc.CX+arc.Cos*x-arc.Sin*y,arc.CY+arc.Sin*x+arc.Cos*y}
end
return Arc
