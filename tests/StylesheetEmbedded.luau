--!strict
-- Production parser and two independent realms; the host bridges the same
-- stylesheet/load dependencies used by mounted embedded documents.
return function(Parser,Node,Runtime,Events,fixtures)
	for _,fixture in fixtures do
		local output={};local clock=0;local pending=1;local parent,child;local subscriptions=0;local cancelled=0
		local parentEvents,childEvents=Events.new(error),Events.new(error)
		local parentParser=Parser.newDocument(fixture.html,{ScriptingEnabled=true});local first=parentParser:Advance()
		local function resource(url,complete)
			local spec=assert(fixture.resources[url],'Unknown embedded fixture resource '..url);local active=true
			local ticket=parent.EventLoop.Methods.setTimeout({function()if active then complete(true,{Source=spec.Source,MIME=spec.MIME})end end,spec.Delay})
			return function()active=false;cancelled+=1;parent.EventLoop.Methods.clearTimeout({ticket})end
		end
		parent=Runtime.new(parentParser.Document,{URL='https://styles.test/page',Events=parentEvents,Clock=function()return clock end,
			ParserSession=parentParser,ParserFirstScript=first,LoadStylesheet=resource,LoadScript=resource,
			GetPendingEmbeddedResources=function()return pending end,ApplyChanges=function()return false end,
			Console=function(_,value)table.insert(output,value)end})
		parent:Start()
		local frame=assert(Node.findById(parentParser.Document,'frame'),'Parent parser must reach its frame before the CSS barrier')
		local childParser=Parser.newDocument(fixture.childHTML,{ScriptingEnabled=true});local childFirst=childParser:Advance()
		child=Runtime.new(childParser.Document,{URL='about:srcdoc',GetBaseURL=function()return 'https://styles.test/page'end,
			Events=childEvents,Clock=function()return clock end,ParserSession=childParser,ParserFirstScript=childFirst,
			LoadStylesheet=resource,LoadScript=resource,ApplyChanges=function()return false end,
			HasParentBlockingStylesheets=function()return parent:HasOwnBlockingStylesheets()end,
			SubscribeParentStylesheetChanges=function(callback)
				subscriptions+=1;local dispose=parent:SubscribeStylesheetChanges(callback)
				return function()subscriptions-=1;dispose()end
			end,
			DocumentLoadStateChanged=function(value)
				if value=='complete'then
					assert(child:IsDocumentComplete(),'Child load completion must follow its window load handlers')
					pending=0;parentEvents:Emit(frame,'load',nil,{Bubbles=false,Cancelable=false});parent:ResourcesChanged()
				end
			end,
			Console=function(_,value)
				if value=='child load complete'then assert(not child:IsDocumentComplete(),'The child window load handler runs before the container completion hook')end
				table.insert(output,value)
			end})
		-- Capture instrumentation runs before parsing, just like CDP's isolated
		-- reference hook; it must not introduce a parser-blocking setup script.
		child:Run("document.addEventListener('DOMContentLoaded',()=>console.log('child dcl',document.readyState));window.addEventListener('load',()=>console.log('child load',document.readyState));")
		child:Start()
		for _=1,220 do clock+=.001;parent:PumpTasks();child:PumpTasks();parent.EventLoop:Checkpoint();child.EventLoop:Checkpoint()end
		assert(#parent.Diagnostics==0 and #child.Diagnostics==0,fixture.name..': '..table.concat(parent.Diagnostics,' | ')..table.concat(child.Diagnostics,' | '))
		local counts={};for _,value in fixture.expected do counts[value]=(counts[value]or 0)+1 end
		for _,value in output do assert(counts[value]and counts[value]>0,fixture.name..': unexpected '..value..' ['..table.concat(output,' | ')..']');counts[value]-=1 end
		for value,count in counts do assert(count==0,fixture.name..': missing '..value..' ['..table.concat(output,' | ')..']')end
		local function before(a,b)
			local i,j=table.find(output,a),table.find(output,b)
			assert(i and j and i<j,fixture.name..': '..a..' must precede '..b..' ['..table.concat(output,' | ')..']')
		end
		before('child dcl interactive','child load complete');before('child load complete','frame load');before('frame load','parent load complete');before('parent dcl interactive','parent load complete')
		for _,pair in fixture.standardBefore or{}do before(pair[1],pair[2])end
		if fixture.name=='child async passes parent CSS'then before('child async','parent CSS load')end
		if fixture.name=='child load microtasks precede frame load'then before('child load microtask','frame load')end
		if fixture.name=='child load document replacement completes new generation'then before('child replacement','frame load');assert(child.ScriptLoader.Generation==1,'Document replacement must publish only its final generation')end
		assert(output[#output]=='parent load complete'and pending==0 and parent:IsDocumentComplete()and child:IsDocumentComplete(),fixture.name..': parent load dependency')
		if fixture.name=='removed parent CSS releases child'then assert(cancelled==1,'Removed parent CSS must cancel its host request')end
		child:Destroy();assert(subscriptions==0,'Child disposal releases its parent stylesheet subscription');parent:Destroy();parentEvents:Destroy();childEvents:Destroy()
	end
	-- Container barriers use only the immediate parent's own set. A grandparent
	-- stylesheet must not accidentally become a recursive script barrier.
	local events=Events.new(error);local runtime=Runtime.new(Parser.parseDocument('<p>Child</p>'),{Events=events,HasParentBlockingStylesheets=function()return true end,ApplyChanges=function()return false end})
	assert(runtime:HasBlockingStylesheets()and not runtime:HasOwnBlockingStylesheets(),'Inherited barriers are separate from the document own stylesheet set')
	runtime:Destroy();events:Destroy()
	print('Embedded stylesheet loading: '..#fixtures..' native captures, explicit container-barrier differences, child/frame/parent load order and subscriptions passed')
end
