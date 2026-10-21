--!strict
--!optimize 2
local Triangle=require(script.Parent.CanvasTriangle)
local WebGPU={}
local function get(value,key)if type(value)=="table"and value.Get then return value.Get(key)elseif type(value)=="table"then return if value.Kind=="object"and value.Values then value.Values[key]else value[key]end;return nil end
local function items(value)return if type(value)=="table"then value.Items or value.Values or{}else{}end
local function number(value,default)local result=tonumber(value);return if result and result==result and math.abs(result)<math.huge then result else default end
local function object(kind,fields)fields=fields or{};fields.Kind=kind;fields.Get=function(key)local value=fields[key];return if value==nil then nil else value end;return fields end
local function promise(value,defer,undefined)
	local result;result=object("Promise",{thenValue=function(args)local callback=args[1];assert(callback~=nil and callback~=undefined,"Promise.then requires a callback");defer(callback,{value});return result end});result.Get=function(key)if key=="then"then return result.thenValue end;return undefined end;return result
end
local function formatSize(format)local found=type(format)=="string"and format:match("float32x(%d)");return tonumber(found)or(if format=="float32"then 1 else 0)end

function WebGPU.new(defer: any,undefined: any,readProperty: any?): any
	local get=readProperty or get
	local manager={Contexts={}}
	local queue
	local device
	local function rasterPass(pass)
		local view=pass.View;local surface=view and view.Surface;if not surface then return end
		if pass.LoadOp=="clear"then local color=pass.ClearColor or{};Triangle.clear(surface,number(get(color,"r"),0),number(get(color,"g"),0),number(get(color,"b"),0),number(get(color,"a"),1))end
		local pipeline,vertexBuffer=pass.Pipeline,pass.VertexBuffers[0];if not pipeline or not vertexBuffer then return end
		local vertex=get(pipeline.Descriptor,"vertex");local layouts=items(get(vertex,"buffers"));local layout=layouts[1];if not layout then return end;local stride=math.max(1,number(get(layout,"arrayStride"),0)/4);local attributes=items(get(layout,"attributes"));local byLocation={}
		for _,attribute in attributes do byLocation[number(get(attribute,"shaderLocation"),0)]=attribute end
		local position,color=byLocation[0],byLocation[1];if not position then return end
		local positionSize,colorSize=formatSize(get(position,"format")),formatSize(color and get(color,"format"));if positionSize<2 then return end
		local values=vertexBuffer.Values;local positionOffset=number(get(position,"offset"),0)/4;local colorOffset=if color then number(get(color,"offset"),0)/4 else 0
		local function component(offset,size,index,channel,default)
			if channel>=size then return default end;return number(values[offset+index*stride+channel+1],default)
		end
		local function vertexAt(index)
			local x,y=component(positionOffset,positionSize,index,0,0),component(positionOffset,positionSize,index,1,0)
			return{X=(x*.5+.5)*surface.Width,Y=(1-(y*.5+.5))*surface.Height,R=component(colorOffset,colorSize,index,0,1),G=component(colorOffset,colorSize,index,1,1),B=component(colorOffset,colorSize,index,2,1),A=component(colorOffset,colorSize,index,3,1)}
		end
		local first,count=pass.FirstVertex,pass.VertexCount;assert(count<=65535,"WebGPU draw vertex limit exceeded");for index=first,first+count-3,3 do Triangle.draw(surface,vertexAt(index),vertexAt(index+1),vertexAt(index+2))end
	end
	queue=object("GPUQueue",{})
	queue.writeBuffer=function(args)local target,byteOffset,data=args[1],math.max(0,math.floor(number(args[2],0))),args[3];assert(target and target.Kind=="GPUBuffer"and data and data.Values,"queue.writeBuffer expects GPUBuffer and typed data");local start=math.floor(byteOffset/4)+1;assert(start+#data.Values-1<=#target.Values,"queue.writeBuffer exceeds buffer size");for index,value in data.Values do target.Values[start+index-1]=value end end
	queue.submit=function(args)for _,commandBuffer in items(args[1])do for _,pass in commandBuffer.Passes do rasterPass(pass)end end end
	local queueGet=queue.Get;queue.Get=function(key)if key=="writeBuffer"then return queue.writeBuffer elseif key=="submit"then return queue.submit end;return queueGet(key)end
	device=object("GPUDevice",{queue=queue})
	local deviceMethods={}
	function deviceMethods.createShaderModule(args)local descriptor=args[1];return object("GPUShaderModule",{Code=tostring(get(descriptor,"code")or"")})end
	function deviceMethods.createBuffer(args)local descriptor=args[1];local size=math.floor(number(get(descriptor,"size"),0));assert(size>0 and size<=4194304,"GPUBuffer size is invalid");local values={};for _=1,math.ceil(size/4)do table.insert(values,0)end;return object("GPUBuffer",{Size=size,Values=values,unmap=function()end,destroy=function(callArgs)local _=callArgs end})end
	function deviceMethods.createRenderPipeline(args)return object("GPURenderPipeline",{Descriptor=args[1]})end
	function deviceMethods.createRenderPipelineAsync(args)return promise(deviceMethods.createRenderPipeline(args),defer,undefined)end
	function deviceMethods.createCommandEncoder()
		local encoder=object("GPUCommandEncoder",{Passes={}});local encoderMethods={}
		function encoderMethods.beginRenderPass(args)
			local descriptor=args[1];local attachments=items(get(descriptor,"colorAttachments"));local attachment=attachments[1];assert(attachment,"A color attachment is required")
			local pass={Kind="GPURenderPassEncoder",View=get(attachment,"view"),LoadOp=get(attachment,"loadOp")or"load",ClearColor=get(attachment,"clearValue"),Pipeline=nil,VertexBuffers={},VertexCount=0,FirstVertex=0,Ended=false};local methods={}
			function methods.setPipeline(callArgs)pass.Pipeline=callArgs[1]end
			function methods.setVertexBuffer(callArgs)pass.VertexBuffers[math.floor(number(callArgs[1],0))]=callArgs[2]end
			function methods.draw(callArgs)pass.VertexCount=math.max(0,math.floor(number(callArgs[1],0)));pass.FirstVertex=math.max(0,math.floor(number(callArgs[3],0)))end
			function methods.endPass()pass.Ended=true end;methods["end"]=methods.endPass
			pass.Get=function(key)return methods[key]or undefined end;table.insert(encoder.Passes,pass);return pass
		end
		function encoderMethods.finish()return object("GPUCommandBuffer",{Passes=encoder.Passes})end
		encoder.Get=function(key)return encoderMethods[key]or undefined end;return encoder
	end
	local deviceGet=device.Get;device.Get=function(key)return deviceMethods[key]or deviceGet(key)end
	local adapter=object("GPUAdapter",{})
	local adapterGet=adapter.Get;adapter.Get=function(key)if key=="requestDevice"then return function()return promise(device,defer,undefined)end end;return adapterGet(key)end
	local gpu=object("GPU",{})
	local gpuGet=gpu.Get;gpu.Get=function(key)if key=="requestAdapter"then return function()return promise(adapter,defer,undefined)end elseif key=="getPreferredCanvasFormat"then return function()return"bgra8unorm"end end;return gpuGet(key)end
	manager.GPU=gpu;manager.BufferUsage=object("GPUBufferUsage",{MAP_READ=1,MAP_WRITE=2,COPY_SRC=4,COPY_DST=8,INDEX=16,VERTEX=32,UNIFORM=64,STORAGE=128,INDIRECT=256,QUERY_RESOLVE=512})
	function manager:CreateContext(surface)
		if self.Contexts[surface]then return self.Contexts[surface]end
		local context=object("GPUCanvasContext",{Surface=surface,Configured=false});local methods={}
		function methods.configure(args)local descriptor=args[1];assert(get(descriptor,"device")==device,"GPUCanvasContext.configure needs the requested GPUDevice");context.Configured=true;context.Format=get(descriptor,"format")or"bgra8unorm"end
		function methods.unconfigure()context.Configured=false end
		function methods.getCurrentTexture()assert(context.Configured,"GPUCanvasContext is not configured");local texture=object("GPUTexture",{Surface=surface});local textureGet=texture.Get;texture.Get=function(key)if key=="createView"then return function()return object("GPUTextureView",{Surface=surface})end end;return textureGet(key)end;return texture end
		context.Get=function(key)return methods[key]or undefined end;self.Contexts[surface]=context;return context
	end
	function manager:Destroy()table.clear(self.Contexts)end
	return manager
end
return WebGPU
