--!strict
local Strings=require(script.Parent.Strings)
local Unicode=require(script.Parent.RegExpUnicode)
local Syntax={}
function Syntax.compile(source: string,flagText: string,step: any,fail: any): any
 local flags={};for i=1,#flagText do local c=flagText:sub(i,i);if not string.find("dgimsuvy",c,1,true)or flags[c]then fail("Invalid regular expression flags")end;flags[c]=true end
 if flags.u and flags.v then fail("RegExp flags u and v cannot be combined")end
 local unicode=flags.u or flags.v;local input=Strings.units(source);local at,count,depth,nodes=1,0,0,0;local names,refs={},{};local current=flags
 local alternationId=0;local choices,groupPaths={},{}
 local function peek(offset)return input[at+(offset or 0)]end
 local function take()local c=input[at];at+=1;return c end
 local function digit(c)return c and c>=48 and c<=57 end
 local function literal(cp)return {Type="char",Code=cp}end
 local function node(kind,fields)nodes+=1;step();if nodes>4096 then fail("RegExp syntax node budget exceeded")end;local value=fields or {};value.Type=kind;value.Flags=current;return value end
 local function code()
  local cp=take();if unicode and cp and cp>=0xd800 and cp<=0xdbff and peek()and peek()>=0xdc00 and peek()<=0xdfff then cp=0x10000+(cp-0xd800)*1024+take()-0xdc00 end;return cp
 end
 local function hex(n)
  local result=0;for i=0,n-1 do local c=input[at+i];local v=c and c<128 and tonumber(string.char(c),16);if not v then return nil end;result=result*16+v end;at+=n;return result
 end
 local function identifier()
  local chars={};while peek()and peek()~=62 do local cp=take()
   if cp==92 then if take()~=117 then fail("Invalid capture group name escape")end;cp=hex(4);if not cp then fail("Invalid capture group name")end end
   table.insert(chars,cp)
  end
  if take()~=62 or #chars==0 then fail("Invalid capture group name")end
  for i,cp in chars do
   local ranges=Unicode.Properties[if i==1 then "binary=ID_Start"else "binary=ID_Continue"];local allowed=cp==36 or cp==95 or(i>1 and(cp==0x200c or cp==0x200d))
   if not allowed then for j=1,#ranges,2 do if cp>=ranges[j]and cp<=ranges[j+1]then allowed=true;break end end end
   if not allowed then fail("Invalid capture group name")end
  end;return Strings.fromUnits(chars)
 end
 local escape,class,disjunction
 escape=function(inClass)
  local c=take();if not c then fail("Trailing regular expression escape")end
  if c==100 or c==68 or c==115 or c==83 or c==119 or c==87 then return {Type="builtin",Name=string.char(c)}end
  if not inClass and(c==98 or c==66)then return node("boundary",{Negate=c==66})end
  local controls={[98]=8,[102]=12,[110]=10,[114]=13,[116]=9,[118]=11};if controls[c]then return literal(controls[c])end
  if c==99 then local letter=peek();if letter and((letter>=65 and letter<=90)or(letter>=97 and letter<=122))then take();return literal(letter%32)end;if unicode then fail("Invalid control escape")end;return literal(99)end
  if c==120 or c==117 then
   if c==117 and unicode and peek()==123 then take();local values={};while peek()and peek()~=125 do table.insert(values,take())end;if take()~=125 or #values==0 then fail("Invalid Unicode escape")end;local number=tonumber(Strings.fromUnits(values),16);if not number or number>0x10ffff then fail("Invalid Unicode escape")end;return literal(number)end
   local value=hex(if c==120 then 2 else 4)
   if not value then if unicode then fail("Invalid hexadecimal escape")end;return literal(c)end
   if unicode and value>=0xd800 and value<=0xdbff then
    local save=at;local low
    if peek()==92 and peek(1)==117 then at+=2;low=hex(4)elseif peek()and peek()>=0xdc00 and peek()<=0xdfff then low=take()end
    if low and low>=0xdc00 and low<=0xdfff then value=0x10000+(value-0xd800)*1024+low-0xdc00 else at=save end
   end;return literal(value)
  end
  if(c==112 or c==80)and unicode then
   if take()~=123 then fail("Invalid Unicode property escape")end;local parts={};while peek()and peek()~=125 do table.insert(parts,take())end;if take()~=125 then fail("Unterminated Unicode property escape")end
   local name=Strings.fromUnits(parts);local property=Unicode.Aliases[name]
   if not property and flags.v and Unicode.StringProperties[name]then if c==80 then fail("String Unicode properties cannot be complemented")end;return {Type="strings",Strings=Unicode.StringProperties[name]}end
   if not property then fail("Unknown Unicode property: "..name)end
   return {Type="property",Ranges=Unicode.Properties[property],Negate=c==80}
  end
  if not inClass and c==107 and peek()==60 then take();local value=node("backref",{Name=identifier()});table.insert(refs,value);return value end
  if c>=49 and c<=57 and not inClass then local digits={c};while digit(peek())do table.insert(digits,take())end;local value=node("backref",{Index=tonumber(Strings.fromUnits(digits)),Digits=digits});table.insert(refs,value);return value end
  if digit(c)then
   if unicode and(c~=48 or digit(peek()))then fail("Invalid decimal escape")end
   if c<=55 then local value=c-48;local remaining=if c<=51 then 2 else 1;while remaining>0 and peek()and peek()>=48 and peek()<=55 do value=value*8+take()-48;remaining-=1 end;return literal(value)end
   return literal(c)
  end
  if unicode and(c>=128 or(not string.find("^$\\.*+?()[]{}|/",string.char(c),1,true)and not(inClass and c==45)and not(flags.v and inClass and string.find("&-!#%,:;<=>@`~",string.char(c),1,true))))then fail("Invalid identity escape")end
  return literal(c)
 end
 class=function()
  depth+=1;if depth>128 then fail("RegExp nesting budget exceeded")end
  local negate=peek()==94;if negate then take()end
  local terms={};local operation=nil;local operands={}
  local function atom()
   local c=peek();if not c then fail("Unterminated character class")end
   if flags.v and c==91 then take();return class()end
   if c==92 then take()
    if flags.v and peek()==113 and peek(1)==123 then
     at+=2;local alternatives,chars={},{}
     while peek()and peek()~=125 do
      if peek()==124 then take();table.insert(alternatives,chars);chars={}
      elseif peek()==92 then take();local item=escape(true);if item.Type~="char"then fail("Class string escapes must be characters")end;table.insert(chars,item.Code)
      else table.insert(chars,code())end
     end;if take()~=125 then fail("Unterminated class string")end;table.insert(alternatives,chars);return {Type="strings",Strings=alternatives}
    end
    return escape(true)
   end
   if flags.v and c<128 and(string.find("(){}|/-",string.char(c),1,true)or(c==peek(1)and string.find("!#$%&*+,.:;<=>?@^`~",string.char(c),1,true)))then fail("Reserved Unicode set character")end
   return literal(code())
  end
  while peek()and peek()~=93 do
   if flags.v and((peek()==38 and peek(1)==38)or(peek()==45 and peek(1)==45))then
    local op=if take()==38 then "intersect"else "subtract";take();if #terms~=1 or terms[1].Type=="range"or(operation and operation~=op)then fail("Invalid Unicode set operation")end
    table.insert(operands,{Type="union",Terms=terms});terms={};operation=op
   else
    local item=atom()
    if peek()==45 and peek(1)~=93 and peek(1)~=nil and not(flags.v and peek(1)==45)then
     take();local ending=atom()
     if item.Type=="char"and ending.Type=="char"then if item.Code>ending.Code then fail("Character class range out of order")end;item={Type="range",First=item.Code,Last=ending.Code}
     elseif unicode then fail("Invalid character class range")else table.insert(terms,item);table.insert(terms,literal(45));item=ending end
    end;table.insert(terms,item)
   end
  end
  if take()~=93 then fail("Unterminated character class")end
  if operation and(#terms~=1 or terms[1].Type=="range")then fail("Invalid Unicode set operand")end
  local result={Type="union",Terms=terms};if operation then table.insert(operands,result);result={Type=operation,Terms=operands}end
  if negate then
   local function strings(set)if set.Type=="strings"then for _,item in set.Strings do if #item~=1 then return true end end elseif set.Terms then for _,term in set.Terms do if strings(term)then return true end end end;return false end
   if flags.v and strings(result)then fail("Negated Unicode sets cannot contain strings")end
   result={Type="negate",Child=result}
  end;depth-=1;return result
 end
 local sequence
 sequence=function()
  local terms={}
  while peek()and peek()~=41 and peek()~=124 do
   local firstCapture=count+1;local c=take();local atom
   if c==40 then
    depth+=1;if depth>128 then fail("RegExp nesting budget exceeded")end
    local groupType,name,negative="capture",nil,false;local previous=current
    if peek()==63 then take();local q=take()
     if q==58 then groupType="group"
     elseif q==61 or q==33 then groupType="lookahead";negative=q==33
     elseif q==60 then if peek()==61 or peek()==33 then groupType="lookbehind";negative=take()==33 else name=identifier()end
     elseif q==105 or q==109 or q==115 or q==45 then
      groupType="group";current=table.clone(current);at-=1;local remove=false;local seen={};local added,removed=0,0
      while peek()and peek()~=58 do local f=take();if f==45 and not remove then remove=true;continue end;if f>=128 then fail("Invalid scoped RegExp flags")end;local key=string.char(f);if not string.find("ims",key,1,true)or seen[key]then fail("Invalid scoped RegExp flags")end;seen[key]=true;current[key]=not remove;added+=1;if remove then removed+=1 end end
      if take()~=58 or added==0 or(remove and removed==0)then fail("Invalid scoped RegExp flags")end
     else fail("Invalid regular expression group")end
    end
    local id;if groupType=="capture"then
     count+=1;id=count;groupPaths[id]=table.clone(choices)
     if name then
      for _,earlier in names[name]or {}do local exclusive=false;for key,branch in groupPaths[earlier]do if choices[key]and choices[key]~=branch then exclusive=true;break end end;if not exclusive then fail("Duplicate named capture group")end end
      names[name]=names[name]or {};table.insert(names[name],id)
     end
    end
    local body=disjunction();if take()~=41 then fail("Unterminated regular expression group")end
    atom=node(groupType,{Child=body,Index=id,Name=name,Negate=negative});current=previous;depth-=1
   elseif c==91 then atom=node("class",{Set=class()})
   elseif c==92 then local escaped=escape(false);if escaped.Type=="char"then atom=node("literal",{Code=escaped.Code})elseif escaped.Type=="builtin"or escaped.Type=="property"or escaped.Type=="strings"then atom=node("class",{Set=escaped})else atom=escaped end
   elseif c==46 then atom=node("dot")elseif c==94 then atom=node("start")elseif c==36 then atom=node("end")
   elseif c==42 or c==43 or c==63 then fail("Nothing to repeat")
   elseif unicode and(c==93 or c==123 or c==125)then fail("Unexpected RegExp syntax character")
   else at-=1;atom=node("literal",{Code=code()})end
   local q=peek();local min,max
   if q==42 then take();min,max=0,math.huge elseif q==43 then take();min,max=1,math.huge elseif q==63 then take();min,max=0,1
   elseif q==123 then local save=at;take();local digits={};while digit(peek())do table.insert(digits,take())end
    if #digits>0 then min=tonumber(Strings.fromUnits(digits));max=min;if peek()==44 then take();digits={};while digit(peek())do table.insert(digits,take())end;max=if #digits==0 then math.huge else tonumber(Strings.fromUnits(digits))end end
    if not min or take()~=125 then at=save;min,max=nil,nil;if unicode then fail("Invalid quantifier")end elseif max<min then fail("Quantifier bounds out of order")end
   end
   if min then
    if atom.Type=="start"or atom.Type=="end"or atom.Type=="boundary"or atom.Type=="lookbehind"or(unicode and atom.Type=="lookahead")then fail("Assertion cannot be quantified")end
    local greedy=peek()~=63;if not greedy then take()end;atom=node("repeat",{Child=atom,Min=min,Max=max,Greedy=greedy,FirstCapture=firstCapture,LastCapture=count})
   end;table.insert(terms,atom)
  end;return node("sequence",{Terms=terms})
 end
 disjunction=function()
  alternationId+=1;local id=alternationId;choices[id]=1;local alternatives={sequence()}
  while peek()==124 do take();choices[id]+=1;table.insert(alternatives,sequence())end;choices[id]=nil
  return if #alternatives==1 then alternatives[1]else node("alternation",{Terms=alternatives})
 end
 local tree=disjunction();if peek()then fail("Unexpected closing parenthesis")end
 for _,ref in refs do
  if ref.Name then if names[ref.Name]then ref.Indices=names[ref.Name]elseif unicode or next(names)then fail("Unknown named backreference")else ref.Type="sequence";ref.Terms={};for _,cp in Strings.units("k<"..ref.Name..">")do table.insert(ref.Terms,{Type="literal",Code=cp,Flags=ref.Flags})end end
  elseif ref.Index>count then if unicode then fail("Invalid backreference")end
   local digits=ref.Digits;local i,value=1,0;local limit=if digits[1]<=51 then 3 else 2
   while i<=#digits and i<=limit and digits[i]<=55 do value=value*8+digits[i]-48;i+=1 end
   ref.Type="sequence";ref.Terms={};if i>1 then table.insert(ref.Terms,{Type="literal",Code=value,Flags=ref.Flags})end;for j=i,#digits do table.insert(ref.Terms,{Type="literal",Code=digits[j],Flags=ref.Flags})end
  end
 end
 return {Tree=tree,Source=source,Flags=flags,Count=count,Names=names}
end
return Syntax
