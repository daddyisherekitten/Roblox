--!strict
return function(Unicode: any,Strings: any,corpus: string)
 local cases=0
 local function decode(source)
  local units={};for hex in source:gmatch('%x+')do local code=tonumber(hex,16);if code>0xffff then code-=0x10000;units[#units+1]=0xd800+math.floor(code/1024);code=0xdc00+code%1024 end;units[#units+1]=code end
  return Strings.fromUnits(units)
 end
 for line in corpus:gmatch('[^\r\n]+')do
  local source=line:match('^([^#]+)')
  if source and not source:match('^%s*@')then
   local columns={};for field in source:gmatch('([^;]*);')do columns[#columns+1]=decode(field)end
   if #columns>=5 then
    cases+=1
    for i=1,5 do
     assert(Unicode.normalize(columns[i],'NFC')==columns[if i<=3 then 2 else 4],`NFC corpus {cases}/{i}`)
     assert(Unicode.normalize(columns[i],'NFD')==columns[if i<=3 then 3 else 5],`NFD corpus {cases}/{i}`)
     assert(Unicode.normalize(columns[i],'NFKC')==columns[4],`NFKC corpus {cases}/{i}`)
     assert(Unicode.normalize(columns[i],'NFKD')==columns[5],`NFKD corpus {cases}/{i}`)
    end
   end
  end
 end
 assert(cases>19000,'Official Unicode normalization corpus incomplete')
 local lone=Strings.fromUnits({0xd800,0x65,0x301,0xdc00})
 assert(Unicode.normalize(lone)==Strings.fromUnits({0xd800,0xe9,0xdc00}),'Lone surrogates remain observable')
 print(`UnicodeNormalization passed ({cases} official Unicode {Unicode.Version} cases, all four forms)`)
end
