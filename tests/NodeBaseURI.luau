--!strict
return function(Parser,Runtime,Events,fixture)
	local required={
		['node kinds share document base']=2,
		['live base and detached owners']=8,
		['template and shadow bases']=5,
		['xml bases and adopted attributes']=3,
		['constructed XML doctype and detached document']=2,
		['descriptor readonly branding and own override']=6,
		['history fallback and frozen first base']=6,
	}
	local seen={}
	for _,case in fixture.cases do
		assert(required[case.name]and not seen[case.name],'Unexpected/duplicate Node base URI case: '..case.name)
		assert(#case.expected==required[case.name],'Required native Node base URI states were removed: '..case.name)
		seen[case.name]=true
	end
	for name in required do assert(seen[name],'Required Node base URI case missing: '..name)end
	local function run(realm,source)local ok,message=realm:Run(source);assert(ok,tostring(message))end
	for _,case in fixture.cases do
		local document=Parser.parseDocument('<!doctype html>'..case.html)
		local events=Events.new(error);local results={}
		local realm=Runtime.new(document,{URL=case.documentURL,Events=events,ApplyChanges=function()return false end,
			Console=function(_,value)table.insert(results,value)end})
		run(realm,case.source);realm:PumpTasks()
		assert(#realm.Diagnostics==0,case.name..': '..table.concat(realm.Diagnostics,' | '))
		assert(#results==#case.expected,case.name..': output count')
		for index,wanted in case.expected do assert(results[index]==wanted,case.name..'['..index..']: '..tostring(results[index])..' vs '..wanted)end
		realm:Destroy();events:Destroy()
	end
	-- Original wrappers and getters consult the receiving node's current realm.
	local first=Parser.parseDocument('<!doctype html><base href="https://first.invalid/root/"><div id=host title=value>Text</div>')
	local second=Parser.parseDocument('<!doctype html><base href="https://second.invalid/root/">')
	local a,b=Events.new(error),Events.new(error)
	local ra=Runtime.new(first,{URL='https://first.invalid/page',Events=a,ApplyChanges=function()return false end})
	local rb=Runtime.new(second,{URL='https://second.invalid/page',Events=b,ApplyChanges=function()return false end})
	run(ra,'globalThis.kept=document.getElementById("host");globalThis.text=kept.firstChild;globalThis.attr=kept.getAttributeNode("title");globalThis.get=Object.getOwnPropertyDescriptor(Node.prototype,"baseURI").get;')
	local kept=ra.Window.Get('kept')
	rb.VM.Global.Bindings.kept={Value=kept}
	run(rb,'document.adoptNode(kept);')
	run(ra,'if(kept.baseURI!=="https://second.invalid/root/"||text.baseURI!==kept.baseURI||attr.baseURI!==kept.baseURI||get.call(kept)!==kept.baseURI)throw new Error("retained adopted Node base");')
	run(rb,'document.querySelector("base").href="https://second.invalid/changed/";')
	run(ra,'if(kept.baseURI!=="https://second.invalid/changed/"||get.call(attr)!==kept.baseURI)throw new Error("current receiving base");document.adoptNode(kept);if(kept.baseURI!=="https://first.invalid/root/")throw new Error("return adoption base");')
	assert(#ra.Diagnostics==0 and #rb.Diagnostics==0,'Retained cross-realm Node base getters must use current owners')
	local getter=ra.Window.Get('get');ra:Destroy();rb:Destroy();a:Destroy();b:Destroy()
	local live=pcall(function()ra.VM:Call(getter,{},kept)end);assert(not live,'Disposed base getter must be inert')
	print('Node base URI: '..#fixture.cases..' native node kinds, bases/history/adoption, descriptors and cross-realm lifetime passed')
end
