--!strict
return function(Parser,Runtime,Events,fixture)
	for _,case in fixture.cases do
	for _,chunkBytes in {1,7,4096}do
		local parts={};for _,byte in case.bytes do table.insert(parts,string.char(byte))end
		local options=table.clone(case.options);options.ScriptingEnabled=true;options.DecodeChunkBytes=chunkBytes
		local parser=assert(Parser.newDocumentBytes(table.concat(parts),options),case.name..': certain byte parser required')
		local first=parser:Advance()
		assert(first and not parser.Done and not parser.Document.Body,case.name..': parser must pause at its first head script')
		local events=Events.new(error);local results={}
		local realm=Runtime.new(parser.Document,{URL='https://bytes.test/page',Events=events,ParserSession=parser,ParserFirstScript=first,
			ApplyChanges=function()return false end,Console=function(_,value)table.insert(results,value)end})
		realm:Start();for _=1,4 do realm:PumpTasks()end
		assert(#realm.Diagnostics==0,case.name..': '..table.concat(realm.Diagnostics,' | '))
		assert(#results==#case.expected,case.name..': '..table.concat(results,' | '))
		for index,wanted in case.expected do assert(results[index]==wanted,case.name..'['..index..']: '..tostring(results[index])..' vs '..wanted)end
		assert(parser.Document.EncodingConfidence=='certain'and parser.Document.EncodingRestarts==0 and parser.Document.ByteLength==#case.bytes)
		realm:Destroy();events:Destroy();assert(not parser.Alive,'Byte parser source must be released with its realm')
	end
	end
	assert(Parser.newDocumentBytes('<!doctype html><meta charset=utf-8>')==nil,'Tentative decoding stays on its explicit bounded pre-publication path')
	for _,options in {{TransportEncoding=1},{MaxBytes=1},{DecodeChunkBytes=0},{DecodeChunkBytes=65537},{DecodeChunkBytes='1'}}do
		assert(not pcall(Parser.newDocumentBytes,'<p>',options),'Byte session validation must precede tokenization')
	end
	local limited=Parser.newDocumentBytes('<p>',{TransportEncoding='utf-8',MaxDecodedBytes=1})
	assert(not pcall(limited.Advance,limited)and not limited.Alive,'Incremental decode output limits terminate and release the parser')
	local early=Parser.newDocumentBytes('<script>0</script>'..string.rep('\255',2000),{TransportEncoding='utf-8',DecodeChunkBytes=7,MaxDecodedBytes=100})
	assert(early:Advance()and early.Alive,'A parser script boundary must not decode and reject the future source')
	assert(not pcall(early.Advance,early)and not early.Alive,'A later expanding chunk still observes the cumulative output budget')
	local work=require('WorkContext');local cancelled,steps={},0
	local aborting=Parser.newDocumentBytes(string.rep('x',20000),{TransportEncoding='utf-8',DecodeChunkBytes=7})
	local ok,message=pcall(work.with,function()steps+=1;if steps==80 then error(cancelled,0)end end,aborting.Advance,aborting)
	assert(not ok and message==cancelled and not aborting.Alive,'Cooperative cancellation releases a live byte source and preserves the cancellation identity')
	print('Live byte documents: '..#fixture.cases..' native certain-encoding/script/write cases at three decoder chunk sizes passed')
end
