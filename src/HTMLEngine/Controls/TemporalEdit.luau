--!strict
local T=require(script.Parent.TemporalValue)
local Edit={Months={"Januar","Februar","März","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"}}
function Edit.fields(c: any): any
	local kind=c.Type;local fields={}
	if kind=="week" then fields={{Key="week",Placeholder="ww",Max=53,Digits=2,Prefix="Woche ",Suffix=", "},{Key="year",Placeholder="jjjj",Max=275760,Digits=4}}
	elseif kind=="month" then fields={{Key="month",Placeholder="Monat",Max=12,Digits=2,Suffix=" "},{Key="year",Placeholder="jjjj",Max=275760,Digits=4}}
	elseif kind~="time" then fields={{Key="day",Placeholder="tt",Max=31,Digits=2,Suffix="."},{Key="month",Placeholder="mm",Max=12,Digits=2,Suffix="."},{Key="year",Placeholder="jjjj",Max=275760,Digits=4,Suffix=if kind=="datetime-local" then ", " else ""}} end
	if kind=="time" or kind=="datetime-local" then
		table.insert(fields,{Key="hour",Placeholder="--",Max=23,Digits=2,Suffix=":"})
		local seconds=(c.Temporal.Step and c.Temporal.Step%60000~=0) or (T.number(kind,c.Value) or 0)%60000~=0
		table.insert(fields,{Key="minute",Placeholder="--",Max=59,Digits=2,Suffix=if seconds then ":" else ""})
		local fraction=(c.Temporal.Step and c.Temporal.Step%1000~=0) or (T.number(kind,c.Value) or 0)%1000~=0
		if seconds then table.insert(fields,{Key="second",Placeholder="--",Max=59,Digits=2,Suffix=if fraction then "." else ""}) end
		if fraction then table.insert(fields,{Key="millisecond",Placeholder="---",Max=999,Digits=3}) end
	end
	return fields
end
function Edit.parts(c: any): any
	if c.TemporalParts then return c.TemporalParts end
	local n=T.number(c.Type,c.Value);if not n then return {} end
	local y,m,d=T.civil(math.floor(n/T.Day));local p={year=y,month=m,day=d}
	if c.Type=="month" then p.year=1970+math.floor(n/12);p.month=n%12+1 end
	if c.Type=="week" then p.year,p.week=T.isoWeek(math.floor(n/T.Day)) end
	local t=n%T.Day;p.hour=math.floor(t/3600000);p.minute=math.floor(t/60000)%60;p.second=math.floor(t/1000)%60;p.millisecond=t%1000
	return p
end
local function compose(c: any,p: any): string
	for _,field in Edit.fields(c) do if p[field.Key]==nil then return "" end end
	if c.Type=="week" then return string.format("%04d-W%02d",p.year,p.week) end
	if c.Type=="month" then return string.format("%04d-%02d",p.year,p.month) end
	local date=if c.Type~="time" then string.format("%04d-%02d-%02d",p.year,p.month,p.day) else ""
	if c.Type=="date" then return date end
	local time=string.format("%02d:%02d",p.hour,p.minute)
	if (p.second and p.second~=0) or (p.millisecond and p.millisecond~=0) then time..=string.format(":%02d",p.second or 0) end
	if p.millisecond and p.millisecond~=0 then time..="."..string.format("%03d",p.millisecond):gsub("0+$","") end
	return if c.Type=="time" then time else date.."T"..time
end
function Edit.change(c: any,key: string,model: any): boolean
	if c.Disabled or c.ReadOnly then return false end
	local fields=Edit.fields(c);local index=math.clamp(c.TemporalSegment or 1,1,#fields);local field=fields[index]
	if key=="Left" or key=="Right" then c.TemporalSegment=math.clamp(index+(if key=="Left" then -1 else 1),1,#fields);c.TemporalDigits=nil;return true end
	if key=="Return" or key=="Space" then return false end
	local p=table.clone(Edit.parts(c));local n=p[field.Key]
	if key=="Backspace" or key=="Delete" then p[field.Key]=nil;c.TemporalDigits=nil
	elseif key=="Up" or key=="Down" then
		local lo=if field.Key=="year" or field.Key=="month" or field.Key=="day" or field.Key=="week" then 1 else 0
		local max=field.Max
		if field.Key=="day" and p.year and p.month then max=T.days(p.year,p.month) end
		if field.Key=="week" and p.year then max=(T.weekStart(p.year+1)-T.weekStart(p.year))/7 end
		p[field.Key]=((n or (if key=="Up" then lo-1 else max+1))+(if key=="Up" then 1 else -1)-lo)%(max-lo+1)+lo;c.TemporalDigits=nil
	elseif key:match("^%d$") then
		local digits=(c.TemporalDigits or "")..key;local nextValue=tonumber(digits) or 0
		if #digits>field.Digits or nextValue>field.Max then digits=key;nextValue=tonumber(key) or 0 end
		p[field.Key]=nextValue;c.TemporalDigits=digits
		if #digits>=field.Digits or nextValue>math.floor(field.Max/10) then c.TemporalSegment=math.min(#fields,index+1);c.TemporalDigits=nil end
	else return false end
	local raw=compose(c,p);local value=T.sanitize(c.Type,raw);local before=c.Value
	model:SetValue(c,value,true)
	c.TemporalParts=p;c.BadInput=value=="" and next(p)~=nil;c.UserEdited=true
	model:NotifyChanged(c,false)
	if before==value then model:Emit(c,"input",{Value=value}) end
	return true
end
return Edit
