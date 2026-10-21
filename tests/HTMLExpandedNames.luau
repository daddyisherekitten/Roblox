--!strict
return function(Parser,Node,Runtime,Events,Names,fixture)
	local compact=Node.element('input',{})
	assert(Names.html(compact,'input')and Names.matches(compact,'input',Names.HTML))
	local prefixed=Node.element('h:input',{});prefixed.NamespaceURI=Names.HTML;prefixed.LocalName='input';prefixed.Prefix='h'
	assert(Names.htmlName(prefixed)=='input'and prefixed.Name=='h:input')
	local foreign=Node.element('input',{});foreign.NamespaceURI='urn:foreign'
	local null=Node.element('input',{});null.NamespaceURI=''
	assert(not Names.html(foreign)and not Names.html(null)and Names.htmlName(Node.element('h:input',{}))=='h:input')
	local events=Events.new(error)
	local realm=Runtime.new(Parser.parseDocument('<!doctype html><title>HTML expanded names</title><body></body>'),
		{URL='https://example.test/expanded',Events=events,ControlAdapter={Events=events},Schedule=function()end,MaxSteps=500000})
	assert(realm:Run(fixture.source..'\nconst expandedResults=htmlExpandedNameChecks();'),table.concat(realm.Diagnostics,'\n'))
	for index,expected in fixture.records do
		assert(realm:Run('window.expandedResult=JSON.stringify(expandedResults['..tostring(index-1)..'].value);'),table.concat(realm.Diagnostics,'\n'))
		local actual=realm.Window.Get('expandedResult')
		local normative=fixture.normative[expected.name]
		local target=if normative then normative.json else expected.json
		assert(actual==target,expected.name..'\nexpected '..target..'\nactual '..tostring(actual))
	end
	assert(realm:Run('const expandedPseudos=htmlExpandedPseudoChecks();'),table.concat(realm.Diagnostics,'\n'))
	for index,expected in fixture.pseudos do
		assert(realm:Run('window.expandedPseudo=JSON.stringify(expandedPseudos['..tostring(index-1)..'].value);'),table.concat(realm.Diagnostics,'\n'))
		assert(realm.Window.Get('expandedPseudo')==expected.json,expected.name..'\nexpected '..expected.json..'\nactual '..tostring(realm.Window.Get('expandedPseudo')))
	end
	assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,'\n'))
	realm:Destroy();events:Destroy()
	local deltas=0;for _ in fixture.normative do deltas+=1 end
	print('H05 expanded HTML names: '..tostring(#fixture.records-deltas)..' exact native interface/live form/validation/select/table/list/details/clone/MO/custom-element records + '..tostring(deltas)..' explicit normative datalist deltas + '..tostring(#fixture.pseudos)..' exact native pseudo records passed')
end
