--!strict
return function(Queue)
	local jobs,events={},{};local live=0
	local tasks={defer=function(fn)table.insert(jobs,coroutine.create(fn))end}
	local function step()
		local co=table.remove(jobs,1);if not co then return end
		local ok,message=coroutine.resume(co);assert(ok,message)
		if coroutine.status(co)~='dead'then table.insert(jobs,co)end
	end
	local function drain()local rounds=0;while #jobs>0 do rounds+=1;assert(rounds<30);step()end end
	local api={CreateEditableImage=function(_,options)
		live+=1;local image={Size=options.Size,WritePixelsBuffer=function()end}
		function image:Destroy()assert(not self.Dead);self.Dead=true;live-=1 end
		return image
	end}
	local q=Queue.new(api,{render=function(scene,_,width,check)
		if scene.Warm then coroutine.yield()end
		if not check()then return nil end
		return buffer.create(width*scene.Height*4)
	end},tasks,{YieldSeconds=0,VisibleChanged=function(ready)table.insert(events,ready)end,Report=function()end})
	local a,b={},{}
	local function request(owner,key,fail)
		return q:Request(owner,key,function()if fail then error('Expected asset failure')end;return {Width=2,Height=2}end,function()end,true)
	end
	request(a,'a');request(b,'b')
	assert(#events==1 and events[1]==false,'Several initial SVGs produce one not-ready transition')
	q:Warm(a,'warm',function()return {Width=2,Height=2,Warm=true}end,16)
	step()
	assert(events[2]==true and q:Pending()>0 and q:WarmPending()==1,'The final visible upload releases readiness before background prewarming finishes')
	request(a,'c');assert(events[3]==false)
	drain();assert(events[4]==true,'An interrupted warm raster does not lose visible completion')
	local count=#events;request(a,'c');assert(#events==count and q:Pending()==0,'An unchanged request does not toggle loading readiness')
	request(a,'failed',true);drain();assert(events[#events]==true,'Failed assets settle instead of trapping the page behind loading')
	request(a,'removed');q:Remove(a);assert(events[#events]==true,'Removing the last pending SVG settles readiness');drain()
	request(b,'reset');q:Reset(b);assert(events[#events]==true,'Resetting pending work settles readiness');drain()
	request(b,'disposed');local before=#events;q:Destroy();drain()
	assert(#events==before and live==0,'Destroyed queues never publish a late readiness event')
	print('SVG visible readiness: grouped uploads, independent prewarming, unchanged requests, failures, removals, reset and disposal passed')
end
