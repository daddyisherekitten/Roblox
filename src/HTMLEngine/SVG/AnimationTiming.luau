--!strict
local Timing={}
local clockUnits={['']=1,s=1,ms=.001,min=60,h=3600}
local easingCurves={ease={.25,.1,.25,1},['ease-in']={.42,0,1,1},['ease-out']={0,0,.58,1},['ease-in-out']={.42,0,.58,1}}
function Timing.clock(value: string?): number?
 if not value then return nil end
 value=value:match('^%s*(.-)%s*$')
 if value=='indefinite' then return math.huge end
 local sign,body=value:match('^([+-])(.*)$');body=body or value
 local h,m,s=body:match('^(%d+):(%d+):(%d+%.?%d*)$')
 local result
 if h then result=tonumber(h)*3600+tonumber(m)*60+tonumber(s)
 else
  m,s=body:match('^(%d+):(%d+%.?%d*)$')
  if m then result=tonumber(m)*60+tonumber(s)
  else local n,unit=body:match('^(%d*%.?%d+)(%a*)$');local factor=clockUnits[unit];if n and factor then result=tonumber(n)*factor end end
 end
 return result and result*(if sign=='-' then -1 else 1)
end
function Timing.list(value: string?,default: string?): any
 local result={};for v in (value or default or ''):gmatch('[^;]+') do table.insert(result,v:match('^%s*(.-)%s*$')) end;return result
end
function Timing.spline(x: number,a: number,b: number,c: number,d: number): number
 local function bez(t,p,q) local u=1-t;return 3*u*u*t*p+3*u*t*t*q+t*t*t end
 local low,high=0,1
 for _=1,24 do local mid=(low+high)/2;if bez(mid,a,c)<x then low=mid else high=mid end end
 return bez((low+high)/2,b,d)
end
function Timing.ease(value: string?,t: number): number
 value=value or 'linear'
 local q=easingCurves[value]
 if not q and value:match('^cubic%-bezier%(') then q={};for n in value:gmatch('[+-]?%d*%.?%d+') do table.insert(q,tonumber(n)) end end
 if q and #q==4 then return Timing.spline(t,q[1],q[2],q[3],q[4]) end
 if value=='step-start' then return 1 elseif value=='step-end' then return if t<1 then 0 else 1 end
 local n,pos=value:match('^steps%(%s*(%d+)%s*,?%s*([%a-]*)%s*%)$');n=tonumber(n)
 if n and n>0 then return math.clamp((math.floor(t*n)+(if pos=='start' or pos=='jump-start' then 1 else 0))/n,0,1) end
 return t
end
function Timing.phase(a: any,time: number,begin: number,endAt: number?): (number?,number?,boolean?)
 if time<begin then return nil end
 local dur=Timing.clock(a.dur) or math.huge
 if dur<=0 then return if a.fill=='freeze' then 1 else nil,0,false end
 local count=if a.repeatCount=='indefinite' then math.huge else tonumber(a.repeatCount) or 1
 if count<=0 then return nil end
 local span=math.min(dur*count,Timing.clock(a.repeatDur) or math.huge,(endAt or math.huge)-begin)
 local at=time-begin;local active=at<span
 if not active and a.fill~='freeze' then return nil end
 at=math.min(at,span)
 if dur==math.huge then return 0,0,active end
 local iteration=math.floor(at/dur);local p=at/dur-iteration
 if not active and p==0 and at>0 then p=1;iteration-=1 end
 return p,math.max(iteration,0),active
end
return Timing
