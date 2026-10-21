--!strict
-- Text-symbol @counter-style descriptors and bounded CSS integer algorithms.
-- Image symbols need a marker-image compositor and are deliberately not
-- replaced by text. They invalidate this renderer's style with a diagnostic.
local Syntax=require(script.Parent.Syntax)
local CounterStyles={}
local predefined={none=true,disc=true,circle=true,square=true,decimal=true,['decimal-leading-zero']=true,['lower-alpha']=true,['upper-alpha']=true,['lower-latin']=true,['upper-latin']=true,['lower-roman']=true,['upper-roman']=true,['disclosure-open']=true,['disclosure-closed']=true}
local function trim(value)return value:match('^%s*(.-)%s*$')or''end
local function ident(value)return value:match('^[%a_%-][%w_%-]*$')~=nil and not ({none=true,initial=true,inherit=true,unset=true,revert=true,['revert-layer']=true})[value:lower()]end
local function tokens(value)
 local out,index={},1
 while index<=#value do
  local ch=value:sub(index,index)
  if ch:match('%s')then index+=1;continue end
  local quote=if ch=='"'or ch=="'"then ch else nil;local parts={};if quote then index+=1 end
  local closed=not quote
  while index<=#value do
   ch=value:sub(index,index)
   if quote and ch==quote then index+=1;closed=true;break end
   if quote and(ch=='\n'or ch=='\r'or ch=='\f')then return nil end
   if not quote and ch:match('%s')then break end
   if ch=='\\'then
    index+=1;local hex=value:sub(index):match('^%x%x?%x?%x?%x?%x?')
    if hex then local code=tonumber(hex,16);if code==0 or code>0x10ffff or(code>=0xd800 and code<=0xdfff)then code=0xfffd end;table.insert(parts,utf8.char(code));index+=#hex;if value:sub(index,index):match('%s')then index+=1 end
    elseif index<=#value then local escaped=value:sub(index,index);if escaped=='\r'and value:sub(index+1,index+1)=='\n'then index+=1 end;if escaped~='\n'and escaped~='\r'and escaped~='\f'then table.insert(parts,escaped)end;index+=1 else return nil end
   else table.insert(parts,ch);index+=1 end
  end
  if not closed then return nil end
  local text=table.concat(parts);if #text>4096 then return nil end
  table.insert(out,{Text=text,String=quote~=nil});if #out>512 then return nil end
 end
 return out
end
function CounterStyles.name(value:string):string
 return if predefined[value:lower()]then value:lower()else value
end
function CounterStyles.string(value:string):string?
 local list=tokens(value);return if list and #list==1 and list[1].String then list[1].Text else nil
end
-- Anonymous counter styles use quoted symbols. Bare identifiers are allowed
-- by @counter-style descriptors but are not <symbol> values in symbols().
function CounterStyles.value(value:string,allowString:boolean?):any?
 value=trim(value)
 if ident(value)or value:lower()=='none'then return CounterStyles.name(value)end
 local literal=CounterStyles.string(value)
 if literal~=nil then return if allowString then {System='literal',Symbols={literal},Suffix='',Prefix=''}else nil end
 local source=value:match('^[Ss][Yy][Mm][Bb][Oo][Ll][Ss]%((.*)%)$');if not source then return nil end
 local list=tokens(source);if not list or #list==0 then return nil end
 local system='symbolic';if not list[1].String then system=list[1].Text:lower();table.remove(list,1)end
 if not({cyclic=true,numeric=true,alphabetic=true,symbolic=true,fixed=true})[system]then return nil end
 if #list<((system=='numeric'or system=='alphabetic')and 2 or 1)then return nil end
 local result={System=system,Symbols={},Suffix=' ',Prefix=''}
 for _,token in list do if not token.String then return nil end;table.insert(result.Symbols,token.Text)end
 return result
end
local function symbols(value,min,max)
 local list=tokens(value);if not list or #list<min or(max and #list>max)then return nil end
 local result={};for _,token in list do if not token.String and(not ident(token.Text)or token.Text:find('(',1,true))then return nil end;table.insert(result,token.Text)end;return result
end
local function commaParts(value)
 local parts,index={},1;while index<=#value do local part,nextIndex,comma=Syntax.scan(value,index,',');index=nextIndex;table.insert(parts,trim(part));if comma==''then break end end;return parts
