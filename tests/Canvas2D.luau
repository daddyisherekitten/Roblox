--!strict
return function(Surface: any,VM: any,Runtime: any,WebGL: any,WorkBudget: any,Parser: any,mediaHTML: string)
	local fakeTime,fakeWaits=0,0
	local directBudget=WorkBudget.new(4,{wait=function()fakeWaits+=1;fakeTime+=.01 end},function()fakeTime+=.001;return fakeTime end)
	assert(directBudget~=nil and WorkBudget.new(0)==nil,"A zero render budget disables cooperative yielding")
	for _=1,20 do directBudget:Checkpoint()end
	directBudget:Finish()
	assert(fakeWaits>0 and directBudget.Yields==fakeWaits and directBudget.WaitMS>0 and directBudget.ActiveMS>0,"WorkBudget yields after its active-time slice and records separate wait time")
	local function rgba(surface: any,x: number,y: number): {number}
		local offset=(y*surface.Width+x)*4
		return {buffer.readu8(surface.Pixels,offset),buffer.readu8(surface.Pixels,offset+1),buffer.readu8(surface.Pixels,offset+2),buffer.readu8(surface.Pixels,offset+3)}
	end
	local function equal(actual: {number},expected: {number},message: string)
		for i=1,4 do assert(math.abs(actual[i]-expected[i])<=2,message.." channel "..i..": "..actual[i])end
	end
	local surface=Surface.new(80,60)
	surface:Set("fillStyle","#ff0000");surface:FillRect(5,5,20,15);equal(rgba(surface,10,10),{255,0,0,255},"fillRect paints opaque CSS color")
	surface:Set("globalAlpha",.5);surface:Set("fillStyle","rgb(0, 0, 255)");surface:FillRect(10,10,20,15);equal(rgba(surface,12,12),{127,0,128,255},"globalAlpha source-over blends")
	surface:ClearRect(12,12,2,2);equal(rgba(surface,12,12),{0,0,0,0},"clearRect restores transparent black")
	surface:Set("globalAlpha",1);surface:Set("strokeStyle","white");surface:Set("lineWidth",3);surface:BeginPath();surface:MoveTo(5,45);surface:LineTo(30,30);surface:LineTo(55,45);surface:Stroke();assert(rgba(surface,30,30)[4]>0,"stroke paints path segments")
	surface:Set("fillStyle","#00ff00");surface:BeginPath();surface:Arc(65,15,10,0,math.pi*2);surface:Fill();equal(rgba(surface,65,15),{0,255,0,255},"arc plus fill paints a circle")
	surface:Save();surface:Set("fillStyle","blue");surface:Restore();assert(surface:Get("fillStyle")=="#00ff00","save/restore preserves drawing state")
	local transformed=Surface.new(120,100);transformed:Set("fillStyle","#ff0000");transformed:Save();transformed:Translate(60,45);transformed:Rotate(math.pi/4);transformed:FillRect(-10,-10,20,20);transformed:Restore();equal(rgba(transformed,60,45),{255,0,0,255},"translate and rotate affect rectangle geometry")
	transformed:Set("fillStyle","#0000ff");transformed:SetTransform(2,0,0,1,10,70);transformed:FillRect(0,0,10,10);equal(rgba(transformed,28,75),{0,0,255,255},"setTransform and nonuniform scale affect rectangles")
	transformed:ResetTransform();transformed:Set("strokeStyle","#00ff00");transformed:Set("lineWidth",3);transformed:BeginPath();transformed:MoveTo(5,50);transformed:QuadraticCurveTo(25,15,45,50);transformed:BezierCurveTo(60,80,80,20,105,50);transformed:Stroke();assert(rgba(transformed,25,32)[4]>0 and rgba(transformed,75,48)[4]>0,"quadratic and cubic curves produce connected path pixels")
	transformed:Set("fillStyle","#ffff00");transformed:BeginPath();transformed:Ellipse(85,20,18,8,math.pi/6,0,math.pi*2);transformed:Fill();equal(rgba(transformed,85,20),{255,255,0,255},"rotated ellipse fills its center")
	transformed:BeginPath();transformed:MoveTo(10,90);transformed:ArcTo(50,90,50,55,12);assert(#transformed.Current.Points>4,"arcTo creates a tangent curve")
	local paints=Surface.new(80,40)
	local linear=paints:CreateLinearGradient(0,0,40,0);linear:AddColorStop(0,"#ff0000");linear:AddColorStop(1,"#0000ff");paints:Set("fillStyle",linear);paints:FillRect(0,0,40,20)
	local left,right=rgba(paints,4,10),rgba(paints,35,10);assert(left[1]>left[3] and right[3]>right[1],"linear gradients interpolate ordered color stops")
	local radial=paints:CreateRadialGradient(60,10,0,60,10,10);radial:AddColorStop(0,"#ffffff");radial:AddColorStop(1,"#000000");paints:Set("fillStyle",radial);paints:FillRect(50,0,20,20)
	assert(rgba(paints,60,10)[1]>rgba(paints,68,10)[1],"radial gradients change color with radius")
	local clipped=Surface.new(30,30);clipped:BeginPath();clipped:Arc(15,15,8,0,math.pi*2);clipped:Clip();clipped:Set("fillStyle","#00ff00");clipped:FillRect(0,0,30,30)
	equal(rgba(clipped,15,15),{0,255,0,255},"clip keeps pixels inside its path");equal(rgba(clipped,2,2),{0,0,0,0},"clip rejects pixels outside its path")
	local evenodd=Surface.new(30,30);evenodd:Set("fillStyle","#ff00ff");evenodd:BeginPath();evenodd:Rect(2,2,26,26);evenodd:Rect(9,9,12,12);evenodd:Fill("evenodd")
	equal(rgba(evenodd,5,5),{255,0,255,255},"evenodd fills the outer path");equal(rgba(evenodd,15,15),{0,0,0,0},"evenodd preserves an inner hole")
	local composited=Surface.new(4,1);composited:Set("fillStyle","#ff0000");composited:FillRect(0,0,2,1);composited:Set("globalCompositeOperation","source-in");composited:Set("fillStyle","#0000ff");composited:FillRect(1,0,2,1)
	equal(rgba(composited,0,0),{0,0,0,0},"source-in clears destination outside the new source");equal(rgba(composited,1,0),{0,0,255,255},"source-in keeps only the overlap");equal(rgba(composited,2,0),{0,0,0,0},"source-in rejects source outside the destination")
	local xorSurface=Surface.new(3,1);xorSurface:Set("fillStyle","#ff0000");xorSurface:FillRect(0,0,3,1);xorSurface:Set("globalCompositeOperation","xor");xorSurface:Set("fillStyle","#0000ff");xorSurface:FillRect(1,0,1,1);equal(rgba(xorSurface,1,0),{0,0,0,0},"xor removes an opaque overlap");equal(rgba(xorSurface,0,0),{255,0,0,255},"xor preserves untouched destination pixels")
	local additive=Surface.new(1,1);additive:Set("fillStyle","rgba(255,0,0,0.5)");additive:FillRect(0,0,1,1);additive:Set("globalCompositeOperation","lighter");additive:Set("fillStyle","rgba(0,0,255,0.5)");additive:FillRect(0,0,1,1);equal(rgba(additive,0,0),{128,0,128,255},"lighter adds premultiplied source and destination")
	additive:Save();additive:Set("globalCompositeOperation","destination-out");additive:Restore();assert(additive:Get("globalCompositeOperation")=="lighter","save and restore preserve globalCompositeOperation");additive:Set("globalCompositeOperation","unsupported");assert(additive:Get("globalCompositeOperation")=="lighter","invalid composite operations are ignored")
	local function blended(operation)
		local target=Surface.new(1,1);target:Set("fillStyle","#808080");target:FillRect(0,0,1,1);target:Set("globalCompositeOperation",operation);target:FillRect(0,0,1,1);return rgba(target,0,0)
	end
	equal(blended("multiply"),{64,64,64,255},"multiply blends channels");equal(blended("screen"),{192,192,192,255},"screen blends channels");equal(blended("difference"),{0,0,0,255},"difference blends channels")
	for _,operation in {"overlay","darken","lighten","color-dodge","color-burn","hard-light","soft-light","exclusion"}do local pixel=blended(operation);assert(pixel[4]==255,"blend mode stays opaque: "..operation)end
	local function nonSeparable(operation)
		local target=Surface.new(1,1);target:Set("fillStyle","#d64b2a");target:FillRect(0,0,1,1);target:Set("globalCompositeOperation",operation);target:Set("fillStyle","#2a67d6");target:FillRect(0,0,1,1);return rgba(target,0,0)
	end
	local destination,source={214,75,42},{42,103,214};local function light(pixel)return (.3*pixel[1]+.59*pixel[2]+.11*pixel[3])/255 end;local function sat(pixel)return (math.max(pixel[1],pixel[2],pixel[3])-math.min(pixel[1],pixel[2],pixel[3]))/255 end
	local huePixel=nonSeparable("hue");assert(huePixel[3]>huePixel[1]and huePixel[4]==255,"hue transfers the source hue")
	local saturationPixel=nonSeparable("saturation");assert(math.abs(sat(saturationPixel)-sat(source))<.03,"saturation transfers source saturation")
	local colorPixel=nonSeparable("color");assert(math.abs(light(colorPixel)-light(destination))<.03,"color preserves destination luminosity")
	local luminosityPixel=nonSeparable("luminosity");assert(math.abs(light(luminosityPixel)-light(source))<.03,"luminosity transfers source luminosity")
	local shadowed=Surface.new(32,24);shadowed:Set("shadowColor","#0000ff");shadowed:Set("shadowOffsetX",8);shadowed:Set("shadowOffsetY",5);shadowed:Set("fillStyle","#ff0000");shadowed:FillRect(2,2,6,6)
	equal(rgba(shadowed,4,4),{255,0,0,255},"the source is painted above its shadow");equal(rgba(shadowed,12,9),{0,0,255,255},"shadow offsets move the alpha silhouette")
	local blurredShadow=Surface.new(32,24);blurredShadow:Set("shadowColor","rgba(0,255,0,0.8)");blurredShadow:Set("shadowBlur",8);blurredShadow:Set("fillStyle","#ffffff");blurredShadow:FillRect(13,9,6,6);assert(rgba(blurredShadow,9,12)[4]>0 and rgba(blurredShadow,9,12)[4]<255,"shadowBlur spreads a partial-alpha silhouette")
	blurredShadow:Save();blurredShadow:Set("shadowBlur",2);blurredShadow:Set("shadowOffsetX",7);blurredShadow:Restore();assert(blurredShadow:Get("shadowBlur")==8 and blurredShadow:Get("shadowOffsetX")==0,"save and restore preserve shadow state")
	local textSurface=Surface.new(240,100);textSurface:Set("font","bold 32px Source Sans Pro");textSurface:Set("textAlign","center");textSurface:Set("textBaseline","middle");textSurface:Set("fillStyle","#ffffff")
	local metrics=textSurface:MeasureText("Canvas");assert(metrics.width>70 and metrics:Get("fontBoundingBoxAscent")>20 and metrics.actualBoundingBoxRight>0,"measureText exposes bounded Source Sans Pro metrics")
	textSurface:FillText("Canvas",120,50);local textPixels=0;for y=20,75 do for x=50,190 do if rgba(textSurface,x,y)[4]>0 then textPixels+=1 end end end;assert(textPixels>250,"fillText rasterizes outline glyphs at the requested alignment and baseline")
	textSurface:Save();textSurface:Set("font","italic 14px sans-serif");textSurface:Set("textAlign","right");textSurface:Restore();assert(textSurface:Get("font")=="bold 32px Source Sans Pro"and textSurface:Get("textAlign")=="center","save and restore preserve Canvas text state")
	textSurface:Set("strokeStyle","#ff0000");textSurface:Set("lineWidth",2);textSurface:StrokeText("OK",120,82,30);local strokePixels=0;for y=65,99 do for x=85,155 do if rgba(textSurface,x,y)[1]>200 then strokePixels+=1 end end end;assert(strokePixels>20,"strokeText outlines glyphs and honors maxWidth")
	local sourcePixels=buffer.create(16);local sourceValues={255,0,0,255,0,255,0,255,0,0,255,255,255,255,255,255};for index,value in sourceValues do buffer.writeu8(sourcePixels,index-1,value)end
	local bitmap={Width=2,Height=2,Pixels=sourcePixels};local drawn=Surface.new(12,8);drawn:Set("imageSmoothingEnabled",false);drawn:DrawImage(bitmap,0,0,4,4);equal(rgba(drawn,0,0),{255,0,0,255},"drawImage scales a complete source bitmap");equal(rgba(drawn,3,3),{255,255,255,255},"drawImage preserves the opposite source corner")
	drawn:DrawImage(bitmap,1,0,1,1,4,0,4,4);equal(rgba(drawn,6,2),{0,255,0,255},"the nine-argument drawImage crops before scaling")
	drawn:Save();drawn:Set("imageSmoothingEnabled",true);drawn:Set("imageSmoothingQuality","high");drawn:Restore();assert(not drawn:Get("imageSmoothingEnabled")and drawn:Get("imageSmoothingQuality")=="low","save and restore preserve image smoothing state")
	local patterned=Surface.new(8,6);patterned:Set("imageSmoothingEnabled",false);local repeated=patterned:CreatePattern(bitmap,"repeat");patterned:Set("fillStyle",repeated);patterned:FillRect(0,0,8,6);equal(rgba(patterned,4,4),{255,0,0,255},"createPattern repeats a bitmap on both axes");equal(rgba(patterned,5,4),{0,255,0,255},"repeated pattern coordinates preserve neighboring pixels")
	local single=Surface.new(8,6);single:Set("imageSmoothingEnabled",false);local noRepeat=single:CreatePattern(bitmap,"no-repeat");noRepeat.Get("setTransform")({{Get=function(key)return({a=1,d=1,e=2,f=1})[key]end}});single:Set("fillStyle",noRepeat);single:FillRect(0,0,8,6);equal(rgba(single,2,1),{255,0,0,255},"CanvasPattern.setTransform moves a no-repeat tile");equal(rgba(single,0,0),{0,0,0,0},"no-repeat leaves pixels outside its transformed tile transparent")
	local pixelSurface=Surface.new(4,3);local imageData=pixelSurface:CreateImageData(2,2);imageData.Data.Set(0,300);imageData.Data.Set(1,127.5);imageData.Data.Set(2,-20);imageData.Data.Set(3,255);pixelSurface:SetTransform(5,0,0,5,100,100);pixelSurface:Set("globalAlpha",0);pixelSurface:PutImageData(imageData,1,1);equal(rgba(pixelSurface,1,1),{255,128,0,255},"putImageData clamps channels and ignores transform and globalAlpha")
	local readback=pixelSurface:GetImageData(0,0,3,3);assert(readback.Width==3 and readback.Height==3 and readback.Data.Get("length")==36,"getImageData exposes browser-shaped dimensions and clamped data");assert(readback.Data.Get(16)==255 and readback.Data.Get(17)==128,"getImageData reads back the copied pixel")
	local outside=pixelSurface:GetImageData(-1,-1,2,2);assert(outside.Data.Get(0)==0 and outside.Data.Get(3)==0,"getImageData pads pixels outside the canvas with transparent black")
	local cloned=pixelSurface:CreateImageData(readback);assert(cloned.Width==3 and cloned.Height==3 and cloned.Data.Get(16)==0,"createImageData(ImageData) copies dimensions into a transparent buffer")
	local png=pixelSurface:EncodePNG();assert(buffer.readu8(png,0)==137 and buffer.readu8(png,1)==80 and buffer.readu8(png,2)==78 and buffer.readu8(png,3)==71,"Canvas PNG export writes the required signature");local dataURL=pixelSurface:ToDataURL();assert(dataURL:sub(1,22)=="data:image/png;base64,"and#dataURL>100,"toDataURL returns a non-empty PNG data URL");assert(Surface.new(0,0):ToDataURL()=="data:,","an empty canvas follows the browser data URL sentinel")
	local glSurface=Surface.new(24,20);local gl=WebGL.new(glSurface,1);local function glCall(name,...)return gl.Get(name)({...})end;local vertexShader=glCall("createShader",gl.Get("VERTEX_SHADER"));glCall("shaderSource",vertexShader,"attribute vec2 position; attribute vec3 color; void main(){ gl_Position=vec4(position,0.0,1.0); }");glCall("compileShader",vertexShader);local fragmentShader=glCall("createShader",gl.Get("FRAGMENT_SHADER"));glCall("shaderSource",fragmentShader,"void main(){ }");glCall("compileShader",fragmentShader);local program=glCall("createProgram");glCall("attachShader",program,vertexShader);glCall("attachShader",program,fragmentShader);glCall("linkProgram",program);assert(glCall("getProgramParameter",program,gl.Get("LINK_STATUS")),"WebGL links compiled vertex and fragment shaders");glCall("useProgram",program)
	local vertices={Kind="Float32Array",Values={-0.8,-0.8,1,0,0,0.8,-0.8,0,1,0,0,0.8,0,0,1}};local vertexBuffer=glCall("createBuffer");glCall("bindBuffer",gl.Get("ARRAY_BUFFER"),vertexBuffer);glCall("bufferData",gl.Get("ARRAY_BUFFER"),vertices,gl.Get("STATIC_DRAW"));local positionLocation=glCall("getAttribLocation",program,"position");local colorLocation=glCall("getAttribLocation",program,"color");glCall("enableVertexAttribArray",positionLocation);glCall("vertexAttribPointer",positionLocation,2,gl.Get("FLOAT"),false,20,0);glCall("enableVertexAttribArray",colorLocation);glCall("vertexAttribPointer",colorLocation,3,gl.Get("FLOAT"),false,20,8);glCall("clearColor",0.02,0.04,0.1,1);glCall("clear",gl.Get("COLOR_BUFFER_BIT"));glCall("drawArrays",gl.Get("TRIANGLES"),0,3);local glCenter=rgba(glSurface,12,10);assert(glCenter[4]==255 and glCenter[1]+glCenter[2]+glCenter[3]>100,"WebGL CPU rasterizer interpolates an attribute-colored triangle")
	assert(surface:TakeDirty() and not surface:TakeDirty(),"dirty state is consumed once")

	local document={Kind="Document",Children={},Attributes={}}
	local canvasNode={Kind="Element",Name="canvas",Attributes={id="test",width="20",height="12"},Children={},Parent=document};table.insert(document.Children,canvasNode)
	local webglNode={Kind="Element",Name="canvas",Attributes={id="gl-test",width="24",height="20"},Children={},Parent=document};table.insert(document.Children,webglNode)
	local webgpuNode={Kind="Element",Name="canvas",Attributes={id="gpu-test",width="24",height="20"},Children={},Parent=document};table.insert(document.Children,webgpuNode)
	local imageNode={Kind="Element",Name="img",Attributes={id="source-image",src="test.png"},Children={},Parent=document};table.insert(document.Children,imageNode)
	local scriptNode={Kind="Element",Name="script",Attributes={["data-canvas-script"]=""},Children={{Kind="Text",Text='const c=document.getElementById("test");const x=c.getContext("2d");x.fillStyle="#ff0000";x.fillRect(0,0,10,12);const g=x.createLinearGradient(10,0,20,0);g.addColorStop(0,"#00ff00");g.addColorStop(1,"#0000ff");x.fillStyle=g;x.fillRect(10,0,10,12);const measured=x.measureText("Hi");function afterFonts(){x.font="10px Source Sans Pro";x.fillStyle="#ffffff";x.fillText("Hi",100,100);}document.fonts.ready.then(afterFonts);const picture=document.getElementById("source-image");function afterImage(){x.imageSmoothingEnabled=false;x.drawImage(picture,0,0,2,2);}picture.decode().then(afterImage);const pattern=x.createPattern(c,"no-repeat");pattern.setTransform({a:1,d:1,e:2,f:3});x.fillStyle=pattern;x.fillRect(100,100,1,1);',Children={}}},Parent=document};table.insert(document.Children,scriptNode)
	scriptNode.Children[1].Text..='const pixels=x.createImageData(1,1);pixels.data[0]=300;pixels.data[1]=64;pixels.data[2]=128;pixels.data[3]=255;x.putImageData(pixels,19,11);const copied=x.getImageData(19,11,1,1);x.putImageData(copied,18,11);'
	scriptNode.Children[1].Text..='const exported=c.toDataURL("image/jpeg",0.5);if(exported.length>100){x.fillStyle="#00ff00";x.fillRect(16,10,1,1);}function blobReady(blob){if(blob&&blob.type==="image/png"&&blob.size>100){x.fillStyle="#00ff00";x.fillRect(17,10,1,1);}}c.toBlob(blobReady,"image/png");'
	scriptNode.Children[1].Text..='let animationFrames=0;function animationStep(timestamp){animationFrames=animationFrames+1;if(timestamp>=0){x.fillStyle="#00ffff";x.fillRect(animationFrames,9,1,1);}if(animationFrames<3){requestAnimationFrame(animationStep);}}function cancelledStep(){x.fillStyle="#ff0000";x.fillRect(15,9,1,1);}const cancelledFrame=requestAnimationFrame(cancelledStep);cancelAnimationFrame(cancelledFrame);requestAnimationFrame(animationStep);const animationStart=performance.now();'
	scriptNode.Children[1].Text..='const gc=document.getElementById("gl-test");const gl=gc.getContext("webgl");const vs=gl.createShader(gl.VERTEX_SHADER);gl.shaderSource(vs,"void main(){ }");gl.compileShader(vs);const fs=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(fs,"void main(){ }");gl.compileShader(fs);const gp=gl.createProgram();gl.attachShader(gp,vs);gl.attachShader(gp,fs);gl.linkProgram(gp);gl.useProgram(gp);const gv=new Float32Array([-0.8,-0.8,1,0,0,0.8,-0.8,0,1,0,0,0.8,0,0,1]);const gb=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,gb);gl.bufferData(gl.ARRAY_BUFFER,gv,gl.STATIC_DRAW);const gpl=gl.getAttribLocation(gp,"position");const gcl=gl.getAttribLocation(gp,"color");gl.enableVertexAttribArray(gpl);gl.vertexAttribPointer(gpl,2,gl.FLOAT,false,20,0);gl.enableVertexAttribArray(gcl);gl.vertexAttribPointer(gcl,3,gl.FLOAT,false,20,8);gl.clearColor(0,0,0,1);gl.clear(gl.COLOR_BUFFER_BIT);gl.drawArrays(gl.TRIANGLES,0,3);'
	scriptNode.Children[1].Text..='const wc=document.getElementById("gpu-test");function gpuDevice(device){const context=wc.getContext("webgpu");const format=navigator.gpu.getPreferredCanvasFormat();context.configure({device:device,format:format});const module=device.createShaderModule({code:"bounded"});const pipeline=device.createRenderPipeline({layout:"auto",vertex:{module:module,buffers:[{arrayStride:20,attributes:[{shaderLocation:0,offset:0,format:"float32x2"},{shaderLocation:1,offset:8,format:"float32x3"}]}]},fragment:{module:module,targets:[{format:format}]}});const vertices=new Float32Array([-0.8,-0.8,1,0,0,0.8,-0.8,0,1,0,0,0.8,0,0,1]);const buffer=device.createBuffer({size:vertices.byteLength,usage:GPUBufferUsage.VERTEX+GPUBufferUsage.COPY_DST});device.queue.writeBuffer(buffer,0,vertices);const encoder=device.createCommandEncoder();const pass=encoder.beginRenderPass({colorAttachments:[{view:context.getCurrentTexture().createView(),clearValue:{r:0,g:0,b:0,a:1},loadOp:"clear",storeOp:"store"}]});pass.setPipeline(pipeline);pass.setVertexBuffer(0,buffer);pass.draw(3,1,0,0);pass.end();device.queue.submit([encoder.finish()]);}function gpuAdapter(adapter){adapter.requestDevice().then(gpuDevice);}navigator.gpu.requestAdapter().then(gpuAdapter);'
	local writes,destroys,sourceDestroys=0,0,0;local writeRegions={}
	local image={WritePixelsBuffer=function(_,origin,size)writes+=1;table.insert(writeRegions,{origin.X,origin.Y,size.X,size.Y})end,Destroy=function()destroys+=1 end}
	local item={Node=canvasNode,ImageGui={}};local glItem={Node=webglNode,ImageGui={}};local gpuItem={Node=webgpuNode,ImageGui={}};local sourceItem={Node=imageNode,Source="rbxassetid://1",SelectedSource="test.png"};local runtimePixels=buffer.create(16);for index,value in {12,34,56,255,0,255,0,255,0,0,255,255,255,255,255,255}do buffer.writeu8(runtimePixels,index-1,value)end
	local cleanups={};local page={Alive=true,Document=document,AddCleanup=function(_,fn)table.insert(cleanups,fn)end}
	local diagnostics={};local frameCallback;local animationDisconnects=0;local renderSignal={Connect=function(_,callback)frameCallback=callback;return{Disconnect=function()animationDisconnects+=1;frameCallback=nil end}end}
	local runtimeTime,runtimeWaits=0,0;local runtimeClock=function()runtimeTime+=.001;return runtimeTime end;local runtimeTask={wait=function()runtimeWaits+=1;runtimeTime+=.01 end}
	Runtime.start(page,{CanvasItems={item,glItem,gpuItem},ImageItems={sourceItem}},function(message)table.insert(diagnostics,message)end,{RunService={RenderStepped=renderSignal},Task=runtimeTask,Clock=runtimeClock,Asset={CreateEditableImage=function()return image end,CreateEditableImageAsync=function()return {Size={X=2,Y=2},ReadPixelsBuffer=function()return runtimePixels end,Destroy=function()sourceDestroys+=1 end}end}},4)
	assert(#diagnostics==0 and writes==6,"Canvas allocates transparent bitmaps and batches each scripted context into one upload; writes="..writes.." diagnostics="..table.concat(diagnostics," | "))
	assert(runtimeWaits>0 and page.CanvasStats and page.CanvasStats.Yields==runtimeWaits,"Canvas rasterization and script execution share the configured cooperative budget")
	equal(rgba(item.CanvasSurface,5,5),{255,0,0,255},"The standard canvas JavaScript subset draws pixels")
	assert(rgba(item.CanvasSurface,18,5)[3]>rgba(item.CanvasSurface,18,5)[2],"CanvasGradient objects pass through the JavaScript bridge")
	equal(rgba(item.CanvasSurface,0,0),{12,34,56,255},"decoded HTML images pass through drawImage in the JavaScript bridge")
	equal(rgba(item.CanvasSurface,19,11),{255,64,128,255},"ImageData typed pixels pass through the JavaScript bridge");equal(rgba(item.CanvasSurface,18,11),{255,64,128,255},"getImageData readback can be written again")
	equal(rgba(item.CanvasSurface,16,10),{0,255,0,255},"canvas.toDataURL exports PNG through the JavaScript bridge");equal(rgba(item.CanvasSurface,17,10),{0,255,0,255},"canvas.toBlob schedules a PNG Blob callback")
	assert(rgba(glItem.CanvasSurface,12,10)[4]==255 and rgba(glItem.CanvasSurface,12,10)[1]+rgba(glItem.CanvasSurface,12,10)[2]+rgba(glItem.CanvasSurface,12,10)[3]>100,"WebGL runs through the browser JavaScript bridge");assert(rgba(gpuItem.CanvasSurface,12,10)[4]==255 and rgba(gpuItem.CanvasSurface,12,10)[1]+rgba(gpuItem.CanvasSurface,12,10)[2]+rgba(gpuItem.CanvasSurface,12,10)[3]>100,"WebGPU adapter, device, queue and render pass run through the browser JavaScript bridge")
	assert(frameCallback~=nil,"requestAnimationFrame starts one shared render connection");local firstTick=frameCallback;firstTick();assert(frameCallback~=nil and writes==7,"the first animation frame batches one canvas upload");equal(writeRegions[#writeRegions],{1,9,1,1},"small animation changes upload only their dirty rectangle");local secondTick=frameCallback;secondTick();assert(writes==8,"the second animation frame batches one canvas upload");equal(writeRegions[#writeRegions],{2,9,1,1},"successive animation frames keep bounded uploads");equal(rgba(item.CanvasSurface,1,9),{0,255,255,255},"the first requested animation callback runs");equal(rgba(item.CanvasSurface,2,9),{0,255,255,255},"callbacks can request the following frame");local cancelledPixel=rgba(item.CanvasSurface,15,9);assert(not(cancelledPixel[1]>250 and cancelledPixel[2]<2 and cancelledPixel[3]<2),"cancelAnimationFrame prevents its callback")
	assert(page:GetCanvasContext("test")==item.CanvasSurface,"Page exposes the named canvas context to Luau")
	cleanups[1]();assert(destroys==3 and sourceDestroys==1 and animationDisconnects==1 and frameCallback==nil and not page.CanvasRuntime.Alive,"Canvas resources, GPU contexts, animation connection and temporary source images are released")
	local hostCleanups={};local hostPage={Alive=true,Document=Parser.parse('<canvas id="host" width="4" height="4"></canvas><script data-canvas-script>throw new Error("Legacy realm must not run");</script>'),Root={SetAttribute=function()end},AddCleanup=function(_,fn)table.insert(hostCleanups,fn)end}
	local hostNode=hostPage.Document.Children[1];local hostItem={Node=hostNode,ImageGui={}};local nativeCreated,nativeDestroyed=0,0
	local sourceNode={Kind="Element",Name="img",Attributes={src="host-source.png"},Children={},Parent=hostPage.Document}
	local sourceItem={Node=sourceNode,Source="host-source.png",SelectedSource="host-source.png"};local sourceItems={sourceItem}
	local nativeLoads,nativeSourceDestroyed=0,0;local sourceRead
	local function nativeSource(_,uri)
		nativeLoads+=1;if uri=="failed.png"then error("Fixture image unavailable")end
		return {Size={X=2,Y=2},ReadPixelsBuffer=function()if sourceRead then sourceRead()end;return sourcePixels end,Destroy=function()nativeSourceDestroyed+=1 end}
	end
	local function nativeImage()nativeCreated+=1;return {WritePixelsBuffer=function()end,Destroy=function()nativeDestroyed+=1 end}end
	local hostDiagnostics={};local hostRuntime=Runtime.start(hostPage,{CanvasItems={hostItem},ImageItems=sourceItems},function(message)table.insert(hostDiagnostics,message)end,{HostOnly=true,Asset={CreateEditableImage=nativeImage,CreateEditableImageAsync=nativeSource}},0)
	assert(hostRuntime.VM==nil and nativeCreated==1,"HTML canvas host mode creates no separate JavaScript/rAF realm")
	local decoded=hostRuntime:ImageSource(sourceNode);assert(decoded.Width==2 and buffer.tostring(decoded.Pixels)==buffer.tostring(sourcePixels)and nativeLoads==1 and nativeSourceDestroyed==1)
	assert(hostRuntime:ImageSource(sourceNode)==decoded and nativeLoads==1,"Decoded native sources are cached without retaining temporary EditableImages")
	table.clear(sourceItems);sourceNode.Parent=nil;assert(hostRuntime:ImageSource(sourceNode)==decoded,"Detached DOM images retain their decoded source bitmap")
	sourceNode.Attributes.src="failed.png";assert(hostRuntime:ImageSource(sourceNode)==nil,"A changed source cannot reuse stale cached pixels")
	sourceItem={Node=sourceNode,Source="failed.png"};table.insert(sourceItems,sourceItem)
	assert(hostRuntime:ImageSource(sourceNode)==nil and hostRuntime:ImageSource(sourceNode)==nil and nativeLoads==2 and #hostDiagnostics==1,"Unavailable image assets fail once and do not allocate repeatedly")
	local cpu=hostRuntime:Surface(hostNode,true);cpu:Set("fillStyle","red");cpu:FillRect(0,0,1,1);hostRuntime:Publish(hostNode)
	hostRuntime:Remove({hostItem});assert(nativeDestroyed==1 and hostRuntime:Surface(hostNode,false)==cpu)
	local retained={Node=hostNode,ImageGui={}};hostRuntime:Add({retained});assert(retained.CanvasSurface==cpu and nativeCreated==2 and rgba(cpu,0,0)[1]==255,"Native canvas reattachment adopts the retained CPU buffer")
	local resized=hostRuntime:Reset(hostNode,6,3);assert(retained.CanvasSurface==resized and resized~=cpu and nativeDestroyed==2 and nativeCreated==3 and retained.IntrinsicWidth==6 and retained.IntrinsicHeight==3)
	hostRuntime:Reset(hostNode,0,3);assert(nativeDestroyed==3 and nativeCreated==3 and retained.CanvasImage==nil,"Zero bitmap dimensions release the native image without allocating another")
	sourceNode.Attributes.src="cancelled.png";sourceItem.Source="cancelled.png";sourceRead=function()hostCleanups[1]()end
	assert(not pcall(function()hostRuntime:ImageSource(sourceNode)end)and nativeSourceDestroyed==2 and not hostRuntime.Alive,"Disposal during image read cancels work and destroys the temporary allocation")
	local mediaDocument=Parser.parseDocument(mediaHTML)
	local function findCanvas(node: any): any?
		if node.Kind=="Element" and node.Name=="canvas" and node.Attributes.id=="sample-canvas" then return node end
		for _,child in node.Children do local found=findCanvas(child);if found then return found end end
		return nil
	end
	local mediaNode=findCanvas(mediaDocument)
	assert(mediaNode,"The generated media page must contain the canvas fixture")
	local mediaImage={WritePixelsBuffer=function()end,Destroy=function()end}
	local mediaItem={Node=mediaNode,ImageGui={}}
	local mediaCleanups,mediaDiagnostics={},{}
	local mediaPage={Alive=true,Document=mediaDocument,AddCleanup=function(_,fn)table.insert(mediaCleanups,fn)end}
	Runtime.start(mediaPage,{CanvasItems={mediaItem}},function(message)table.insert(mediaDiagnostics,message)end,
		{Asset={CreateEditableImage=function()return mediaImage end}},0)
	assert(#mediaDiagnostics==0,"The actual media page canvas script must run: "..table.concat(mediaDiagnostics," | "))
	equal(rgba(mediaItem.CanvasSurface,0,0),{232,244,239,255},"The media page paints its canvas background")
	equal(rgba(mediaItem.CanvasSurface,40,100),{8,127,114,255},"The media page paints its canvas bars")
	assert(rgba(mediaItem.CanvasSurface,238,70)[1]>200,"The media page paints its orange circle")
	mediaCleanups[1]()
	print("Canvas: WebGL, WebGPU, animation, PNG export, bitmap images, pixel APIs, patterns, gradients, clipping, CSS blending, shadows, text, paths, transforms, bounded JS and batched uploads passed")
end
