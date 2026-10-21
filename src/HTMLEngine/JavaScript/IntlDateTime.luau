--!strict
-- Gregorian/Latin de-DE, en-US and en-GB profile. CLDR token patterns and IANA
-- transitions are versioned data; unsupported families remain explicit.
local Data=require(script.Parent.IntlDateData)
local Zones=require(script.Parent.IntlTimeZones)
local Dates=require(script.Parent.LibraryDate)
local Library={}
function Library.install(vm: any,namespace: any,context: any,options: any): any
 local VM,U,N=vm.Model,vm.Model.Undefined,vm.Model.Null;local alive=true;local states=setmetatable({},{__mode='kv'})
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function text(value)value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then fail('TypeError','Cannot convert Symbol to Intl text')end;return VM.string(value)end
 local function def(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function native(name,length,call)local fn={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)assert(alive and vm.Alive,'Intl.DateTimeFormat disposed');return call(args,receiver)end};def(fn,'length',{value=length,configurable=true});def(fn,'name',{value=name,configurable=true});return fn end
 local proto=vm.Object({});vm.Prototypes.IntlDateTimeFormat=proto
 local function method(target,name,length,callback)def(target,name,{value=native(name,length,callback),writable=true,configurable=true})end
 local function state(receiver)local value=states[receiver];if not value then fail('TypeError','Intl.DateTimeFormat requires its receiver')end;return value end
 local dateKeys={'year','month','day','weekday','era'};local timeKeys={'hour','minute','second','fractionalSecondDigits'}
 local styles={'full','long','medium','short'}
 local function optional(opts,key,values)local selected=context.Choice(opts,key,values,nil);return selected end
 local function resolve(requested)
  for _,tag in requested do local r=context.Parse(tag);if r.Language=='de'then return if r.Region=='DE'then 'de-DE'else 'de',r elseif r.Language=='en'then return if r.Region=='GB'then 'en-GB'elseif r.Region=='US'then 'en-US'else 'en',r end end
  local r=context.Parse(options.DefaultLocale or 'en-US');return if r.Language=='de'then 'de-DE'elseif r.Region=='GB'then 'en-GB'else 'en-US',r
 end
 local function make(locales,input,newTarget,required,defaults)
  local requested=context.Locales(locales or U);local opts=context.Options(input or U);context.Choice(opts,'localeMatcher',{'lookup','best fit'},'best fit')
  local locale,r=resolve(requested);local dataLocale=if locale:sub(1,2)=='de'then 'de-DE'elseif locale=='en-GB'then 'en-GB'else 'en-US'
  local function validType(value)
   if value==''or value:sub(1,1)=='-'or value:sub(-1)=='-'or value:find('--',1,true)then return false end
   for part in value:gmatch('[^-]+')do if #part<3 or #part>8 or not part:match('^%w+$')then return false end end;return true
  end
  local calendar=vm.Get(opts,'calendar');local calendarValue=if calendar~=U then text(calendar)else nil;if calendarValue and not validType(calendarValue)then fail('RangeError','Invalid calendar')end
  local numbering=vm.Get(opts,'numberingSystem');local numberingValue=if numbering~=U then text(numbering)else nil;if numberingValue and not validType(numberingValue)then fail('RangeError','Invalid numberingSystem')end
  -- Valid unsupported calendar/numbering requests negotiate to the available
  -- Gregorian/Latin profile, as locale negotiation does for unsupported locales.
  local extensions={}
  if r.Keywords.ca=='gregory'and(calendar==U or calendarValue=='gregory')then extensions[#extensions+1]='ca-gregory'end
  local raw12=vm.Get(opts,'hour12');local rawCycle=optional(opts,'hourCycle',{'h11','h12','h23','h24'});local cycle=rawCycle or r.Keywords.hc or(if dataLocale=='en-US'then 'h12'else 'h23')
  if not table.find({'h11','h12','h23','h24'},cycle)then cycle=if dataLocale=='en-US'then 'h12'else 'h23'end
  if raw12~=U then cycle=if VM.truth(raw12)then 'h12'else 'h23'end
  if r.Keywords.hc==cycle and raw12==U and(rawCycle==nil or rawCycle==cycle)then extensions[#extensions+1]='hc-'..cycle end
  if r.Keywords.nu=='latn'and(numbering==U or numberingValue=='latn')then extensions[#extensions+1]='nu-latn'end
  if #extensions>0 then locale..='-u-'..table.concat(extensions,'-')end
  local rawZone=vm.Get(opts,'timeZone');local zone=Zones.canonical(if rawZone==U then options.DefaultTimeZone or options.TimeZone or 'UTC'else text(rawZone));if not zone then fail('RangeError','Time zone is outside the available IANA profile')end
  local f={};f.weekday=optional(opts,'weekday',{'long','short','narrow'});f.era=optional(opts,'era',{'long','short','narrow'});f.year=optional(opts,'year',{'numeric','2-digit'});f.month=optional(opts,'month',{'numeric','2-digit','long','short','narrow'});f.day=optional(opts,'day',{'numeric','2-digit'})
  f.dayPeriod=optional(opts,'dayPeriod',{'long','short','narrow'});if f.dayPeriod then fail('RangeError','Flexible day periods are outside this DateTimeFormat profile')end
  for _,key in {'hour','minute','second'}do f[key]=optional(opts,key,{'numeric','2-digit'})end
  local rawFraction=vm.Get(opts,'fractionalSecondDigits');if rawFraction~=U then local n=VM.number(vm.ToPrimitive(rawFraction,'number'));if n~=n or n<1 or n>3 then fail('RangeError','Invalid fractionalSecondDigits')end;f.fractionalSecondDigits=math.floor(n)end
  local zoneName=optional(opts,'timeZoneName',{'short','long','shortOffset','longOffset','shortGeneric','longGeneric'})
  context.Choice(opts,'formatMatcher',{'basic','best fit'},'best fit');local dateStyle=optional(opts,'dateStyle',styles);local timeStyle=optional(opts,'timeStyle',styles)
  if required=='date'and timeStyle or required=='time'and dateStyle then fail('TypeError','Date locale method received a conflicting style')end
  local any=false;for _,key in dateKeys do any=any or f[key]~=nil end;for _,key in timeKeys do any=any or f[key]~=nil end;any=any or zoneName~=nil
  if(dateStyle or timeStyle)and any then fail('TypeError','Date/time styles cannot be mixed with component fields')end
  if not dateStyle and not timeStyle then
   local datePresent,timePresent=false,false
   for _,key in {'year','month','day','weekday'}do datePresent=datePresent or f[key]~=nil end
   for _,key in timeKeys do timePresent=timePresent or f[key]~=nil end
   local useDefaults=if required=='date'then not datePresent elseif required=='time'then not timePresent else not(datePresent or timePresent)
   if useDefaults then if defaults~='time'then f.year,f.month,f.day='numeric','numeric','numeric'end;if defaults=='all'or defaults=='time'then f.hour,f.minute,f.second='numeric','numeric','numeric'end end
  end
  local records=Data.Locales[dataLocale];local datePattern,timePattern,stylePattern
  if dateStyle or timeStyle then stylePattern=Data.Patterns[records.Styles[(dateStyle or '')..'|'..(timeStyle or '')..'|'..cycle]]
  else
   local d={};for _,key in dateKeys do d[#d+1]=f[key]or ''end;local t={};for _,key in timeKeys do t[#t+1]=if f[key]~=nil then tostring(f[key])else ''end;t[#t+1]=cycle
   local dateId=records.Dates[table.concat(d,'|')];local timeId=records.Times[table.concat(t,'|')];datePattern=dateId and Data.Patterns[dateId];timePattern=timeId and Data.Patterns[timeId]
  end
  local resolved={locale=locale,calendar='gregory',numberingSystem='latn',timeZone=zone}
  local function fields(pattern)if pattern then for key,value in pattern.Resolved do resolved[key]=value end end end
  if stylePattern then resolved.dateStyle=dateStyle;resolved.timeStyle=timeStyle;if timeStyle then resolved.hourCycle=cycle;resolved.hour12=cycle=='h11'or cycle=='h12'end
  else fields(datePattern);fields(timePattern);if zoneName then resolved.timeZoneName=zoneName end end
  local prototype=if newTarget then vm.Get(newTarget,'prototype')else proto;if not vm.ObjectModel.IsObject(prototype)then prototype=proto end
  local value=vm.Object({},prototype);local record={Locale=dataLocale,Resolved=resolved,Fields=f,Date=datePattern,Time=timePattern,Style=stylePattern,DateStyle=dateStyle,TimeStyle=timeStyle,Cycle=cycle,Zone=zone,ZoneName=zoneName};value.IntlDateTimeFormatState=record;states[value]=record;return value,record
 end
 local function now()if options.DateNow then return options.DateNow()elseif DateTime then return DateTime.now().UnixTimestampMillis else return os.time()*1000 end end
 local function parts(s,input)
  local time=if input==nil or input==U then now()else VM.number(vm.ToPrimitive(input,'number'))
  if time~=time or math.abs(time)>8640000000000000 then fail('RangeError','Invalid time value')end;time=if time<0 then math.ceil(time)else math.floor(time)
  local offset=Zones.offset(s.Zone,time);if not offset then fail('RangeError','Named time zone data covers 1900 through 2100')end
  local p=Dates.componentsUTC(time+offset*1000);local out={};local data=Data.Locales[s.Locale]
  local function add(kind,value)if value~=''then out[#out+1]=vm.Object({type=kind,value=value},nil,{'type','value'})end end
  local function token(kind,width)
   if kind=='literal'then return width end
   local f=s.Fields;local year=if p[1]<=0 then 1-p[1]else p[1]
   if width==''then
    if kind=='month'then width=if s.DateStyle=='full'or s.DateStyle=='long'then 'long'elseif s.DateStyle=='medium'then 'short'else 'numeric'
    elseif kind=='weekday'then width='long'elseif kind=='era'then width='short'
    elseif kind=='year'then width=if s.DateStyle=='short'then '2-digit'else 'numeric'
    elseif kind=='timeZoneName'then width=if s.TimeStyle=='full'then 'long'else 'short'
    elseif kind=='hour'or kind=='minute'or kind=='second'then width=if kind=='hour'and(s.Cycle=='h11'or s.Cycle=='h12')then 'numeric'else '2-digit'
    elseif kind=='day'then width=if s.Locale=='en-US'then 'numeric'else '2-digit'end
   end
   if kind=='year'then return if width=='2-digit'then string.format('%02d',year%100)else tostring(year)
   elseif kind=='month'then if data.Months[width]then return data.Months[width][p[2]+1]end;return if width=='2-digit'then string.format('%02d',p[2]+1)else tostring(p[2]+1)
   elseif kind=='day'then return if width=='2-digit'then string.format('%02d',p[3])else tostring(p[3])
   elseif kind=='weekday'then return data.Weekdays[width][p[8]+1]
   elseif kind=='era'then return data.Eras[width][if p[1]<=0 then 1 else 2]
   elseif kind=='hour'then local h=p[4];if s.Cycle=='h11'then h%=12 elseif s.Cycle=='h12'then h=h%12;if h==0 then h=12 end elseif s.Cycle=='h24'and h==0 then h=24 end;return if width=='2-digit'then string.format('%02d',h)else tostring(h)
   elseif kind=='minute'or kind=='second'then local n=p[if kind=='minute'then 5 else 6];return if width=='2-digit'then string.format('%02d',n)else tostring(n)
   elseif kind=='fractionalSecond'then return string.format('%03d',p[7]):sub(1,f.fractionalSecondDigits or 3)
   elseif kind=='dayPeriod'then return data.DayPeriods[if s.Cycle=='h11'then 'h11'else 'h12'][if p[4]<12 then 1 else 2]
   elseif kind=='timeZoneName'then return Zones.name(s.Zone,time,s.Locale,s.ZoneName or width)or ''end
   return ''
  end
  local function append(pattern)if pattern then for _,part in pattern.Parts do
   vm.Step();local value
   if part[3]then value=Data.Names[part[3]][if part[1]=='month'then p[2]+1 elseif part[1]=='weekday'then p[8]+1 else if p[1]<=0 then 1 else 2]
   else value=token(part[1],part[2])end;add(part[1],value)
  end end end
  if s.Style then append(s.Style)else
   append(s.Date);if s.Date and s.Time then add('literal',s.Date.Join or ', ')end;append(s.Time)
   if s.ZoneName then if #out>0 then add('literal',if s.Date and not s.Time then s.Date.ZoneJoin or ', 'else ' ')end;add('timeZoneName',Zones.name(s.Zone,time,s.Locale,s.ZoneName)or '')end
  end
  return out
 end
 local function format(s,input)
  local out={};local normalize=s.Style and s.Style.FormatNarrowSpace or s.Time and s.Time.FormatNarrowSpace
  for _,part in parts(s,input)do local value=vm.Get(part,'value');if normalize and vm.Get(part,'type')=='literal'then value=value:gsub(utf8.char(0x202f),' ')end;out[#out+1]=value end;return table.concat(out)
 end
 local ctor=native('DateTimeFormat',0,function(args)return make(args[1],args[2],nil,'any','date')end);ctor.Construct=function(args,newTarget)return make(args[1],args[2],newTarget,'any','date')end
 def(ctor,'prototype',{value=proto});def(proto,'constructor',{value=ctor,writable=true,configurable=true});def(namespace,'DateTimeFormat',{value=ctor,writable=true,configurable=true})
 if vm.SymbolToStringTag then def(proto,vm.SymbolToStringTag,{value='Intl.DateTimeFormat',configurable=true})end
 def(proto,'format',{get=native('get format',0,function(_,receiver)local s=state(receiver);if not s.Bound then s.Bound=native('',1,function(args)return format(s,args[1])end)end;return s.Bound end),configurable=true})
 method(proto,'formatToParts',1,function(args,receiver)return vm.Array(parts(state(receiver),args[1]))end)
 method(proto,'resolvedOptions',0,function(_,receiver)
  local values=table.clone(state(receiver).Resolved);local order={}
  for _,key in {'locale','calendar','numberingSystem','timeZone','hourCycle','hour12','weekday','era','year','month','day','hour','minute','second','fractionalSecondDigits','timeZoneName','dateStyle','timeStyle'}do if values[key]~=nil then order[#order+1]=key end end
  return vm.Object(values,nil,order)
 end)
 method(ctor,'supportedLocalesOf',1,function(args)local list=context.Locales(args[1]or U);local opts=context.Options(args[2]or U);context.Choice(opts,'localeMatcher',{'lookup','best fit'},'best fit');local out={};for _,tag in list do local r=context.Parse(tag);if r.Language=='de'or r.Language=='en'then out[#out+1]=tag end end;return vm.Array(out)end)
 local api={}
 function api.Format(value,locales,opts,required,defaults)local _,s=make(locales,opts,nil,required,defaults);return format(s,value)end
 function api:Destroy()alive=false;table.clear(states)end
 return api
end
return Library
