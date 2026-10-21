--!strict
-- Gregorian time arithmetic is independent of host date range. Local time uses
-- an explicit realm offset adapter; absent that adapter the realm uses UTC.
local Dates={}
local Zones=require(script.Parent.IntlTimeZones)
local DAY=86400000
local function civilDays(year,month,day)
 year-=if month<=2 then 1 else 0
 local era=math.floor(year/400);local y=year-era*400;local m=month+(if month>2 then -3 else 9)
 return era*146097+y*365+math.floor(y/4)-math.floor(y/100)+math.floor((153*m+2)/5)+day-1-719468
end
local function civilDate(days)
 local z=days+719468;local era=math.floor(z/146097);local doe=z-era*146097
 local yoe=math.floor((doe-math.floor(doe/1460)+math.floor(doe/36524)-math.floor(doe/146096))/365)
 local year=yoe+era*400;local doy=doe-(365*yoe+math.floor(yoe/4)-math.floor(yoe/100));local mp=math.floor((5*doy+2)/153)
 local day=doy-math.floor((153*mp+2)/5)+1;local month=mp+(if mp<10 then 3 else -9);year+=if month<=2 then 1 else 0
 return year,month,day
end
function Dates.componentsUTC(value: number): any
 local days=math.floor(value/DAY);local time=value-days*DAY;local year,month,day=civilDate(days)
 local hour=math.floor(time/3600000);time-=hour*3600000;local minute=math.floor(time/60000);time-=minute*60000;local second=math.floor(time/1000);time-=second*1000
 return {year,month-1,day,hour,minute,second,time,(days+4)%7}
