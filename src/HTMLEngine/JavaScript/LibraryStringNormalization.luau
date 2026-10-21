--!strict
local Unicode=require(script.Parent.UnicodeNormalization)
local Library={}
function Library.install(c: any)
 c.method(c.prototypes.String,'normalize',0,function(args,value)
  if value==nil or value==c.U or value==c.N then c.fail('TypeError','String.normalize requires a receiver')end
  local source=c.text(value)
  local form=c.text(c.arg(args,1,'NFC'))
  if form~='NFC'and form~='NFD'and form~='NFKC'and form~='NFKD'then c.fail('RangeError','Invalid normalization form')end
  return c.stringResult(Unicode.normalize(source,form,c.step,function()c.fail('RangeError','Unicode normalization intermediate budget exceeded')end))
 end)
end
return Library