end
local function integer(value)local n=tonumber(value);return if n and value:match('^[+-]?%d+$')and math.abs(n)<=2147483647 then n else nil end
function CounterStyles.parse(name:string,body:string):(any?,string?)
 name=CounterStyles.name(name)
 if not ident(name)or({decimal=true,disc=true,circle=true,square=true,['disclosure-open']=true,['disclosure-closed']=true})[name:lower()]then return nil,'Invalid @counter-style name: '..name end
 local result={Name=name}
 for _,entry in Syntax.declarations(body)do
  if entry.Important then continue end
  local key,value=entry.Text:match('^%s*([%a%-]+)%s*:%s*(.-)%s*$');if not key then continue end;key=key:lower()
  if key=='system'then
   local kind,argument=value:match('^(%S+)%s*(.-)$');kind=kind and kind:lower()
   if ({cyclic=true,symbolic=true,alphabetic=true,numeric=true,additive=true})[kind]and argument==''then result.System=kind;result.Argument=nil
   elseif kind=='fixed'and(argument==''or integer(argument))then result.System=kind;result.Argument=integer(argument)or 1
   elseif kind=='extends'and ident(argument)then result.System=kind;result.Argument=CounterStyles.name(argument)end
  elseif key=='symbols'then local list=symbols(value,1);if list then result.Symbols=list end
  elseif key=='additive-symbols'then
   local pairs,previous={},math.huge;local valid=true
   for _,part in commaParts(value)do local weight,text=part:match('^(%S+)%s+(.+)$');local n=weight and integer(weight);local symbol=text and symbols(text,1,1)
    if not n or n<0 or n>=previous or not symbol then valid=false;break end;previous=n;table.insert(pairs,{Weight=n,Symbol=symbol[1]})end
   if valid and #pairs>0 then result.Additive=pairs end
  elseif key=='negative'then local list=symbols(value,1,2);if list then result.Negative={list[1],list[2]or''}end
  elseif key=='prefix'or key=='suffix'then local list=symbols(value,1,1);if list then result[if key=='prefix'then'Prefix'else'Suffix']=list[1]end
  elseif key=='fallback'then if ident(value)then result.Fallback=CounterStyles.name(value)end
  elseif key=='pad'then local count,symbol=value:match('^(%S+)%s+(.+)$');local n=count and integer(count);local list=symbol and symbols(symbol,1,1);if n and n>=0 and n<=4096 and list then result.Pad={n,list[1]}end
  elseif key=='range'then
   if value:lower()=='auto'then result.Range='auto'else local ranges={};local valid=true
    for _,part in commaParts(value)do local a,b=part:match('^(%S+)%s+(%S+)$');local low=if a=='infinite'then-math.huge elseif a then integer(a)else nil;local high=if b=='infinite'then math.huge elseif b then integer(b)else nil
     if not low or not high or low>high then valid=false;break end;table.insert(ranges,{low,high})end
    if valid and #ranges>0 then result.Range=ranges end
   end
  elseif key=='speak-as'then if ident(value)then result.SpeakAs=value end
  end
 end
 result.System=result.System or'symbolic'
 if result.System=='extends'then if result.Symbols or result.Additive then return nil,'Extending @counter-style cannot declare symbols: '..name end
 elseif result.System=='additive'then if not result.Additive then return nil,'Missing additive-symbols for @counter-style: '..name end
 elseif not result.Symbols or #result.Symbols<((result.System=='numeric'or result.System=='alphabetic')and 2 or 1)then return nil,'Missing text symbols for @counter-style: '..name end
 return result,nil
end
local defaults={Negative={'-',''},Prefix='',Suffix='. ',Pad={0,''},Fallback='decimal',Range='auto'}
local function builtin(name)
 local letters={};if name=='lower-alpha'or name=='lower-latin'or name=='upper-alpha'or name=='upper-latin'then local base=if name:sub(1,5)=='lower'then 97 else 65;for i=0,25 do table.insert(letters,string.char(base+i))end;return {System='alphabetic',Symbols=letters}end
 if name=='disc'or name=='circle'or name=='square'or name=='disclosure-open'or name=='disclosure-closed'then return {System='cyclic',Symbols={({disc='•',circle='◦',square='▪',['disclosure-open']='▾',['disclosure-closed']='▸'})[name]},Suffix=' '}end
 if name=='lower-roman'or name=='upper-roman'then return {System='builtin',BuiltIn=name,Range={{1,3999}}}end
 return {System='numeric',Symbols={'0','1','2','3','4','5','6','7','8','9'},Pad={if name=='decimal-leading-zero'then 2 else 0,'0'}}
