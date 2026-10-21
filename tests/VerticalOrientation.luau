--!strict
-- The official property file, including explicit default intervals, is the
-- independent oracle. This proves data lookup, not native font substitutions.
return function(Orientation: any,corpus: string,enclosing: {number})
 local expected={}
 for line in corpus:gmatch('[^\r\n]+')do
  local first,last,kind=line:match('^([%x]+)%.%.([%x]+)%s*;%s*(%a+)')
  if not first then first,kind=line:match('^([%x]+)%s*;%s*(%a+)');last=first end
  if first then for code=tonumber(first,16),tonumber(last,16)do expected[code]=kind end end
 end
 for code=0,0x10ffff do
  local result=Orientation.class(code)
  assert(result==(expected[code]or'R'),'Unicode17 Vertical_Orientation mismatch at '..code)
 end
 for _,code in enclosing do
  assert(Orientation.cluster('A'..utf8.char(code))=='U','Enclosing mark must orient the complete cluster: '..code)
 end
 assert(Orientation.cluster('A\u{308}')=='R'and Orientation.cluster('天\u{308}')=='U','Other marks preserve the first codepoint orientation')
 print('Vertical orientation: 1,114,112 Unicode17 codepoint classifications and '..#enclosing..' enclosing-mark adapters passed')
end
