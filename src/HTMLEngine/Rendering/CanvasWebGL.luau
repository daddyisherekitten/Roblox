--!strict
--!optimize 2
local Triangle=require(script.Parent.CanvasTriangle)
local WebGL={}
local CONSTANTS={DEPTH_BUFFER_BIT=0x00000100,STENCIL_BUFFER_BIT=0x00000400,COLOR_BUFFER_BIT=0x00004000,POINTS=0x0000,LINES=0x0001,TRIANGLES=0x0004,ARRAY_BUFFER=0x8892,ELEMENT_ARRAY_BUFFER=0x8893,STATIC_DRAW=0x88e4,DYNAMIC_DRAW=0x88e8,FLOAT=0x1406,UNSIGNED_SHORT=0x1403,VERTEX_SHADER=0x8b31,FRAGMENT_SHADER=0x8b30,COMPILE_STATUS=0x8b81,LINK_STATUS=0x8b82,NO_ERROR=0,VERSION=0x1f02,SHADING_LANGUAGE_VERSION=0x8b8c,VENDOR=0x1f00,RENDERER=0x1f01}
local function number(value,default)local result=tonumber(value);return if result and result==result and math.abs(result)<math.huge then result else default end
local function object(kind,fields)
	fields=fields or{};fields.Kind=kind;fields.Get=function(key)local value=fields[key];return if value==nil then nil else value end;return fields