end
local function descriptor(registry,name,active,depth)
 if type(name)=='table'then return table.clone(name),nil end
 if depth>64 then return builtin('decimal'),nil end
 if active[name]then local cycle={};for key,position in active do if position>=active[name]then cycle[key]=true end end;return builtin('decimal'),cycle end
 local raw=registry and registry[name];if not raw then return builtin(name)end
 local result,cycle={},nil
 if raw.System=='extends'then active[name]=depth;result,cycle=descriptor(registry,raw.Argument,active,depth+1);active[name]=nil;if cycle and cycle[name]then result=builtin('decimal')end end
 result=table.clone(result);for key,value in raw do if key~='System'or value~='extends'then result[key]=value end end
 return result,cycle
end
local function inRange(style,number)
 local range=style.Range or'auto'
 if range~='auto'then for _,pair in range do if number>=pair[1]and number<=pair[2]then return true end end;return false end
 if style.System=='alphabetic'or style.System=='symbolic'then return number>=1 end
 if style.System=='additive'then return number>=0 end
 if style.System=='fixed'then local first=style.Argument or 1;return number>=first and number<first+#style.Symbols end
 return true
end
local function representation(style,number,builtinFormat)
 local system,symbols=style.System,style.Symbols or{};local count=#symbols;local parts={}
 if system=='builtin'then return builtinFormat and builtinFormat(number,style.BuiltIn)or tostring(number)end
 if system=='cyclic'then return symbols[(number-1)%count+1]end
 if system=='fixed'then return symbols[number-(style.Argument or 1)+1]end
 if system=='literal'then return symbols[1]end
 if system=='symbolic'then local times=math.ceil(number/count);local symbol=symbols[(number-1)%count+1];if times>4096 or #symbol*times>16384 then return nil end;return string.rep(symbol,times)end
 if system=='alphabetic'then repeat number-=1;table.insert(parts,1,symbols[number%count+1]);number=math.floor(number/count)until number==0;return table.concat(parts)end
 if system=='numeric'then repeat table.insert(parts,1,symbols[number%count+1]);number=math.floor(number/count)until number==0;return table.concat(parts)end
 if system=='additive'then
  local remaining,bytes=number,0;for _,pair in style.Additive do local times=if pair.Weight==0 then(if remaining==0 and #parts==0 then 1 else 0)else math.floor(remaining/pair.Weight)
   bytes+=#pair.Symbol*times;if times>4096 or bytes>16384 then return nil end;if times>0 then table.insert(parts,string.rep(pair.Symbol,times));remaining-=times*pair.Weight end end
  return if remaining==0 and #parts>0 then table.concat(parts)else nil
 end
 return nil
end
local function length(text)local count=0;for _ in utf8.graphemes(text)do count+=1 end;return count end
function CounterStyles.format(registry:any,number:number,name:any,marker:boolean?,builtinFormat:any?):string
 if name=='none'then return''end
 number=math.floor(number);local seen={};local style,text;local selected=descriptor(registry,name,{},0)
 if selected.System=='literal'then return selected.Symbols[1]end
 local prefix,suffix=selected.Prefix or'',selected.Suffix or'. '
 for _=1,64 do
  if seen[name]then name='decimal';registry=nil end;seen[name]=true;style=descriptor(registry,name,{},0)
  for key,value in defaults do if style[key]==nil then style[key]=value end end
  if inRange(style,number)then
   local negative=number<0 and style.System~='cyclic'and style.System~='fixed'
   text=representation(style,if negative then-number else number,builtinFormat)
   if text and #text<=16384 then
    local remaining=style.Pad[1]-length(text)-(if negative then length(style.Negative[1])+length(style.Negative[2])else 0)
    if remaining>0 then if #style.Pad[2]*remaining+#text>16384 then name=style.Fallback;continue end;text=string.rep(style.Pad[2],remaining)..text end
    if negative then text=style.Negative[1]..text..style.Negative[2]end
    return if marker then prefix..text..suffix else text
   end
  end
  name=style.Fallback
 end
 return tostring(number)
end
return CounterStyles
