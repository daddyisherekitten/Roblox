--!strict
-- Native asset/CPU work may suspend the Roblox task. These suspensions must
-- cross the host boundary without becoming an async await or generator yield.
return function(Parser,Node,Runtime,Surface)
	local document=Parser.parseDocument('<html><body><canvas id="canvas" width="4" height="4"></canvas><img id="image"></body></html>')
	local storage,output,diagnostics={},{},{};local suspended=0
	local function suspend(kind)suspended+=1;coroutine.yield(kind)end
	local function fresh(node,w,h)local value=Surface.new(w,h,function()suspend("native-pixels")end);storage[node]=value;return value end
	local adapter={
		Surface=function(_,node,create)local value=storage[node];if not value and create~=false then suspend("native-surface");value=fresh(node,4,4)end;return value end,
		Reset=function(_,node,w,h)suspend("native-reset");return fresh(node,w,h)end,
		ImageSource=function()suspend("native-image");local pixels=buffer.create(4);buffer.writeu8(pixels,0,255);buffer.writeu8(pixels,3,255);return {Width=1,Height=1,Pixels=pixels}end,
		Publish=function()end,Destroy=function()table.clear(storage)end,
	}
	local realm=Runtime.new(document,{Schedule=function()end,CanvasAdapter=adapter,
		Console=function(_,value)table.insert(output,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
	local function run(source)
		local thread=coroutine.create(function()realm:Run(source)end)
		while coroutine.status(thread)~="dead"do
			local ok,value=coroutine.resume(thread);assert(ok,tostring(value))
			if coroutine.status(thread)~="dead"then assert(type(value)=="string"and value:sub(1,7)=="native-","Only native task suspensions may escape the realm entry")end
		end
		assert(not realm:IsExecuting()and #diagnostics==0,table.concat(diagnostics," | "))
	end
	run([=[
async function paint(){
 const c=document.getElementById('canvas'),x=c.getContext('2d');
 c.width=4;x.fillStyle='blue';x.fillRect(0,0,4,4);
 x.drawImage(document.getElementById('image'),0,0);
 return x.getImageData(0,0,1,1).data[0];
}
paint().then(value=>console.log('async',value));
]=])
	assert(output[1]=="async 255"and suspended>5,"Async canvas setters, CPU operations and image decoding resume through HostCall")
	run([=[
function* pixels(){
 const c=document.getElementById('canvas'),x=c.getContext('2d');
 c.setAttribute('height','4');x.fillRect(0,0,2,2);
 yield 42;x.drawImage(document.getElementById('image'),0,0);
 return x.getImageData(0,0,1,1).data[0];
}
const iterator=pixels(),first=iterator.next(),last=iterator.next();
console.log('generator',first.value,first.done,last.value,last.done);
]=])
	assert(output[2]=="generator 42 false 255 true","Canvas host suspension preserves the actual JavaScript generator yield and return")
	assert(storage[Node.findById(document,"canvas")].Width==4);realm:Destroy();assert(next(storage)==nil)
	print("Canvas host integration: native asset/CPU suspensions preserve async completion, generator yields, dimension resets and cleanup passed")
end
