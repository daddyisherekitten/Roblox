--!strict
local Timing=require(script.Parent.AnimationTiming)
local Value=require(script.Parent.AnimationValue)
local Style=require(script.Parent.Style)
local Geometry=require(script.Parent.Geometry)
local Curves=require(script.Parent.Curves)
local PathMetrics=require(script.Parent.PathMetrics)
local AnimationCSS=require(script.Parent.AnimationCSS)
local Animation={}
local supported={animate=true,animateColor=true,set=true,animateTransform=true,animateMotion=true}
local function href(n) return n.Attributes.href or (n.ExpandedAttributes and n.ExpandedAttributes['http://www.w3.org/1999/xlink\0href']) end
function Animation.new(document: any): any
 local self={Items={},Diagnostics={},Events={},Time=0,Version=0,Document=document}
 local seen={}
 local function report(code,value) local key=code..':'..tostring(value);if not seen[key] then seen[key]=true;table.insert(self.Diagnostics,{Code=code,Value=value}) end end
 self.Report=report
 local function walk(n)
  if supported[n.Name] then
   local ref=href(n);local target=if ref then document.Ids[ref:match('^#(.+)$')] else n.Parent
   if target and target.Kind=='Element' then table.insert(self.Items,{Node=n,Target=target,Order=#self.Items+1,Starts={},Ends={}})
   else report('animation-target-unavailable',ref) end
   if n.Attributes.min or n.Attributes.max then report('animation-min-max-unimplemented',n.Attributes.id) end
  end
  for _,c in n.Children or {} do walk(c) end
 end
 walk(document.Root);assert(#self.Items<=256,'SVG animation budget exceeded')
 self.Rules=Style.collect(document,report);self.CSS=AnimationCSS.new(document,report)
 function self:InvalidateEvents() self.EventKinds=nil;self.Version+=1 end
 function self:HasEvent(kind)
  if not self.EventKinds then
   local kinds={}
   for _,item in self.Items do for _,attribute in {'begin','end'} do
    for _,entry in Timing.list(item.Node.Attributes[attribute]) do
     if Timing.clock(entry)~=nil or entry=='indefinite' then continue end
     local _,event,offset=entry:match('^([%w_-]+)%.([%w_]+)(.*)$')
     if not event then event,offset=entry:match('^([%w_]+)(.*)$') end
     local delta=if offset=='' then 0 else Timing.clock(offset)
     if event and delta and event~='begin' and event~='end' then kinds[event]=true end
    end
   end end
   self.EventKinds=kinds
  end
  return self.EventKinds[kind]==true
 end
 function self:Event(target,kind,time)
  -- Unrelated pointer traffic must not evict event-based animation start/end
  -- times or grow the history scanned by every timing sample.
  if not self:HasEvent(kind) then return end
  table.insert(self.Events,{Target=target,Kind=kind,Time=time or self.Time});self.Version+=1;if #self.Events>256 then table.remove(self.Events,1) end
 end
 function self:BeginElement(node,time)
  for _,item in self.Items do if item.Node==node then table.insert(item.Starts,time or self.Time);self.Version+=1;if #item.Starts>256 then table.remove(item.Starts,1) end;return end end
 end
 function self:EndElement(node,time)
  for _,item in self.Items do if item.Node==node then table.insert(item.Ends,time or self.Time);self.Version+=1;if #item.Ends>256 then table.remove(item.Ends,1) end;return end end
 end
 local instances
 instances=function(item,attribute,parents)
  parents=parents or {};if parents[item] then report('animation-syncbase-cycle',item.Node.Attributes.id);return {} end
  parents=table.clone(parents);parents[item]=true
  local result=table.clone(if attribute=='begin' then item.Starts else item.Ends)
  for _,entry in Timing.list(item.Node.Attributes[attribute],if attribute=='begin' then '0s' else '') do
   local clock=Timing.clock(entry)
   if clock and clock~=math.huge then table.insert(result,clock)
   elseif entry~='indefinite' then
    local name,event,offset=entry:match('^([%w_-]+)%.([%w_]+)(.*)$')
    if not event then event,offset=entry:match('^([%w_]+)(.*)$') end
    local target=if name then document.Ids[name] else item.Target
    local delta=if offset=='' then 0 else Timing.clock(offset)
    if event and delta then
     if event=='begin' or event=='end' then
      local found=false
      for _,other in self.Items do if other.Node==target then
       found=true;local starts=instances(other,'begin',parents)
       local duration=Timing.clock(other.Node.Attributes.dur)
       local repeats=if other.Node.Attributes.repeatCount=='indefinite' then math.huge else tonumber(other.Node.Attributes.repeatCount) or 1
       local span=duration and math.min(duration*repeats,Timing.clock(other.Node.Attributes.repeatDur) or math.huge)
       for i,begin in starts do
        if event=='begin' then table.insert(result,begin+delta)
        elseif span and span<math.huge and (not starts[i+1] or starts[i+1]>=begin+span) then table.insert(result,begin+span+delta) end
       end
      end end
      if not found then report('animation-syncbase-unavailable',entry) end
     else for _,e in self.Events do if e.Target==target and e.Kind==event then table.insert(result,e.Time+delta) end end end
    else report('animation-begin-unimplemented',entry) end
   end
  end
  table.sort(result);return result
 end
 local function interval(item,time)
  local a=item.Node.Attributes;local chosen=nil
  for _,start in instances(item,'begin') do
   if start>time then break end
   if chosen and a.restart=='never' then break end
   if chosen and a.restart=='whenNotActive' then local _,_,active=Timing.phase(a,start,chosen);if active then continue end end
   chosen=start
  end
  if not chosen then return nil end
  local stop=nil;for _,finish in instances(item,'end') do if finish>=chosen then stop=finish;break end end
  return chosen,stop
 end
 local function interpolate(a,key,values,p,context)
  if #values==1 then return values[1] end
  local mode=a.calcMode or 'linear';local times={}
  if mode=='paced' then
   times[1]=0;local total=0
   for i=2,#values do total+=Value.distance(key,values[i-1],values[i],context);times[i]=total end
   if total>0 then for i=2,#values do times[i]/=total end else for i=1,#values do times[i]=(i-1)/(#values-1) end end
  elseif a.keyTimes then
   for _,v in Timing.list(a.keyTimes) do local number=tonumber(v);if not number then report('invalid-animation-key-times',a.keyTimes);return nil end;table.insert(times,number) end
   if #times~=#values or times[1]~=0 then report('invalid-animation-key-times',a.keyTimes);return nil end
   for i=2,#times do if times[i]<times[i-1] or times[i]>1 then report('invalid-animation-key-times',a.keyTimes);return nil end end
   if mode~='discrete' and times[#times]~=1 then report('invalid-animation-key-times',a.keyTimes);return nil end
  else for i=1,#values do times[i]=(i-1)/(if mode=='discrete' then #values else #values-1) end end
  local i=1;while i<#values and p>=times[i+1] do i+=1 end
  if i==#values or mode=='discrete' then return values[i] end
  local f=if times[i+1]==times[i] then 1 else (p-times[i])/(times[i+1]-times[i])
  if mode=='spline' then
   local splines=Timing.list(a.keySplines);local q={};for n in (splines[i] or ''):gmatch('[+-]?%d*%.?%d+') do table.insert(q,tonumber(n)) end
   if #q~=4 or q[1]<0 or q[1]>1 or q[3]<0 or q[3]>1 then report('invalid-animation-key-splines',a.keySplines);return nil end
   f=Timing.spline(f,q[1],q[2],q[3],q[4])
  elseif mode~='linear' and mode~='paced' then report('unsupported-animation-calc-mode',mode);return nil end
  return Value.mix(key,values[i],values[i+1],f,context)
 end
 local function motion(item,p,context)
  local a=item.Node.Attributes;local d=a.path
  for _,child in item.Node.Children do if child.Name=='mpath' then local ref=href(child);local target=ref and document.Ids[ref:match('^#(.+)$')];d=target and target.Attributes.d;break end end
  if not d then report('animation-motion-path-unavailable',a.id);return nil end
  if item.PathSource~=d then
   local geometry=Geometry.build('path',{d=d},context);if not geometry then return nil end
   item.Path=Curves.flatten(geometry.Subpaths,64);item.PathSource=d;item.PathLength=PathMetrics.measure(item.Path)
  end
  local fraction=p
  if a.keyPoints and (a.calcMode or 'paced')~='paced' then fraction=tonumber(interpolate(a,'number',Timing.list(a.keyPoints),p,context));if not fraction then return nil end end
  local at=math.clamp(fraction,0,1)*item.PathLength;local last
  for _,part in item.Path do for i=1,#part.Points-(if part.Closed then 0 else 1) do
   local x,y=part.Points[i],part.Points[i%#part.Points+1];local length=PathMetrics.distance(x,y)
   if length>0 then
    local f=math.min(at/length,1);local angle=math.deg(math.atan2(y[2]-x[2],y[1]-x[1]))
    if a.rotate=='auto-reverse' then angle+=180 elseif a.rotate~='auto' then angle=tonumber(a.rotate) or 0 end
    last=`translate({x[1]+(y[1]-x[1])*f} {x[2]+(y[2]-x[2])*f}) rotate({angle})`
    if at<=length then return last end;at-=length
   end
  end end
  return last
 end
 function self:Sample(time,states)
  assert(time>=0 and time<math.huge,'Finite nonnegative animation time required');self.Time=time
  local context={Width=480,Height=320,FontSize=16,RootFontSize=16};local output,computed={},{}
  local function style(n)
   if not n or n.Kind~='Element' then return nil end
   if not computed[n] then computed[n]=Style.compute(n,style(n.Parent),context,self.Rules,report,states) end
   return computed[n]
  end
  local active={}
  for _,item in self.Items do local begin,finish=interval(item,time);if begin then table.insert(active,{Item=item,Begin=begin,Finish=finish}) end end
  table.sort(active,function(a,b) return if a.Begin==b.Begin then a.Item.Order<b.Item.Order else a.Begin<b.Begin end)
  for _,entry in active do
   local item=entry.Item;local n,a=item.Node,item.Node.Attributes;local p,iteration=Timing.phase(a,time,entry.Begin,entry.Finish)
   if p==nil then continue end
   local target=item.Target;local values=output[target] or {};local base=style(target)
   local key=if n.Name=='animateMotion' then 'transform' else a.attributeName
   if not key then report('animation-attribute-missing',a.id);continue end
   local underlying=values[key] or base.Values[key] or target.Attributes[key] or '0'
   local result
   if n.Name=='animateMotion' then
    result=motion(item,p,context)
    if result then result=(if underlying=='none' then '' else underlying..' ')..result end
    if a.accumulate=='sum' then report('animation-motion-accumulate-unimplemented',a.id) end
   elseif n.Name=='set' then result=a.to
   else
    local sequence=Timing.list(a.values)
    if #sequence==0 then
     local first=a.from or (if a.by and not a.to then '0' else underlying)
     if n.Name=='animateTransform' and not a.from then first=if a.type=='scale' then '1' else '0' end
     local last=a.to or (a.by and Value.add(key,first,a.by,1,context))
     if last then sequence={first,last} end
    end
    if #sequence==0 then report('animation-values-unavailable',a.id);continue end
    result=interpolate(a,key,sequence,p,context)
    if result and a.accumulate=='sum' and iteration>0 then result=Value.add(key,result,sequence[#sequence],iteration,context) or result end
    if n.Name=='animateTransform' and result then
     if not ({translate=true,scale=true,rotate=true,skewX=true,skewY=true})[a.type] then report('animation-transform-type-unavailable',a.type);continue end
     result=a.type..'('..result..')'
     if a.additive=='sum' then result=(if underlying=='none' then '' else underlying..' ')..result end
    elseif result and (a.additive=='sum' or (a.by and not a.from and not a.to)) then result=Value.add(key,underlying,result,1,context) or result end
   end
   if result then values[key]=result;output[target]=values end
  end
  return self.CSS:Sample(time,output,style,self.TransitionTime),style
 end
 return self
end
return Animation
