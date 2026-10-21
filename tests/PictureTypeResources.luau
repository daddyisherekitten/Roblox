--!strict
-- BUILD-only request qualification controls. The reference serves PNG for all
-- declared hints; these assertions do not establish native format decoding.
return function(Parser: any, Runtime: any, Events: any, rows: any, Node: any, loadRenderTree: any)
	assert(#rows==27,"Picture source hint reference must retain all 27 rows")
	local seen={}
	for _,row in rows do
		assert(type(row.index)=="number"and row.index%1==0 and row.index>=0 and row.index<=26 and not seen[row.index],"Unique picture hint index 0..26 required")
		seen[row.index]=true
	end
	for index=0,26 do assert(seen[index],"Missing picture source hint index "..index) end
	local checks, cases = 0, 0
	local function equal(actual, expected, message)
		checks += 1; assert(actual == expected, message .. ": " .. tostring(actual) .. " / " .. tostring(expected))
	end
	for _, row in rows do
		local requests, cancel, logs = {}, {}, {}
		local events, clock = Events.new(error), 0
		local document = Parser.parseDocument('<!doctype html><body><picture id="p"><source id="s" srcset="candidate.png"><img id="i" src="fallback.png" alt="Fallback"></picture></body>')
		local realm = Runtime.new(document, {
			URL="https://picture.test/index.html", Events=events, Clock=function()return clock end,
			Schedule=function()end, ApplyChanges=function()return false end,
			Console=function(_, message) table.insert(logs, message) end,
			LoadImage=function(url, complete, spec)
				local request={URL=url,Complete=complete,Spec=spec};table.insert(requests,request)
				return function() cancel[request]=true end
			end,
		})
		local function run(source) local ok,err=realm:Run(source);assert(ok,tostring(err)) end
		local function pump() for _=1,12 do clock+=.01;realm:PumpTasks();realm.EventLoop:Checkpoint() end end
		-- Before any stable request starts, source hint mutations coalesce.
		-- Transfer arbitrary hint strings through actual DOM binding conversion.
		if row.type ~= nil then realm.VM.Global.Bindings.referenceHint={Value=row.type} end
		run('var source=document.getElementById("s"), image=document.getElementById("i");source.type="image/x-fiction";'..
			(if row.type==nil then 'source.removeAttribute("type")' else 'source.setAttribute("type",referenceHint)'))
		realm:Start();pump();equal(#requests,1,"one coalesced picture request "..row.index)
		equal(requests[1].URL,"https://picture.test/"..row.selected,"selected request "..row.index)
		requests[1].Complete(true,{Width=320,Height=180});pump()
		run('console.log(image.currentSrc, image.naturalWidth, image.naturalHeight, image.complete)')
		equal(logs[#logs],"https://picture.test/"..row.selected.." 320 180 true","actual bound image state "..row.index)
		-- Switching qualification must keep the original image/node and suppress
		-- callbacks from a request superseded in the same stable checkpoint.
		run('source.type="image/png";source.srcset="pending.png";image.decode().catch(()=>{})');pump()
		equal(#requests,2,"pending source starts "..row.index)
		run('source.type="image/x-fiction"');pump()
		equal(#requests,3,"unknown type switches to fallback "..row.index)
		equal(requests[3].URL,"https://picture.test/fallback.png","fallback request "..row.index)
		equal(cancel[requests[2]],true,"superseded request canceled "..row.index)
		requests[2].Complete(true,{Width=900,Height=900});requests[3].Complete(true,{Width=80,Height=40});pump()
		run('console.log(image===document.getElementById("i"), image.currentSrc, image.naturalWidth, image.naturalHeight)')
		equal(logs[#logs],"true https://picture.test/fallback.png 80 40","stale result cannot publish "..row.index)
		assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n"));realm:Destroy();events:Destroy();cases += 1

		-- Actual retained renderer path, independent of the controlled VM loader.
		local factory={}
		function factory.create(class,parent,properties)
			local gui=table.clone(properties);gui.ClassName,gui.Parent=class,parent;gui.Visible=properties.Visible~=false
			function gui:Destroy() assert(not self.Destroyed);self.Destroyed=true;self.Parent=nil end
			return gui
		end
		factory.modifier=factory.create
		local rendered=Parser.parseDocument('<!doctype html><body><picture><source id="s" srcset="candidate.png"><img id="i" src="fallback.png" alt="Example" width="320" height="180"></picture></body>')
		local source=Node.findElement(rendered,function(node)return node.Attributes and node.Attributes.id=="s"end)
		local image=Node.findElement(rendered,function(node)return node.Attributes and node.Attributes.id=="i"end)
		source.Attributes.type=row.type
		local tree=loadRenderTree(factory).build(rendered,{AbsoluteSize={X=800,Y=600}},function()end,function(font)return font end,nil,nil,
			function(raw)return if raw=="candidate.png"then"rbxassetid://123"elseif raw=="fallback.png"then"rbxassetid://456"else nil end,"",nil)
		local item=assert(tree:FindImageItem(image));local gui,paint,box=item.Gui,item.ImageGui,tree.NodeBoxes[image]
		equal(item.Source,if row.selected=="candidate.png"then"rbxassetid://123"else"rbxassetid://456","rendered qualification "..row.index)
		source.Attributes.type="image/png";tree:RefreshImageResource(image)
		equal(item.Source,"rbxassetid://123","rendered known source "..row.index)
		source.Attributes.type="image/x-fiction";tree:RefreshImageResource(image)
		equal(item.Source,"rbxassetid://456","rendered unknown fallback "..row.index)
		equal(item.Gui,gui,"retained outer GUI "..row.index)
		equal(item.ImageGui,paint,"retained native paint "..row.index)
		equal(tree.NodeBoxes[image],box,"retained CSS box "..row.index)
	end
	do
		local requests,logs,publications={}, {},{}
		local viewport={Width=800,Height=600,Environment={Resolution=2}};local clock=0
		local events=Events.new(error)
		local document=Parser.parseDocument('<!doctype html><base href="assets/"><picture><source id="s" media="(height >= 500px) and (resolution >= 2dppx)" srcset="same.png 400w" sizes="200px"><img id="i" src="fallback.png"></picture>')
		local realm=Runtime.new(document,{URL='https://responsive.test/root/index.html',Events=events,Clock=function()return clock end,Schedule=function()end,ApplyChanges=function()return false end,
			ResourceViewport=function()return viewport end,ImageChanged=function(node,ok,data)table.insert(publications,{Node=node,OK=ok,Data=data})end,
			Console=function(_,message)table.insert(logs,message)end,LoadImage=function(url,complete)local r={URL=url,Complete=complete};table.insert(requests,r);return function()r.Cancelled=true end end})
		local function run(code)local ok,message=realm:Run(code);assert(ok,tostring(message))end
		local function pump()for _=1,12 do clock+=.01;realm:PumpTasks();realm.EventLoop:Checkpoint()end end
		local image=Node.findById(document,'i')
		run('var i=document.getElementById("i"),s=document.getElementById("s"),loads=0;i.onload=()=>loads++');realm:Start();pump()
		equal(#requests,1,'one responsive DPR request');equal(requests[1].URL,'https://responsive.test/root/assets/same.png','selected relative SOURCE uses owner document base')
		requests[1].Complete(true,{Width=200,Height=100});pump();run('console.log(i.currentSrc,i.naturalWidth,i.naturalHeight,loads)')
		equal(logs[#logs],'https://responsive.test/root/assets/same.png 100 50 1','DPR media and width-descriptor density reach actual image properties')
		local state=image.ImageResourceState;local generation=state.Generation;local pixels=requests[1]
		run('s.sizes="400px"');pump();run('console.log(i.naturalWidth,i.naturalHeight,loads)')
		equal(logs[#logs],'200 100 1','same decoded source changes natural geometry without another load event')
		equal(#requests,1,'density-only mutation keeps decoded request');equal(state.Generation,generation,'density-only mutation keeps request identity');equal(pixels.Cancelled,nil,'density-only mutation does not cancel native request')
		equal(publications[#publications].Data.Width,200,'density-only geometry publication is current')
		local published=#publications
		run('s.width=90;s.height=45');pump()
		equal(#requests,1,'selected SOURCE dimension mutation does not reload decoded source')
		equal(#publications,published+2,'selected SOURCE width and height mutations notify retained image consumers')
		viewport.Height=400;realm.ImageResources:ViewportChanged();pump();equal(#requests,2,'height media reevaluates the actual request')
		equal(requests[2].URL,'https://responsive.test/root/assets/fallback.png','nonmatching SOURCE switches to IMG default')
		run('s.media="";s.sizes="100px"');pump();equal(#requests,3,'pending fallback is replaced by qualified SOURCE')
		equal(requests[2].Cancelled,true,'replaced pending candidate is cancelled')
		local pendingGeneration=state.Generation
		run('s.sizes="200px"');pump();equal(#requests,3,'same pending source density changes do not duplicate IO');equal(state.Generation,pendingGeneration,'pending source keeps its generation')
		requests[2].Complete(true,{Width=900,Height=900});requests[3].Complete(true,{Width=200,Height=100});pump()
		run('console.log(i.currentSrc,i.naturalWidth,i.naturalHeight,loads)')
		equal(logs[#logs],'https://responsive.test/root/assets/same.png 100 50 2','late result uses latest pending density and ignores superseded resource')
		assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,'\n'));realm:Destroy();events:Destroy()
	end
	print("PICTURE_TYPE_RESOURCES", "cases="..cases, "assertions="..checks, "scope=actual Runtime/DOM controlled image adapter and retained RenderTree factory; no native decoding/Studio/whole-realm GC claim")
end
