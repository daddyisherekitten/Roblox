--!strict
-- JSON parsing and serialization stay independent of Roblox HttpService and
-- retain JavaScript null/undefined, UTF-16 escapes, property order and callbacks.
local Strings=require(script.Parent.Strings)
local BigInt=require(script.Parent.BigInt)
local JSON={}
-- This immutable identity represents a host internal slot. Author properties,
-- prototypes and Proxy get traps cannot copy it; it retains no realm state.
local RAW_JSON_BRAND=table.freeze({})
function JSON.install(c: any)
 local VM,vm,U,N=c.VM,c.vm,c.U,c.N
 local get,set,step=c.get,c.set,c.step
 local isObject=vm.ObjectModel.IsObject
 local function isRaw(value)return type(value)=='table'and rawget(value,'RawJSONBrand')==RAW_JSON_BRAND end
 local function create(target,key,value)
  assert(vm.ObjectModel.DefineOwn(target,key,{Value=value,Writable=true,Enumerable=true,Configurable=true}),'Cannot create internal JSON property')
 end
 local function quote(value)
  local units=Strings.units(value);local parts={'"'};local index=1
  while index<=#units do step();local unit=units[index];local following=units[index+1]
   if unit==34 then table.insert(parts,'\\"')elseif unit==92 then table.insert(parts,'\\\\')
   elseif unit==8 then table.insert(parts,'\\b')elseif unit==9 then table.insert(parts,'\\t')elseif unit==10 then table.insert(parts,'\\n')elseif unit==12 then table.insert(parts,'\\f')elseif unit==13 then table.insert(parts,'\\r')
   elseif unit<32 or(unit>=0xd800 and unit<=0xdfff and not(unit<=0xdbff and following and following>=0xdc00 and following<=0xdfff))then table.insert(parts,string.format('\\u%04x',unit))
   elseif unit>=0xd800 and unit<=0xdbff then table.insert(parts,Strings.fromUnits({unit,following}));index+=1
   else table.insert(parts,Strings.fromUnits({unit}))end;index+=1
  end;table.insert(parts,'"');return c.stringResult(table.concat(parts))
 end
 local function parse(args)
  local source=c.text(c.arg(args,1,U));local at=1;local records={};local function syntax(message)c.fail('SyntaxError',message..' at position '..tostring(at-1))end
  local function skip()while at<=#source do local byte=source:byte(at);if byte~=32 and byte~=9 and byte~=10 and byte~=13 then break end;step();at+=1 end end
  local function parseString()
   local first=at;at+=1;local parts={};local bytes=0
   while at<=#source do step();local byte=source:byte(at)
    if byte==34 then at+=1;return Strings.fromUnits(Strings.units(table.concat(parts))),first,at end
    if byte<32 then syntax('Unescaped control character')end
    if byte==92 then
     at+=1;local escaped=source:sub(at,at);local mapped={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
     if mapped[escaped]then table.insert(parts,mapped[escaped]);at+=1
     elseif escaped=='u'then local hex=source:sub(at+1,at+4);if #hex~=4 or not hex:match('^%x%x%x%x$')then syntax('Invalid Unicode escape')end
      table.insert(parts,Strings.fromUnits({tonumber(hex,16)}));at+=5
     else syntax('Invalid escape')end
    else table.insert(parts,string.char(byte));at+=1 end
    bytes+=1;if bytes>65536 then c.fail('RangeError','JSON string budget exceeded')end
   end;syntax('Unterminated string')
  end
  local value
  value=function(depth)
   step();if depth>64 then c.fail('RangeError','JSON nesting depth exceeded')end;skip();local first=at;local char=source:sub(at,at);local result
   if char=='"'then result=parseString()
   elseif char=='{'then
    result=vm.Object({});at+=1;skip();if source:sub(at,at)=='}'then at+=1;return result,first,at end
    local count=0;while true do skip();if source:sub(at,at)~='"'then syntax('Expected property name')end;local key=parseString();skip()
     if source:sub(at,at)~=':'then syntax('Expected colon')end;at+=1;local item,start,finish=value(depth+1);create(result,key,item)
     records[result]=records[result]or {};records[result][key]={Value=item,Source=source:sub(start,finish-1)};count+=1;c.bound(count)
     skip();local delimiter=source:sub(at,at);at+=1;if delimiter=='}'then break elseif delimiter~=','then syntax('Expected comma or closing brace')end
    end
   elseif char=='['then
    result=c.array(0);at+=1;skip();if source:sub(at,at)==']'then at+=1;return result,first,at end
    while true do local item,start,finish=value(depth+1);local key=tostring(result.Length);c.bound(result.Length+1);create(result,key,item)
     records[result]=records[result]or {};records[result][key]={Value=item,Source=source:sub(start,finish-1)}
     skip();local delimiter=source:sub(at,at);at+=1;if delimiter==']'then break elseif delimiter~=','then syntax('Expected comma or closing bracket')end
    end
   elseif source:sub(at,at+3)=='true'then result=true;at+=4
   elseif source:sub(at,at+4)=='false'then result=false;at+=5
   elseif source:sub(at,at+3)=='null'then result=N;at+=4
   else
    local tail=source:sub(at);local lexeme=tail:match('^-?0')or tail:match('^-?[1-9]%d*');if not lexeme then syntax('Unexpected token')end
    local finish=at+#lexeme
    if source:sub(finish,finish)=='.'then local fraction=source:sub(finish):match('^%.%d+');if not fraction then syntax('Invalid number')end;lexeme..=fraction;finish+=#fraction end
    if source:sub(finish,finish):lower()=='e'then local exponent=source:sub(finish):match('^[eE][+-]?%d+');if not exponent then syntax('Invalid exponent')end;lexeme..=exponent end
    result=tonumber(lexeme);if result==nil then syntax('Invalid number')end;at+=#lexeme
   end;return result,first,at
  end
  local root,start,finish=value(0);skip();if at<=#source then syntax('Unexpected trailing token')end
  local reviver=c.arg(args,2,U);if not VM.callable(reviver)then return root end
  local holder=vm.Object({['']=root});records[holder]={['']={Value=root,Source=source:sub(start,finish-1)}}
  local function update(parent,key,item)
   if item==U then c.delete(parent,key);return end
   vm.ObjectModel.DefineOwn(parent,key,{Value=item,Writable=true,Enumerable=true,Configurable=true})
  end
  local function revive(parent,key,depth,record)
   step();if depth>64 then c.fail('RangeError','JSON reviver depth exceeded')end;local current=get(parent,key)
   local matched=record~=nil and vm.ObjectModel.SameValue(record.Value,current)
   local childRecords=if matched then records[current]else nil
   if isObject(current)then
    local array=c.isArray(current);local own=if array then nil else c.enumerableStringKeys(current)
    if array then local size=c.bound(c.length(current));for index=0,size-1 do local childKey=tostring(index);update(current,childKey,revive(current,childKey,depth+1,childRecords and childRecords[childKey]))end
    else for _,childKey in own do if type(childKey)=='string'then update(current,childKey,revive(current,childKey,depth+1,childRecords and childRecords[childKey]))end end end
   end
   local context=vm.Object({})
   if not isObject(current)and matched then create(context,'source',record.Source)end
   return vm:Call(reviver,{key,current,context},parent)
  end;return revive(holder,'',0,records[holder][''])
 end
 local function rawJSON(args)
  local source=c.text(c.arg(args,1,U));local first,last=source:byte(1),source:byte(-1)
  local function boundary(unit,leading)
   return unit~=nil and(unit>=97 and unit<=122 or unit>=48 and unit<=57 or unit==34 or leading and unit==45)
  end
  if not boundary(first,true)or not boundary(last,false)then c.fail('SyntaxError','Raw JSON must contain one primitive value without surrounding whitespace')end
  local parsed=parse({source})
  assert(not isObject(parsed),'Raw JSON validation produced a composite value')
  local result=vm.Object({},N);result.RawJSONBrand=RAW_JSON_BRAND
  assert(vm.ObjectModel.DefineOwn(result,'rawJSON',{Value=source,Writable=false,Enumerable=true,Configurable=false}),'Cannot create raw JSON text');vm.PreventExtensions(result)
  return result
 end
 local function stringify(args)
  local replacer=c.arg(args,2,U);local callback=if VM.callable(replacer)then replacer else nil;local propertyList
  if not callback and isObject(replacer)and c.isArray(replacer)then propertyList={};local seen={}
   for i=0,c.bound(c.length(replacer))-1 do local item=get(replacer,tostring(i));if isObject(item)and(item.Kind=='boxed-string'or item.Kind=='boxed-number')then item=c.text(item)end
    if type(item)=='string'or type(item)=='number'then local key=c.text(item);if not seen[key]then seen[key]=true;table.insert(propertyList,key)end end
   end
  end
  local space=c.arg(args,3,U);if isObject(space)then if space.Kind=='boxed-string'then space=c.text(space)elseif space.Kind=='boxed-number'then space=c.number(space)end end
  local gap='';if type(space)=='number'then gap=string.rep(' ',math.clamp(c.integer(space),0,10))elseif type(space)=='string'then local units=Strings.units(space);local first={};for i=1,math.min(#units,10)do first[i]=units[i]end;gap=Strings.fromUnits(first)end
  local stack={};local serial
  serial=function(holder,key,depth)
   step();if depth>64 then c.fail('RangeError','JSON serialization depth exceeded')end;local value=get(holder,key)
   if isObject(value)or BigInt.is(value)then local toJSON=get(value,'toJSON');if VM.callable(toJSON)then value=vm:Call(toJSON,{key},value)end end
   if callback then value=vm:Call(callback,{key,value},holder)end
   if isRaw(value)then return get(value,'rawJSON')end
   if isObject(value)then
    if value.Kind=='boxed-string'then value=c.text(value)elseif value.Kind=='boxed-number'then value=c.number(value)
    elseif value.Kind=='boxed-boolean'or value.Kind=='boxed-bigint'then value=value.PrimitiveValue end
   end
   if BigInt.is(value)then c.fail('TypeError','BigInt cannot be serialized to JSON')end
   if value==N then return 'null'elseif value==U or VM.callable(value)or(type(value)=='table'and value.Kind=='symbol')then return nil
   elseif type(value)=='boolean'then return if value then 'true'else 'false'elseif type(value)=='string'then return quote(value)
   elseif type(value)=='number'then return if value~=value or math.abs(value)==math.huge then 'null'else c.text(value)
   elseif not isObject(value)then return nil end
   if stack[value]then c.fail('TypeError','Converting circular structure to JSON')end;stack[value]=true
   local array=c.isArray(value);local parts={};local nextIndent=string.rep(gap,depth+1);local indent=string.rep(gap,depth)
   if array then for i=0,c.bound(c.length(value))-1 do table.insert(parts,serial(value,tostring(i),depth+1)or'null')end
   else local own=propertyList or c.enumerableStringKeys(value);for _,property in own do if type(property)~='string'then continue end;local result=serial(value,property,depth+1)
    if result then table.insert(parts,quote(property)..':'..(if gap~=''then ' 'else '')..result)end
   end end;stack[value]=nil
   local open,close=if array then '['else '{',if array then ']'else '}'
   if #parts==0 then return open..close end
   return c.stringResult(if gap==''then open..table.concat(parts,',')..close else open..'\n'..nextIndent..table.concat(parts,',\n'..nextIndent)..'\n'..indent..close)
  end
  local result=serial(vm.Object({['']=c.arg(args,1,U)}),'',0);return result or U
 end
 local object=vm.Object({});c.method(object,'parse',2,parse);c.method(object,'stringify',3,stringify)
 c.method(object,'rawJSON',1,rawJSON);c.method(object,'isRawJSON',1,function(args)return isRaw(c.arg(args,1,U))end)
 c.global('JSON',object)
end
return JSON
