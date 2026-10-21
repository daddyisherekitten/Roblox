--!strict
-- Exact signed integers using binary limbs. Values contain no realm closures;
-- arithmetic is bounded to 4096 bits and charged through the calling VM.
local Strings=require(script.Parent.Strings)
local BigInt={}
local BASE,MAX=65536,256
local alphabet='0123456789abcdefghijklmnopqrstuvwxyz'
function BigInt.is(value: any): boolean return type(value)=='table'and value.Kind=='bigint' end
local function normalize(digits)
 while #digits>0 and digits[#digits]==0 do digits[#digits]=nil end;return digits
end
local function value(digits,sign)
 normalize(digits);local chunks={};for i=#digits,1,-1 do chunks[#chunks+1]=string.format('%04x',digits[i])end
 return {Kind='bigint',Digits=digits,Sign=if #digits==0 then 0 else sign,Canonical=(if sign<0 and #digits>0 then '-'else '')..table.concat(chunks)}
end
local function compareMagnitude(a,b)
 if #a~=#b then return if #a<#b then -1 else 1 end
 for i=#a,1,-1 do if a[i]~=b[i]then return if a[i]<b[i]then -1 else 1 end end;return 0
end
function BigInt.Compare(a: any,b: any): number
 if a.Sign~=b.Sign then return if a.Sign<b.Sign then -1 else 1 end;return compareMagnitude(a.Digits,b.Digits)*a.Sign
end
function BigInt.Equal(a: any,b: any): boolean return BigInt.is(a)and BigInt.is(b)and BigInt.Compare(a,b)==0 end
local function fromNumber(n)
 local digits={};local positive=math.abs(n);while positive>=1 do digits[#digits+1]=positive%BASE;positive=math.floor(positive/BASE)end;return value(digits,if n<0 then -1 else 1)
end
local function bits(digits)
 if #digits==0 then return 0 end;local top,n=digits[#digits],0;while top>0 do top=math.floor(top/2);n+=1 end;return (#digits-1)*16+n
end
local function bit(digits,at)local item=digits[math.floor(at/16)+1]or 0;return math.floor(item/2^(at%16))%2 end
local function smallDivision(digits,divisor)
 local quotient,carry={},0;for i=#digits,1,-1 do local current=carry*BASE+digits[i];quotient[i]=math.floor(current/divisor);carry=current%divisor end;return normalize(quotient),carry
end
function BigInt.String(v: any,radix: number?): string
 radix=radix or 10;if v.Sign==0 then return '0'end
 local digits=table.clone(v.Digits);local out={};while #digits>0 do local rem;digits,rem=smallDivision(digits,radix);out[#out+1]=alphabet:sub(rem+1,rem+1)end
 local result={};if v.Sign<0 then result[1]='-'end;for i=#out,1,-1 do result[#result+1]=out[i]end;return table.concat(result)
end
function BigInt.Number(v: any): number
 local length=bits(v.Digits);local shift=math.max(length-53,0);local n=0;for at=length-1,shift,-1 do n=n*2+bit(v.Digits,at)end
 if shift>0 and bit(v.Digits,shift-1)==1 then
  local above=false;for at=0,shift-2 do if bit(v.Digits,at)==1 then above=true;break end end
  if above or n%2==1 then n+=1 end
 end;return n*2^shift*v.Sign
end
function BigInt.CompareNumber(v: any,n: number): number?
 if n~=n then return nil elseif n==math.huge then return -1 elseif n==-math.huge then return 1 end
 local integer=if n<0 then math.ceil(n)else math.floor(n);local result=BigInt.Compare(v,fromNumber(integer))
 return if result~=0 or n==integer then result else if n>integer then -1 else 1
end
function BigInt.install(vm: any,globals: any): any
 if vm.BigInt then return vm.BigInt end
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};vm.BigInt=api
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function check()assert(api.Alive and vm.Alive,'JavaScript BigInt disposed')end
 local function charge(n)for _=1,n or 1 do vm.Step()end end
 local function bound(digits)if #digits>MAX then fail('RangeError','BigInt exceeds 4096-bit budget')end;return digits end
 local function make(digits,sign)return value(bound(normalize(digits)),sign)end
 local function addMagnitude(a,b)
  local out,carry={},0;for i=1,math.max(#a,#b)do charge();local sum=(a[i]or 0)+(b[i]or 0)+carry;out[i]=sum%BASE;carry=math.floor(sum/BASE)end
  if carry>0 then out[#out+1]=carry end;return bound(out)
 end
 local function subtractMagnitude(a,b)
  local out,borrow={},0;for i=1,#a do charge();local diff=a[i]-(b[i]or 0)-borrow;borrow=if diff<0 then 1 else 0;out[i]=diff%BASE end;return normalize(out)
 end
 local function add(a,b)
  if a.Sign==0 then return b elseif b.Sign==0 then return a end
  if a.Sign==b.Sign then return make(addMagnitude(a.Digits,b.Digits),a.Sign)end
  local order=compareMagnitude(a.Digits,b.Digits);return if order>=0 then make(subtractMagnitude(a.Digits,b.Digits),a.Sign)else make(subtractMagnitude(b.Digits,a.Digits),b.Sign)
 end
 local function negate(v)return make(table.clone(v.Digits),-v.Sign)end
 local function multiply(a,b)
  if a.Sign==0 or b.Sign==0 then return make({},0)end
  if #a.Digits+#b.Digits>MAX+1 then fail('RangeError','BigInt exceeds multiplication budget')end
  local out={};for i=1,#a.Digits do local carry=0;for j=1,#b.Digits do charge();local at=i+j-1;local product=(out[at]or 0)+a.Digits[i]*b.Digits[j]+carry;out[at]=product%BASE;carry=math.floor(product/BASE)end
   out[i+#b.Digits]=carry
  end;return make(out,a.Sign*b.Sign)
 end
 local function left(digits,count)
  if #digits==0 then return {}end;local whole,partial=math.floor(count/16),count%16
  if #digits+whole>MAX then fail('RangeError','BigInt shift exceeds budget')end
  local out={};for i=1,whole do out[i]=0 end;local carry=0;for i=1,#digits do charge();local item=digits[i]*2^partial+carry;out[i+whole]=item%BASE;carry=math.floor(item/BASE)end
  if carry>0 then out[#out+1]=carry end;return bound(out)
 end
 local function right(digits,count)
  local whole,partial=math.floor(count/16),count%16;local out={};local lost=false
  for i=1,math.min(whole,#digits)do if digits[i]~=0 then lost=true end end
  if whole>=#digits then return {},lost end
  if partial>0 and digits[whole+1]%2^partial~=0 then lost=true end
  for i=whole+1,#digits do charge();out[i-whole]=math.floor(digits[i]/2^partial)+(if partial>0 then((digits[i+1]or 0)%2^partial)*2^(16-partial)else 0)end
  return normalize(out),lost
 end
 local function divide(a,b)
  if b.Sign==0 then fail('RangeError','BigInt division by zero')end
  if compareMagnitude(a.Digits,b.Digits)<0 then return make({},0),a end
  local quotient,remainder={},{};local size=bits(a.Digits)
  for at=size-1,0,-1 do charge();remainder=left(remainder,1);if bit(a.Digits,at)==1 then remainder[1]=(remainder[1]or 0)+1 end
   if compareMagnitude(remainder,b.Digits)>=0 then remainder=subtractMagnitude(remainder,b.Digits);local limb=math.floor(at/16)+1;quotient[limb]=(quotient[limb]or 0)+2^(at%16)end
  end
  -- Quotient limbs may have internal zero gaps after bitwise construction.
  for i=1,math.ceil(size/16)do quotient[i]=quotient[i]or 0 end
  return make(quotient,a.Sign*b.Sign),make(remainder,a.Sign)
 end
 function api:Parse(source)
  check();source=Strings.trim(source);if #source>16384 then fail('RangeError','BigInt input budget exceeded')end
  local sign=1;local signed=false;if source:sub(1,1)=='+'or source:sub(1,1)=='-'then signed=true;sign=if source:sub(1,1)=='-'then -1 else 1;source=source:sub(2)end
  if source==''then if signed then fail('SyntaxError','Invalid BigInt string')end;return make({},0)end
  local radix=10;local prefix=source:sub(1,2):lower();if prefix=='0x'or prefix=='0o'or prefix=='0b'then if signed then fail('SyntaxError','Invalid signed radix BigInt')end;radix=if prefix=='0x'then 16 elseif prefix=='0o'then 8 else 2;source=source:sub(3)end
  if source==''then fail('SyntaxError','Invalid BigInt string')end
  local digits={};for i=1,#source do charge();local character=source:sub(i,i):lower();local found=alphabet:find(character,1,true);local digit=if found then found-1 else 36
   if digit>=radix then fail('SyntaxError','Invalid BigInt digit')end
   local carry=digit;for j=1,#digits do charge();local item=digits[j]*radix+carry;digits[j]=item%BASE;carry=math.floor(item/BASE)end
   if carry>0 then digits[#digits+1]=carry end;bound(digits)
  end;return make(digits,sign)
 end
 function api:ToBigInt(input)
  check();local primitive=vm.ToPrimitive(input,'number');if BigInt.is(primitive)then return primitive elseif primitive==true then return make({1},1)elseif primitive==false then return make({},0)
  elseif type(primitive)=='string'then return self:Parse(primitive)end;fail('TypeError','Value cannot be converted to BigInt')
 end
 function api:FromNumber(input)
  check();if input~=input or math.abs(input)==math.huge or input~=math.floor(input)then fail('RangeError','BigInt number must be a finite integer')end;return make(fromNumber(input).Digits,if input<0 then -1 else 1)
 end
 api.Is=BigInt.is;api.ToString=function(_,v,radix)check();charge(#v.Digits);return BigInt.String(v,radix)end;api.ToNumber=function(_,v)return BigInt.Number(v)end
 api.Compare=function(_,a,b)return BigInt.Compare(a,b)end;api.Equal=function(_,a,b)return BigInt.Equal(a,b)end
 function api:Unary(op,a)
  check();if not BigInt.is(a)then fail('TypeError','BigInt operand required')end
  if op=='-'then return negate(a)elseif op=='~'then return add(negate(a),make({1},-1))elseif op=='++'then return add(a,make({1},1))elseif op=='--'then return add(a,make({1},-1))end;fail('TypeError','Unsupported BigInt unary operation')
 end
 local function twos(a,n)
  local out={};for i=1,n do out[i]=a.Digits[i]or 0 end
  if a.Sign<0 then local carry=1;for i=1,n do local item=65535-out[i]+carry;out[i]=item%BASE;carry=math.floor(item/BASE)end end;return out
 end
 function api:Binary(op,a,b)
  check();if not BigInt.is(a)or not BigInt.is(b)then fail('TypeError','Cannot mix BigInt and Number operands')end
  if op=='+'then return add(a,b)elseif op=='-'then return add(a,negate(b))elseif op=='*'then return multiply(a,b)
  elseif op=='/'or op=='%'then local q,r=divide(a,b);return if op=='/'then q else r
  elseif op=='**'then
   if b.Sign<0 then fail('RangeError','BigInt exponent must be nonnegative')end;if b.Sign==0 then return make({1},1)end
   if a.Sign==0 then return a end;if #a.Digits==1 and a.Digits[1]==1 then return make({1},if a.Sign<0 and b.Digits[1]%2==1 then -1 else 1)end
   if #b.Digits>1 or b.Digits[1]>4096 then fail('RangeError','BigInt exponent exceeds budget')end
   local exponent=b.Digits[1];local result=make({1},1);local base=a;while exponent>0 do charge();if exponent%2==1 then result=multiply(result,base)end;exponent=math.floor(exponent/2);if exponent>0 then base=multiply(base,base)end end;return result
  elseif op=='<<'or op=='>>'then
   local direction=if op=='<<'then 1 else -1;if b.Sign<0 then direction=-direction end;local count=if #b.Digits>1 then 4097 else b.Digits[1]or 0
   if direction>0 then return make(left(a.Digits,count),a.Sign)end
   local digits,lost=right(a.Digits,count);if a.Sign<0 and lost then digits=addMagnitude(digits,{1})end;return make(digits,a.Sign)
  elseif op=='&'or op=='|'or op=='^'then
   local n=math.max(#a.Digits,#b.Digits)+1;local aa,bb=twos(a,n),twos(b,n);local out={}
   for i=1,n do charge();out[i]=if op=='&'then bit32.band(aa[i],bb[i])elseif op=='|'then bit32.bor(aa[i],bb[i])else bit32.bxor(aa[i],bb[i])end
   if out[n]>=32768 then local carry=1;for i=1,n do local item=65535-out[i]+carry;out[i]=item%BASE;carry=math.floor(item/BASE)end;return make(out,-1)end;return make(out,1)
  end;fail('TypeError','Unsupported BigInt operator '..op)
 end
 local function truncate(count,input,signed)
  local n=VM.number(vm.ToPrimitive(count,'number'));if n~=n then n=0 elseif n<0 then n=math.ceil(n)else n=math.floor(n)end
  if n<0 or n>9007199254740991 then fail('RangeError','BigInt bit count is outside ToIndex range')end
  local bigint=api:ToBigInt(input);if n==0 then return make({},0)end
  if n>4096 then if bigint.Sign>=0 or signed then return bigint end;fail('RangeError','Unsigned BigInt result exceeds budget')end
  local length=math.ceil(n/16);local digits=twos(bigint,length);local last=n%16;if last>0 then digits[length]%=2^last end
  if signed and bit(digits,n-1)==1 then local power={};for i=1,length do power[i]=0 end;local limb=math.floor(n/16)+1;power[limb]=2^(n%16);return make(subtractMagnitude(power,digits),-1)end
  return make(digits,1)
 end
 local proto=vm.Object({});vm.Prototypes.BigInt=proto
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function native(name,n,fn)local v={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};define(v,'length',{value=n,configurable=true});define(v,'name',{value=name,configurable=true});return v end
 local function receiver(v)if BigInt.is(v)then return v elseif type(v)=='table'and v.Kind=='boxed-bigint'then return v.PrimitiveValue end;fail('TypeError','BigInt method called on incompatible receiver')end
 local constructor=native('BigInt',1,function(args)local input=if args[1]==nil then U else args[1];input=vm.ToPrimitive(input,'number');return if type(input)=='number'then api:FromNumber(input)else api:ToBigInt(input)end)
 define(constructor,'prototype',{value=proto});define(proto,'constructor',{value=constructor,writable=true,configurable=true})
 for _,name in {'asIntN','asUintN'}do define(constructor,name,{value=native(name,2,function(args)return truncate(if args[1]==nil then U else args[1],if args[2]==nil then U else args[2],name=='asIntN')end),writable=true,configurable=true})end
 define(proto,'valueOf',{value=native('valueOf',0,function(_,v)return receiver(v)end),writable=true,configurable=true})
 define(proto,'toString',{value=native('toString',0,function(args,v)local primitive=receiver(v);local raw=if args[1]==nil or args[1]==U then 10 else args[1];local radix=VM.number(vm.ToPrimitive(raw,'number'));radix=if radix~=radix then 0 elseif radix<0 then math.ceil(radix)else math.floor(radix);if radix<2 or radix>36 then fail('RangeError','BigInt radix must be 2–36')end;return api:ToString(primitive,radix)end),writable=true,configurable=true})
 if vm.SymbolToStringTag then define(proto,vm.SymbolToStringTag,{value='BigInt',configurable=true})end
 globals.BigInt=constructor;vm.Global.Bindings.BigInt={Value=constructor}
 function api:Destroy()self.Alive=false end
 return api
end
return BigInt
