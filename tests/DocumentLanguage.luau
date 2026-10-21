--!strict
return function(Parser,Node,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local document=Parser.parseDocument(case.html);local actual,diagnostics={},{};local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,Console=function(_,value)table.insert(actual,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
		local ok,message=runtime:Run("function record(){const a=[];for(let i=0;i<arguments.length;i++)a.push(String(arguments[i]));console.log(a.join('|'));}"..case.code);assert(ok,tostring(message))
		local expected=case.standardExpected or case.expected
		assert(#actual==#expected,case.name..': record count')
		for i,value in expected do assert(actual[i]==value,case.name..': '..actual[i]..' ~= '..value)end
		assert(#diagnostics==0,case.name..': unexpected runtime diagnostics');runtime:Destroy();events:Destroy()
	end
	local selectors=require('CSS/Selectors');local function matches(node,source)return selectors.matches(node,assert(selectors.compile(source)))end
	local document=Parser.parseDocument('<!doctype html><p id="probe">Probe</p>',{ContentLanguage=' fr-CH '})
	assert(matches(Node.findById(document,'probe'),':lang(fr)'),'Single transport language fallback')
	document=Parser.parseDocument('<!doctype html><p id="probe">Probe</p>',{ContentLanguage='fr, en'})
	assert(matches(Node.findById(document,'probe'),':lang("")'),'Multiple transport languages are unknown')
	document=Parser.parseDocument('<!doctype html><meta http-equiv=content-language content=de><p id="probe">Probe</p>',{ContentLanguage='fr'})
	assert(matches(Node.findById(document,'probe'),':lang(de)'),'Pragma precedes transport fallback')
	assert(not pcall(Parser.parseDocument,'',{ContentLanguage=4}),'Transport language option validation')
	print('Document language: '..#fixture.cases..' native sequences, insertion-only effects, shadow/template/namespace boundaries and transport fallback passed')
end
