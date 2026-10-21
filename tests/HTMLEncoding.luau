--!strict
return function(Parser,Node,Sniff,Info,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local expected=case.standardExpected or case.expected
		local parts={};for _,byte in case.bytes do table.insert(parts,string.char(byte))end
		local document=Parser.parseDocumentBytes(table.concat(parts),case.options)
		assert(document.CharacterEncoding==expected.encoding,case.name..': encoding '..document.CharacterEncoding..' ~= '..expected.encoding)
		local probe=Node.findById(document,'probe')or document.Body
		assert(Node.textContent(probe)==expected.text,case.name..': decoded text '..Node.textContent(probe)..' ~= '..expected.text)
		local warnings={};local metadata=Info.collect(document,'https://example.test/',function(message)table.insert(warnings,message)end)
		assert(metadata.Charset==document.CharacterEncoding:lower()and #warnings==0,case.name..': metadata reflects actual decoding')
		assert(document.EncodingRestarts<=1 and document.ByteLength==#case.bytes,'Bounded restart and original size')
		if case.name=='Late meta restarts'or case.name=='Partial declaration at prescan boundary'or case.name=='Late entity label uses parser'then
			assert(document.EncodingRestarts==1 and document.EncodingSource=='parser-meta',case.name..': actual parser restart')
		elseif case.name=='BOM beats transport'or case.name=='UTF-16LE BOM'or case.name=='UTF-16BE BOM'then assert(document.EncodingRestarts==0 and document.EncodingSource=='bom',case.name..': certain BOM cannot restart')end
	end
	local document=Parser.parseDocumentBytes('<!doctype html><meta charset=windows-1251><p id="probe">\192\255</p>')
	local events=Events.new(error);local runtime=Runtime.new(document,{Events=events})
	local ok,message=runtime:Run([=[
if(document.characterSet!=='windows-1251' || document.charset!==document.characterSet || document.inputEncoding!==document.characterSet)throw new Error('Document encoding aliases');
document.querySelector('meta').setAttribute('charset','utf-8');
if(document.characterSet!=='windows-1251' || document.getElementById('probe').textContent!=='Ая')throw new Error('Post-parse metadata cannot recode an existing document');
]=]);assert(ok,tostring(message));runtime:Destroy();events:Destroy()
	assert(Sniff.content('charset nope; charset = "latin1"')=='windows-1252','Content extraction retries missing equals')
	assert(Sniff.content('charset=bogus; charset=utf-8')==nil,'First encoding value fails without falling through')
	assert(Sniff.prescan('<meta charset=bogus content="text/html;charset=utf-8" http-equiv=content-type>')==nil,'Invalid direct prescan label suppresses content fallback')
	assert(Sniff.meta({charset='bogus',content='text/html;charset=utf-8',['http-equiv']='content-type'})=='utf-8','Real parser can use the content pragma after invalid direct label')
	local chosen,confidence=Sniff.detect('',{ParentEncoding='shift_jis',ParentSameOrigin=true});assert(chosen=='shift_jis'and confidence=='tentative')
	chosen=Sniff.detect('',{ParentEncoding='utf-16le',ParentSameOrigin=true});assert(chosen=='windows-1252','Do not inherit an ASCII-incompatible UTF16 parent')
	chosen=Sniff.detect('',{OverrideEncoding='utf-8',TransportEncoding='latin1'});assert(chosen=='utf-8','Explicit user override priority')
	local old=Parser.parseDocument('<meta charset=windows-1251><p>ä</p>');assert(Node.textContent(old.Body)=='ä'and not old.CharacterEncoding,'Decoded strings are never reinterpreted')
	local success=pcall(Parser.parseDocumentBytes,'abc',{MaxBytes=2});assert(not success,'Byte input limit')
	success=pcall(Parser.parseDocumentBytes,'\255',{TransportEncoding='utf-8',MaxDecodedBytes=2});assert(not success,'Decoded expansion limit')
	for _,options in {false,{TransportEncoding=4},{ParentSameOrigin='true'},{DefaultEncoding='invalid'}}do
		assert(not pcall(Parser.parseDocumentBytes,'',options),'Invalid byte options fail before parsing')
	end
	local work=require('WorkContext');local checkpoints=0;local cancelled={}
	local okCancel,errorCancel=pcall(work.with,function()checkpoints+=1;if checkpoints==64 then error(cancelled,0)end end,Parser.parseDocumentBytes,string.rep('x',5000),{TransportEncoding='utf-8'})
	assert(not okCancel and errorCancel==cancelled and checkpoints==64,'Decode cancellation propagates before building the DOM')
	local decoder=require('Encoding/Decoder');local outputSteps=0
	local okLimit=pcall(decoder.decode,{Encoding='windows-1252',Pending='',MaxOutputBytes=2},string.rep('\128',10000),false,function()outputSteps+=1 end)
	assert(not okLimit and outputSteps==1,'Decoded byte limit stops at the first expanding scalar')
	print('HTML encoding: '..#fixture.cases..' real Chromium HTTP sources, byte sniffing, parser restarts, document properties and limits passed')
end
