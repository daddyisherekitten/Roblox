--!strict
local Data=require(script.Parent.IntlTimeZoneData)
local Zones={Version=Data.Version,Start=Data.Start,End=Data.End}
local names={};for name in Data.Zones do names[name:lower()]=name end
local utcAliases={utc=true,gmt=true,['etc/utc']=true,['etc/gmt']=true,['etc/uct']=true,['etc/universal']=true,['etc/zulu']=true,uct=true,universal=true,zulu=true,greenwich=true}
function Zones.canonical(source: string): string?
 local lower=source:lower();if utcAliases[lower]then return 'UTC'end
 local sign,hour,minute=source:match('^([+-])(%d%d):?(%d%d)$');if not sign then sign,hour=source:match('^([+-])(%d%d)$');minute='00'end
 if sign then if tonumber(hour)>23 or tonumber(minute)>59 then return nil end;return sign..hour..':'..minute end
 return names[lower]
end
function Zones.offset(zone: string,time: number): number?
 if zone=='UTC'then return 0 end
 if zone:sub(1,1)=='+'or zone:sub(1,1)=='-'then local sign,h,m=zone:match('^([+-])(%d%d):(%d%d)$');return(if sign=='+'then 1 else -1)*(tonumber(h)*3600+tonumber(m)*60)end
 local record=Data.Zones[zone];if not record or time<Data.Start or time>=Data.End then return nil end
 local low,high=1,#record.Transitions;local result=record.Initial
 while low<=high do local mid=math.floor((low+high)/2);local change=record.Transitions[mid];if change[1]<=time then result=change[2];low=mid+1 else high=mid-1 end end
 return result
end
function Zones.toUTC(zone: string,localTime: number): number?
 if zone=='UTC'or zone:sub(1,1)=='+'or zone:sub(1,1)=='-'then return localTime-(Zones.offset(zone,localTime)or 0)*1000 end
 local record=Data.Zones[zone];if not record then return nil end
 local offsets={};local found={};local result
 for _,near in {localTime-86400000,localTime,localTime+86400000}do local offset=Zones.offset(zone,near);if offset and not found[offset]then offsets[#offsets+1]=offset;found[offset]=true end end
 -- Repeated wall time chooses its first instant. A missing wall time advances
 -- by the gap using the offset from before the transition (ECMA compatible).
 for _,offset in offsets do local candidate=localTime-offset*1000;if Zones.offset(zone,candidate)==offset and(not result or candidate<result)then result=candidate end end
 if result then return result end
 local previous=Zones.offset(zone,localTime-86400000);return if previous then localTime-previous*1000 else nil
end
function Zones.name(zone: string,time: number,locale: string,style: string): string?
 local offset=Zones.offset(zone,time);if not offset then return nil end
 local long=style=='longOffset'or style=='long'or style=='longGeneric';local prefix='GMT'
 local function offsetName()
  local abs=math.abs(offset);local h=math.floor(abs/3600);local m=math.floor(abs%3600/60);local s=abs%60
  return prefix..(if offset<0 then '-'else '+')..(if long then string.format('%02d',h)else tostring(h))..(if long or m>0 or s>0 then string.format(':%02d',m)else '')..(if s>0 then string.format(':%02d',s)else '')
 end
 if style=='shortOffset'or style=='longOffset'or zone:sub(1,1)=='+'or zone:sub(1,1)=='-'then return offsetName()end
 if zone=='UTC'then return if style=='long'then(if locale=='de-DE'then 'Koordinierte Weltzeit'else 'Coordinated Universal Time')elseif style=='longGeneric'or style=='shortGeneric'then offsetName()else 'UTC'end
 local record=Data.Zones[zone];local values=record.Names[locale]and record.Names[locale][style]
 if not values then return offsetName()end
 -- Standard/generic CLDR names are captured for the two 2026 seasons. Historic
 -- non-seasonal offsets use truthful GMT offsets instead of a modern DST name.
 local summer=Zones.offset(zone,1784073600000)
 if offset~=record.WinterOffset and offset~=summer then return offsetName()end
 return values[if offset==record.WinterOffset then 1 else 2]
end
return Zones
