--!strict
return function(Parser,Node,Runtime,Events,fixture,hoverFixture)
	for _,case in fixture.cases do
		local source=if case.mime then '<!doctype html><body></body>'else case.html
		local document=Parser.parseDocument(source);local actual,diagnostics={},{};local events=Events.new(error)
		local runtime=Runtime.new(document,{Events=events,Console=function(_,value)table.insert(actual,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
		local prefix="function record(){const a=[];for(let i=0;i<arguments.length;i++)a.push(String(arguments[i]));console.log(a.join('|'));}"
		if case.mime then prefix..='const document=new DOMParser().parseFromString('..string.format('%q',case.html)..','..string.format('%q',case.mime)..');'end
		local ok,message=runtime:Run(prefix..case.code);assert(ok,case.name..': '..tostring(message))
		assert(#actual==#case.expected,case.name..': record count')
		for i,value in case.expected do assert(actual[i]==value,case.name..' record '..i..': '..actual[i]..' ~= '..value)end
		assert(#diagnostics==0,case.name..': unexpected diagnostics');runtime:Destroy();events:Destroy()
	end
	local Selectors=require('CSS/Selectors')
	local Stylesheet=require('CSS/Stylesheet')
	local function content(declarations)
		local value
		for _,entry in declarations.Normal do if entry.Field=='GeneratedContent'then value=entry.Value end end
		for _,entry in declarations.Important do if entry.Field=='GeneratedContent'then value=entry.Value end end
		if not value or value.Mode then return value and value.Mode or 'none'end
		local parts={};for _,token in value do assert(token.Kind=='text');table.insert(parts,string.format('%q',token.Value))end
		return table.concat(parts,' ')
	end
	for _,case in hoverFixture.cases do
		local document=Parser.parseDocument(case.html)
		assert(document.Mode==case.mode,case.name..': document mode')
		local child=Node.findById(document,'child')
		local states={hover=child,active=if case.active then child else nil}
		for _,probe in case.matches do
			local selector=assert(Selectors.compile(probe.selector))
			local expected=if probe.standardExpected~=nil then probe.standardExpected else probe.expected
			assert(Selectors.matches(Node.findById(document,probe.node),selector,states)==expected,
				case.name..': '..probe.node..' '..probe.selector)
		end
		local rules=Stylesheet.collect(document,error)
		for _,probe in case.pseudos do
			local declarations=Stylesheet.matchPseudo(rules,Node.findById(document,probe.node),probe.pseudo,states)
			local value=content(declarations)
			assert(value==probe.content,case.name..': '..probe.node..'::'..probe.pseudo..' '..tostring(value)..' ~= '..probe.content)
		end
	end
	local document=Parser.parseDocument('<div id="MiXeD" class="ToNe">Raw parser data</div>')
	assert(Selectors.matches(Node.findById(document,'MiXeD'),assert(Selectors.compile('#mixed.tone'))),'Parsed data reaches its mode before DOM installation')
	-- The same compiled rule must follow its node's current document, without
	-- caching a quirks decision across adoption or attribute changes.
	local standards=Node.document();standards.Mode='no-quirks'
	local target=Node.findById(document,'MiXeD');local selector=assert(Selectors.compile(':hover'))
	assert(not Selectors.matches(target,selector,{hover=target}))
	Node.removeChild(target.Parent,target);Node.append(standards,target)
	assert(not Selectors.matches(target,selector,{hover=target}),'Data-only insertion does not perform DOM adoption')
	target.OwnerDocument=standards
	assert(Selectors.matches(target,selector,{hover=target}))
	Node.removeChild(target.Parent,target);Node.append(document,target)
	target.OwnerDocument=document
	assert(not Selectors.matches(target,selector,{hover=target}))
	target.Name='a';assert(not Selectors.matches(target,selector,{hover=target}));target.Attributes.href=''
	assert(Selectors.matches(target,selector,{hover=target}))
	-- A pseudo-element exempts its own originating compound, not ancestors.
	local parent=Node.element('div',{});local nested=Node.element('span',{})
	Node.append(document,parent);Node.append(parent,nested)
	local pseudo=Stylesheet.collect(document,error,':hover::before{content:"own"}:hover > :hover::after{content:"ancestor"}')
	assert(content(Stylesheet.matchPseudo(pseudo,nested,'before',{hover=nested}))=='"own"')
	assert(content(Stylesheet.matchPseudo(pseudo,nested,'after',{hover=nested}))=='none')
	print('Quirks hover: '..#hoverFixture.cases..' trusted Chromium hover/pressed sequences, functional/compound/pseudo exemptions and live document modes passed')
	print('Quirks selectors: '..#fixture.cases..' native mode/ASCII-only/attribute/namespace/functional/live/adoption sequences passed')
end
