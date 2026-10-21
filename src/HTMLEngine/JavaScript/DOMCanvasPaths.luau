--!strict
-- Path2D owns geometry independently of any canvas bitmap or drawing state.
local Surface=require(script.Parent.Parent.Rendering.CanvasSurface)
local SVGPath=require(script.Parent.Parent.SVG.Path)
local Curves=require(script.Parent.Parent.SVG.Curves)
local DOMCanvasPaths={}
function DOMCanvasPaths.install(vm,globals,h)
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null
	local paths=setmetatable({},{__mode="kv"});local proto=vm.Object({});local api={}
	local function get(value)local raw=paths[value];if not raw then h.Fail("TypeError","Illegal Path2D receiver")end;return raw end
	local function copy(raw,m)
		local result={};local count=0
		for _,part in raw.Path do
			local points={};for _,p in part.Points do
				local x,y=p.X,p.Y;count+=1;points[#points+1]={X=m[1]*x+m[3]*y+m[5],Y=m[2]*x+m[4]*y+m[6],UX=m[1]*x+m[3]*y+m[5],UY=m[2]*x+m[4]*y+m[6]}
			end;result[#result+1]={Points=points,Closed=part.Closed}
		end;return result,count
	end
	local identity={1,0,0,1,0,0}
	local function wrap(raw)local value=vm.Object({},proto);value.CanvasPathState=raw;paths[value]=raw;return value end
	local ctor=h.Native("Path2D",0,function()h.Fail("TypeError","Path2D requires new")end)
	ctor.Construct=function(args)
		h.Check()
		local raw=Surface.new(0,0);local source=h.Arg(args,1)
		if source==U then return wrap(raw)end
		if paths[source]then raw.Path,raw.PathPointCount=copy(paths[source],identity);raw.Current=raw.Path[#raw.Path]
		else
			local parts,diagnostics=SVGPath.parse(h.Text(source))
			for _,issue in diagnostics do if issue.Code=="path-size-limit"or issue.Code=="path-point-limit"then h.Fail("QuotaExceededError","Path2D SVG data budget exceeded")end end
			local flattened=Curves.flatten(parts,1)
			for _,part in flattened do
				for index,p in part.Points do if index==1 then raw:MoveTo(p[1],p[2])else raw:LineTo(p[1],p[2])end end
				if part.Closed then raw:ClosePath()end
			end
		end;return wrap(raw)
	end
	h.Define(ctor,"prototype",{value=proto});h.Define(proto,"constructor",{value=ctor,writable=true,configurable=true})
	if vm.SymbolToStringTag then h.Define(proto,vm.SymbolToStringTag,{value="Path2D",configurable=true})end
	globals.Path2D=ctor;vm.Global.Bindings.Path2D={Value=ctor}
	for name,entry in {moveTo={"MoveTo",2},lineTo={"LineTo",2},rect={"Rect",4},arc={"Arc",5},arcTo={"ArcTo",5},ellipse={"Ellipse",7},quadraticCurveTo={"QuadraticCurveTo",4},bezierCurveTo={"BezierCurveTo",6}}do
		local key,spec=name,entry
		h.Method(proto,key,spec[2],function(args,value)
			local raw=get(value);if #args<spec[2]then h.Fail("TypeError",key.." requires arguments")end
			local numbers={};for i=1,spec[2]do numbers[i]=h.Number(args[i])end
			for _,n in numbers do if not h.Finite(n)then return U end end
			if(key=="arc"and numbers[3]<0)or(key=="arcTo"and numbers[5]<0)or(key=="ellipse"and(numbers[3]<0 or numbers[4]<0))then h.Fail("IndexSizeError","Radius cannot be negative")end
			if key=="arc"or key=="ellipse"then numbers[spec[2]+1]=VM.truth(h.Arg(args,spec[2]+1))end
			raw[spec[1]](raw,table.unpack(numbers));return U
		end)
	end
	h.Method(proto,"closePath",0,function(_,value)get(value):ClosePath();return U end)
	h.Method(proto,"addPath",1,function(args,value)
		local target,source=get(value),get(h.Arg(args,1));local matrix=h.Matrix(h.Arg(args,2))
		for _,n in matrix do if not h.Finite(n)then return U end end
		if target.PathPointCount+source.PathPointCount>65536 then h.Fail("QuotaExceededError","Path2D point budget exceeded")end
		local parts,count=copy(source,matrix)
		for _,part in parts do table.insert(target.Path,part)end
		target.PathPointCount+=count;target.Current=target.Path[#target.Path];return U
	end)
	function api:Get(value)return paths[value]end
	function api:With(surface,value,action)
		local raw=get(value);local old,current,count=surface.Path,surface.Current,surface.PathPointCount
		surface.Path,surface.PathPointCount=copy(raw,surface.State.Transform);surface.Current=surface.Path[#surface.Path]
		local ok,result=pcall(action)
		surface.Path,surface.Current,surface.PathPointCount=old,current,count
		if not ok then error(result,0)end;return result
	end
	function api:Destroy()table.clear(paths)end
	return api
end
return DOMCanvasPaths
