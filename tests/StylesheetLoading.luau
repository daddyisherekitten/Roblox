--!strict
return function(Parser,Runtime,Events,fixtures)
	local discrepancies=0
	for _,fixture in fixtures do
		local output={};local clock=0;local events=Events.new(error);local realm;local cancellations=0;local lateCallbacks={}
		local parser=Parser.newDocument(fixture.html,{ScriptingEnabled=true});local first=parser:Advance()
		local function resource(url,complete)
			local spec=fixture.resources[url];local cancelled=false
			if not spec then complete(false,'Missing test resource '..url);return end
			local id=realm.EventLoop.Methods.setTimeout({function()
				if not cancelled then complete(not spec.Status or spec.Status<400,{Source=spec.Source,MIME=spec.MIME,OriginClean=spec.OriginClean,URL=spec.URL})end
			end,spec.Delay})
			local callback=function()complete(not spec.Status or spec.Status<400,{Source=spec.Source,MIME=spec.MIME,OriginClean=spec.OriginClean,URL=spec.URL})end
			return function()cancelled=true;cancellations+=1;table.insert(lateCallbacks,callback);realm.EventLoop.Methods.clearTimeout({id})end
		end
		realm=Runtime.new(parser.Document,{URL='https://styles.test/page',Events=events,Clock=function()return clock end,
			ParserSession=parser,ParserFirstScript=first,LoadStylesheet=resource,LoadScript=resource,
			ApplyChanges=function()return false end,Console=function(_,value)table.insert(output,value)end})
		realm:Start()
		for _=1,200 do clock+=.001;realm:PumpTasks();realm.EventLoop:Checkpoint()end
		assert(#realm.Diagnostics==0,fixture.name..': '..table.concat(realm.Diagnostics,'\n'))
		local expected=fixture.standardExpected or fixture.profileExpected or fixture.expected
		-- Networking/rendering task ordering is not a stable total browser order.
		-- Compare recorded semantics, then the normative parser/load dependencies.
		local counts={};for _,value in expected do counts[value]=(counts[value]or 0)+1 end
		for _,value in output do assert(counts[value]and counts[value]>0,fixture.name..': unexpected '..value..' ['..table.concat(output,' | ')..']');counts[value]-=1 end
		for value,count in counts do assert(count==0,fixture.name..': missing '..value..' ['..table.concat(output,' | ')..']')end
		local dcl,load=table.find(output,'dcl interactive'),table.find(output,'load complete');assert(dcl and load and dcl<load,fixture.name..': readyState order')
		assert(output[#output]=='load complete',fixture.name..': resource events must precede window load')
		assert(realm.StylesheetResources.Pending==0 and not realm.StylesheetResources:HasBlockingScripts(),fixture.name..': unresolved stylesheet request')
		if fixture.timeout then assert(cancellations>0,fixture.name..': removed imports must release their host request')end
		local count=#output;for _,callback in lateCallbacks do callback()end;realm:PumpTasks()
		assert(#output==count and realm.StylesheetResources.Pending==0,fixture.name..': obsolete host callbacks must not publish or emit')
		if fixture.standardExpected then discrepancies+=1 end
		realm:Destroy();events:Destroy();assert(not parser.Alive)
	end
	-- One packaged dependency must not associate a parent before later async
	-- siblings have been discovered; deleting one tree leaves the other live.
	local document=Parser.parseDocument('<!doctype html><style id=sheet>@import "parent.css";@import "sibling.css";</style>')
	local callbacks,cancelled={},{};local events=Events.new(error)
	local realm=Runtime.new(document,{URL='https://styles.test/page',Events=events,
		Stylesheets={['https://styles.test/parent.css']='@import "fast.css";@import "slow.css";', ['https://styles.test/fast.css']='p{color:red}'},
		LoadStylesheet=function(url,complete)callbacks[url]=complete;return function()cancelled[url]=true end end,
		ApplyChanges=function()return false end})
	local function run(source)realm:Run(source);assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,' | '))end
	run('globalThis.s=document.getElementById("sheet").sheet;globalThis.first=s.cssRules[0];globalThis.second=s.cssRules[1];if(first.styleSheet!==null||second.styleSheet!==null)throw new Error("pending critical subtree associated early");s.deleteRule(0);')
	assert(cancelled['https://styles.test/slow.css']and not cancelled['https://styles.test/sibling.css'],'Deleting one graph must cancel only its own unresolved descendant')
	callbacks['https://styles.test/slow.css'](true,{Source='p{color:green}',MIME='text/css'});realm:PumpTasks()
	run('if(first.styleSheet!==null||second.styleSheet!==null)throw new Error("deleted or unfinished graph published");')
	callbacks['https://styles.test/sibling.css'](true,{Source='p{color:blue}',MIME='text/css'});realm:PumpTasks()
	run('if(document.getElementById("sheet").sheet!==s||s.cssRules[0]!==second||second.styleSheet.cssRules.length!==1||first.styleSheet!==null)throw new Error("surviving graph identity");')
	assert(realm.StylesheetResources.Pending==0,'Surviving sibling completes its owner resource')
	realm:Destroy();events:Destroy()
	print('Stylesheet loading: '..#fixtures..' native semantic captures reviewed; '..discrepancies..' preserved standards/browser differences; parser/async/defer/load, CSSOM cancellation, mixed packaged/async dependencies and cleanup passed')
end
