--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Canvas 2D wrappers belong to the HTML realm. CPU surfaces belong to the
-- native resource adapter, so detach and native repaint preserve bitmap data.
local Color=require(script.Parent.Parent.CSS.Color)
local CanvasPaths=require(script.Parent.DOMCanvasPaths)
local DOMCanvas={}
function DOMCanvas.install(vm: any,globals: any,options: any): any
	local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local binary=options.Binary;local api={Alive=true}
	local contexts,images,paints={},{},{};for _,map in {contexts,images,paints}do setmetatable(map,{__mode="kv"})end
	local byNode=setmetatable({},{__mode="k"});local methods=setmetatable({},{__mode="k"})
	local contextProto,imageProto,gradientProto,patternProto,metricsProto=vm.Object({}),vm.Object({}),vm.Object({}),vm.Object({}),vm.Object({})
	local function check()assert(api.Alive and vm.Alive,"DOM canvas disposed")end
	local function fail(name,message)VM.throw(if options.HostEvents and name~="TypeError"and name~="RangeError"then options.HostEvents:DOMException(message,name)else VM.error(name,message))end
	local function arg(args,index)return if args[index]==nil then U else args[index]end
	local function nullish(value)return value==nil or value==N or value==U end
	local function text(value)value=vm.ToPrimitive(value,"string");if type(value)=="table"and value.Kind=="symbol"then fail("TypeError","Cannot convert Symbol to string")end;return VM.string(value)end
	local function number(value)return VM.number(vm.ToPrimitive(value,"number"))end
	local function finite(value)return value==value and math.abs(value)~=math.huge end
	local function unsigned(value)local n=number(value);if not finite(n)or n==0 then return 0 end;return (if n<0 then math.ceil(n)else math.floor(n))%4294967296 end
	local function long(value)
		local n=number(value);if not finite(n)then fail("TypeError","Pixel coordinates must be finite")end
		n=if n<0 then math.ceil(n)else math.floor(n);if n< -2147483648 or n>2147483647 then fail("TypeError","Pixel coordinate exceeds the signed integer range")end;return n
	end
	local function native(name,length,fn)
		local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)
			check();if options.HostCall then return options.HostCall(function()return fn(args,receiver)end)end;return fn(args,receiver)
		end}
		vm.DefineProperty(value,"name",vm.Object({value=name,configurable=true},VM.Null));vm.DefineProperty(value,"length",vm.Object({value=length,configurable=true},VM.Null));return value
	end
	local function define(target,key,desc)vm.DefineProperty(target,key,vm.Object(desc,VM.Null))end
	local function method(proto,key,length,fn)define(proto,key,{value=native(key,length,fn),writable=true,enumerable=true,configurable=true})end
	local function accessor(proto,key,read,write)
		define(proto,key,{get=native("get "..key,0,function(_,value)return read(value)end),set=if write then native("set "..key,1,function(args,value)write(value,arg(args,1));return U end)else U,enumerable=true,configurable=true})
	end
	local function state(map,value,name)local record=map[value];if not record then fail("TypeError","Illegal "..name.." receiver")end;return record end
	local function canvas(node)return ElementNames.html(node,"canvas")end
	local function dimension(node,key,value)
		if value==nil then value=node.Attributes[key]end
		local digits=value and value:match("^%s*%+?(%d+)");local n=digits and tonumber(digits)
		return if n then n else if key=="width"then 300 else 150
	end
	local function bounds(w,h)if w>2048 or h>2048 or w*h>4194304 then fail("QuotaExceededError","Canvas bitmap exceeds the renderer pixel limit")end end
	local function surface(node)local w,h=dimension(node,"width"),dimension(node,"height");bounds(w,h);return options.Surface(node,true)end
	local function publish(node)if options.Publish then options.Publish(node)end end
	function api:ValidateAttribute(node,key,value)
		if not canvas(node)or(key~="width"and key~="height")then return end
		local w,h=dimension(node,"width"),dimension(node,"height")
		if key=="width"then w=if value==nil then 300 else dimension(node,key,value)else h=if value==nil then 150 else dimension(node,key,value)end;bounds(w,h)
	end
	function api:AttributeChanged(node,key)
		if not canvas(node)or(key~="width"and key~="height")then return end
		local w,h=dimension(node,"width"),dimension(node,"height");bounds(w,h)
		if options.Surface(node,false)then
			local action=function()options.Reset(node,w,h);publish(node)end
			if options.HostCall then options.HostCall(action)else action()end
		end
	end
	function api:Get(node,key)
		if canvas(node)and(key=="width"or key=="height")then return true,dimension(node,key)end;return false,U
	end
	function api:Set(node,key,value,strict)
		if not canvas(node)or(key~="width"and key~="height")then return false end
		local n=unsigned(value);self:ValidateAttribute(node,key,tostring(n));options.Attribute(node,key,tostring(n));return true
	end
	local function imageData(w,h,data)
		local value=vm.Object({},imageProto);local s={Width=w,Height=h,Data=data};value.ImageDataState=s;images[value]=s;return value
	end
	local function wrapImage(raw)
		local bytes=buffer.tostring(raw.Pixels);local backing=binary:Buffer(bytes);return imageData(raw.Width,raw.Height,binary:CreateView("Uint8ClampedArray",backing,0,#bytes))
	end
	local function unwrapImage(value)
		local s=state(images,value,"ImageData");local desc=binary:Describe(s.Data);if not desc or desc.Detached then fail("InvalidStateError","ImageData buffer is detached")end
		return {Kind="ImageData",Width=s.Width,Height=s.Height,Pixels=buffer.fromstring(binary:ReadBytes(s.Data))}
	end
	local function source(value)
		local node=options.Unwrap(value)
		if canvas(node)then return {CanvasSource=surface(node)}end
		if not ElementNames.html(node,"img")then fail("TypeError","Expected a supported canvas image source")end
		local data=options.ImageSource and options.ImageSource(node)
		if not data then fail("InvalidStateError","Image pixels are unavailable for drawing")end;return {CanvasImageSource=data}
	end
	local function colorSpace(settings)
		if nullish(settings)then return end
		local value=vm.Get(settings,"colorSpace");if value~=U and text(value)~="srgb"then fail("NotSupportedError","Only sRGB canvas pixel data is supported")end
		local format=vm.Get(settings,"pixelFormat");if format~=U and text(format)~="rgba-unorm8"then fail("NotSupportedError","Only RGBA8 canvas pixel data is supported")end
	end
	local function paintWrapper(raw,proto)
		local value=vm.Object({},proto);value.CanvasPaintState=raw;paints[value]=raw;return value
	end
	local function serializedColor(raw)
		local color,alpha=Color.parse(raw:match("^%s*(.-)%s*$"):lower());if not color or color=="currentcolor"then return raw end
		local r,g,b=math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5)
		if alpha==1 then return string.format("#%02x%02x%02x",r,g,b)end
		local byte=math.floor(alpha*255+.5);local rounded=math.floor(byte/255*100+.5)/100
		if math.floor(rounded*255+.5)~=byte then rounded=math.floor(byte/255*1000+.5)/1000 end
		return "rgba("..r..", "..g..", "..b..", "..tostring(rounded)..")"
	end
	local function matrix(value)
		local fields={}
		for _,key in {"a","b","c","d","e","f","m11","m12","m21","m22","m41","m42"}do
			local raw=if nullish(value)then U else vm.Get(value,key);fields[key]=if raw==U then U else number(raw)
		end
		local result={};for index,pair in {{"a","m11",1},{"b","m12",0},{"c","m21",0},{"d","m22",1},{"e","m41",0},{"f","m42",0}}do
			local a,b=fields[pair[1]],fields[pair[2]]
			local hasA,hasB=a~=U,b~=U;a=if hasA then number(a)else pair[3];b=if hasB then number(b)else a
			if hasA and hasB and a~=b and not(a~=a and b~=b)then fail("TypeError","Matrix aliases disagree")end;result[index]=if hasA then a else b
		end;return result
	end
	local properties={fillStyle=true,strokeStyle=true,lineWidth=true,globalAlpha=true,globalCompositeOperation=true,shadowColor=true,shadowBlur=true,shadowOffsetX=true,shadowOffsetY=true,font=true,textAlign=true,textBaseline=true,direction=true,imageSmoothingEnabled=true,imageSmoothingQuality=true}
	local numericProperties={lineWidth=true,globalAlpha=true,shadowBlur=true,shadowOffsetX=true,shadowOffsetY=true}
	for key in properties do local property=key
		accessor(contextProto,property,function(value)
			local s=state(contexts,value,"CanvasRenderingContext2D");local result=surface(s.Node):Get(property)
			if type(result)=="table"then
				for wrapper,raw in paints do if raw==result then return wrapper end end
				return paintWrapper(result,if result.Kind=="CanvasGradient"then gradientProto else patternProto)
			end;return if property=="fillStyle"or property=="strokeStyle"or property=="shadowColor"then serializedColor(result)else result
		end,function(value,item)
			local s=state(contexts,value,"CanvasRenderingContext2D");local converted
			if numericProperties[property]then converted=number(item);if not finite(converted)then return end
			elseif property=="imageSmoothingEnabled"then converted=VM.truth(item)
			elseif(property=="fillStyle"or property=="strokeStyle")and paints[item]then converted=paints[item]
			else converted=text(item)end
			-- Invalid CSS paint values are ignored by the canvas state setter.
			local ok,failure=pcall(function()surface(s.Node):Set(property,converted)end)
			if not ok and property~="fillStyle"and property~="strokeStyle"and property~="shadowColor"then error(failure,0)end
		end)
	end
	accessor(contextProto,"canvas",function(value)return options.Wrap(state(contexts,value,"CanvasRenderingContext2D").Node)end)
	method(contextProto,"getContextAttributes",0,function(_,value)local s=state(contexts,value,"CanvasRenderingContext2D");return vm.Object(table.clone(s.Settings))end)
	local numericMethods={fillRect={"FillRect",4},clearRect={"ClearRect",4},strokeRect={"StrokeRect",4},moveTo={"MoveTo",2},lineTo={"LineTo",2},rect={"Rect",4},arc={"Arc",5},arcTo={"ArcTo",5},ellipse={"Ellipse",7},quadraticCurveTo={"QuadraticCurveTo",4},bezierCurveTo={"BezierCurveTo",6},translate={"Translate",2},scale={"Scale",2},rotate={"Rotate",1},transform={"Transform",6},createLinearGradient={"CreateLinearGradient",4},createRadialGradient={"CreateRadialGradient",6},getImageData={"GetImageData",4}}
	for key,spec in numericMethods do local name,entry=key,spec
		method(contextProto,name,entry[2],function(args,value)
			local s=state(contexts,value,"CanvasRenderingContext2D");if #args<entry[2]then fail("TypeError",name.." requires "..entry[2].." arguments")end
			local converted={};for index=1,entry[2]do converted[index]=if name=="getImageData"then long(args[index])else number(args[index])end
			for _,n in converted do if not finite(n)then
				if name=="createLinearGradient"or name=="createRadialGradient"then fail("NotSupportedError","Gradient arguments are not finite")end;return U
			end end
			if(name=="arc"and converted[3]<0)or(name=="arcTo"and converted[5]<0)or(name=="ellipse"and(converted[3]<0 or converted[4]<0))or(name=="createRadialGradient"and(converted[3]<0 or converted[6]<0))then fail("IndexSizeError","Radius cannot be negative")end
			if name=="arc"or name=="ellipse"then converted[entry[2]+1]=VM.truth(arg(args,entry[2]+1))end
			if name=="getImageData"then colorSpace(arg(args,5));if(converted[3]==0 or converted[4]==0)then fail("IndexSizeError","ImageData dimensions cannot be zero")end;bounds(math.abs(converted[3]),math.abs(converted[4]))end
			local result=surface(s.Node)[entry[1]](surface(s.Node),table.unpack(converted))
			if name=="createLinearGradient"or name=="createRadialGradient"then return paintWrapper(result,gradientProto)elseif name=="getImageData"then return wrapImage(result)end
			publish(s.Node);return U
		end)
	end
	for key,name in {beginPath="BeginPath",closePath="ClosePath",save="Save",restore="Restore",resetTransform="ResetTransform"}do local methodName,rawName=key,name
		method(contextProto,methodName,0,function(_,value)local s=state(contexts,value,"CanvasRenderingContext2D");surface(s.Node)[rawName](surface(s.Node));return U end)
	end
	method(contextProto,"reset",0,function(_,value)local s=state(contexts,value,"CanvasRenderingContext2D");local raw=surface(s.Node);options.Reset(s.Node,raw.Width,raw.Height);publish(s.Node);return U end)
	method(contextProto,"getTransform",0,function(_,value)local s=state(contexts,value,"CanvasRenderingContext2D");local m=surface(s.Node).State.Transform
		if options.Matrix then return options.Matrix(m)end;return vm.Object({a=m[1],b=m[2],c=m[3],d=m[4],e=m[5],f=m[6],m11=m[1],m12=m[2],m21=m[3],m22=m[4],m41=m[5],m42=m[6],is2D=true})
	end)
	method(contextProto,"setTransform",0,function(args,value)local s=state(contexts,value,"CanvasRenderingContext2D");local m
		if #args<2 then m=matrix(arg(args,1))else if #args<6 then fail("TypeError","setTransform requires six numbers")end;m={};for index=1,6 do m[index]=number(args[index])end end
		for _,n in m do if not finite(n)then return U end end;surface(s.Node):SetTransform(table.unpack(m));return U
	end)
	local paths=CanvasPaths.install(vm,globals,{Check=check,Native=native,Define=define,Method=method,Fail=fail,Arg=arg,Text=text,Number=number,Finite=finite,Matrix=matrix})
	method(contextProto,"stroke",0,function(args,value)
		local s=state(contexts,value,"CanvasRenderingContext2D");local raw=surface(s.Node)
		if #args>0 then paths:With(raw,args[1],function()raw:Stroke()end)else raw:Stroke()end
		publish(s.Node);return U
	end)
	for key,name in {fill="Fill",clip="Clip"}do local methodName,rawName=key,name
		method(contextProto,methodName,0,function(args,value)
			local s=state(contexts,value,"CanvasRenderingContext2D");local path=paths:Get(arg(args,1))
			local ruleArg=arg(args,if path then 2 else 1);local rule=if ruleArg==U then "nonzero"else text(ruleArg)
			if rule~="nonzero"and rule~="evenodd"then fail("TypeError","Invalid canvas fill rule")end
			local raw=surface(s.Node);local action=function()raw[rawName](raw,rule)end
			if path then paths:With(raw,args[1],action)else action()end;publish(s.Node);return U
		end)
	end
	method(contextProto,"isPointInPath",2,function(args,value)
		local s=state(contexts,value,"CanvasRenderingContext2D");local path=paths:Get(arg(args,1));local i=if path then 2 else 1
		if #args<i+1 then fail("TypeError","isPointInPath requires coordinates")end
		local x,y=number(args[i]),number(args[i+1]);local ruleArg=arg(args,i+2);local rule=if ruleArg==U then "nonzero"else text(ruleArg)
		if rule~="nonzero"and rule~="evenodd"then fail("TypeError","Invalid canvas fill rule")end
		if not finite(x)or not finite(y)then return false end
		local raw=surface(s.Node);local action=function()return raw:IsPointInPath(x,y,rule)end
		return if path then paths:With(raw,args[1],action)else action()
	end)
	for key,name in {fillText="FillText",strokeText="StrokeText",measureText="MeasureText"}do local methodName,rawName=key,name
		method(contextProto,methodName,if key=="measureText"then 1 else 3,function(args,value)
			local s=state(contexts,value,"CanvasRenderingContext2D");local required=if methodName=="measureText"then 1 else 3;if #args<required then fail("TypeError",methodName.." requires arguments")end
			local content=text(args[1]);local x,y,w=if #args>=2 then number(args[2])else nil,if #args>=3 then number(args[3])else nil,if #args>=4 then number(args[4])else nil
			if(x and not finite(x))or(y and not finite(y))or(w and(not finite(w)or w<=0))then return U end
			local result=surface(s.Node)[rawName](surface(s.Node),content,x,y,w)
			if methodName=="measureText"then local values={};for field,numberValue in result do if type(numberValue)=="number"then values[field]=numberValue end end;local metric=vm.Object({},metricsProto);for field,numberValue in values do define(metric,field,{value=numberValue,enumerable=true})end;return metric end
			publish(s.Node);return U
		end)
	end
	method(contextProto,"createImageData",2,function(args,value)
		local s=state(contexts,value,"CanvasRenderingContext2D");local known=images[arg(args,1)]
		if known then return wrapImage(surface(s.Node):CreateImageData(known.Width,known.Height))end
		if #args<2 then fail("TypeError","createImageData requires two dimensions")end;local w,h=long(args[1]),long(args[2])
		colorSpace(arg(args,3));if math.floor(math.abs(w))==0 or math.floor(math.abs(h))==0 then fail("IndexSizeError","ImageData dimensions cannot be zero")end;bounds(math.abs(w),math.abs(h));return wrapImage(surface(s.Node):CreateImageData(w,h))
	end)
	method(contextProto,"putImageData",3,function(args,value)
		local s=state(contexts,value,"CanvasRenderingContext2D");if #args<3 then fail("TypeError","putImageData requires arguments")end;local raw=unwrapImage(args[1]);local converted={raw}
		local count=if #args>=7 then 7 else 3;for index=2,count do converted[index]=long(args[index])end
		surface(s.Node):PutImageData(table.unpack(converted));publish(s.Node);return U
	end)
	method(contextProto,"drawImage",3,function(args,value)
		local s=state(contexts,value,"CanvasRenderingContext2D");if #args<3 then fail("TypeError","drawImage requires 3, 5 or 9 arguments")end
		local converted={source(args[1])};local count=if #args>=9 then 9 elseif #args>=5 then 5 else 3;for index=2,count do converted[index]=number(args[index]);if not finite(converted[index])then return U end end
		surface(s.Node):DrawImage(table.unpack(converted));publish(s.Node);return U
	end)
	method(contextProto,"createPattern",2,function(args,value)
		local s=state(contexts,value,"CanvasRenderingContext2D");if #args<2 then fail("TypeError","createPattern requires an image and repetition")end
		local repetition=if nullish(args[2])then "repeat"else text(args[2]);if repetition==""then repetition="repeat"end
		if repetition~="repeat"and repetition~="repeat-x"and repetition~="repeat-y"and repetition~="no-repeat"then fail("SyntaxError","Invalid canvas pattern repetition")end
		local src=source(args[1]);local bitmap=src.CanvasSource or src.CanvasImageSource;if bitmap.Width==0 or bitmap.Height==0 then return N end
		return paintWrapper(surface(s.Node):CreatePattern(src,repetition),patternProto)
	end)
	method(gradientProto,"addColorStop",2,function(args,value)
		local raw=state(paints,value,"CanvasGradient");if raw.Kind~="CanvasGradient"then fail("TypeError","Expected CanvasGradient")end;if #args<2 then fail("TypeError","addColorStop requires arguments")end
		local offset=number(args[1]);if not finite(offset)then fail("TypeError","Gradient offset must be finite")end;local color=text(args[2]);if offset<0 or offset>1 then fail("IndexSizeError","Gradient offset is outside [0, 1]")end
		local ok=pcall(function()raw:AddColorStop(offset,color)end);if not ok then fail("SyntaxError","Invalid gradient color")end;return U
	end)
	method(patternProto,"setTransform",0,function(args,value)local raw=state(paints,value,"CanvasPattern");if raw.Kind~="CanvasPattern"then fail("TypeError","Expected CanvasPattern")end;local m=matrix(arg(args,1));local fields={a=m[1],b=m[2],c=m[3],d=m[4],e=m[5],f=m[6]};raw.Get("setTransform")({fields});return U end)
	function api:Method(node,key)
		if not canvas(node)or(key~="getContext"and key~="toDataURL"and key~="toBlob")then return nil end
		local entries=methods[node];if not entries then entries={};methods[node]=entries end
		if not entries[key]then entries[key]=native(key,if key=="getContext"or key=="toBlob"then 1 else 0,function(args,receiver)
			if options.Unwrap(receiver)~=node then fail("TypeError","Illegal HTMLCanvasElement receiver")end
			if key=="getContext"then
				if #args<1 then fail("TypeError","getContext requires a context identifier")end;local family=text(args[1]);if family~="2d"then return N end
				local value=byNode[node];if value then return value end
				local settings={alpha=true,colorSpace="srgb",colorType="unorm8",desynchronized=false,willReadFrequently=false};local init=arg(args,2)
				if not nullish(init)then
					for _,key in {"alpha","colorSpace","colorType","desynchronized","willReadFrequently"}do local raw=vm.Get(init,key);if raw~=U then settings[key]=if key=="colorSpace"or key=="colorType"then text(raw)else VM.truth(raw)end end
				end
				if not settings.alpha or settings.colorSpace~="srgb"or settings.colorType~="unorm8"then fail("NotSupportedError","Only transparent sRGB RGBA8 canvas contexts are supported")end
				surface(node)
				value=vm.Object({},contextProto);local s={Node=node,Settings=settings};value.CanvasContextState=s;contexts[value]=s;byNode[node]=value;return value
			elseif key=="toDataURL"then if not nullish(arg(args,1))then text(args[1])end;return surface(node):ToDataURL()
			else local callback=arg(args,1);if not VM.callable(callback)then fail("TypeError","toBlob requires a callback")end
				if not nullish(arg(args,2))then text(args[2])end;local bytes=surface(node):EncodePNG();local blob=if bytes then options.CreateBlob({Bytes=buffer.tostring(bytes),Type="image/png"})else N
				options.QueueTask(function()if not api.Alive then return end;if options.Call then options.Call(callback,{blob},U)else vm:Call(callback,{blob},U)end end);return U
			end
		end)end;return entries[key]
	end
	local function constructor(name,length,proto,create)
		local value=native(name,length,function()fail("TypeError",name.." requires new")end);value.Construct=function(args)
			check();local action=function()if create then return create(args)end;fail("TypeError","Illegal "..name.." constructor")end
			return if options.HostCall then options.HostCall(action)else action()
		end
		define(value,"prototype",{value=proto});define(proto,"constructor",{value=value,writable=true,configurable=true});globals[name]=value;if vm.Global then vm.Global.Bindings[name]={Value=value}end
	end
	constructor("CanvasRenderingContext2D",0,contextProto);constructor("CanvasGradient",0,gradientProto);constructor("CanvasPattern",0,patternProto);constructor("TextMetrics",0,metricsProto)
	constructor("ImageData",2,imageProto,function(args)
		if #args<2 then fail("TypeError","ImageData requires arguments")end
		local desc=binary:Describe(args[1]);local w,h,data
		if desc then
			if desc.Kind~="Uint8ClampedArray"then fail("TypeError","ImageData requires Uint8ClampedArray")end;if desc.Detached then fail("InvalidStateError","ImageData buffer is detached")end
			w=unsigned(args[2]);local length=desc.Length;if length==0 or length%4~=0 or w==0 then fail("InvalidStateError","Invalid ImageData buffer or width")end
			h=if arg(args,3)==U then length/(4*w)else unsigned(args[3]);if h~=math.floor(h)or h*4*w~=length then fail("IndexSizeError","ImageData buffer dimensions disagree")end;data=args[1];colorSpace(arg(args,4))
		else w,h=unsigned(args[1]),unsigned(args[2]);colorSpace(arg(args,3));if w==0 or h==0 then fail("IndexSizeError","ImageData dimensions cannot be zero")end;bounds(w,h);local backing=binary:Buffer(string.rep("\0",w*h*4));data=binary:CreateView("Uint8ClampedArray",backing,0,w*h*4)end
		bounds(w,h);return imageData(w,h,data)
	end)
	for _,pair in {{"width","Width"},{"height","Height"},{"data","Data"}}do local key,field=pair[1],pair[2];accessor(imageProto,key,function(value)return state(images,value,"ImageData")[field]end)end
	accessor(imageProto,"colorSpace",function(value)state(images,value,"ImageData");return "srgb"end)
	for _,pair in {{contextProto,"CanvasRenderingContext2D"},{imageProto,"ImageData"},{gradientProto,"CanvasGradient"},{patternProto,"CanvasPattern"},{metricsProto,"TextMetrics"}}do if vm.SymbolToStringTag then define(pair[1],vm.SymbolToStringTag,{value=pair[2],configurable=true})end end
	function api:Destroy()if not self.Alive then return end;self.Alive=false;paths:Destroy();for _,map in {contexts,images,paints,byNode,methods}do table.clear(map)end end
	return api
end
return DOMCanvas
