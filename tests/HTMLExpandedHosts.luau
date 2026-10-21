--!strict
return function(Parser,Node,Runtime,Events,Sheet,Style,fixture)
	local document=Parser.parseDocument(fixture.html);local events=Events.new(error);local states={};local clock=0;local realm
	local requests={Script={},Stylesheet={},Image={}};local cancelled=0
	local function styleOf(node)
		if node.Kind~='Element'then return nil end
		local parent=if node.Parent and node.Parent.Kind=='Element'then styleOf(node.Parent)else{}
		local rules=Sheet.collect(document,error,nil,nil,'https://example.test/hosts',realm and realm.CSSOM)
		return Style.resolve(node,parent,error,nil,Sheet.match(rules,node,states))
	end
	local tree={NodeStyles=setmetatable({},{__index=function(_,node)return styleOf(node)end}),NodeBoxes={}}
	local function resource(kind,url,complete)
		table.insert(requests[kind],url)
		if kind=='Image'then complete(true,{Width=1,Height=1})
		elseif kind=='Script'then complete(true,{Source='expandedResourceLog.push("script-loaded")',MIME='text/javascript'})
		else complete(true,{Source='#expanded-css-target{height:45px}',MIME='text/css'})end
		return function()cancelled+=1 end
	end
	realm=Runtime.new(document,{URL='https://example.test/hosts',Events=events,ControlAdapter={Events=events},States=states,Clock=function()return clock end,
		MaxSteps=750000,Schedule=function()end,ApplyChanges=function()return false end,
		GeometryAdapter={GetTree=function()return tree end,GetViewport=function()return {Width=800,Height=600}end},
		LoadScript=function(url,complete)return resource('Script',url,complete)end,
		LoadStylesheet=function(url,complete)return resource('Stylesheet',url,complete)end,
		LoadImage=function(url,complete)return resource('Image',url,complete)end,
		CreateTopLayerAdapter=function()return {
			UpdateDialog=function(_,node,s)states.modal=states.modal or{};states.modal[node]=s.Open and s.Modal end,
			UpdatePopover=function(_,node,s)states['popover-open']=states['popover-open']or{};states['popover-open'][node]=s.Open end,
		}end})
	local function run(code)assert(realm:Run(code),table.concat(realm.Diagnostics,' | '));assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
	local function pump()for _=1,32 do clock+=.01;realm:PumpTasks();realm.EventLoop:Checkpoint()end end
	realm:Start();pump()
	run(fixture.source..'\nconst expandedResults=htmlExpandedHostChecks();')
	for index,expected in fixture.records do
		run('window.expandedResult=JSON.stringify(expandedResults['..tostring(index-1)..'].value);')
		local actual=realm.Window.Get('expandedResult');assert(actual==expected.json,expected.name..' expected '..expected.json..' actual '..tostring(actual))
	end
	run('htmlExpandedResourceStart();');pump();run('window.expandedAsync=htmlExpandedResourceFinish();')
	for index,expected in fixture.resources do
		run('window.expandedResult=JSON.stringify(expandedAsync['..tostring(index-1)..'].value);')
		local actual=realm.Window.Get('expandedResult');assert(actual==expected.json,expected.name..' expected '..expected.json..' actual '..tostring(actual))
	end
	assert(#requests.Script==1 and #requests.Stylesheet==1 and #requests.Image==2,'Exactly the HTML owners acquire resources')
	local Responsive=require('HTML/ResponsiveSources')
	for _,entry in fixture.srcsets do
		-- HTML permits UA-dependent selection among distinct densities. Preserve
		-- Chromium's choice while testing our deterministic 1x profile separately.
		local actual=Responsive.fromSrcset(entry.source,nil,800,1)
		assert(actual==entry.profileSelected,'Srcset URL/separator/descriptor lexical profile: '..entry.source)
		if entry.selection=='single-source'then assert(actual==entry.selected,'Single-source native URL matches exactly')end
	end
	assert(realm.ScriptLoader.Pending==0 and realm.ImageResources.Pending==0 and realm.StylesheetResources.Pending==0,'All resource owners settle')
	realm:Destroy();events:Destroy();assert(not realm.Alive)
	-- A foreign attribute change must not cancel or restart the real request.
	local pending,cancellations={},0;local mounted=Parser.parseDocument(fixture.html);local hostEvents=Events.new(error)
	local live=Runtime.new(mounted,{URL='https://example.test/hosts',Events=hostEvents,Schedule=function()end,ApplyChanges=function()return false end,
		LoadImage=function(url,complete)
			local entry={URL=url,Complete=complete};table.insert(pending,entry)
			return function()entry.Cancelled=true;cancellations+=1 end
		end})
	local function execute(source)assert(live:Run(source),table.concat(live.Diagnostics,' | '))end
	local function settle()for _=1,8 do live:PumpTasks();live.EventLoop:Checkpoint()end end
	execute([[const H='http://www.w3.org/1999/xhtml';const pendingImage=document.createElementNS(H,'h:img');pendingImage.id='pending-image';pendingImage.src='one.png';globalThis.imageLoads=0;pendingImage.onload=()=>imageLoads++;document.body.append(pendingImage);]])
	settle();assert(#pending==1)
	local imageNode=assert(Node.findById(mounted,'pending-image'));local resourceState=imageNode.ImageResourceState
	execute([[pendingImage.setAttributeNS('urn:foreign','src','ignored.png');pendingImage.setAttributeNS('urn:foreign','loading','lazy');]])
	settle();assert(#pending==1 and cancellations==0 and imageNode.ImageResourceState==resourceState,'Namespaced image attributes preserve the live owner/request')
	execute([[pendingImage.src='two.png';]]);settle()
	assert(#pending==2 and cancellations==1 and imageNode.ImageResourceState==resourceState,'Source replacement retains the DOM owner and cancels only its old request')
	pending[1].Complete(true,{Width=99,Height=99});settle()
	execute([[window.ownerResult=[pendingImage.complete,pendingImage.naturalWidth,imageLoads];]])
	local vm=live.VM;local before=live.Window.Get('ownerResult');assert(vm.Get(before,'0')==false and vm.Get(before,'1')==0 and vm.Get(before,'2')==0,'Obsolete completion cannot publish or emit')
	pending[2].Complete(true,{Width=31,Height=17});settle()
	execute([[window.ownerResult=[pendingImage.complete,pendingImage.naturalWidth,pendingImage.naturalHeight,imageLoads,pendingImage.tagName];]])
	local after=live.Window.Get('ownerResult');assert(vm.Get(after,'0')and vm.Get(after,'1')==31 and vm.Get(after,'2')==17 and vm.Get(after,'3')==1 and vm.Get(after,'4')=='H:IMG','Current resource generation publishes the prefixed owner once')
	execute([[pendingImage.src='pending.png';]]);settle();assert(#pending==3)
	live:Destroy();hostEvents:Destroy();assert(cancellations==2 and imageNode.ImageResourceState==nil,'Disposal clears the owner and cancels only its outstanding host work')
	pending[3].Complete(true,{Width=7,Height=7});assert(not live.Alive)
	print('H05 expanded HTML hosts: '..#fixture.records..' exact native image/canvas/audio/dialog/popover/script/style/meta records + '..#fixture.resources..' exact async decode/script/link/image outcomes passed')
end
