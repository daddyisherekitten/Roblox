--!strict
return function(Parser,Node,DOM,VM,Events,HostEvents,BinaryData,DOMCanvas,Surface)
	local document=Parser.parseDocument('<html><body><canvas id="a" width="8" height="8"></canvas><canvas id="b" width="8" height="8"></canvas><img id="image"></body></html>')
	local vm,canvas;local surfaces,tasks={},{};local publications,hostCalls=0,0
	local bridge=DOM.new(document,{Events=Events.new(error),Window={},Changed=function()end,
		ElementGet=function(node,key)if not canvas then return nil end;local method=canvas:Method(node,key);if method then return method end;local handled,value=canvas:Get(node,key);return if handled then value else nil end,
		ElementSet=function(node,key,value,strict)return canvas and canvas:Set(node,key,value,strict)end,
		AttributeChanged=function(node,key)if canvas then canvas:AttributeChanged(node,key)end end,
		ValidateAttribute=function(node,key,value)if canvas then canvas:ValidateAttribute(node,key,value)end end,
		ValidateDataAttribute=function(node,key,value)if canvas then canvas:ValidateAttribute(node,key,value)end end,
		GetControl=function()return VM.Undefined end,SetControl=function()end,
		Get=function(value,key)return vm.Get(value,key)end,Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end})
	local globals={document=bridge.Document};vm=VM.new(globals,{MaxSteps=100000});bridge.AttachVM(vm)
	local binary=vm:Install(function()return BinaryData.install(vm,globals,{MaxBytes=1048576})end)
	local host=vm:Install(function()return HostEvents.install(vm,globals,{Report=error})end)
	canvas=vm:Install(function()return DOMCanvas.install(vm,globals,{Binary=binary,HostEvents=host,Wrap=bridge.Wrap,Unwrap=bridge.Unwrap,
		HostCall=function(fn)hostCalls+=1;return fn()end,
		ImageSource=function(node)if node.Name~="img"then return nil end;local pixels=buffer.create(4);buffer.writeu8(pixels,1,255);buffer.writeu8(pixels,3,255);return {Width=1,Height=1,Pixels=pixels}end,
		Surface=function(node,create)local surface=surfaces[node];if not surface and create~=false then local _,width=canvas:Get(node,"width");local _,height=canvas:Get(node,"height");surface=Surface.new(width,height);surfaces[node]=surface end;return surface end,
		Reset=function(node,w,h)local surface=Surface.new(w,h);surfaces[node]=surface;return surface end,
		Publish=function()publications+=1 end,Attribute=function(node,key,value)local target=bridge.Wrap(node);return vm:Call(vm.Get(target,"setAttribute"),{key,value},target)end,
		QueueTask=function(fn)table.insert(tasks,fn)end,CreateBlob=function(s)return vm.Object({size=#s.Bytes,type=s.Type,Bytes=s.Bytes})end})end)
	local function get(value,key)return vm.Get(value,key)end
	local function set(value,key,v)return vm.Set(value,key,v,true)end
	local function call(value,key,...)return vm:Call(get(value,key),{...},value)end
	local function errorName(fn,name)local ok,err=pcall(fn);assert(not ok,"Expected "..name);assert(get(VM.exceptionValue(err),"name")==name,VM.string(VM.exceptionValue(err)))end
	local aNode,bNode=Node.findById(document,"a"),Node.findById(document,"b");local a,b=bridge.Wrap(aNode),bridge.Wrap(bNode)
	local ctx=call(a,"getContext","2d");assert(call(a,"getContext","2d")==ctx and get(ctx,"canvas")==a and get(ctx,"constructor")==globals.CanvasRenderingContext2D)
	assert(call(a,"getContext","webgl")==VM.Null and call(a,"getContext","unknown")==VM.Null)
	local unattached=vm:Call(vm.Get(bridge.Document,"createElement"),{"canvas"},bridge.Document).DOMNode
	errorName(function()call(bridge.Wrap(unattached),"getContext","2d",vm.Object({alpha=false}))end,"NotSupportedError");assert(surfaces[unattached]==nil,"Rejected context settings allocate no bitmap")
	set(ctx,"fillStyle","#ff0000");call(ctx,"fillRect","1",true,3,3)
	local data=call(ctx,"getImageData",1,1,1,1);local bytes=get(data,"data")
	assert(get(data,"width")==1 and get(data,"height")==1 and get(bytes,"0")==255 and get(bytes,"1")==0 and get(bytes,"3")==255)
	assert(binary:Describe(bytes).Kind=="Uint8ClampedArray"and get(data,"constructor")==globals.ImageData)
	set(ctx,"fillStyle","invalid-color");assert(get(ctx,"fillStyle")=="#ff0000");set(ctx,"globalAlpha",math.huge);assert(get(ctx,"globalAlpha")==1)
	for _,pair in {{"red","#ff0000"},{"#ff000080","rgba(255, 0, 0, 0.5)"},{"rgba(1,2,3,.123)","rgba(1, 2, 3, 0.12)"},{"transparent","rgba(0, 0, 0, 0)"}}do set(ctx,"fillStyle",pair[1]);assert(get(ctx,"fillStyle")==pair[2],"sRGB paint serialization matches Chromium")end
	call(ctx,"fillRect",0/0,0,8,8);assert(get(get(call(ctx,"getImageData",0,0,1,1),"data"),"3")==0)
	local gradient=call(ctx,"createLinearGradient",0,0,8,0);call(gradient,"addColorStop",0,"blue");call(gradient,"addColorStop",1,"red");set(ctx,"fillStyle",gradient);assert(get(ctx,"fillStyle")==gradient)
	errorName(function()call(gradient,"addColorStop",2,"red")end,"IndexSizeError");errorName(function()call(gradient,"addColorStop",.5,"invalid")end,"SyntaxError")
	errorName(function()call(gradient,"addColorStop",0/0,"red")end,"TypeError")
	call(ctx,"fillRect",0,0,8,8)
	local other=call(b,"getContext","2d");call(other,"drawImage",a,0,0);assert(buffer.tostring(surfaces[aNode].Pixels)==buffer.tostring(surfaces[bNode].Pixels))
	local pattern=call(other,"createPattern",a,"no-repeat");call(pattern,"setTransform",vm.Object({a=2,d=2,e=1}));set(other,"fillStyle",pattern);assert(get(other,"fillStyle")==pattern)
	errorName(function()call(other,"createPattern",a,"bad")end,"SyntaxError")
	call(ctx,"setTransform",vm.Object({a=2,d=3,e=1,f=4}));local matrix=call(ctx,"getTransform");assert(get(matrix,"a")==2 and get(matrix,"d")==3 and get(matrix,"e")==1)
	errorName(function()call(ctx,"setTransform",vm.Object({a=1,m11=2}))end,"TypeError");assert(get(call(ctx,"getTransform"),"a")==2)
	call(ctx,"setTransform",vm.Object({m11=4,m22=5}));assert(get(call(ctx,"getTransform"),"a")==4 and get(call(ctx,"getTransform"),"d")==5,"Matrix aliases can provide missing short names")
	errorName(function()call(ctx,"arc",1,1,-1,0,1)end,"IndexSizeError");call(ctx,"arcTo",0,0,-1,-1,1)
	local fresh=vm:Construct(globals.ImageData,{2,2});assert(get(get(fresh,"data"),"length")==16)
	errorName(function()call(ctx,"getImageData",0,0,0/0,1)end,"TypeError");errorName(function()call(ctx,"getImageData",math.huge,0,1,1)end,"TypeError")
	errorName(function()call(ctx,"createImageData",2147483648,1)end,"TypeError");errorName(function()call(ctx,"putImageData",fresh,0/0,0)end,"TypeError")
	set(get(fresh,"data"),"0",0);set(get(fresh,"data"),"1",255);set(get(fresh,"data"),"3",255);call(other,"putImageData",fresh,0,0)
	assert(get(get(call(other,"getImageData",0,0,1,1),"data"),"1")==255)
	call(other,"drawImage",bridge.Wrap(Node.findById(document,"image")),0,0);assert(get(get(call(other,"getImageData",0,0,1,1),"data"),"1")==255,"DOM image adapters provide CPU pixels to ordinary script drawImage")
	errorName(function()call(other,"drawImage",bridge.Wrap(Node.findById(document,"image").Parent),0,0)end,"TypeError")
	local adopted=vm:Construct(globals.ImageData,{get(fresh,"data"),2});assert(get(adopted,"data")==get(fresh,"data")and get(adopted,"height")==2)
	errorName(function()set(fresh,"width",3)end,"TypeError");errorName(function()call(other,"getImageData",0,0,0,1)end,"IndexSizeError")
	local beforeSurface=surfaces[aNode];call(a,"setAttribute","width","8");assert(surfaces[aNode]~=beforeSurface and call(a,"getContext","2d")==ctx and get(ctx,"fillStyle")=="#000000"and get(call(ctx,"getTransform"),"a")==1,"Same-value canvas dimension writes reset state and pixels, preserving the context wrapper")
	set(a,"height",4);assert(get(a,"height")==4 and surfaces[aNode].Height==4 and call(a,"getContext","2d")==ctx)
	set(ctx,"fillStyle","red");call(ctx,"fillRect",0,0,1,1);call(a,"remove");assert(call(a,"getContext","2d")==ctx and get(get(call(ctx,"getImageData",0,0,1,1),"data"),"0")==255,"Detached canvas retains its CPU buffer and realm context")
	errorName(function()set(a,"width",2049)end,"QuotaExceededError");assert(get(a,"width")==8,"Invalid dimension budgets fail before attribute mutation")
	errorName(function()call(a,"setAttribute","width","2049")end,"QuotaExceededError");assert(get(a,"width")==8,"Detached direct attribute writes retain the same quota validation")
	call(a,"setAttribute","width","2px");assert(get(a,"width")==2 and surfaces[aNode].Width==2)
	local dataURL=call(a,"toDataURL");assert(dataURL:sub(1,22)=="data:image/png;base64,")
	local delivered;call(a,"toBlob",function(args)delivered=args[1]end);assert(delivered==nil and #tasks==1);table.remove(tasks,1)();assert(get(delivered,"type")=="image/png"and get(delivered,"size")>0)
	set(a,"width",0);assert(call(a,"toDataURL")=="data:,");call(a,"toBlob",function(args)delivered=args[1]end);table.remove(tasks,1)();assert(delivered==VM.Null)
	errorName(function()vm:Call(get(ctx,"fillRect"),{0,0,1,1},a)end,"TypeError")
	assert(publications>0 and hostCalls>20,"Canvas calls and constructors enter the optional host-yield boundary");canvas:Destroy();host:Destroy();binary:Destroy();bridge:Destroy();vm:Destroy()
	print("Common realm canvas: stable 2D wrappers, pixel views, transforms, gradients, patterns, PNG tasks, reset and detached bitmap lifetime passed")
end