end
function WebGL.new(surface: any,version: number): any
	local state={Clear={0,0,0,0},Viewport={0,0,surface.Width,surface.Height},Bound={},Attributes={},Program=nil,NextAttribute=0,Error=0}
	local context={Kind=if version==2 then"WebGL2RenderingContext"else"WebGLRenderingContext"}
	local methods={}
	function methods.createShader(args)return object("WebGLShader",{Type=args[1],Source="",Compiled=false,Info=""})end
	function methods.shaderSource(args)local shader=args[1];assert(shader and shader.Kind=="WebGLShader","shaderSource expects WebGLShader");shader.Source=tostring(args[2]or"")end
	function methods.compileShader(args)local shader=args[1];assert(shader and shader.Kind=="WebGLShader","compileShader expects WebGLShader");shader.Compiled=shader.Source:find("void%s+main%s*%(")~=nil;shader.Info=if shader.Compiled then""else"Shader source needs void main()"end
	function methods.getShaderParameter(args)local shader=args[1];return args[2]==CONSTANTS.COMPILE_STATUS and shader and shader.Compiled==true end
	function methods.getShaderInfoLog(args)return(args[1]and args[1].Info)or""end
	function methods.deleteShader(args)if args[1]then args[1].Deleted=true end end
	function methods.createProgram()return object("WebGLProgram",{Shaders={},Linked=false,Info="",Locations={}})end
	function methods.attachShader(args)local program,shader=args[1],args[2];assert(program and program.Kind=="WebGLProgram"and shader and shader.Kind=="WebGLShader","attachShader expects program and shader");table.insert(program.Shaders,shader)end
	function methods.linkProgram(args)local program=args[1];local vertex,fragment=false,false;for _,shader in program.Shaders do if shader.Compiled and shader.Type==CONSTANTS.VERTEX_SHADER then vertex=true elseif shader.Compiled and shader.Type==CONSTANTS.FRAGMENT_SHADER then fragment=true end end;program.Linked=vertex and fragment;program.Info=if program.Linked then""else"Compiled vertex and fragment shaders are required"end
	function methods.getProgramParameter(args)local program=args[1];return args[2]==CONSTANTS.LINK_STATUS and program and program.Linked==true end
	function methods.getProgramInfoLog(args)return(args[1]and args[1].Info)or""end
	function methods.useProgram(args)local program=args[1];assert(program==nil or program.Linked,"useProgram expects a linked program");state.Program=program end
	function methods.deleteProgram(args)if args[1]then args[1].Deleted=true end end
	function methods.getAttribLocation(args)local program,name=args[1],tostring(args[2]);assert(program and program.Kind=="WebGLProgram","getAttribLocation expects WebGLProgram");if program.Locations[name]==nil then program.Locations[name]=state.NextAttribute;state.NextAttribute+=1 end;return program.Locations[name]end
	function methods.createBuffer()return object("WebGLBuffer",{Values={},ArrayKind="Float32Array"})end
	function methods.bindBuffer(args)local target=args[1];assert(target==CONSTANTS.ARRAY_BUFFER or target==CONSTANTS.ELEMENT_ARRAY_BUFFER,"Unsupported WebGL buffer target");state.Bound[target]=args[2]end
	function methods.bufferData(args)local target,data=args[1],args[2];local targetBuffer=state.Bound[target];assert(targetBuffer and targetBuffer.Kind=="WebGLBuffer","No WebGL buffer is bound");assert(type(data)=="table"and data.Values,"bufferData expects a typed array");assert(#data.Values<=1048576,"WebGL buffer value limit exceeded");targetBuffer.Values=table.clone(data.Values);targetBuffer.ArrayKind=data.Kind end
	function methods.deleteBuffer(args)if args[1]then args[1].Deleted=true end end
	function methods.enableVertexAttribArray(args)local index=args[1];state.Attributes[index]=state.Attributes[index]or{};state.Attributes[index].Enabled=true end
	function methods.disableVertexAttribArray(args)local index=args[1];state.Attributes[index]=state.Attributes[index]or{};state.Attributes[index].Enabled=false end
	function methods.vertexAttribPointer(args)local index,size,dataType,normalized,stride,offset=args[1],args[2],args[3],args[4],args[5],args[6];assert(dataType==CONSTANTS.FLOAT and size>=1 and size<=4,"Only float WebGL attributes with one to four components are supported");local bound=state.Bound[CONSTANTS.ARRAY_BUFFER];assert(bound,"No ARRAY_BUFFER is bound");state.Attributes[index]={Enabled=state.Attributes[index]and state.Attributes[index].Enabled or false,Buffer=bound,Size=size,Normalized=normalized==true,Stride=number(stride,0),Offset=number(offset,0)}end
	function methods.clearColor(args)state.Clear={number(args[1],0),number(args[2],0),number(args[3],0),number(args[4],0)}end
	function methods.clear(args)if bit32.band(number(args[1],0),CONSTANTS.COLOR_BUFFER_BIT)~=0 then Triangle.clear(surface,table.unpack(state.Clear))end end
	function methods.viewport(args)state.Viewport={number(args[1],0),number(args[2],0),math.max(0,number(args[3],surface.Width)),math.max(0,number(args[4],surface.Height))}end
	local function attributeFor(namePattern,fallback)
		if state.Program then for name,index in state.Program.Locations do local attribute=state.Attributes[index];if name:lower():find(namePattern)and attribute and attribute.Enabled then return attribute end end end
		for _,attribute in state.Attributes do if attribute.Enabled and(not fallback or attribute.Size>=fallback)then return attribute end end
		return nil
	end
	local function component(attribute,vertex,index,default)
		if not attribute or index>=attribute.Size then return default end;local stride=if attribute.Stride==0 then attribute.Size else attribute.Stride/4;local offset=attribute.Offset/4+vertex*stride+index;return number(attribute.Buffer.Values[offset+1],default)
	end
	local function vertexReader()
		local position=attributeFor("pos",2);assert(position,"drawArrays needs an enabled position attribute");local color=attributeFor("col",3);local viewport=state.Viewport
		return function(index)local x,y=component(position,index,0,0),component(position,index,1,0);return{X=viewport[1]+(x*.5+.5)*viewport[3],Y=surface.Height-viewport[2]-(y*.5+.5)*viewport[4],R=component(color,index,0,1),G=component(color,index,1,1),B=component(color,index,2,1),A=component(color,index,3,1)}end
	end
	local function ready(count)local program=state.Program;assert(program and program.Linked,"draw call needs a linked active program");assert(count<=65535,"WebGL draw vertex limit exceeded");return if count>=3 then vertexReader()else nil end
	function methods.drawArrays(args)assert(args[1]==CONSTANTS.TRIANGLES,"Only TRIANGLES are supported");local first,count=math.max(0,math.floor(number(args[2],0))),math.max(0,math.floor(number(args[3],0)));local vertex=ready(count);if not vertex then return end;for index=first,first+count-3,3 do Triangle.draw(surface,vertex(index),vertex(index+1),vertex(index+2))end end
	function methods.drawElements(args)assert(args[1]==CONSTANTS.TRIANGLES and args[3]==CONSTANTS.UNSIGNED_SHORT,"Only UNSIGNED_SHORT TRIANGLES are supported");local source=state.Bound[CONSTANTS.ELEMENT_ARRAY_BUFFER];assert(source,"No ELEMENT_ARRAY_BUFFER is bound");local count=math.max(0,math.floor(number(args[2],0)));local first=math.floor(number(args[4],0)/2);if count>0 then assert(first>=0 and first+count<=#source.Values,"drawElements exceeds the element buffer")end;local vertex=ready(count);if not vertex then return end;for index=first+1,first+count-2,3 do Triangle.draw(surface,vertex(math.floor(number(source.Values[index],0))),vertex(math.floor(number(source.Values[index+1],0))),vertex(math.floor(number(source.Values[index+2],0))))end end
	function methods.getParameter(args)local key=args[1];if key==CONSTANTS.VERSION then return if version==2 then"WebGL 2.0 Roblox CPU"else"WebGL 1.0 Roblox CPU"elseif key==CONSTANTS.SHADING_LANGUAGE_VERSION then return"WebGL GLSL ES 1.00 bounded"elseif key==CONSTANTS.VENDOR then return"Roblox HTMLEngine"elseif key==CONSTANTS.RENDERER then return"Canvas CPU rasterizer"end;return nil end
	function methods.getContextAttributes()return object("WebGLContextAttributes",{alpha=true,antialias=false,depth=false,stencil=false,premultipliedAlpha=true,preserveDrawingBuffer=true})end
	function methods.getError()local value=state.Error;state.Error=0;return value end
	function methods.flush()end;function methods.finish()end;function methods.enable()end;function methods.disable()end
	context.Get=function(key)if key=="drawingBufferWidth"then return surface.Width elseif key=="drawingBufferHeight"then return surface.Height elseif CONSTANTS[key]~=nil then return CONSTANTS[key]elseif methods[key]then return methods[key]end;return nil end
	return context
end
return WebGL
