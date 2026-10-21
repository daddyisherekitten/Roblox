--!strict
--!optimize 2
-- Column-major homogeneous matrices, using CSS's right-handed coordinates.
local Matrix4={}
function Matrix4.identity(): any return {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1} end
function Matrix4.multiply(a: any,b: any): any
	local out=table.create(16,0)
	for col=0,3 do for row=1,4 do
		local sum=0;for k=0,3 do sum+=a[k*4+row]*b[col*4+k+1] end
		out[col*4+row]=sum
	end end
	return out
end
function Matrix4.translate(x: number,y: number,z: number?): any
	local m=Matrix4.identity();m[13],m[14],m[15]=x,y,z or 0;return m
end
function Matrix4.scale(x: number,y: number,z: number?): any
	local m=Matrix4.identity();m[1],m[6],m[11]=x,y,z or 1;return m
end
function Matrix4.rotate(x: number,y: number,z: number,angle: number): any
 local largest=math.max(math.abs(x),math.abs(y),math.abs(z));if largest==0 then return Matrix4.identity()end
 x,y,z=x/largest,y/largest,z/largest
 local length=math.sqrt(x*x+y*y+z*z)
	x,y,z=x/length,y/length,z/length
	local c,s=math.cos(math.rad(angle)),math.sin(math.rad(angle));local t=1-c
	return {t*x*x+c,t*x*y+s*z,t*x*z-s*y,0,t*x*y-s*z,t*y*y+c,t*y*z+s*x,0,t*x*z+s*y,t*y*z-s*x,t*z*z+c,0,0,0,0,1}
end
function Matrix4.perspective(depth: number): any
	local m=Matrix4.identity();if depth<math.huge then m[12]=-1/math.max(1,depth) end;return m
end
function Matrix4.point(m: any,x: number,y: number,z: number?): any
	z=z or 0
	return {X=m[1]*x+m[5]*y+m[9]*z+m[13],Y=m[2]*x+m[6]*y+m[10]*z+m[14],Z=m[3]*x+m[7]*y+m[11]*z+m[15],W=m[4]*x+m[8]*y+m[12]*z+m[16]}
end
function Matrix4.around(m: any,x: number,y: number,z: number?): any
	return Matrix4.multiply(Matrix4.multiply(Matrix4.translate(x,y,z),m),Matrix4.translate(-x,-y,-(z or 0)))
end
function Matrix4.flat(m: any): any
	-- Flatten the rendered plane onto z=0 without dropping its projective x/y/w.
	local out=table.clone(m);out[3],out[7],out[11],out[15]=0,0,1,0;return out
end
function Matrix4.native(m: any): boolean
	local eps=1e-8
	if math.abs(m[3])+math.abs(m[4])+math.abs(m[7])+math.abs(m[8])+math.abs(m[9])+math.abs(m[10])+math.abs(m[12])+math.abs(m[15])+math.abs(m[16]-1)>eps then return false end
	return math.abs(m[1]-m[6])<eps and math.abs(m[2]+m[5])<eps
end
function Matrix4.equal(a: any,b: any): boolean
	for i=1,16 do if math.abs(a[i]-b[i])>1e-8 then return false end end;return true
end
function Matrix4.inverse(m: any): any?
	local rows={}
	for r=1,4 do rows[r]={};for c=1,4 do rows[r][c]=m[(c-1)*4+r];rows[r][c+4]=if r==c then 1 else 0 end end
	for c=1,4 do
		local pivot=c;for r=c+1,4 do if math.abs(rows[r][c])>math.abs(rows[pivot][c]) then pivot=r end end
		if math.abs(rows[pivot][c])<1e-12 then return nil end
		rows[c],rows[pivot]=rows[pivot],rows[c];local value=rows[c][c]
		for k=1,8 do rows[c][k]/=value end
		for r=1,4 do if r~=c then local factor=rows[r][c];for k=1,8 do rows[r][k]-=factor*rows[c][k] end end end
	end
	local out={};for c=1,4 do for r=1,4 do out[(c-1)*4+r]=rows[r][c+4] end end;return out
