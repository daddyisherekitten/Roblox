--!strict
return function(Parser,Runtime,Events,fixtures)
	for _,fixture in fixtures do
		local document=Parser.parseDocument('<!doctype html>'..fixture.html)
		local events=Events.new(error);local results={}
		local realm=Runtime.new(document,{URL=fixture.documentURL,Events=events,ApplyChanges=function()return false end,
			Console=function(_,value)table.insert(results,value)end})
		realm:Run(fixture.source);realm:PumpTasks()
		assert(#realm.Diagnostics==0,fixture.name..': '..table.concat(realm.Diagnostics,' | '))
		assert(#results==#fixture.expected,fixture.name..': '..tostring(#results)..' vs '..#fixture.expected)
		for index,wanted in fixture.expected do assert(results[index]==wanted,fixture.name..'['..index..']: '..tostring(results[index])..' vs '..wanted)end
		realm:Destroy();events:Destroy()
	end
	print('Frozen bases: '..#fixtures..' native mutation/history/namespace sequences passed')
end
