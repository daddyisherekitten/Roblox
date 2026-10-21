-- Shared decoded at-keywords must reach CSSOM and the actual cascade.
return function(Parser,Runtime,Events,Sheet,Style,Node,native,Imports)
	for _,fixture in native.fixtures do
		local output;local document=Parser.parseDocument('<!doctype html><head><style id=style></style></head><body><p id=probe>Probe</p>')
		local runtime=Runtime.new(document,{Events=Events.new(error),Console=function(_,value)output=value end})
		runtime.VM.Global.Bindings.css={Value=fixture.css,Mutable=true}
		runtime:Run('document.getElementById("style").textContent=css; '..native.snapshot..' console.log(JSON.stringify(snapshot()));')
		assert(#runtime.Diagnostics==0,fixture.name..': '..table.concat(runtime.Diagnostics,' | '))
		assert(output==fixture.expected,fixture.name..': '..tostring(output)..' ~= '..fixture.expected)
		runtime:Destroy()
		local imports=Imports.read(fixture.css)
		assert((#imports>0)==(fixture.expected:find('"type":3',1,true)~=nil),fixture.name..': resource discovery must respect the same prelude grammar')
	end
	for _,fixture in native.mutationFixtures do
		local output={};local runtime=Runtime.new(Parser.parseDocument('<!doctype html><head><style id=style></style></head><body>'),{Events=Events.new(error),Console=function(_,value)table.insert(output,value)end})
		runtime.VM.Global.Bindings.css={Value=fixture.css,Mutable=true}
		runtime:Run('document.getElementById("style").textContent=css;const s=document.getElementById("style").sheet;function record(value){console.log(String(value))}try{'..fixture.source..'}catch(e){record("uncaught "+e.name)}record(Array.from(s.cssRules,r=>r.type).join(","));')
		assert(#runtime.Diagnostics==0,fixture.name..': '..table.concat(runtime.Diagnostics,' | '))
		assert(table.concat(output,' | ')==table.concat(fixture.standardExpected or fixture.expected,' | '),fixture.name..': '..table.concat(output,' | '))
		runtime:Destroy()
	end
	local document=Parser.parseDocument('<!doctype html><p id=probe>Probe</p>');local probe=Node.findElement(document,function(n)return n.Attributes and n.Attributes.id=='probe'end)
	local errors={};local css='@\\6c ayer café, \\62 ase; @\\69 mport u\\72 l("base.css") l\\61 yer(base) s\\75 pports(display: block); @layer café{#probe{color:red}} @\\6d edia (min-width:1px){#probe{height:27px}}'
	local rules=Sheet.collect(document,function(s)table.insert(errors,s)end,css,{['https://prelude.test/base.css']='#probe{color:blue}'},'https://prelude.test/index.html')
	Sheet.setMediaEnvironment(rules,{Width=800,Height=600})
	local resolved=Style.resolve(probe,{FontSize=16,Font='Arial'},error,false,Sheet.match(rules,probe))
	assert(#errors==0,table.concat(errors,' | '));assert(resolved.Color.B==1 and resolved.Color.R==0 and resolved.Height.Value==27,'Decoded keywords and imported Unicode layers reach actual values')
	local delimited=Sheet.collect(document,error,'@layer a\\.b,a.b;@layer a\\.b{#probe{color:red}}@layer a.b{#probe{color:blue}}')
	assert(Style.resolve(probe,{FontSize=16,Font='Arial'},error,false,Sheet.match(delimited,probe)).Color.B==1,'Escaped dot stays inside one layer identifier')
	print('CSS preludes: '..#native.fixtures..' native rule trees, '..#native.mutationFixtures..' mutation sequences and actual escaped import/group/layer cascade passed')
end