end
function Matrix4.backFacing(m: any): boolean
	-- A two-dimensional transform preserves the forward z axis, even when its
	-- x/y plane is reflected or singular. Avoid a full inverse on every paint.
	if m[3]==0 and m[4]==0 and m[7]==0 and m[8]==0 and m[9]==0 and m[10]==0 and m[11]==1 and m[12]==0 and m[15]==0 and m[16]==1 then return false end
	local inverse=Matrix4.inverse(m)
	return inverse~=nil and inverse[11]<0
end
local function dot(a: any,b: any): number return a[1]*b[1]+a[2]*b[2]+a[3]*b[3] end
local function normalize(v: any,length: number): any return {v[1]/length,v[2]/length,v[3]/length} end
local function subtract(a: any,b: any,factor: number): any return {a[1]-b[1]*factor,a[2]-b[2]*factor,a[3]-b[3]*factor} end
local function decompose(value: any): any?
	if math.abs(value[16])<1e-12 then return nil end
	local m={};for i=1,16 do m[i]=value[i]/value[16] end
	local affine=table.clone(m);affine[4],affine[8],affine[12],affine[16]=0,0,0,1
	local inverse=Matrix4.inverse(affine);if not inverse then return nil end
	local rhs={m[4],m[8],m[12],m[16]};local perspective={}
	for i=1,4 do perspective[i]=0;for k=1,4 do perspective[i]+=inverse[(i-1)*4+k]*rhs[k] end end
	local rows={{m[1],m[2],m[3]},{m[5],m[6],m[7]},{m[9],m[10],m[11]}}
	local scale={};local skew={}
	scale[1]=math.sqrt(dot(rows[1],rows[1]));if scale[1]<1e-12 then return nil end;rows[1]=normalize(rows[1],scale[1])
	skew[1]=dot(rows[1],rows[2]);rows[2]=subtract(rows[2],rows[1],skew[1]);scale[2]=math.sqrt(dot(rows[2],rows[2]));if scale[2]<1e-12 then return nil end;rows[2]=normalize(rows[2],scale[2]);skew[1]/=scale[2]
	skew[2]=dot(rows[1],rows[3]);rows[3]=subtract(rows[3],rows[1],skew[2]);skew[3]=dot(rows[2],rows[3]);rows[3]=subtract(rows[3],rows[2],skew[3]);scale[3]=math.sqrt(dot(rows[3],rows[3]));if scale[3]<1e-12 then return nil end;rows[3]=normalize(rows[3],scale[3]);skew[2]/=scale[3];skew[3]/=scale[3]
	local a,b,c=rows[1],rows[2],rows[3];local cross={b[2]*c[3]-b[3]*c[2],b[3]*c[1]-b[1]*c[3],b[1]*c[2]-b[2]*c[1]}
	if dot(a,cross)<0 then for i=1,3 do scale[i]=-scale[i];rows[i]=normalize(rows[i],-1) end end
	a,b,c=rows[1],rows[2],rows[3]
	local q={};local trace=a[1]+b[2]+c[3]
	if trace>0 then local s=math.sqrt(trace+1)*2;q={ (b[3]-c[2])/s,(c[1]-a[3])/s,(a[2]-b[1])/s,s/4 }
	elseif a[1]>b[2] and a[1]>c[3] then local s=math.sqrt(1+a[1]-b[2]-c[3])*2;q={s/4,(b[1]+a[2])/s,(c[1]+a[3])/s,(b[3]-c[2])/s}
	elseif b[2]>c[3] then local s=math.sqrt(1+b[2]-a[1]-c[3])*2;q={(b[1]+a[2])/s,s/4,(c[2]+b[3])/s,(c[1]-a[3])/s}
	else local s=math.sqrt(1+c[3]-a[1]-b[2])*2;q={(c[1]+a[3])/s,(c[2]+b[3])/s,s/4,(a[2]-b[1])/s} end
	return {Translation={m[13],m[14],m[15]},Scale=scale,Skew=skew,Quaternion=q,Perspective=perspective}
