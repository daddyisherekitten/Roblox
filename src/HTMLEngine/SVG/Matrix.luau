--!strict
--!optimize 2
--!native
-- Affine [SX KX TX; KY SY TY; 0 0 1], retaining the viewport field names.
local Matrix={}
function Matrix.identity(): any return {SX=1,SY=1,KX=0,KY=0,TX=0,TY=0} end
function Matrix.point(t: any,x: number,y: number): (number,number)
	return t.SX*x+(t.KX or 0)*y+t.TX,(t.KY or 0)*x+t.SY*y+t.TY
end
function Matrix.multiply(p: any,c: any): any
	local b,k=p.KY or 0,p.KX or 0;local bb,kk=c.KY or 0,c.KX or 0
	return {SX=p.SX*c.SX+k*bb,KX=p.SX*kk+k*c.SY,TX=p.SX*c.TX+k*c.TY+p.TX,
		KY=b*c.SX+p.SY*bb,SY=b*kk+p.SY*c.SY,TY=b*c.TX+p.SY*c.TY+p.TY}
end
function Matrix.determinant(t: any): number return t.SX*t.SY-(t.KX or 0)*(t.KY or 0) end
function Matrix.inverse(t: any): any?
 local d=Matrix.determinant(t)
 if d==0 or d~=d or math.abs(d)==math.huge then return nil end
 local b,c=t.KY or 0,t.KX or 0
 local result={SX=t.SY/d,KX=-c/d,KY=-b/d,SY=t.SX/d,TX=(c*t.TY-t.SY*t.TX)/d,TY=(b*t.TX-t.SX*t.TY)/d}
 for _,v in result do if v~=v or math.abs(v)==math.huge then return nil end end
 return result
end
function Matrix.valid(t: any): boolean
	for _,v in t do if v~=v or math.abs(v)>=math.huge then return false end end
	return true
end
function Matrix.scale(t: any): number
	-- Largest singular value: conservative curve detail under skew/reflection.
	local a,b,c,d=t.SX,t.KY or 0,t.KX or 0,t.SY
	local m=math.max(math.abs(a),math.abs(b),math.abs(c),math.abs(d))
	if m==0 then return 0 end
	a,b,c,d=a/m,b/m,c/m,d/m
	local sum=a*a+b*b+c*c+d*d;local det=a*d-b*c
	return m*math.sqrt((sum+math.sqrt(math.max(0,sum*sum-4*det*det)))/2)
end
function Matrix.polygon(t: any,points: any): any
	local result={};for _,p in points do local x,y=Matrix.point(t,p[1],p[2]);table.insert(result,{x,y}) end
	return result
end
function Matrix.bounds(points: any): any
	local x,y,xx,yy=math.huge,math.huge,-math.huge,-math.huge
	for _,p in points do x=math.min(x,p[1]);y=math.min(y,p[2]);xx=math.max(xx,p[1]);yy=math.max(yy,p[2]) end
	return if #points==0 then {X=0,Y=0,Width=0,Height=0} else {X=x,Y=y,Width=xx-x,Height=yy-y}
end
function Matrix.rectangle(t: any,r: any): any
	return Matrix.polygon(t,{{r.X,r.Y},{r.X+r.Width,r.Y},{r.X+r.Width,r.Y+r.Height},{r.X,r.Y+r.Height}})
end
return Matrix
