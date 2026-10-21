--!strict
return function(Parser,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local expected=case.standardExpected or case.expected
		local output,diagnostics={},{};local events=Events.new(error)
		local runtime=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),{Events=events,MaxSteps=2000000,
			Console=function(_,value)table.insert(output,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
		local ok,message=runtime:Run('function record(v){console.log(String(v));}'..case.source)
		assert(ok,case.name..': '..tostring(message));assert(#diagnostics==0,table.concat(diagnostics,' / '))
		assert(#output==#expected,case.name..': output count')
		for i,value in output do assert(value==expected[i],case.name..' ['..i..']: '..value..' ~= '..expected[i])end
		runtime:Destroy();events:Destroy()
	end
	local events=Events.new(error);local runtime=Runtime.new(Parser.parseDocument('<!doctype html>'),{Events=events,MaxSteps=100000})
	local ok,message=runtime:Run([=[
function check(v,m){if(!v)throw new Error(m);}
const d=new TextDecoder(' \tLATIN1\r\n');
check(d.encoding==='windows-1252' && d.decode(new Uint8Array([128]))==='€','ASCII label trimming and canonical aliases');
const u=new TextDecoder();
check(u.decode(new Uint8Array([239]),{stream:true})==='' && u.decode(new Uint8Array([187]),{stream:true})==='' && u.decode(new Uint8Array([191,65]))==='A','BOM spanning writes');
check(u.decode(new Uint8Array([239,187,191,66]))==='B','New calls reset BOM state');
check(new TextDecoder('utf-8',{ignoreBOM:true}).decode(new Uint8Array([239,187,191]))==='\ufeff','ignoreBOM retains the character');
check(new TextDecoder('windows-1252').decode(new Uint8Array([239,187,191]))==='ï»¿','Single-byte decoders do not remove UTF BOM bytes');
const f=new TextDecoder('utf-8',{fatal:true});
let errors=0;try{f.decode(new Uint8Array([255]));}catch(e){check(e.name==='TypeError','Fatal decoding type');errors++;}
check(f.decode(new Uint8Array([65]))==='A','Fatal decoder is reusable');
try{new TextDecoder('\u00a0utf-8');}catch(e){check(e.name==='RangeError','ASCII whitespace only');errors++;}
try{new TextDecoder('replacement');}catch(e){check(e.name==='RangeError','Replacement is not exposed by TextDecoder');errors++;}
check(errors===3,'Expected decoding failures');
]=]);assert(ok,tostring(message));runtime:Destroy();events:Destroy()
	print('Encoding: '..#fixture.cases..' Chromium traces, label aliases, byte mappings, BOM, streaming, fatal errors and reuse passed')
end
