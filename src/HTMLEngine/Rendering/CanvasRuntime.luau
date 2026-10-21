--!strict
--!optimize 2
local VM=require(script.Parent.Parent.SVG.ScriptVM)
local Surface=require(script.Parent.CanvasSurface)
local WebGL=require(script.Parent.CanvasWebGL)
local WebGPU=require(script.Parent.CanvasWebGPU)
local WorkBudget=require(script.Parent.WorkBudget)
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
local CanvasRuntime={}
local function text(node)local parts={};local function visit(current)if current.Kind=="Text"then table.insert(parts,current.Text)end;for _,child in current.Children do visit(child)end end;visit(node);return table.concat(parts)end
local function dimension(value,fallback)local digits=value and value:match("^%s*%+?(%d+)");if not digits then return fallback end;return math.min(2048,tonumber(digits)or fallback)end
local function typedArray(kind,maxValue)
	local function construct(args)
		local source=args[1];local values={}
		if type(source)=="number"then assert(source>=0 and source==math.floor(source)and source<=1048576,"Typed array length is invalid");values=table.create(source,0)
		elseif type(source)=="table"then local items=source.Values or source.Items;assert(items,"Typed array source is invalid");assert(#items<=1048576,"Typed array value limit exceeded");values=table.create(#items);for index,value in items do values[index]=tonumber(value)or 0 end
		elseif source~=nil and source~=VM.Undefined then error("Typed array source is invalid")end
		local result={Kind=kind,Values=values}
		local bytesPerElement=if kind=="Uint16Array"then 2 else 4
		local function normalize(value)local numberValue=tonumber(value)or 0;if kind=="Float32Array"then return numberValue end;numberValue=math.floor(numberValue);return numberValue%(maxValue+1)end
		for index,value in values do values[index]=normalize(value)end
		local function setValues(callArgs)local input=callArgs[1];local offset=math.max(0,math.floor(tonumber(callArgs[2])or 0));local items=input and(input.Values or input.Items);assert(items and offset+#items<=#values,"Typed array set exceeds its bounds");for index,value in items do values[offset+index]=normalize(value)end end
		result.Get=function(key)
			if key=="length"then return #values elseif key=="byteLength"then return #values*bytesPerElement end
			if key=="set"then return setValues end
			local index=tonumber(key);return if index and index==math.floor(index)and index>=0 and index<#values then values[index+1]else VM.Undefined
		end
		result.Set=function(key,value)local index=tonumber(key);if index and index==math.floor(index)and index>=0 and index<#values then values[index+1]=normalize(value)end end
		return result
	end
	return {Kind="native-function",Values={name=kind,length=3},Construct=construct,Call=function()VM.throw(VM.error("TypeError",kind.." requires new"))end}
end

function CanvasRuntime.start(page,tree,diagnostic,services,workBudgetMS)
	local asset=if services and services.Asset then services.Asset else game:GetService("AssetService")
	local byId,wrappers,contexts,webglContexts,images,readyCallbacks={},{},{},{},{},{}
	local imageWrappers,sourceCache={},{}
	for _,map in {wrappers,contexts,webglContexts,imageWrappers}do setmetatable(map,{__mode="kv"})end
	setmetatable(sourceCache,{__mode="v"})
	local imageSources=setmetatable({},{__mode="k"})
	local function imageEntry(item)return {Source=item.Source,Attribute=item.Node.Attributes.src,Item=setmetatable({item},{__mode="v"}),Label=item.SelectedSource}end
	local registered,savedByNode,ownedItems={},setmetatable({},{__mode="kv"}),setmetatable({},{__mode="k"})
	local surfaces=setmetatable({},{__mode="k"})
	local runtime={Alive=true,Diagnostics={},Items=tree.CanvasItems};local vm
	local budget=WorkBudget.new(workBudgetMS or 0,services and services.Task,services and services.Clock);runtime.WorkBudget=budget;page.CanvasStats=budget
	local function ensureAlive()
		if not runtime.Alive or page.Alive==false then error("Canvas work cancelled",0)end
	end
	local function checkpoint()
		if budget then budget:Checkpoint()end
		ensureAlive()
	end
	local function publishBudget()if not budget then return end;budget:Finish();if not page.Alive or not page.Root or not page.Root.SetAttribute then return end;page.Root:SetAttribute("CanvasYields",budget.Yields);page.Root:SetAttribute("CanvasWaitMS",budget.WaitMS);page.Root:SetAttribute("CanvasActiveMS",budget.ActiveMS)end
	if budget and page.Root and page.Root.SetAttribute then page.Root:SetAttribute("CanvasYields",0);page.Root:SetAttribute("CanvasWaitMS",0);page.Root:SetAttribute("CanvasActiveMS",0)end
	local function defer(callback,args)ensureAlive();table.insert(readyCallbacks,{Callback=callback,Args=args})end
	local gpuRuntime=WebGPU.new(defer,VM.Undefined,function(value,key)
		if value==nil then return nil end
		return if vm then vm.Get(value,key) else nil
	end)
	local function report(message)local value=tostring(message);table.insert(runtime.Diagnostics,value);diagnostic("canvas-script: "..value)end
	local function drainReady()
		local delivered=0
		while #readyCallbacks>0 do local callbacks=readyCallbacks;readyCallbacks={};for _,entry in callbacks do ensureAlive();delivered+=1;assert(delivered<=128,"Canvas deferred callback limit exceeded");vm:Call(entry.Callback,entry.Args)end end
	end
	local function upload(item)
		ensureAlive()
		local surface=item.CanvasSurface;if not surface then return end;local dirty,bounds=surface:TakeDirtyRegion();if not dirty or not item.CanvasImage then return end
		if not bounds then item.CanvasImage:WritePixelsBuffer(Vector2.new(0,0),Vector2.new(surface.Width,surface.Height),surface.Pixels);return end
		local x0,y0,x1,y1=bounds[1],bounds[2],bounds[3],bounds[4];local width,height=x1-x0+1,y1-y0+1;local length=width*height*4
		local pixels=item.CanvasUploadBuffer;if not pixels or buffer.len(pixels)~=length then pixels=buffer.create(length);item.CanvasUploadBuffer=pixels end
		for row=0,height-1 do buffer.copy(pixels,row*width*4,surface.Pixels,((y0+row)*surface.Width+x0)*4,width*4)end
		item.CanvasImage:WritePixelsBuffer(Vector2.new(x0,y0),Vector2.new(width,height),pixels)
	end
	local animationEpoch=os.clock();local animationConnection:any=nil;local animationBusy=false;local nextFrameId=0;local pendingFrameCount=0;local pendingFrames={};local pendingFrameOrder={};local runningFrames={};local cancelledFrames={}
	local function stopAnimationConnection()
		if animationConnection then animationConnection:Disconnect();animationConnection=nil end
	end
	local function ensureAnimationConnection()
		if animationConnection then return end
		local runner=if services and services.RunService then services.RunService else game:GetService("RunService");local signal=runner.RenderStepped or runner.Heartbeat
		assert(signal and signal.Connect,"Canvas animation requires RunService.RenderStepped or Heartbeat")
		animationConnection=signal:Connect(function()
			if not runtime.Alive then stopAnimationConnection();return end;if animationBusy then return end;animationBusy=true;if budget then budget:Reset()end
			local completed,problem=pcall(function()
				local callbacks,order=pendingFrames,pendingFrameOrder;pendingFrames={};pendingFrameOrder={};pendingFrameCount=0;runningFrames=callbacks;local timestamp=(os.clock()-animationEpoch)*1000
				for _,id in order do
					if not runtime.Alive or page.Alive==false then return end
					local callback=callbacks[id];if not callback then continue end
					if cancelledFrames[id]then cancelledFrames[id]=nil;continue end
					local ok,message=pcall(function()vm:Call(callback,{timestamp})end);if not ok and runtime.Alive and page.Alive~=false then report(message)end
				end
				local drained,message=pcall(drainReady);if not drained and runtime.Alive then report(message)end
				runningFrames={};if not runtime.Alive or page.Alive==false then return end;for _,item in tree.CanvasItems do upload(item)end;publishBudget()
			end)
			animationBusy=false;if not completed and runtime.Alive then report(problem)end;if pendingFrameCount==0 then stopAnimationConnection()end
		end)
	end
	local function requestAnimationFrame(args)
		ensureAlive()
		local callback=args[1];assert(callback~=nil and callback~=VM.Undefined,"requestAnimationFrame requires a callback");assert(pendingFrameCount<128,"Canvas animation callback limit exceeded")
		nextFrameId+=1;pendingFrames[nextFrameId]=callback;table.insert(pendingFrameOrder,nextFrameId);pendingFrameCount+=1;ensureAnimationConnection();return nextFrameId
	end
	local function cancelAnimationFrame(args)
		local id=args[1];if type(id)~="number"then return VM.Undefined end
		if pendingFrames[id]then pendingFrames[id]=nil;pendingFrameCount-=1 elseif runningFrames[id]then cancelledFrames[id]=true end;return VM.Undefined
	end
	function runtime:Destroy()
		if not self.Alive then return end
		self.Alive=false;stopAnimationConnection()
		table.clear(pendingFrames);table.clear(pendingFrameOrder);table.clear(runningFrames);table.clear(cancelledFrames);pendingFrameCount=0
		if vm then vm:Destroy()end
		gpuRuntime:Destroy()
		for _,image in images do pcall(function()image:Destroy()end)end
		for item in ownedItems do item.CanvasImage=nil;item.CanvasUploadBuffer=nil;item.CanvasSurface=nil;item.ContextKind=nil end
		for _,item in tree.ImageItems or {}do item.CanvasImageSource=nil end
		table.clear(images);table.clear(byId);table.clear(wrappers);table.clear(contexts);table.clear(webglContexts)
		table.clear(imageWrappers);table.clear(sourceCache);table.clear(imageSources);table.clear(readyCallbacks)
		table.clear(registered);table.clear(savedByNode);table.clear(ownedItems);table.clear(surfaces)
	end
	-- Own partial initialization before any allocation or yielding source load.
	page.CanvasRuntime=runtime;page:AddCleanup(function()runtime:Destroy()end)
	local methodNames={fillRect="FillRect",clearRect="ClearRect",strokeRect="StrokeRect",drawImage="DrawImage",fillText="FillText",strokeText="StrokeText",measureText="MeasureText",createImageData="CreateImageData",getImageData="GetImageData",putImageData="PutImageData",beginPath="BeginPath",moveTo="MoveTo",lineTo="LineTo",closePath="ClosePath",rect="Rect",arc="Arc",arcTo="ArcTo",ellipse="Ellipse",quadraticCurveTo="QuadraticCurveTo",bezierCurveTo="BezierCurveTo",fill="Fill",stroke="Stroke",clip="Clip",createLinearGradient="CreateLinearGradient",createRadialGradient="CreateRadialGradient",createPattern="CreatePattern",save="Save",restore="Restore",translate="Translate",scale="Scale",rotate="Rotate",transform="Transform",setTransform="SetTransform",resetTransform="ResetTransform"}
	local function context(item)
		if contexts[item]then return contexts[item]end
		local wrapper={};local bound={};wrapper.Get=function(key)local value=item.CanvasSurface:Get(key);if value~=nil then return value end;local name=methodNames[key];if not name then return VM.Undefined end;local method=bound[name];if not method then method=function(args)return item.CanvasSurface[name](item.CanvasSurface,table.unpack(args))end;bound[name]=method end;return method end;wrapper.Set=function(key,value)item.CanvasSurface:Set(key,value)end;contexts[item]=wrapper;return wrapper
	end
	local function canvas(item)
		if wrappers[item]then return wrappers[item]end
		local wrapper={CanvasSource=item.CanvasSurface}
		local function getContext(args)
			local requested=args[1];local family=if requested=="experimental-webgl"then"webgl"else requested
			if family~="2d"and family~="webgl"and family~="webgl2"and family~="webgpu"then return VM.Null end
			if item.ContextKind and item.ContextKind~=family then return VM.Null end;item.ContextKind=family
			if family=="2d"then return context(item)elseif family=="webgpu"then return gpuRuntime:CreateContext(item.CanvasSurface)end
			if not webglContexts[item]then webglContexts[item]=WebGL.new(item.CanvasSurface,if family=="webgl2"then 2 else 1)end;return webglContexts[item]
		end
		local function toDataURL()return item.CanvasSurface:ToDataURL()end
		local function toBlob(args)
			local callback=args[1];assert(callback~=nil and callback~=VM.Undefined,"canvas.toBlob requires a callback")
			local bytes=item.CanvasSurface:EncodePNG();local blob=if bytes then{Kind="Blob",Bytes=bytes,Get=function(property)if property=="size"then return buffer.len(bytes)elseif property=="type"then return"image/png"end;return VM.Undefined end}else VM.Null
			defer(callback,{blob});return VM.Undefined
		end
		wrapper.Get=function(key)
			if key=="width"then return item.CanvasSurface.Width elseif key=="height"then return item.CanvasSurface.Height
			elseif key=="getContext"then return getContext elseif key=="toDataURL"then return toDataURL elseif key=="toBlob"then return toBlob end
			return VM.Undefined
		end;wrappers[item]=wrapper;return wrapper
	end
	function runtime:Add(additions)
	ensureAlive()
	for _,item in additions do
		if registered[item] then continue end
		local ticket={};registered[item]=ticket;ownedItems[item]=true
		local saved=savedByNode[item.Node]
		if saved and saved~=item then
			item.CanvasSurface,item.ContextKind=saved.CanvasSurface,saved.ContextKind
			contexts[item],webglContexts[item],wrappers[item]=contexts[saved],webglContexts[saved],wrappers[saved]
		end
		savedByNode[item.Node]=nil
		local width,height=dimension(item.Node.Attributes.width,300),dimension(item.Node.Attributes.height,150)
		item.CanvasSurface=surfaces[item.Node]or item.CanvasSurface or Surface.new(width,height,if budget then checkpoint else nil);surfaces[item.Node]=item.CanvasSurface
		item.CanvasSurface.ReadProperty=function(value,key)return if vm then vm.Get(value,key)elseif value.Values then value.Values[key]else value[key]end
		width,height=item.CanvasSurface.Width,item.CanvasSurface.Height
		local surface=item.CanvasSurface
		if item.Node.Attributes.id then byId[item.Node.Attributes.id]=item end
		if width>0 and height>0 then
			local ok,image=pcall(function()return asset:CreateEditableImage({Size=Vector2.new(width,height)})end)
			if ok and image then
				if not runtime.Alive or page.Alive==false or registered[item]~=ticket or item.CanvasSurface~=surface then image:Destroy();ensureAlive();continue end
				item.CanvasImage=image;table.insert(images,image);item.ImageGui.ImageContent=Content.fromObject(image)
				image:WritePixelsBuffer(Vector2.new(0,0),Vector2.new(width,height),item.CanvasSurface.Pixels)
			else ensureAlive();report("EditableImage unavailable for canvas "..(item.Node.Attributes.id or"(without id)"))end
		end
	end
	end
	function runtime:Remove(removals)
		for _,item in removals do
			if not registered[item] then continue end
			registered[item]=nil;savedByNode[item.Node]=item
			local id=item.Node.Attributes.id;if id and byId[id]==item then byId[id]=nil end
			local image=item.CanvasImage;item.CanvasImage=nil;item.CanvasUploadBuffer=nil
			if image then local index=table.find(images,image);if index then table.remove(images,index) end;image:Destroy() end
		end
	end
	function runtime:Resolve(node)
		for item in registered do if item.Node==node then return canvas(item) end end
		local saved=savedByNode[node];return if saved then canvas(saved) else nil
	end
	function runtime:Surface(node,create)
		ensureAlive();local value=surfaces[node];if value or create==false then return value end
		value=Surface.new(dimension(node.Attributes.width,300),dimension(node.Attributes.height,150),if budget then checkpoint else nil);surfaces[node]=value;return value
	end
	function runtime:Reset(node,width,height)
		ensureAlive();local value=Surface.new(width,height,if budget then checkpoint else nil);surfaces[node]=value
		for item in ownedItems do if item.Node~=node then continue end
			item.CanvasSurface=value;item.AttributeWidth,item.AttributeHeight=width,height;item.IntrinsicWidth,item.IntrinsicHeight=width,height
			local wrapped=wrappers[item];if wrapped then wrapped.CanvasSource=value end
			if not registered[item]then continue end
			local image=item.CanvasImage;item.CanvasImage=nil;item.CanvasUploadBuffer=nil
			if image then local index=table.find(images,image);if index then table.remove(images,index)end;image:Destroy()end
			if width==0 or height==0 then if item.ImageGui then item.ImageGui.ImageContent=Content.none end;continue end
			local ticket=registered[item];local ok,replacement=pcall(function()return asset:CreateEditableImage({Size=Vector2.new(width,height)})end)
			if ok and replacement then
				if not runtime.Alive or page.Alive==false or registered[item]~=ticket or surfaces[node]~=value then replacement:Destroy();ensureAlive();continue end
				item.CanvasImage=replacement;table.insert(images,replacement);item.ImageGui.ImageContent=Content.fromObject(replacement);replacement:WritePixelsBuffer(Vector2.new(0,0),Vector2.new(width,height),value.Pixels)
			else ensureAlive();report("EditableImage unavailable for resized canvas")end
		end;return value
	end
	function runtime:Publish(node)
		ensureAlive();if budget then budget:Reset()end
		for item in registered do if item.Node==node then upload(item);break end end;publishBudget()
	end
	local function loadSource(source,label)
		local cached=sourceCache[source];if cached~=nil then return if cached==false then nil else cached end
		local editable;local ok,result=pcall(function()
			editable=asset:CreateEditableImageAsync(Content.fromUri(source));assert(editable,"EditableImage allocation unavailable")
			ensureAlive()
			local size=editable.Size;assert(size.X>=1 and size.Y>=1 and size.X<=2048 and size.Y<=2048 and size.X*size.Y<=4194304,"Canvas source image exceeds the pixel limit")
			local pixels=editable:ReadPixelsBuffer(Vector2.new(0,0),size);ensureAlive()
			return {Width=size.X,Height=size.Y,Pixels=pixels}
		end)
		if editable then editable:Destroy()end
		ensureAlive()
		if ok then sourceCache[source]=result;return result end
		sourceCache[source]=false;report("Canvas source image unavailable: "..tostring(label or source).." ("..tostring(result)..")");return nil
	end
	function runtime:ImageSource(node)
		ensureAlive()
		if not ElementNames.html(node,"img")then return nil end
		local entry=imageSources[node]
		for _,item in tree.ImageItems or {}do if item.Node==node then
			if not entry or entry.Item[1]~=item or entry.Source~=item.Source then entry=imageEntry(item);imageSources[node]=entry end;break
		end end
		-- Detached images may retain decoded pixels. A changed source must never
		-- reuse the previous bitmap while the renderer resolves the new resource.
		if not entry or not entry.Source or entry.Attribute~=node.Attributes.src then return nil end
		local source,attribute=entry.Source,entry.Attribute
		local result=entry.Bitmap or loadSource(source,entry.Label)
		local item=entry.Item[1];if node.Attributes.src~=attribute or(item and item.Source~=source)then return nil end
		if result then entry.Bitmap=result;if item then item.CanvasImageSource=result end end;return result
	end
	local function initialize()
	ensureAlive()
	runtime:Add(tree.CanvasItems or {})
	for _,item in tree.ImageItems or {}do if ElementNames.html(item.Node,"img")then imageSources[item.Node]=imageEntry(item)end end
	if services and services.HostOnly then
		function page:GetCanvasContext(id)local item=byId[id];return item and item.CanvasSurface or nil end
		return
	end

	local function imageElement(item)
		if imageWrappers[item]then return imageWrappers[item]end
		local source=item.CanvasImageSource
		local function thenReady(args)assert(args[1]~=nil,"image.decode().then requires a callback");defer(args[1],{});return VM.Undefined end;local promise={Get=function(key)if key=="then"then return thenReady end;return VM.Undefined end};local function decode()return promise end
		local wrapper={CanvasImageSource=source};wrapper.Get=function(key)if key=="width"or key=="naturalWidth"then return source and source.Width or 0 elseif key=="height"or key=="naturalHeight"then return source and source.Height or 0 elseif key=="complete"then return source~=nil elseif key=="decode"then return decode end;return VM.Undefined end
		imageWrappers[item]=wrapper;return wrapper
	end
	for _,item in tree.ImageItems or {}do
		local id=item.Node and item.Node.Attributes.id;if not id then continue end;byId[id]=item
		if item.Source then item.CanvasImageSource=loadSource(item.Source,item.SelectedSource or id)end
	end

	local function fontsThen(args)assert(args[1]~=nil,"document.fonts.ready.then requires a callback");defer(args[1],{});return VM.Undefined end
	local ready={Get=function(key)if key=="then"then return fontsThen end;return VM.Undefined end}
	local fonts={Get=function(key)if key=="ready"then return ready end;return VM.Undefined end}
	local function getElementById(args)local item=byId[VM.string(args[1])];return if item then(if item.CanvasSurface then canvas(item)else imageElement(item))else VM.Null end
	local document={Get=function(key)
		if key=="getElementById"then return getElementById
		elseif key=="fonts"then return fonts end;return VM.Undefined
	end}
	local function performanceNow()return(os.clock()-animationEpoch)*1000 end;local performance={Get=function(key)if key=="now"then return performanceNow end;return VM.Undefined end}
	local navigator={Get=function(key)if key=="gpu"then return gpuRuntime.GPU end;return VM.Undefined end}
	local function mathCall(fn)return function(args)return fn(table.unpack(args))end end;local mathValues={PI=math.pi};for key,fn in {min=math.min,max=math.max,round=math.round,floor=math.floor,ceil=math.ceil,abs=math.abs,sin=math.sin,cos=math.cos}do mathValues[key]=mathCall(fn)end;local mathObject={Get=function(key)return mathValues[key]or VM.Undefined end}
	vm=VM.new({document=document,navigator=navigator,GPUBufferUsage=gpuRuntime.BufferUsage,Float32Array=typedArray("Float32Array",0),Uint16Array=typedArray("Uint16Array",65535),Uint32Array=typedArray("Uint32Array",4294967295),requestAnimationFrame=requestAnimationFrame,cancelAnimationFrame=cancelAnimationFrame,performance=performance,Math=mathObject}, {MaxSteps=100000,Checkpoint=if budget then checkpoint else nil});runtime.VM=vm
	local scripts={};local function visit(node)if node.Kind=="Element"and node.Name=="script"and node.Attributes["data-canvas-script"]~=nil then table.insert(scripts,node)end;for _,child in node.Children do visit(child)end end;visit(page.Document)
	for _,node in scripts do
		local kind=node.Attributes.type or"text/javascript";if kind~="text/javascript"and kind~="application/javascript"then report("Unsupported canvas script type: "..kind);continue end
		if budget then budget:Reset()end;local ok,message=pcall(function()vm:Run(text(node));drainReady()end);ensureAlive();if not ok then report(message)end;for _,item in tree.CanvasItems do upload(item)end;publishBudget()
	end
	function page:GetCanvasContext(id)local item=byId[id];return item and item.CanvasSurface or nil end
	end
	local ok,message=pcall(initialize)
	if not ok then runtime:Destroy();error(message,0)end
	return runtime
end
return CanvasRuntime
