--!strict
return function(Parser,Runtime,Events,Selectors,Nesting,fixture)
	local nativeNames={};for _,record in fixture.records do nativeNames[record.name]=true end
	for _,name in {'offset raw "9"','offset setter -1','offset setter 4294967297','reset setter false','reset setter true','expanded HTML reflection'}do assert(nativeNames[name],'Missing heading IDL reference '..name)end
	local levelNames={};for _,record in fixture.headings do levelNames[record.name]=true end
	for _,name in {'inclusive nested offsets','own reset inclusive','ancestor reset inclusive','foreign ancestor ignored','namespaced attributes ignored','unprefixed namespace attributes ignored','shadow host ancestor','slotted DOM ancestor','ARIA independent algorithm'}do assert(levelNames[name],'Missing heading level reference '..name)end
	local function realm()
		local events=Events.new(error)
		local runtime=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),
			{Events=events,ControlAdapter={Events=events},Schedule=function()end,MaxSteps=500000})
		return runtime,events
	end
	for _,record in fixture.records do
		local runtime,events=realm()
		assert(runtime:Run(record.source),table.concat(runtime.Diagnostics,'\n'))
		assert(runtime:Run('window.headingJSON=JSON.stringify(window.headingResult);'),table.concat(runtime.Diagnostics,'\n'))
		local expected=if record.normative then record.normative.json else record.json
		assert(runtime.Window.Get('headingJSON')==expected,record.name..': '..tostring(runtime.Window.Get('headingJSON'))..' ~= '..expected)
		runtime:Destroy();events:Destroy()
	end
	for _,record in fixture.headings do
		local runtime,events=realm()
		assert(runtime:Run(record.setup..[=[
			window.headingFlags=[h.matches(':heading')];
			for(let level=1;level<=9;level++)headingFlags.push(h.matches(':heading('+level+')'));
			window.headingJSON=JSON.stringify(headingFlags);
		]=]),table.concat(runtime.Diagnostics,'\n'))
		local expected={tostring(record.expected~=nil)}
		for level=1,9 do table.insert(expected,tostring(level==record.expected))end
		assert(runtime.Window.Get('headingJSON')=='['..table.concat(expected,',')..']',record.name..': '..tostring(runtime.Window.Get('headingJSON')))
		runtime:Destroy();events:Destroy()
	end
	for _,source in {':heading',':HEADING',':heading(2)',':heading(+02,3,-1,0,99)',':heading(/*before*/2/**/,/*next*/3/**/)',':heading(2,2)',':is(:heading(2),.other)',':where(:heading(2))',':not(:heading(2))',':has(> :heading(2))'}do
		assert(Selectors.compile(source),source)
	end
	for _,body in {'',' ','/**/','2,',',2','2,,3','2 3','2.0','2e0','2E+0','2px','0n+2','+ 2','- 2','++2','--2','"2"','\\32','2/**/3','2/**/px','2\\70 x','2;3','2/**/.0','2/**/e0','2/**/foo'}do
		assert(not Selectors.compile(':heading('..body..')'),body)
	end
	assert(Selectors.compile(':heading(2)').Specificity[2]==1)
	assert(Selectors.compile(':where(:heading(2))').Specificity[2]==0)
	assert(Nesting.format(':heading(+02, /*comment*/3,-1)')==':heading(2, 3, -1)')
	local runtime,events=realm()
	assert(runtime:Run([=[
		const outer=document.createElement('section'),h=document.createElement('h2');
		outer.headingOffset=1;outer.append(h);document.body.append(outer);
		const live=[h.matches(':heading(3)'),outer.matches(':has(:heading(3))')];
		outer.headingReset=true;outer.headingOffset=0;
		live.push(h.matches(':heading(2)'),outer.matches(':has(:heading(3))'));
		h.headingOffset=8;live.push(h.matches(':heading(9)'));
		outer.removeChild(h);live.push(h.matches(':heading(9)'));
		h.removeAttribute('headingoffset');live.push(h.matches(':heading(2)'));
		const foreign=document.createElementNS('urn:test','h2');
		const descriptor=Object.getOwnPropertyDescriptor(HTMLElement.prototype,'headingOffset');
		let brand=false;try{descriptor.get.call(foreign);}catch(error){brand=error instanceof TypeError;}
		live.push(brand);window.headingJSON=JSON.stringify(live);
	]=]),table.concat(runtime.Diagnostics,'\n'))
	assert(runtime.Window.Get('headingJSON')=='[true,true,true,false,true,true,true,true]',tostring(runtime.Window.Get('headingJSON')))
	runtime:Destroy();events:Destroy()
	print('Heading selectors: '..tostring(#fixture.records)..' experimental IDL controls + '..tostring(#fixture.headings)..' raw AX/normative DOM levels, integer-token grammar, CSSOM, live offsets/reset/reparent/brand passed')
end
