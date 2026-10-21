--!strict
-- HTML civil dates are timezone independent. No os.time/local DST conversions.
local Numeric=require(script.Parent.NumericValue)
local T={Day=86400000,Week=604800000,WeekBase=-259200000}
function T.applies(kind: string): boolean return kind=="date" or kind=="datetime-local" or kind=="month" or kind=="week" or kind=="time" end
function T.days(y: number,m: number): number
	return if m==2 then (if y%4==0 and (y%100~=0 or y%400==0) then 29 else 28) else (if m==4 or m==6 or m==9 or m==11 then 30 else 31)
end
function T.dayNumber(y: number,m: number,d: number): number
	y-=if m<=2 then 1 else 0
	local era=math.floor(y/400);local yy=y-era*400;local mm=m+(if m>2 then -3 else 9)
	return era*146097+yy*365+math.floor(yy/4)-math.floor(yy/100)+math.floor((153*mm+2)/5)+d-1-719468
end
function T.civil(day: number): (number,number,number)
	local z=math.floor(day)+719468;local era=math.floor(z/146097);local doe=z-era*146097
	local yo=math.floor((doe-math.floor(doe/1460)+math.floor(doe/36524)-math.floor(doe/146096))/365)
	local y=yo+era*400;local doy=doe-(365*yo+math.floor(yo/4)-math.floor(yo/100));local mp=math.floor((5*doy+2)/153)
	local d=doy-math.floor((153*mp+2)/5)+1;local m=mp+(if mp<10 then 3 else -9)
	return y+(if m<=2 then 1 else 0),m,d
end
function T.weekStart(y: number): number local jan4=T.dayNumber(y,1,4);return jan4-(jan4+3)%7 end
function T.isoWeek(day: number): (number,number)
	local y=T.civil(day+3-(day+3)%7)
	return y,math.floor((day-T.weekStart(y))/7)+1
end
local function month(text: string): (number?,number?)
	local ys,ms=text:match("^(%d%d%d%d%d*)%-(%d%d)$");local y,m=tonumber(ys),tonumber(ms)
	if not y or not m or y<1 or y>275760 or m<1 or m>12 then return nil,nil end
	return y,m
end
local function date(text: string): number?
	local prefix,ds=text:match("^(.-)%-(%d%d)$");if not prefix then return nil end
	local y,m=month(prefix);local d=tonumber(ds)
	if not y or not m or not d or d<1 or d>T.days(y,m) then return nil end
	local n=T.dayNumber(y,m,d)*T.Day;return if n<=8640000000000000 then n else nil
end
local function time(text: string): number?
	local hs,ms,tail=text:match("^(%d%d):(%d%d)(.*)$");local h,m=tonumber(hs),tonumber(ms)
	if not h or not m or h>23 or m>59 then return nil end
	local s,frac=0,0
	if tail~="" then
		local ss=tail:match("^:(%d%d)$");local seconds,fraction=tail:match("^:(%d%d)%.(%d%d?%d?)$")
		if not ss and not seconds then return nil end
		s=tonumber(ss or seconds) or 0;if s>59 then return nil end
		if fraction then frac=(tonumber(fraction) or 0)*10^(3-#fraction) end
	end
	return ((h*60+m)*60+s)*1000+frac
end
function T.number(kind: string,text: string): number?
	if kind=="date" then return date(text)
	elseif kind=="month" then local y,m=month(text);return if y and m then (y-1970)*12+m-1 else nil
	elseif kind=="week" then
		local ys,ws=text:match("^(%d%d%d%d%d*)%-W(%d%d)$");local y,w=tonumber(ys),tonumber(ws)
		if not y or not w or y<1 or y>275760 or w<1 or w>(T.weekStart(y+1)-T.weekStart(y))/7 then return nil end
		local n=(T.weekStart(y)+(w-1)*7)*T.Day;return if math.abs(n)<=8640000000000000 then n else nil
	elseif kind=="time" then return time(text)
	elseif kind=="datetime-local" then
		local ds,ts=text:match("^(.-)[T ](.*)$");if not ds then return nil end
		local d,t=date(ds),time(ts);return if d and t and d+t<=8640000000000000 then d+t else nil
	end
	return nil
end
function T.format(kind: string,n: number): string
	if n~=n or math.abs(n)>8640000000000000 then return "" end
	if kind=="month" then local total=math.floor(n)+1970*12;local y=math.floor(total/12);return if y>0 then string.format("%04d-%02d",y,total%12+1) else "" end
	if kind=="week" then local y,w=T.isoWeek(math.floor(n/T.Day));return if y>0 then string.format("%04d-W%02d",y,w) else "" end
	local timeOnly=kind=="time"
	local y,m,d=T.civil(math.floor(n/T.Day));if not timeOnly and y<1 then return "" end
	local ds=string.format("%04d-%02d-%02d",y,m,d)
	if kind=="date" then return ds end
	if timeOnly and (n<0 or n>=T.Day) then return "" end
	local t=math.floor(n%T.Day);local h=math.floor(t/3600000);local minute=math.floor(t/60000)%60;local sec=math.floor(t/1000)%60;local ms=t%1000
	local ts=string.format("%02d:%02d",h,minute)
	if sec~=0 or ms~=0 then ts..=string.format(":%02d",sec) end
	if ms~=0 then ts..="."..string.format("%03d",ms):gsub("0+$","") end
	return if timeOnly then ts else ds.."T"..ts
end
function T.sanitize(kind: string,text: string): string
	local n=T.number(kind,text);return if not n then "" elseif kind=="datetime-local" then T.format(kind,n) else text
end
function T.read(kind: string,a: any): any
	local scale=if kind=="month" then 1 elseif kind=="week" then T.Week elseif kind=="date" then T.Day else 1000
	local step=Numeric.parse(a.step);local min,max=T.number(kind,a.min or ""),T.number(kind,a.max or "")
	return {Min=min,Max=max,Base=min or T.number(kind,a.value or "") or (if kind=="week" then T.WeekBase else 0),
		Step=if (a.step or ""):lower()=="any" then nil else (if step and step>0 then step else (if scale==1000 then 60 else 1))*scale}
end
function T.flags(c: any): (boolean,boolean,boolean)
	local n=T.number(c.Type,c.Value);if not n then return false,false,false end
	local r=c.Temporal;local under=r.Min~=nil and n<r.Min;local over=r.Max~=nil and n>r.Max
	if c.Type=="time" and r.Min and r.Max and r.Min>r.Max then under=n<r.Min and n>r.Max;over=under end
	local index=if r.Step then (n-r.Base)/r.Step else 0
	return under,over,math.abs(index-math.round(index))>1e-7
end
function T.step(c: any,count: number): string?
	local r=c.Temporal;local step=r.Step;if not step or (r.Min and r.Max and r.Min>r.Max) then return nil end
	local before=T.number(c.Type,c.Value) or 0;local index=(before-r.Base)/step;local nearest=math.round(index)
	local nextIndex=if math.abs(index-nearest)<1e-7 then nearest+count elseif count<0 then math.floor(index) else math.ceil(index)
	local lo=r.Min or (if c.Type=="time" then 0 elseif c.Type=="month" then -23628 else -62135596800000)
	local hi=r.Max or (if c.Type=="time" then T.Day-1 else 8640000000000000)
	local first,last=math.ceil((lo-r.Base)/step-1e-7),math.floor((hi-r.Base)/step+1e-7);if first>last then return nil end
	local n=r.Base+math.clamp(nextIndex,first,last)*step
	if (count>0 and n<before) or (count<0 and n>before) then return nil end
	local text=T.format(c.Type,n);return if text~="" then text else nil
end
return T
