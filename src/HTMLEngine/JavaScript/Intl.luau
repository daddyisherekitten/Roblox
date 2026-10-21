--!strict
-- A bounded Intl profile: locale identifiers and Latin decimal/currency/percent
-- number/list formatting for English and German. Other CLDR families are open.
local Strings=require(script.Parent.Strings)
local Numbers=require(script.Parent.LibraryNumbers)
local BigInt=require(script.Parent.BigInt)
local Data=require(script.Parent.IntlData)
local IntlLists=require(script.Parent.IntlLists)
local IntlDateTime=require(script.Parent.IntlDateTime)
local NumberData=require(script.Parent.IntlNumberData)
local Rounding=require(script.Parent.IntlNumberRounding)
local Intl={}
function Intl.install(vm: any,globals: any,options: any?): any
 if vm.Intl then return vm.Intl end;options=options or {}
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local api={Alive=true};vm.Intl=api
 local locales,formats=setmetatable({},{__mode='kv'}),setmetatable({},{__mode='kv'})
 local function check()assert(api.Alive and vm.Alive,'JavaScript Intl disposed')end
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function text(value)value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then fail('TypeError','Cannot convert Symbol to Intl text')end;local s=VM.string(value);if #s>65536 then fail('RangeError','Intl string budget exceeded')end;return s end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function property(target,key,value)define(target,key,{value=value,writable=true,configurable=true})end
 local function native(name,n,fn)local v={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end};define(v,'length',{value=n,configurable=true});define(v,'name',{value=name,configurable=true});return v end
 local function method(target,name,n,fn)property(target,name,native(name,n,fn))end
 local function brand(map,value,name)local r=map[value];if not r then fail('TypeError',name..' called on incompatible receiver')end;return r end
 local objectConstructor=vm.Global.Bindings.Object.Value
 local function toObject(value)if value==N then fail('TypeError','Cannot convert null to Intl options')end;return vm:Call(objectConstructor,{value})end
 local function objectOptions(value)return if value==U or value==nil then vm.Object({})else toObject(value)end
 local function field(value,key)return vm.Get(value,key)end
 local function choice(value,key,allowed,default)
  local raw=field(value,key);if raw==U then return default end;local selected=text(raw);if not table.find(allowed,selected)then fail('RangeError','Invalid Intl '..key)end;return selected
 end
 local languageAliases={deu='de',eng='en',fra='fr',fre='fr',iw='he',['in']='id',ji='yi',mo='ro',tl='fil'}
 local regionAliases={BU='MM',DD='DE',FX='FR',TP='TL',YD='YE',ZR='CD'}
 local function alpha(s)return s:match('^%a+$')~=nil end
 local function alnum(s)return s:match('^%w+$')~=nil end
 local function validLanguage(s)return alpha(s)and(#s==2 or #s==3 or #s>=5 and #s<=8)end
 local function validType(s)
  if s==''or s:sub(1,1)=='-'or s:sub(-1)=='-'or s:find('--',1,true)then return false end
  for part in s:gmatch('[^-]+')do if #part<3 or #part>8 or not alnum(part)then return false end end;return true
 end
 local function serialize(r)
  local out={r.Language};if r.Script then out[#out+1]=r.Script end;if r.Region then out[#out+1]=r.Region end;for _,v in r.Variants do out[#out+1]=v end
  local base=table.concat(out,'-');local extensions={};for singleton,value in r.Extensions do extensions[#extensions+1]={singleton,value}end;table.sort(extensions,function(a,b)return a[1]<b[1]end)
  local attributes=table.clone(r.Attributes);table.sort(attributes);local unicode={};for _,v in attributes do unicode[#unicode+1]=v end
  local keys={};for k in r.Keywords do keys[#keys+1]=k end;table.sort(keys)
  for _,k in keys do unicode[#unicode+1]=k;local v=r.Keywords[k];if v~=''and v~='true'then unicode[#unicode+1]=v end end
  if #unicode>0 then extensions[#extensions+1]={'u',table.concat(unicode,'-')};table.sort(extensions,function(a,b)return a[1]<b[1]end)end
  for _,ext in extensions do out[#out+1]=ext[1];out[#out+1]=ext[2]end;if r.Private then out[#out+1]='x';out[#out+1]=r.Private end
  r.BaseName=base;r.Tag=table.concat(out,'-');return r.Tag
 end
 local function parse(source)
  source=text(source);if #source>255 or source==''or source:find('_',1,true)or source:sub(1,1)=='-'or source:sub(-1)=='-'or source:find('--',1,true)then fail('RangeError','Invalid locale identifier')end
  local parts={};for part in source:gmatch('[^-]+')do parts[#parts+1]=part end
  if not validLanguage(parts[1])then fail('RangeError','Invalid locale language')end
  local language=parts[1]:lower();local r={Language=languageAliases[language]or language,Variants={},Extensions={},Attributes={},Keywords={}};local i=2
  if parts[i]and #parts[i]==4 and alpha(parts[i])then r.Script=parts[i]:sub(1,1):upper()..parts[i]:sub(2):lower();i+=1 end
  if parts[i]and(#parts[i]==2 and alpha(parts[i])or #parts[i]==3 and parts[i]:match('^%d+$'))then r.Region=parts[i]:upper();r.Region=regionAliases[r.Region]or r.Region;i+=1 end
  if language=='sh'then r.Language='sr';r.Script=r.Script or 'Latn'end
  local variants={};while parts[i]and(#parts[i]>=5 and #parts[i]<=8 or #parts[i]==4 and parts[i]:match('^%d'))and alnum(parts[i])do local v=parts[i]:lower();if variants[v]then fail('RangeError','Duplicate locale variant')end;variants[v]=true;r.Variants[#r.Variants+1]=v;i+=1 end
  local seen={};while i<=#parts do local singleton=parts[i]:lower();i+=1;if #singleton~=1 or not alnum(singleton)or seen[singleton]then fail('RangeError','Invalid locale extension')end;seen[singleton]=true
   local values={};while i<=#parts and(#parts[i]>1 or singleton=='x')do local p=parts[i]:lower();if #p>8 or #p<(if singleton=='x'then 1 else 2)or not alnum(p)then fail('RangeError','Invalid locale extension subtag')end;values[#values+1]=p;i+=1 end
   if #values==0 then fail('RangeError','Empty locale extension')end
   if singleton=='u'then
    local at=1;local attrs={};while values[at]and #values[at]>=3 do local a=values[at];if not attrs[a]then r.Attributes[#r.Attributes+1]=a;attrs[a]=true end;at+=1 end
    while at<=#values do local key=values[at];if #key~=2 then fail('RangeError','Invalid Unicode locale keyword')end;at+=1;local types={};while values[at]and #values[at]>=3 do types[#types+1]=values[at];at+=1 end;if r.Keywords[key]==nil then r.Keywords[key]=table.concat(types,'-')end end
   elseif singleton=='x'then r.Private=table.concat(values,'-')else r.Extensions[singleton]=table.concat(values,'-')end
  end
  serialize(r);if options.CanonicalizeTag then local canonical=options.CanonicalizeTag(r.Tag);if canonical~=r.Tag then local saved=options.CanonicalizeTag;options.CanonicalizeTag=nil;local ok,result=pcall(parse,canonical);options.CanonicalizeTag=saved;if not ok then error(result,0)end;return result end end;return r
 end
 local localeProto=vm.Object({});vm.Prototypes.IntlLocale=localeProto
 local localeCtor
 local function locale(args,newTarget)
  local proto=if newTarget then vm.Get(newTarget,'prototype')else localeProto;if not vm.ObjectModel.IsObject(proto)then proto=localeProto end
  local input=arg(args,1);if type(input)~='string'and not vm.ObjectModel.IsObject(input)then fail('TypeError','Intl.Locale tag must be a string or object')end
  local r=parse(if locales[input]then locales[input].Tag else input);local opts=objectOptions(arg(args,2))
  for _,name in {'language','script','region'}do local raw=field(opts,name);if raw~=U then local v=text(raw)
   if name=='language'then if not validLanguage(v)then fail('RangeError','Invalid language option')end;local alias=parse(v);r.Language=alias.Language;r.Script=alias.Script or r.Script
   elseif name=='script'then if #v~=4 or not alpha(v)then fail('RangeError','Invalid script option')end;r.Script=v:sub(1,1):upper()..v:sub(2):lower()
   else if not(#v==2 and alpha(v)or #v==3 and v:match('^%d+$'))then fail('RangeError','Invalid region option')end;r.Region=regionAliases[v:upper()]or v:upper()end
  end end
  for _,entry in {{'calendar','ca'},{'collation','co'},{'hourCycle','hc'},{'caseFirst','kf'},{'numeric','kn'},{'numberingSystem','nu'}}do local raw=field(opts,entry[1]);if raw~=U then local v=if entry[1]=='numeric'then(if VM.truth(raw)then 'true'else 'false')else text(raw)
   if entry[1]=='hourCycle'and not table.find({'h11','h12','h23','h24'},v)or entry[1]=='caseFirst'and not table.find({'upper','lower','false'},v)then fail('RangeError','Invalid Intl.Locale option')end
   if not validType(v)then fail('RangeError','Invalid locale keyword type')end;r.Keywords[entry[2]]=v:lower()
  end end
  serialize(r)
  local value=vm.Object({},proto);value.IntlLocaleState=r;locales[value]=r;return value
 end
 localeCtor=native('Locale',1,function()fail('TypeError','Intl.Locale requires new')end);localeCtor.Construct=locale;define(localeCtor,'prototype',{value=localeProto});property(localeProto,'constructor',localeCtor)
 for _,entry in {{'baseName','BaseName'},{'language','Language'},{'script','Script'},{'region','Region'}}do define(localeProto,entry[1],{get=native('get '..entry[1],0,function(_,receiver)return brand(locales,receiver,'Intl.Locale.'..entry[1])[entry[2]]or U end),configurable=true})end
 for _,entry in {{'calendar','ca'},{'collation','co'},{'hourCycle','hc'},{'caseFirst','kf'},{'numeric','kn'},{'numberingSystem','nu'}}do define(localeProto,entry[1],{get=native('get '..entry[1],0,function(_,receiver)local v=brand(locales,receiver,'Intl.Locale.'..entry[1]).Keywords[entry[2]];return if entry[1]=='numeric'then v~=nil and v~='false'else if v==''then 'true'else v or U end),configurable=true})end
 method(localeProto,'toString',0,function(_,receiver)return brand(locales,receiver,'Intl.Locale.toString').Tag end)
 if vm.SymbolToStringTag then define(localeProto,vm.SymbolToStringTag,{value='Intl.Locale',configurable=true})end
 local function localeList(input)
  local out,seen={},{};if input==U or input==nil then return out end
  local list=if type(input)=='string'or locales[input]then vm.Array({input})else toObject(input)
  local n=VM.number(field(list,'length'));n=if n~=n or n<=0 then 0 else math.floor(n);if n>4096 then fail('RangeError','Intl locale list budget exceeded')end
  for i=0,n-1 do vm.Step();if vm.Has(list,tostring(i))then local tag=vm.Get(list,tostring(i));if type(tag)~='string'and not vm.ObjectModel.IsObject(tag)then fail('TypeError','Locale list entries must be strings or objects')end;local canonical=parse(if locales[tag]then locales[tag].Tag else tag).Tag;if not seen[canonical]then out[#out+1]=canonical;seen[canonical]=true end end end;return out
 end
 local namespace=vm.Object({});property(namespace,'Locale',localeCtor);method(namespace,'getCanonicalLocales',1,function(args)return vm.Array(localeList(arg(args,1)))end)
 if vm.SymbolToStringTag then define(namespace,vm.SymbolToStringTag,{value='Intl',configurable=true})end
 local formatProto=vm.Object({});vm.Prototypes.IntlNumberFormat=formatProto;local formatCtor
 local function resolve(requested)
  local function available(r)return if r.Language=='de'then(if r.Region=='DE'then 'de-DE'else 'de')elseif r.Language=='en'then(if r.Region=='US'then 'en-US'elseif r.Region=='GB'then 'en-GB'else 'en')else nil end
  for _,tag in requested do local r=parse(tag);local selected=available(r);if selected then return selected,r end end
  local r=parse(options.DefaultLocale or 'en-US');return available(r)or 'en-US',r
 end
 local function defaultDigit(raw,key,minimum,maximum,default)
  if raw==U then return default end;local n=VM.number(vm.ToPrimitive(raw,'number'));if n~=n or n<minimum or n>maximum then fail('RangeError','Invalid Intl '..key)end;return math.floor(n)
 end
 local function digitOption(opts,key,minimum,maximum,default)return defaultDigit(field(opts,key),key,minimum,maximum,default)end
 local function numberFormat(args,newTarget)
  local proto=if newTarget then vm.Get(newTarget,'prototype')else formatProto;if not vm.ObjectModel.IsObject(proto)then proto=formatProto end
  local requested=localeList(arg(args,1));local opts=objectOptions(arg(args,2));choice(opts,'localeMatcher',{'lookup','best fit'},'best fit');local rawNu=field(opts,'numberingSystem');if rawNu~=U then rawNu=text(rawNu);if not validType(rawNu)then fail('RangeError','Invalid numberingSystem')end else rawNu=nil end
  local selected,localeRecord=resolve(requested)
  local dataLocale=if selected:sub(1,2)=='de'then 'de-DE'elseif selected=='en-GB'then 'en-GB'else 'en-US'
  local style=choice(opts,'style',{'decimal','percent','currency','unit'},'decimal');local currencyRaw=field(opts,'currency');local currency
  if currencyRaw~=U then currency=text(currencyRaw):upper();if #currency~=3 or not alpha(currency)then fail('RangeError','Invalid currency code')end end
  local currencyDisplay=choice(opts,'currencyDisplay',{'code','symbol','narrowSymbol','name'},'symbol');local currencySign=choice(opts,'currencySign',{'standard','accounting'},'standard')
  if style=='currency'and not currency then fail('TypeError','Currency style requires currency')end
  local unit=field(opts,'unit');if unit~=U then unit=text(unit);local first,second=unit:match('^(.-)%-per%-(.-)$');if not Data.Units[unit]and not(first and Data.Units[first]and Data.Units[second])then fail('RangeError','Invalid Intl unit')end elseif style=='unit'then fail('TypeError','Unit style requires unit')end
  local unitDisplay=choice(opts,'unitDisplay',{'short','narrow','long'},'short')
  local notation=choice(opts,'notation',{'standard','scientific','engineering','compact'},'standard')
  local minInteger=digitOption(opts,'minimumIntegerDigits',1,21,1);local rawMinFraction,rawMaxFraction=field(opts,'minimumFractionDigits'),field(opts,'maximumFractionDigits')
  local minSignificant,maxSignificant=field(opts,'minimumSignificantDigits'),field(opts,'maximumSignificantDigits')
  local increment=digitOption(opts,'roundingIncrement',1,5000,1);local rounding=choice(opts,'roundingMode',{'ceil','floor','expand','trunc','halfCeil','halfFloor','halfExpand','halfTrunc','halfEven'},'halfExpand')
  local priority=choice(opts,'roundingPriority',{'auto','morePrecision','lessPrecision'},'auto');local zeros=choice(opts,'trailingZeroDisplay',{'auto','stripIfInteger'},'auto')
  if not table.find({1,2,5,10,20,25,50,100,200,250,500,1000,2000,2500,5000},increment)then fail('RangeError','Invalid roundingIncrement')end
  local significant=minSignificant~=U or maxSignificant~=U or priority~='auto'
  local minSig=if significant then defaultDigit(minSignificant,'minimumSignificantDigits',1,21,1)else nil
  local maxSig=if significant then defaultDigit(maxSignificant,'maximumSignificantDigits',1,21,math.max(minSig,21))else nil
  if minSig and minSig>maxSig then fail('RangeError','minimumSignificantDigits exceeds maximumSignificantDigits')end
  local useFraction=not significant or priority~='auto'
  local minFraction=if useFraction then defaultDigit(rawMinFraction,'minimumFractionDigits',0,100,nil)else 0
  local maxFraction=if useFraction then defaultDigit(rawMaxFraction,'maximumFractionDigits',0,100,nil)else 0
  local currencyData=NumberData.Locales[dataLocale].Currencies[currency]
  local defaultDigits=if style=='currency'then(if currencyData then currencyData.Digits elseif Data[currency]then Data[currency].Digits else 2)elseif style=='percent'then 0 else 3
  minFraction=minFraction or math.min(if style=='currency'then defaultDigits else 0,maxFraction or 100);maxFraction=maxFraction or math.max(minFraction,defaultDigits);if minFraction>maxFraction then fail('RangeError','minimumFractionDigits exceeds maximumFractionDigits')end
  if increment~=1 and(significant or priority~='auto')then fail('TypeError','roundingIncrement requires fraction rounding')end
  if increment~=1 and minFraction~=maxFraction then fail('RangeError','roundingIncrement requires equal fraction digits')end
  if notation=='compact'and minSignificant==U and maxSignificant==U and rawMinFraction==U and rawMaxFraction==U then minFraction,maxFraction,minSig,maxSig,priority=0,0,1,2,'morePrecision'end
  local compactDisplay=choice(opts,'compactDisplay',{'short','long'},'short')
  local grouping=field(opts,'useGrouping');if grouping==U then grouping=if notation=='compact'then 'min2'else 'auto'elseif grouping==false then grouping=false elseif grouping==true then grouping='always'else grouping=text(grouping);if grouping=='true'or grouping=='false'then grouping='auto'elseif not table.find({'auto','always','min2'},grouping)then fail('RangeError','Invalid useGrouping')end end
  local signDisplay=choice(opts,'signDisplay',{'auto','never','always','exceptZero','negative'},'auto')
  local localeTag=selected;if localeRecord.Keywords.nu=='latn'and(rawNu==nil or rawNu=='latn')then localeTag..='-u-nu-latn'end
  if style=='unit'and not NumberData.Locales[dataLocale].Units[unit]then fail('RangeError','This unit compound is outside the available CLDR profile')end
  local state={Locale=localeTag,DataLocale=dataLocale,German=selected:sub(1,2)=='de',Style=style,Currency=currency,CurrencyDisplay=currencyDisplay,CurrencySign=currencySign,Unit=unit,UnitDisplay=unitDisplay,MinInteger=minInteger,MinFraction=minFraction,MaxFraction=maxFraction,MinSignificant=minSig,MaxSignificant=maxSig,Increment=increment,Rounding=rounding,Priority=priority,Notation=notation,CompactDisplay=compactDisplay,Grouping=grouping,SignDisplay=signDisplay,Zeros=zeros}
  local value=vm.Object({},proto);value.IntlNumberFormatState=state;formats[value]=state;return value
 end
 local function decimal(value)
  local primitive=vm.ToPrimitive(value,'number');local source
  if BigInt.is(primitive)then source=BigInt.String(primitive)elseif type(primitive)=='string'then source=Strings.trim(primitive);if source==''then source='0'end
   if source:match('^0[xXoObB]')then local ok,n=pcall(vm.BigInt.Parse,vm.BigInt,source);source=if ok then BigInt.String(n)else 'NaN'end
   local approximate=Numbers.parse(source);if math.abs(approximate)==math.huge then source=Numbers.string(approximate)elseif approximate==0 then source=if source:sub(1,1)=='-'then '-0'else '0'end
  else local n=VM.number(primitive);source=if n==0 and 1/n<0 then '-0'else Numbers.string(n)end
  local negative=source:sub(1,1)=='-';if source:sub(1,1)=='-'or source:sub(1,1)=='+'then source=source:sub(2)end
  if source=='Infinity'then return nil,nil,negative,'infinity'end
  local coefficient,exponent=source:match('^(.-)[eE]([+-]?%d+)$');if not coefficient then coefficient,exponent=source,'0'end
  if not coefficient:match('^%d+%.?%d*$')and not coefficient:match('^%.%d+$')then return nil,nil,false,'nan'end
  local integer,fraction=coefficient:match('^(%d*)%.(%d*)$');if not integer then integer,fraction=coefficient,''end
  local shift=tonumber(exponent);if math.abs(shift)>4096 then return nil,nil,negative,if shift>0 then 'infinity'else nil end
  local digits=integer..fraction;local point=#integer+shift
  if point<0 then digits=string.rep('0',-point)..digits;point=0 elseif point>#digits then digits..=string.rep('0',point-#digits)end
  return digits,point,negative,nil
 end
 local function formatParts(state,input)
  local digits,point,negative,special=decimal(input);local parts={};local function part(kind,value)parts[#parts+1]=vm.Object({type=kind,value=value},nil,{'type','value'})end
  local zero=false;local integer,fraction;local exponent=0;local numberData=NumberData.Locales[state.DataLocale];local compact
  if not special then
   digits=digits or '0';point=point or 1;if state.Style=='percent'then point+=2 end
   local first=digits:find('[1-9]');local magnitude=if first then point-first else 0
   if state.Notation=='scientific'then exponent=magnitude elseif state.Notation=='engineering'then exponent=math.floor(magnitude/3)*3
   elseif state.Notation=='compact'and magnitude>=3 then
    exponent=math.min(math.floor(magnitude/3)*3,12);compact=numberData.Compact[state.CompactDisplay][tostring(exponent)]
    if not compact or #compact[1]==0 then exponent=0;compact=nil end
   end
   point-=exponent;integer,fraction=Rounding.format(digits,point,negative,state,vm.Step)
   local carry=if state.Notation=='scientific'and #integer>1 then #integer-1 elseif(state.Notation=='engineering'or compact and exponent<12)and #integer>3 then 3 else 0
   if carry>0 then exponent+=carry;integer,fraction=Rounding.format(integer..fraction,#integer-carry,negative,state,vm.Step);if compact then compact=numberData.Compact[state.CompactDisplay][tostring(math.min(exponent,12))]end end
   zero=integer=='0'and not fraction:find('[1-9]')
   integer=string.rep('0',math.max(state.MinInteger-#integer,0))..integer
  end
  local showMinus=negative and state.SignDisplay~='never'and not(state.SignDisplay=='negative'and zero)and not(state.SignDisplay=='exceptZero'and zero)
  local showPlus=not negative and(state.SignDisplay=='always'or state.SignDisplay=='exceptZero'and not zero and special~='nan')
  local accounting=showMinus and state.Style=='currency'and state.CurrencySign=='accounting'and not state.German
  if accounting then part('literal','(')elseif showMinus then part('minusSign','-')elseif showPlus then part('plusSign','+')end
  local data=Data[state.Currency];local currencySymbol=if data then data[if state.German then(if state.CurrencyDisplay=='narrowSymbol'then 'NarrowDE'else 'DE')else(if state.CurrencyDisplay=='narrowSymbol'then 'NarrowEN'else 'EN')]else state.Currency
  local currencyRecord=numberData.Currencies[state.Currency];if currencyRecord and currencyRecord.Symbols[state.CurrencyDisplay]then currencySymbol=currencyRecord.Symbols[state.CurrencyDisplay]end
  if state.Style=='currency'and state.CurrencyDisplay=='code'then currencySymbol=state.Currency end
  if state.Style=='currency'and state.CurrencyDisplay~='name'and not state.German then part('currency',currencySymbol);if not special and currencySymbol:match('^%a%a%a$')then part('literal',utf8.char(160))end end
  if special then part(special,if special=='nan'then 'NaN'else '∞')else
   local useGrouping=state.Grouping~=false and #integer>=(if state.Grouping=='min2'then 5 else 4);local first=if useGrouping then(#integer-1)%3+1 else #integer;part('integer',integer:sub(1,first))
   if useGrouping then for i=first+1,#integer,3 do part('group',if state.German then '.'else ',');part('integer',integer:sub(i,i+2))end end
   if fraction~=''then part('decimal',if state.German then ','else '.');part('fraction',fraction)end
  end
  if not special and(state.Notation=='scientific'or state.Notation=='engineering')then part('exponentSeparator','E');if exponent<0 then part('exponentMinusSign','-')end;part('exponentInteger',tostring(math.abs(exponent)))end
  local one=not special and integer:gsub('^0+','')=='1'and fraction==''
  local function affix(values)for _,entry in values or {}do part(entry[1],entry[2])end end
  if compact and not special then affix(compact[if one then 1 else 2])end
  if state.Style=='unit'then affix(numberData.Units[state.Unit][state.UnitDisplay][if one then 1 else 2])
  elseif state.Style=='percent'then if state.German then part('literal',utf8.char(160))end;part('percentSign','%')
  elseif state.Style=='currency'then
   if state.CurrencyDisplay=='name'then local record=numberData.Currencies[state.Currency];if record then affix(record.Names[if one then 1 else 2])else part('literal',' ');part('currency',state.Currency)end
   elseif state.German then part('literal',utf8.char(160));part('currency',currencySymbol)end
  end
  if accounting then part('literal',')')end;return parts
 end
 formatCtor=native('NumberFormat',0,function(args)return numberFormat(args)end);formatCtor.Construct=numberFormat;define(formatCtor,'prototype',{value=formatProto});property(formatProto,'constructor',formatCtor);property(namespace,'NumberFormat',formatCtor)
 define(formatProto,'format',{get=native('get format',0,function(_,receiver)local state=brand(formats,receiver,'Intl.NumberFormat.format');if not state.Bound then state.Bound=native('',1,function(args)local out={};for _,part in formatParts(state,arg(args,1))do out[#out+1]=vm.Get(part,'value')end;return table.concat(out)end)end;return state.Bound end),configurable=true})
 method(formatProto,'formatToParts',1,function(args,receiver)return vm.Array(formatParts(brand(formats,receiver,'Intl.NumberFormat.formatToParts'),arg(args,1)))end)
 method(formatProto,'resolvedOptions',0,function(_,receiver)
  local s=brand(formats,receiver,'Intl.NumberFormat.resolvedOptions');local values={locale=s.Locale,numberingSystem='latn',style=s.Style,minimumIntegerDigits=s.MinInteger,useGrouping=s.Grouping,notation=s.Notation,signDisplay=s.SignDisplay,roundingIncrement=s.Increment,roundingMode=s.Rounding,roundingPriority=s.Priority,trailingZeroDisplay=s.Zeros}
  local order={'locale','numberingSystem','style'};if s.Style=='currency'then values.currency,values.currencyDisplay,values.currencySign=s.Currency,s.CurrencyDisplay,s.CurrencySign;for _,key in {'currency','currencyDisplay','currencySign'}do order[#order+1]=key end end
  if s.Style=='unit'then values.unit,values.unitDisplay=s.Unit,s.UnitDisplay;order[#order+1]='unit';order[#order+1]='unitDisplay'end
  order[#order+1]='minimumIntegerDigits'
  if not s.MaxSignificant or s.Priority~='auto'then values.minimumFractionDigits,values.maximumFractionDigits=s.MinFraction,s.MaxFraction;order[#order+1]='minimumFractionDigits';order[#order+1]='maximumFractionDigits'end
  if s.MaxSignificant then values.minimumSignificantDigits,values.maximumSignificantDigits=s.MinSignificant,s.MaxSignificant;order[#order+1]='minimumSignificantDigits';order[#order+1]='maximumSignificantDigits'end
  for _,key in {'useGrouping','notation'}do order[#order+1]=key end
  if s.Notation=='compact'then values.compactDisplay=s.CompactDisplay;order[#order+1]='compactDisplay'end
  for _,key in {'signDisplay','roundingIncrement','roundingMode','roundingPriority','trailingZeroDisplay'}do order[#order+1]=key end;return vm.Object(values,nil,order)
 end)
 method(formatCtor,'supportedLocalesOf',1,function(args)local list=localeList(arg(args,1));local opts=objectOptions(arg(args,2));choice(opts,'localeMatcher',{'lookup','best fit'},'best fit');local out={};for _,tag in list do local language=parse(tag).Language;if language=='en'or language=='de'then out[#out+1]=tag end end;return vm.Array(out)end)
 if vm.SymbolToStringTag then define(formatProto,vm.SymbolToStringTag,{value='Intl.NumberFormat',configurable=true})end
 method(vm.Prototypes.Number,'toLocaleString',0,function(args,receiver)
  local value=if type(receiver)=='number'then receiver elseif type(receiver)=='table'and receiver.Kind=='boxed-number'then receiver.PrimitiveValue else nil
  if value==nil then fail('TypeError','Number.toLocaleString requires a Number receiver')end
  local formatter=numberFormat({arg(args,1),arg(args,2)});local out={};for _,part in formatParts(formats[formatter],value)do out[#out+1]=vm.Get(part,'value')end;return table.concat(out)
 end)
 local lists=IntlLists.install(vm,namespace,{Locales=localeList,Options=objectOptions,Choice=choice,Resolve=resolve,Parse=parse})
 local dateTime=IntlDateTime.install(vm,namespace,{Locales=localeList,Options=objectOptions,Choice=choice,Resolve=resolve,Parse=parse},options)
 api.FormatDateTime=dateTime.Format
 globals.Intl=namespace;vm.Global.Bindings.Intl={Value=namespace};api.ParseLocale=parse
 function api:Destroy()self.Alive=false;lists:Destroy();dateTime:Destroy();table.clear(locales);table.clear(formats)end
 return api
end
return Intl
