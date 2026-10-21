--!strict
return function(Context,Upload,Queue,BackgroundPixels,Style)
	local now,waits=0,0;local alive=true
	local tasks={wait=function()waits+=1;now+=.016;coroutine.yield('slice')end,defer=function()end}
	local function clock()now+=.00003;return now end
	local work=Context.new(2,{Clock=clock,Task=tasks,Alive=function()return alive end})
	local function drive(fn)
		local thread=coroutine.create(fn);local rounds=0
		while coroutine.status(thread)~='dead'do rounds+=1;assert(rounds<10000);local ok,value=coroutine.resume(thread);assert(ok,tostring(value))end
	end
	local pixels=buffer.create(130*260*4)
	for i=0,buffer.len(pixels)-1 do buffer.writeu8(pixels,i,i%251)end
	local image={Bytes=buffer.create(buffer.len(pixels)),Writes=0}
	function image:WritePixelsBuffer(position,size,bytes)
		assert(position.X==0 and size.X==130 and buffer.len(bytes)==size.X*size.Y*4)
		self.Writes+=1;buffer.copy(self.Bytes,position.Y*130*4,bytes,0,buffer.len(bytes));now+=.0014
	end
	drive(function()work:Run(function()assert(Upload.write(image,Vector2.new(130,260),pixels))end)end)
	assert(waits>0 and image.Writes==3 and buffer.tostring(image.Bytes)==buffer.tostring(pixels),'Partial final upload rows reconstruct the exact original bytes')
	local before=waits;image.Writes=0;assert(Upload.write(image,Vector2.new(130,260),pixels));assert(image.Writes==1 and waits==before,'Ordinary texture updates retain the existing single-write path')
	local node={Name='div',Attributes={style='background:linear-gradient(to right,red,blue)'}}
	local style=Style.resolve(node,{Font='Roboto',FontSize=16,Color=Color3.new(0,0,0)},error)
	local gradient=style.BackgroundImages[1]
	local plan=BackgroundPixels.plan(130,80,gradient,style)
	local expected=BackgroundPixels.render(130,80,gradient,style,plan);local actual
	before=waits;drive(function()actual=work:Run(BackgroundPixels.render,130,80,gradient,style,plan)end)
	assert(waits>before and buffer.tostring(expected)==buffer.tostring(actual),'CSS raster pauses preserve all gradient samples')

	local jobs,live,published,errors={},0,0,{}
	tasks.defer=function(fn)table.insert(jobs,coroutine.create(fn))end
	local api={CreateEditableImage=function(_,options)
		live+=1;local result={Size=options.Size,Bytes=buffer.create(options.Size.X*options.Size.Y*4),Writes=0}
		function result:WritePixelsBuffer(position,size,bytes)
			self.Writes+=1;buffer.copy(self.Bytes,position.Y*self.Size.X*4,bytes,0,buffer.len(bytes));now+=.0014
		end
		function result:Destroy()assert(not self.Dead);self.Dead=true;live-=1 end
		return result
	end}
	local queue=Queue.new(api,{render=function()return pixels end},tasks,{LoadingWork=work,Clock=clock,Report=function(message)table.insert(errors,message)end})
	queue:Request({},'initial',function()
		for _=1,40 do now+=.0003;Context.checkpoint()end
		return {Width=130,Height=260}
	end,function(result)
		assert(result.Writes==3 and buffer.tostring(result.Bytes)==buffer.tostring(pixels),'SVG readiness cannot publish a partially uploaded texture')
		published+=1
	end,true)
	local function step()
		local thread=table.remove(jobs,1);if not thread then return end
		local ok,message=coroutine.resume(thread);assert(ok,tostring(message));if coroutine.status(thread)~='dead'then table.insert(jobs,thread)end
	end
	local function drain()local count=0;while #jobs>0 do count+=1;assert(count<1000);step()end end
	drain();assert(published==1 and #errors==0 and queue.Stats.Uploads==1 and queue.Stats.BuildWaitMS>0 and queue.Stats.BuildActiveMS<queue.Stats.BuildMS)
	local owner={};queue:Request(owner,'cancel',function()return {Width=130,Height=260}end,function()error('Cancelled upload was published')end,true)
	step();queue:Remove(owner);drain();assert(live==1,'Removal between upload bands releases only that owner')
	work:Finish()
	local publishedWrites=0
	queue:Warm(owner,'late-visible',function()
		for _=1,40 do now+=.0003;Context.checkpoint()end;return {Width=130,Height=260}
	end)
	step()
	queue:Request(owner,'late-visible',function()error('Warmed state rebuilt')end,function(result)publishedWrites=result.Writes end,true)
	drain();assert(publishedWrites==1,'A visible frame arriving during prewarming is uploaded atomically after presentation')
	local beforeWarm=waits
	queue:Warm({},'late-prewarm',function()for _=1,40 do now+=.0003;Context.checkpoint()end;return {Width=130,Height=260}end)
	drain();assert(waits>beforeWarm and queue.Stats.WarmCompleted==2,'Prewarming keeps yielding after the page has been presented')
	queue:Destroy();drain();assert(live==0 and #queue.Cache==0)
	print('Loading textures: byte-identical gradients, bounded upload bands, completed SVG presentation, cancellation and budgeted late prewarming passed')
end
