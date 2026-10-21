--!strict
-- UAX #15 decomposition, canonical ordering and blocked composition, including
-- algorithmic Hangul. Lone ECMAScript surrogate units pass through unchanged.
local Strings=require(script.Parent.Strings)
local Data=require(script.Parent.UnicodeNormalizationData)
local Unicode={Version=Data.Version}
function Unicode.normalize(value: string,form: string?,charge: (() -> ())?,overflow: (() -> ())?): string
 form=form or 'NFC';assert(form=='NFC'or form=='NFD'or form=='NFKC'or form=='NFKD','Invalid normalization form')
 if not value:find('[\128-\255]')then return value end
 local compatibility=form=='NFKC'or form=='NFKD';local output={}
 local function emit(code)
  if charge then charge()end
  if #output>=262144 then if overflow then overflow()end;error('Unicode normalization intermediate budget exceeded',0)end
  if code>=0xac00 and code<0xd7a4 then
   local index=code-0xac00;output[#output+1]=0x1100+math.floor(index/588);output[#output+1]=0x1161+math.floor(index%588/28)
   if index%28~=0 then output[#output+1]=0x11a7+index%28 end
  else
   local mapping=Data.Decomposition[code]
   if mapping and(mapping[1]==0 or compatibility)then for i=2,#mapping do emit(mapping[i])end else output[#output+1]=code end
  end
 end
 for code in Strings.codes(value)do emit(code)end
 -- Sort combining runs stably, rather than quadratic insertion sorting for a
 -- long user string of marks. Starters and lone surrogates keep their boundary.
 local at=1
 while at<=#output do
  if(Data.Combining[output[at]]or 0)==0 then at+=1;continue end
  local first=at;local marks={}
  while at<=#output and(Data.Combining[output[at]]or 0)~=0 do marks[#marks+1]={Code=output[at],Class=Data.Combining[output[at]],Index=at};at+=1 end
  table.sort(marks,function(a,b)if charge then charge()end;return if a.Class==b.Class then a.Index<b.Index else a.Class<b.Class end)
  for i,mark in marks do output[first+i-1]=mark.Code end
 end
 if form=='NFC'or form=='NFKC'then
  local composed={};local starterIndex,starter,lastClass=0,0,0
  for _,code in output do
   if charge then charge()end
   local class=Data.Combining[code]or 0;local composite
   if starterIndex>0 and(lastClass==0 or lastClass<class)then
    if starter>=0x1100 and starter<0x1113 and code>=0x1161 and code<0x1176 then composite=0xac00+(starter-0x1100)*588+(code-0x1161)*28
    elseif starter>=0xac00 and starter<0xd7a4 and(starter-0xac00)%28==0 and code>0x11a7 and code<0x11c3 then composite=starter+code-0x11a7
    else local row=Data.Composition[starter];composite=row and row[code]end
   end
   if composite then composed[starterIndex]=composite;starter=composite
   else composed[#composed+1]=code;if class==0 then starterIndex,starter=#composed,code end;lastClass=class end
  end
  output=composed
 end
 local units={};for _,code in output do if code>0xffff then code-=0x10000;units[#units+1]=0xd800+math.floor(code/1024);code=0xdc00+code%1024 end;units[#units+1]=code end
 return Strings.fromUnits(units)
end
return Unicode
