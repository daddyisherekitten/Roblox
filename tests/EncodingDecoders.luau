--!strict
return function(Decoder,fixture)
	for _,case in fixture.pairs do
		local expected=case.standardRows or case.rows
		for lead=0,255 do
			local hash=5381
			for trail=0,255 do
				local state={Encoding=case.encoding,Pending='',SeenBOM=false}
				for _,cp in utf8.codes(Decoder.decode(state,string.char(lead,trail),false))do hash=(hash*33+cp)%4294967296 end
				hash=(hash*33+0x110000)%4294967296
			end
			assert(hash==expected[lead+1],case.encoding..' byte-pair row '..lead..': '..hash..' ~= '..expected[lead+1])
		end
	end
	print('Encoding decoders: '..#fixture.pairs..' complete 65536 byte-pair comparisons passed')
end
