--!strict
local Strings=require(script.Parent.Strings)
local Syntax=require(script.Parent.RegExpSyntax)
local Matcher=require(script.Parent.RegExpMatcher)
local HTMLPattern=require(script.Parent.Parent.Controls.Pattern)
local RegExp={}
function RegExp.install(vm: any,globals: any,options: any?): any
 options=options or {};local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};local states=setmetatable({},{__mode="kv"})
 local symbols=vm.Collections.WellKnown;local proto=vm.Object({});vm.Prototypes.RegExp=proto
 local constructor
 local patterns=HTMLPattern.new(vm.Step,function(message)VM.throw(VM.error('RangeError',message))end)
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function check()assert(api.Alive and vm.Alive,"JavaScript RegExp disposed")end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function text(value)
  if vm.ToPrimitive then value=vm.ToPrimitive(value,"string")end;if type(value)=="table"and value.Kind=="symbol"then fail("TypeError","Cannot convert Symbol to string")end
  local value=VM.string(value);if #value>262144 then fail("RangeError","RegExp string byte budget exceeded")end;return value
 end
 local function number(value)if vm.ToPrimitive then value=vm.ToPrimitive(value,"number")end;if type(value)=="table"and value.Kind=="symbol"then fail("TypeError","Cannot convert Symbol to number")end;return VM.number(value)end
 local function length(value)local n=number(value);return if n~=n or n<=0 then 0 else math.min(math.floor(n),9007199254740991)end
 local function object(value)return type(value)=="table"and value~=U and value~=N and value.Kind~="symbol"and value.Kind~="bigint"end
 local function def(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,VM.Null))end
 local function native(name,n,callback)local value={Kind="native-function",Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return callback(args,receiver)end};def(value,"length",{value=n,configurable=true});def(value,"name",{value=name,configurable=true});return value end
 local function method(target,key,name,n,callback)local value=native(name,n,callback);def(target,key,{value=value,writable=true,configurable=true});return value end
 local function getter(target,key,callback)def(target,key,{get=native("get "..(if type(key)=="string"then key else "["..key.Description.."]"),0,function(_,value)return callback(value)end),configurable=true})end
 local function brand(value)local state=states[value];if not state then fail("TypeError","RegExp method requires a RegExp receiver")end;return state end
 local function isRegExp(value)if not object(value)then return false end;local match=vm.Get(value,symbols.match);return if match~=U then VM.truth(match)else states[value]~=nil end
 local function slice(units,a,b)local out={};for i=math.max(0,a)+1,math.min(#units,b)do table.insert(out,units[i])end;return Strings.fromUnits(out)end
 local function advance(units,index,unicode)local _,following=Matcher.next(units,index,unicode,1);return if following==index then index+1 else following end
 local function setIndex(value,index)vm.Set(value,"lastIndex",index,true)end
 local function boundArray(values)if #values>16384 then fail("RangeError","RegExp result count budget exceeded")end end
 local flagOrder={{"hasIndices","d"},{"global","g"},{"ignoreCase","i"},{"multiline","m"},{"dotAll","s"},{"unicode","u"},{"unicodeSets","v"},{"sticky","y"}}
 function api:Create(pattern,flagText)
  check();pattern=if pattern==nil or pattern==U then ""else text(pattern);flagText=if flagText==nil or flagText==U then ""else text(flagText)
  if Strings.length(pattern)>8192 then fail("RangeError","RegExp pattern length budget exceeded")end
  local compiled=Syntax.compile(pattern,flagText,vm.Step,function(message)fail("SyntaxError",message)end)
  local ordered={};for _,entry in flagOrder do if compiled.Flags[entry[2]]then table.insert(ordered,entry[2])end end;compiled.FlagText=table.concat(ordered)
  local value=vm.Object({},proto);value.RegExpState=compiled;states[value]=compiled;def(value,"lastIndex",{value=0,writable=true});return value
 end
 local function create(args,called)
  local pattern,flags=arg(args,1),arg(args,2);local regular=isRegExp(pattern)
  if called and regular and flags==U and vm.Get(pattern,"constructor")==constructor then return pattern end
  local state=states[pattern]
  if state then return api:Create(state.Source,if flags==U then state.FlagText else flags)end
  if regular then return api:Create(vm.Get(pattern,"source"),if flags==U then vm.Get(pattern,"flags")else flags)end
  return api:Create(pattern,flags)
 end
 constructor=native("RegExp",2,function(args)return create(args,true)end);constructor.Construct=function(args)check();return create(args,false)end
 def(constructor,"prototype",{value=proto});def(proto,"constructor",{value=constructor,writable=true,configurable=true});getter(constructor,symbols.species,function(value)return value end)
 globals.RegExp=constructor;vm.Global.Bindings.RegExp={Value=constructor}
 for _,entry in flagOrder do getter(proto,entry[1],function(value)if value==proto then return U end;return brand(value).Flags[entry[2]]==true end)end
 getter(proto,"flags",function(value)if not object(value)then fail("TypeError","RegExp flags requires an object")end;local flags={};for _,entry in flagOrder do if VM.truth(vm.Get(value,entry[1]))then table.insert(flags,entry[2])end end;return table.concat(flags)end)
 local function escapedSource(source)
  if source==""then return "(?:)"end;local out={};local escaped=false;local inClass=false
  for _,cp in Strings.units(source)do
   if cp==10 then table.insert(out,"\\n")elseif cp==13 then table.insert(out,"\\r")elseif cp==0x2028 then table.insert(out,"\\u2028")elseif cp==0x2029 then table.insert(out,"\\u2029")
   elseif cp==47 and not escaped and not inClass then table.insert(out,"\\/")else table.insert(out,Strings.fromUnits({cp}))end
   if not escaped then if cp==91 then inClass=true elseif cp==93 then inClass=false end end
   escaped=cp==92 and not escaped
  end;return Strings.fromUnits(Strings.units(table.concat(out)))
 end
 getter(proto,"source",function(value)return if value==proto then "(?:)"else escapedSource(brand(value).Source)end)
 method(proto,"toString","toString",0,function(_,value)if not object(value)then fail("TypeError","RegExp.toString requires object")end;return "/"..text(vm.Get(value,"source")).."/"..text(vm.Get(value,"flags"))end)
 local function builtinExec(value,input)
  local state=brand(value);local units=Strings.units(input);if #units>65536 then fail("RangeError","RegExp input length budget exceeded")end
  local last=length(vm.Get(value,"lastIndex"));local flags=state.Flags;local global,sticky=flags.g,flags.y
  local index=if global or sticky then last else 0
  if(flags.u or flags.v)and units[index]and units[index+1]and units[index]>=0xd800 and units[index]<=0xdbff and units[index+1]>=0xdc00 and units[index+1]<=0xdfff then index-=1 end
  while index<=#units do
   vm.Step();local result=Matcher.match(state,units,index,vm.Step,function(message)fail("RangeError",message)end,options.MaxBacktrackingSteps)
   if result then
    if global or sticky then setIndex(value,result.Position)end
    local values={slice(units,index,result.Position)};local indices={vm.Array({index,result.Position})}
    for id=1,state.Count do local span=result.Captures[id];table.insert(values,if span then slice(units,span[1],span[2])else U);table.insert(indices,if span then vm.Array({span[1],span[2]})else U)end
    local match=vm.Array(values);local groups,indexGroups=U,U
    if next(state.Names)then groups=vm.Object({},N);indexGroups=vm.Object({},N);for name,ids in state.Names do local id=ids[1];for _,candidate in ids do if result.Captures[candidate]then id=candidate;break end end;vm.Set(groups,name,values[id+1]);vm.Set(indexGroups,name,indices[id+1])end end
    vm.Set(match,"index",index);vm.Set(match,"input",input);vm.Set(match,"groups",groups)
    if flags.d then local array=vm.Array(indices);vm.Set(array,"groups",indexGroups);vm.Set(match,"indices",array)end
    return match
   end
   if sticky then break end;index=advance(units,index,flags.u or flags.v)
  end
  if global or sticky then setIndex(value,0)end;return N
 end
 method(proto,"exec","exec",1,function(args,value)return builtinExec(value,text(arg(args,1)))end)
 local function exec(value,input)
  if not object(value)then fail("TypeError","RegExp operation requires object")end
  local fn=vm.Get(value,"exec");if VM.callable(fn)then local result=vm:Call(fn,{input},value);if result~=N and not object(result)then fail("TypeError","RegExp exec must return an object or null")end;return result end
  return builtinExec(value,input)
 end
 method(proto,"test","test",1,function(args,value)return exec(value,text(arg(args,1)))~=N end)
 method(proto,"compile","compile",2,function(args,value)
  brand(value);local pattern,flags=arg(args,1),arg(args,2);local other=states[pattern]
  if other then if flags~=U then fail("TypeError","RegExp.compile cannot override another RegExp's flags")end;pattern,flags=other.Source,other.FlagText end
  local temporary=api:Create(pattern,flags);local state=states[temporary];states[temporary]=nil;states[value]=state;value.RegExpState=state;setIndex(value,0);return value
 end)
 method(proto,symbols.match,"[Symbol.match]",1,function(args,value)
  local input=text(arg(args,1));if not VM.truth(vm.Get(value,"global"))then return exec(value,input)end
  local unicode=VM.truth(vm.Get(value,"unicode"))or VM.truth(vm.Get(value,"unicodeSets"));local units=Strings.units(input);setIndex(value,0);local values={}
  while true do vm.Step();local match=exec(value,input);if match==N then break end;local matched=text(vm.Get(match,"0"));table.insert(values,matched);boundArray(values);if matched==""then setIndex(value,advance(units,length(vm.Get(value,"lastIndex")),unicode))end end
  return if #values==0 then N else vm.Array(values)
 end)
 method(proto,symbols.search,"[Symbol.search]",1,function(args,value)
  local input=text(arg(args,1));local previous=vm.Get(value,"lastIndex");if previous~=0 or(type(previous)=="number"and 1/previous<0)then setIndex(value,0)end
  local result=exec(value,input);local now=vm.Get(value,"lastIndex");if now~=previous or(type(now)=="number"and now==0 and 1/now~=1/previous)then vm.Set(value,"lastIndex",previous,true)end
  return if result==N then -1 else vm.Get(result,"index")
 end)
 local function species(value)
  local c=vm.Get(value,"constructor");if c==U then return constructor end;if not object(c)and type(c)~="function"then fail("TypeError","Invalid RegExp constructor")end
  local s=vm.Get(c,symbols.species);return if s==U or s==N then constructor else s
 end
 method(proto,symbols.matchAll,"[Symbol.matchAll]",1,function(args,value)
  local input=text(arg(args,1));local flags=text(vm.Get(value,"flags"));local copy=vm:Construct(species(value),{value,flags});setIndex(copy,length(vm.Get(value,"lastIndex")))
  local global=string.find(flags,"g",1,true)~=nil;local unicode=string.find(flags,"u",1,true)~=nil or string.find(flags,"v",1,true)~=nil;local units=Strings.units(input);local done=false
  local iteratorProto=vm.Prototypes.RegExpStringIterator;if not iteratorProto then iteratorProto=vm.Object({},vm.Prototypes.Iterator);def(iteratorProto,symbols.toStringTag,{value="RegExp String Iterator",configurable=true});vm.Prototypes.RegExpStringIterator=iteratorProto end
  local iterator=vm.Object({},iteratorProto);iterator.Kind="iterator"
  method(iterator,"next","next",0,function()
   if done then return vm.Object({value=U,done=true})end;local match=exec(copy,input);if match==N then done=true;return vm.Object({value=U,done=true})end
   if not global then done=true elseif text(vm.Get(match,"0"))==""then setIndex(copy,advance(units,length(vm.Get(copy,"lastIndex")),unicode))end;return vm.Object({value=match,done=false})
  end);return iterator
 end)
 local function substitution(replacement,input,units,start,matched,captures,groups)
  local out={};local at=1
  while at<=#replacement do local c=replacement:sub(at,at);local nextChar=replacement:sub(at+1,at+1)
   if c~="$"then table.insert(out,c);at+=1
   elseif nextChar=="$"then table.insert(out,"$");at+=2
   elseif nextChar=="&"then table.insert(out,matched);at+=2
   elseif nextChar=="`"then table.insert(out,slice(units,0,start));at+=2
   elseif nextChar=="'"then table.insert(out,slice(units,start+Strings.length(matched),#units));at+=2
   elseif nextChar=="<"and groups~=U then
    local ending=string.find(replacement,">",at+2,true);if ending then local value=vm.Get(groups,replacement:sub(at+2,ending-1));table.insert(out,if value==U then ""else text(value));at=ending+1 else table.insert(out,"$");at+=1 end
   elseif tonumber(nextChar)then
    local first=tonumber(nextChar);local second=tonumber(replacement:sub(at+2,at+2));local index,used=first,2
    if second and first*10+second>0 and first*10+second<=#captures then index,used=first*10+second,3 end
    if index>0 and index<=#captures then table.insert(out,if captures[index]==U then ""else captures[index]);at+=used else table.insert(out,"$");at+=1 end
   else table.insert(out,"$");at+=1 end
  end;return Strings.fromUnits(Strings.units(table.concat(out)))
 end
 method(proto,symbols.replace,"[Symbol.replace]",2,function(args,value)
  local input=text(arg(args,1));local replacement=arg(args,2);local functional=VM.callable(replacement);if not functional then replacement=text(replacement)end
  local units=Strings.units(input);local global=VM.truth(vm.Get(value,"global"));local unicode=false
  if global then unicode=VM.truth(vm.Get(value,"unicode"))or VM.truth(vm.Get(value,"unicodeSets"));setIndex(value,0)end
  local results={};while true do local result=exec(value,input);if result==N then break end;table.insert(results,result);boundArray(results);if not global then break end;if text(vm.Get(result,"0"))==""then setIndex(value,advance(units,length(vm.Get(value,"lastIndex")),unicode))end end
  local out={};local cursor=0;local total=0
  for _,result in results do
   local count=math.max(0,length(vm.Get(result,"length"))-1);if count>4096 then fail("RangeError","RegExp capture budget exceeded")end
   local matched=text(vm.Get(result,"0"));local start=math.clamp(length(vm.Get(result,"index")),0,#units);local captures={}
   for i=1,count do local capture=vm.Get(result,tostring(i));captures[i]=if capture==U then U else text(capture)end
   local groups=vm.Get(result,"groups");local resultText
   if functional then local callArgs={matched};for _,capture in captures do table.insert(callArgs,capture)end;table.insert(callArgs,start);table.insert(callArgs,input);if groups~=U then table.insert(callArgs,groups)end;resultText=text(vm:Call(replacement,callArgs,U))
   else resultText=substitution(replacement,input,units,start,matched,captures,groups)end
   if start>=cursor then local prefix=slice(units,cursor,start);total+=#prefix+#resultText;if total>262144 then fail("RangeError","RegExp replacement byte budget exceeded")end;table.insert(out,prefix);table.insert(out,resultText);cursor=start+Strings.length(matched)end
  end;table.insert(out,slice(units,cursor,#units));return table.concat(out)
 end)
 method(proto,symbols.split,"[Symbol.split]",2,function(args,value)
  local input=text(arg(args,1));local flags=text(vm.Get(value,"flags"));local unicode=string.find(flags,"u",1,true)~=nil or string.find(flags,"v",1,true)~=nil
  local copy=vm:Construct(species(value),{value,if string.find(flags,"y",1,true)then flags else flags.."y"});local limit=if arg(args,2)==U then 4294967295 else number(args[2]);limit=if limit~=limit or math.abs(limit)==math.huge then 0 else math.floor(math.abs(limit))*(if limit<0 then -1 else 1)%4294967296
  local result={};if limit==0 then return vm.Array(result)end;local units=Strings.units(input)
  if #units==0 then if exec(copy,input)==N then table.insert(result,input)end;return vm.Array(result)end
  local p,q=0,0
  while q<#units do setIndex(copy,q);local match=exec(copy,input)
   if match==N then q=advance(units,q,unicode)else local ending=math.min(length(vm.Get(copy,"lastIndex")),#units)
    if ending==p then q=advance(units,q,unicode)else
     table.insert(result,slice(units,p,q));boundArray(result);if #result==limit then return vm.Array(result)end;p=ending
     local captures=length(vm.Get(match,"length"))-1;if captures>4096 then fail("RangeError","RegExp split capture budget exceeded")end
     for i=1,captures do table.insert(result,vm.Get(match,tostring(i)));boundArray(result);if #result==limit then return vm.Array(result)end end;q=p
    end
   end
  end;table.insert(result,slice(units,p,#units));return vm.Array(result)
 end)
 method(constructor,"escape","escape",1,function(args)
  local value=arg(args,1);if type(value)~="string"then fail("TypeError","RegExp.escape requires a string")end;local out={};local units=Strings.units(value);local controls={[9]="\\t",[10]="\\n",[11]="\\v",[12]="\\f",[13]="\\r"}
  for i,cp in units do
   if i==1 and((cp>=48 and cp<=57)or(cp>=65 and cp<=90)or(cp>=97 and cp<=122))then table.insert(out,string.format("\\x%02x",cp))
   elseif cp<128 and string.find("^$\\.*+?()[]{}|/",string.char(cp),1,true)then table.insert(out,"\\"..string.char(cp))
   elseif controls[cp]then table.insert(out,controls[cp])
   elseif cp<128 and string.find(",- =<>#&!%:;@~'`\"",string.char(cp),1,true)then table.insert(out,string.format("\\x%02x",cp))
   elseif cp==0xa0 or cp==0x1680 or(cp>=0x2000 and cp<=0x200a)or cp==0x2028 or cp==0x2029 or cp==0x202f or cp==0x205f or cp==0x3000 or cp==0xfeff or(cp>=0xd800 and cp<=0xdfff and not(cp<=0xdbff and units[i+1]and units[i+1]>=0xdc00 and units[i+1]<=0xdfff)and not(cp>=0xdc00 and units[i-1]and units[i-1]>=0xd800 and units[i-1]<=0xdbff))then table.insert(out,string.format("\\u%04x",cp))
   else table.insert(out,Strings.fromUnits({cp}))end
  end;return Strings.fromUnits(Strings.units(table.concat(out)))
 end)
 -- Install symbol dispatch around existing literal-string operations, retaining
 -- the standard library's non-RegExp implementation and coercion behavior.
 local stringProto=vm.Prototypes.String
 for _,name in {"match","matchAll","search","replace","replaceAll","split"}do
  local old=vm.Get(stringProto,name);local symbol=symbols[if name=="replaceAll"then "replace"else name]
  method(stringProto,name,name,if name=="replace"or name=="replaceAll"or name=="split"then 2 else 1,function(args,value)
   if value==U or value==N then fail("TypeError","String method requires a receiver")end
   local pattern=arg(args,1)
   if pattern~=U and pattern~=N then
    if(name=="matchAll"or name=="replaceAll")and isRegExp(pattern)then local flags=vm.Get(pattern,"flags");if flags==U or flags==N then fail("TypeError","RegExp flags cannot be null")end;if not string.find(text(flags),"g",1,true)then fail("TypeError",name.." requires a global RegExp")end end
    local fn=vm.Get(pattern,symbol);if fn~=U and fn~=N then if not VM.callable(fn)then fail("TypeError","RegExp symbol method is not callable")end;return vm:Call(fn,if name=="replace"or name=="replaceAll"or name=="split"then{value,arg(args,2)}else{value},pattern)end
   end
   if name=="match"or name=="matchAll"or name=="search"then local input=text(value);local regex=api:Create(pattern,if name=="matchAll"then "g"else "");return vm:Call(vm.Get(regex,symbol),{input},regex)end
   return vm:Call(old,args,value)
  end)
 end
 -- Predicate string operations reject RegExp, unless Symbol.match opts out.
 for _,name in {"includes","startsWith","endsWith"}do local old=vm.Get(stringProto,name);method(stringProto,name,name,1,function(args,value)
  if value==U or value==N then fail("TypeError","String method requires receiver")end;local input=text(value);if isRegExp(arg(args,1))then fail("TypeError",name.." does not accept RegExp")end;return vm:Call(old,args,input)
 end)end
 function api:Describe(value)local state=states[value];return if state then {Source=state.Source,Flags=state.FlagText}else nil end
 -- HTML patterns use intrinsics, so replacing RegExp or its prototype cannot
 -- change native form validation. Keep only a bounded cache of pattern sources.
 function api:PatternMismatch(source:string,input:string,multiple:boolean?):boolean
  check();return patterns:Mismatch(source,input,multiple)
 end
 function api:Destroy()self.Alive=false;table.clear(states);patterns:Destroy()end
 return api
end
return RegExp