end
function Dates.install(c: any)
 local VM,vm,U,N=c.VM,c.vm,c.U,c.N;local get=c.get
 local function clip(value)
  if value~=value or math.abs(value)>8640000000000000 then return 0/0 end
  local n=if value<0 then math.ceil(value)else math.floor(value);return if n==0 then 0 else n
 end
 local function offset(value)
  local configured=c.options.TimezoneOffsetMinutes
  if configured==nil and(c.options.DefaultTimeZone or c.options.TimeZone)then
   local zone=Zones.canonical(c.options.DefaultTimeZone or c.options.TimeZone);if not zone then c.fail('RangeError','Unavailable Date time zone')end
   local seconds=Zones.offset(zone,value);if not seconds then c.fail('RangeError','Named Date time zone data covers 1900 through 2100')end;return -seconds/60
  end
  return if type(configured)=='function'then configured(value)elseif type(configured)=='number'then configured else 0
 end
 local function toUTC(value)
  -- Iteration handles ordinary DST changes when the host supplies an offset
  -- function. Exact ambiguous-time policy may instead use DateLocalToUTC.
  if c.options.DateLocalToUTC then return c.options.DateLocalToUTC(value)end
  if c.options.TimezoneOffsetMinutes==nil and(c.options.DefaultTimeZone or c.options.TimeZone)then
   if value~=value or math.abs(value)==math.huge then return 0/0 end
   local zone=Zones.canonical(c.options.DefaultTimeZone or c.options.TimeZone);local result=zone and Zones.toUTC(zone,value)
   if not result then c.fail('RangeError','Named Date time zone data covers 1900 through 2100')end;return result
  end
  local first=value+offset(value)*60000;return value+offset(first)*60000
 end
 local function components(value,localTime)
  if localTime then value-=offset(value)*60000 end
  return Dates.componentsUTC(value)
 end
 local function make(parts)
  for _,value in parts do if value~=value or math.abs(value)==math.huge then return 0/0 end end
  local year,month=c.integer(parts[1]),c.integer(parts[2]);year+=math.floor(month/12);month=month%12
  return civilDays(year,month+1,c.integer(parts[3]))*DAY+c.integer(parts[4])*3600000+c.integer(parts[5])*60000+c.integer(parts[6])*1000+c.integer(parts[7])
 end
 local function parse(value)
  local source=c.text(value)
  -- Required zero-millisecond round trips from toString/toUTCString. General
  -- implementation-defined natural-language date parsing remains outside this
  -- profile rather than passing through an unrelated host parser.
  local monthNames={Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
  local mon,d,y,h,m,s,sign,zh,zm=source:match('^%a%a%a (%a%a%a) (%d%d) ([+-]?%d+) (%d%d):(%d%d):(%d%d) GMT([+-])(%d%d)(%d%d)')
  if not mon then d,mon,y,h,m,s=source:match('^%a%a%a, (%d%d) (%a%a%a) ([+-]?%d+) (%d%d):(%d%d):(%d%d) GMT$');sign,zh,zm='+','00','00'end
  if mon and monthNames[mon]then return clip(make({tonumber(y),monthNames[mon]-1,tonumber(d),tonumber(h),tonumber(m),tonumber(s),0})+(tonumber(zh)*60+tonumber(zm))*60000*(if sign=='+'then -1 else 1))end
  local yearText,monthText,dayText,rest=source:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)(.*)$')
  if not yearText then yearText,monthText,dayText,rest=source:match('^([+-]%d%d%d%d%d%d)%-(%d%d)%-(%d%d)(.*)$')end
  if not yearText then
   yearText,monthText,rest=source:match('^(%d%d%d%d)%-(%d%d)(.*)$');dayText='01'
   if not yearText then yearText,rest=source:match('^(%d%d%d%d)(.*)$');monthText,dayText='01','01'end
  end
  if not yearText or yearText=='-000000'then return 0/0 end
  local year,month,day=tonumber(yearText),tonumber(monthText),tonumber(dayText)
  if month<1 or month>12 or day<1 or day>31 then return 0/0 end
  local hour,minute,second,milli=0,0,0,0;local localTime=false;local timezone=0
  if rest~=''then
   local h,m,tail=rest:match('^T(%d%d):(%d%d)(.*)$');if not h then return 0/0 end;hour,minute=tonumber(h),tonumber(m)
   if tail:sub(1,1)==':'then local sec,remaining=tail:match('^:(%d%d)(.*)$');if not sec then return 0/0 end;second,tail=tonumber(sec),remaining end
   if tail:sub(1,1)=='.'then local ms,remaining=tail:match('^%.(%d+)(.*)$');if not ms then return 0/0 end;milli,tail=tonumber((ms..'00'):sub(1,3)),remaining end
   if minute>59 or second>59 or hour>24 or(hour==24 and(minute~=0 or second~=0 or milli~=0))then return 0/0 end
   if tail==''then localTime=true elseif tail=='Z'then timezone=0
   else local sign,zh,zm=tail:match('^([+-])(%d%d):(%d%d)$');if not sign or tonumber(zh)>23 or tonumber(zm)>59 then return 0/0 end;timezone=(tonumber(zh)*60+tonumber(zm))*(if sign=='+'then -1 else 1)end
  end
  local time=make({year,month-1,day,hour,minute,second,milli})
  return clip(if localTime then toUTC(time)else time+timezone*60000)
 end
 local function now()
  if c.options.DateNow then return clip(c.options.DateNow())end
  if DateTime then return DateTime.now().UnixTimestampMillis end
  return os.time()*1000
 end
 local proto=vm.Object({},c.prototypes.Object);c.prototypes.Date=proto
 local function receiver(value)
  if not c.isObject(value)or value.Kind~='date'then c.fail('TypeError','Date method called on incompatible receiver')end;return value
 end
 local function construct(args,newTarget)
  local value
  if #args==0 then value=now()elseif #args==1 then local item=args[1]
   if c.isObject(item)and item.Kind=='date'then value=item.TimeValue
   else if vm.ToPrimitive then item=vm.ToPrimitive(item,'default')end;value=if type(item)=='string'then parse(item)else clip(c.number(item))end
  else local parts={};for i=1,7 do parts[i]=if args[i]~=nil then c.number(args[i])else if i==3 then 1 else 0 end
   if parts[1]>=0 and parts[1]<=99 then parts[1]=c.integer(parts[1])+1900 end;value=clip(toUTC(make(parts)))
  end
  local object=vm.Object({},c.constructPrototype(newTarget,proto));object.Kind='date';object.TimeValue=value;return object
 end
 local weekdays={'Sun','Mon','Tue','Wed','Thu','Fri','Sat'};local months={'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'}
 local function iso(value)
  if value~=value then c.fail('RangeError','Invalid time value')end
  local p=components(value,false);local year=if p[1]>=0 and p[1]<=9999 then string.format('%04d',p[1])else string.format('%s%06d',if p[1]<0 then '-'else '+',math.abs(p[1]))
  return year..string.format('-%02d-%02dT%02d:%02d:%02d.%03dZ',p[2]+1,p[3],p[4],p[5],p[6],p[7])
 end
 local function dateString(value)
  local p=components(value,true);return weekdays[p[8]+1]..' '..months[p[2]+1]..string.format(' %02d %04d',p[3],p[1])
 end
 local function timeString(value)
  local p=components(value,true);local minutes=-offset(value);local zone=if minutes<0 then '-'else '+';minutes=math.abs(minutes)
  return string.format('%02d:%02d:%02d GMT%s%02d%02d',p[4],p[5],p[6],zone,math.floor(minutes/60),minutes%60)..(if minutes==0 then ' (Coordinated Universal Time)'else '')
 end
 local function fullString(value)return if value~=value then 'Invalid Date'else dateString(value)..' '..timeString(value)end
 local constructor=c.native('Date',7,function()return fullString(now())end,construct,{prototype=proto})
 c.define(proto,'constructor',constructor)
 c.method(constructor,'now',0,now)
 c.method(constructor,'parse',1,function(args)return parse(c.arg(args,1,U))end)
 c.method(constructor,'UTC',7,function(args)
  if #args==0 then return 0/0 end;local parts={};for i=1,7 do parts[i]=if args[i]~=nil then c.number(args[i])else if i==3 then 1 else 0 end
  if parts[1]>=0 and parts[1]<=99 then parts[1]=c.integer(parts[1])+1900 end;return clip(make(parts))
 end)
 c.method(proto,'valueOf',0,function(_,value)return receiver(value).TimeValue end)
 c.method(proto,'getTime',0,function(_,value)return receiver(value).TimeValue end)
 c.method(proto,'setTime',1,function(args,value)value=receiver(value);value.TimeValue=clip(c.number(c.arg(args,1,U)));return value.TimeValue end)
 local fields={FullYear=1,Month=2,Date=3,Hours=4,Minutes=5,Seconds=6,Milliseconds=7,Day=8}
 for name,index in fields do for _,utc in {false,true}do c.method(proto,'get'..(if utc then 'UTC'else '')..name,0,function(_,value)
  local time=receiver(value).TimeValue;return if time~=time then time else components(time,not utc)[index]
 end)end end
 c.method(proto,'getTimezoneOffset',0,function(_,value)local time=receiver(value).TimeValue;return if time~=time then time else offset(time)end)
 c.method(proto,'getYear',0,function(_,value)local time=receiver(value).TimeValue;return if time~=time then time else components(time,true)[1]-1900 end)
 local setters={FullYear={1,3},Month={2,2},Date={3,1},Hours={4,4},Minutes={5,3},Seconds={6,2},Milliseconds={7,1}}
 for name,info in setters do for _,utc in {false,true}do c.method(proto,'set'..(if utc then 'UTC'else '')..name,info[2],function(args,value)
  value=receiver(value);local time=value.TimeValue
  if time~=time then if name=='FullYear'then time=0 else return 0/0 end end
  local p=components(time,not utc);for i=1,math.min(math.max(#args,1),info[2])do p[info[1]+i-1]=c.number(c.arg(args,i,U))end
  table.remove(p,8);local updated=make(p);value.TimeValue=clip(if utc then updated else toUTC(updated));return value.TimeValue
 end)end end
 c.method(proto,'setYear',1,function(args,value)
  value=receiver(value);local year=c.number(c.arg(args,1,U));if year~=year then value.TimeValue=year;return year end
  local time=if value.TimeValue~=value.TimeValue then 0 else value.TimeValue;local p=components(time,true);year=c.integer(year);p[1]=if year>=0 and year<=99 then year+1900 else year;table.remove(p,8);value.TimeValue=clip(toUTC(make(p)));return value.TimeValue
 end)
 c.method(proto,'toISOString',0,function(_,value)return iso(receiver(value).TimeValue)end)
 c.method(proto,'toJSON',1,function(_,value)
  value=c.requireObject(value);local primitive=if value.Kind=='date'then value.TimeValue elseif vm.ToPrimitive then vm.ToPrimitive(value,'number')else c.number(value)
  if type(primitive)=='number'and(primitive~=primitive or math.abs(primitive)==math.huge)then return N end
  return vm:Call(get(value,'toISOString'),{},value)
 end)
 c.method(proto,'toString',0,function(_,value)return fullString(receiver(value).TimeValue)end)
 c.method(proto,'toDateString',0,function(_,value)local time=receiver(value).TimeValue;return if time~=time then 'Invalid Date'else dateString(time)end)
 c.method(proto,'toTimeString',0,function(_,value)local time=receiver(value).TimeValue;return if time~=time then 'Invalid Date'else timeString(time)end)
 for _,entry in {{'toLocaleString','any','all'},{'toLocaleDateString','date','date'},{'toLocaleTimeString','time','time'}}do
  c.method(proto,entry[1],0,function(args,value)
   local time=receiver(value).TimeValue;if time~=time then return 'Invalid Date'end
   if not vm.Intl or not vm.Intl.FormatDateTime then c.fail('TypeError','Date locale formatting requires Intl initialization')end
   return vm.Intl.FormatDateTime(time,c.arg(args,1,U),c.arg(args,2,U),entry[2],entry[3])
  end)
 end
 local function utcString(_,value)
  local time=receiver(value).TimeValue;if time~=time then return 'Invalid Date'end;local p=components(time,false)
  return weekdays[p[8]+1]..string.format(', %02d ',p[3])..months[p[2]+1]..string.format(' %04d %02d:%02d:%02d GMT',p[1],p[4],p[5],p[6])
 end
 c.method(proto,'toUTCString',0,utcString);c.define(proto,'toGMTString',get(proto,'toUTCString'))
 c.global('Date',constructor)
end
-- Well-known Symbols are installed by Collections after the ordinary library.
function Dates.finalize(c: any)
 local vm,VM=c.vm,c.VM
 if not vm.SymbolToPrimitive then return end
 vm.DefineProperty(c.prototypes.Date,vm.SymbolToPrimitive,vm.Object({value=c.native('[Symbol.toPrimitive]',1,function(args,value)
  if not c.isObject(value)then c.fail('TypeError','Date primitive conversion requires an object')end
  local hint=c.arg(args,1,c.U);if hint~='default'and hint~='string'and hint~='number'then c.fail('TypeError','Invalid Date primitive hint')end
  for _,key in(if hint=='number'then {'valueOf','toString'}else {'toString','valueOf'})do
   local fn=c.get(value,key);if VM.callable(fn)then local result=vm:Call(fn,{},value);if not c.isObject(result)then return result end end
  end
  c.fail('TypeError','Cannot convert Date receiver to a primitive')
 end),configurable=true},VM.Null))
end
return Dates