end
local function recompose(d: any): any
	local m=Matrix4.identity();for i=1,4 do m[(i-1)*4+4]=d.Perspective[i] end
	m=Matrix4.multiply(m,Matrix4.translate(d.Translation[1],d.Translation[2],d.Translation[3]))
	local q=d.Quaternion;local x,y,z,w=q[1],q[2],q[3],q[4]
	local rotation={1-2*(y*y+z*z),2*(x*y+z*w),2*(x*z-y*w),0,2*(x*y-z*w),1-2*(x*x+z*z),2*(y*z+x*w),0,2*(x*z+y*w),2*(y*z-x*w),1-2*(x*x+y*y),0,0,0,0,1}
	m=Matrix4.multiply(m,rotation)
	local skew=Matrix4.identity();skew[5],skew[9],skew[10]=d.Skew[1],d.Skew[2],d.Skew[3]
	m=Matrix4.multiply(m,skew)
	return Matrix4.multiply(m,Matrix4.scale(d.Scale[1],d.Scale[2],d.Scale[3]))
end
function Matrix4.interpolate(a: any,b: any,t: number): any
	if t<=0 then return a elseif t>=1 then return b end
	local da,db=decompose(a),decompose(b)
	if not da or not db then return if t<.5 then a else b end
	local function mix(x: number,y: number): number return x+(y-x)*t end
	local qa,qb=da.Quaternion,db.Quaternion;local cosine=0;for i=1,4 do cosine+=qa[i]*qb[i] end
	if cosine<0 then qb={-qb[1],-qb[2],-qb[3],-qb[4]};cosine=-cosine end
	local fa,fb=1-t,t
	if cosine<.9995 then local angle=math.acos(math.clamp(cosine,-1,1));local sine=math.sin(angle);fa,fb=math.sin((1-t)*angle)/sine,math.sin(t*angle)/sine end
	local q={};local norm=0;for i=1,4 do q[i]=qa[i]*fa+qb[i]*fb;norm+=q[i]^2 end
	for i=1,4 do q[i]/=math.sqrt(norm) end
	local d={Quaternion=q,Translation={},Scale={},Skew={},Perspective={}}
	for _,field in {"Translation","Scale","Skew","Perspective"}do for i,value in da[field]do d[field][i]=mix(value,db[field][i])end end
	return recompose(d)
end
function Matrix4.accumulate(a: any,b: any,count: number?): any
	count=count or 1
	if count==0 then return a end
	local da,db=decompose(a),decompose(b)
	-- A failed decomposition cannot accumulate; the effect replaces the base.
	if not da or not db then return b end
	local d={Translation={},Scale={},Skew={},Perspective={}}
	for _,field in {"Translation","Scale","Skew","Perspective"}do
		for i,value in da[field]do
			local identity=if field=="Scale" or field=="Perspective" and i==4 then 1 else 0
			d[field][i]=value+(db[field][i]-identity)*count
		end
	end
	local qa,qb=da.Quaternion,db.Quaternion
	local angle=math.acos(math.clamp(qb[4],-1,1));local sine=math.sin(angle)
	if math.abs(sine)<1e-12 then qb={0,0,0,1}
	else local factor=math.sin(angle*count)/sine;qb={qb[1]*factor,qb[2]*factor,qb[3]*factor,math.cos(angle*count)}end
	local ax,ay,az,aw=qa[1],qa[2],qa[3],qa[4];local bx,by,bz,bw=qb[1],qb[2],qb[3],qb[4]
	d.Quaternion={aw*bx+ax*bw+ay*bz-az*by,aw*by-ax*bz+ay*bw+az*bx,aw*bz+ax*by-ay*bx+az*bw,aw*bw-ax*bx-ay*by-az*bz}
	return recompose(d)
end
return Matrix4
