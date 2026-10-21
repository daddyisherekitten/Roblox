--!strict
return function(Parser,DocumentInfo,Runtime,Events,fixtures)
	for _,fixture in fixtures do
		local expected=fixture.standardExpected or fixture.expected
		local document=Parser.parseDocument(fixture.html,{IsSrcdoc=true,FallbackBaseURL=fixture.fallbackBaseURL,ScriptingEnabled=true})
		local info=DocumentInfo.collect(document,'about:srcdoc',error)
		local events=Events.new(error);local results={}
		local realm=Runtime.new(document,{URL='about:srcdoc',GetBaseURL=function()return info.BaseURL end,Events=events,ApplyChanges=function()return false end,
			Console=function(_,value)table.insert(results,value)end})
		realm:Run("for(const value of [document.URL,document.baseURI,document.compatMode,document.characterSet,document.title,document.body.textContent])console.log(value);")
		assert(#realm.Diagnostics==0,fixture.name..': '..table.concat(realm.Diagnostics,' | '))
		assert(#results==#expected,fixture.name..': '..tostring(#results))
		for index,wanted in expected do assert(results[index]==wanted,fixture.name..'['..index..']: '..tostring(results[index])..' vs '..wanted)end
		realm:Run("document.open();document.write('<p>New</p>');document.close();if(document.compatMode!=='CSS1Compat')throw new Error('srcdoc open changed mode');")
		assert(#realm.Diagnostics==0,fixture.name..': document replacement');realm:Destroy();events:Destroy()
	end
	print('Srcdoc: '..#fixtures..' native mode/URL/base/charset cases and replacement invariants passed')
end
