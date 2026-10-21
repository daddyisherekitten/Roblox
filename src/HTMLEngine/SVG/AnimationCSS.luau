--!strict
local Timing=require(script.Parent.AnimationTiming)
local Value=require(script.Parent.AnimationValue)
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local AuthorRules=require(script.Parent.Parent.CSS.AuthorRules)
local CSS={}
function CSS.new(document: any,report: any): any
 local frames,nodes={},{}
 AuthorRules.collect(document,report,nil,function(name,body)
  local result={};local at=1
  while at<=#body do
   local header,nextIndex=Syntax.scan(body,at,'{');local text,after=Syntax.scan(body,nextIndex,'}');at=after
   local declarations=AuthorRules.declarations(text)
   for point in header:gmatch('[^,]+') do
    point=point:match('^%s*(.-)%s*$');local t=if point=='from' then 0 elseif point=='to' then 1 else (tonumber(point:match('^(.-)%%$')) or -100)/100
    if t>=0 and t<=1 then for _,d in declarations do if not d.Important then result[d.Name]=result[d.Name] or {};result[d.Name][t]=d.Value end end end
   end
  end
  -- Keyframe offsets are static; sorting/cloning them for every animated
  -- property on every frame is unnecessary. Missing endpoints still resolve
  -- against the current underlying style when sampled.
  local compiled={}
  for key,points in result do
   local authored={};for t in points do table.insert(authored,t) end;table.sort(authored)
   local complete=table.clone(authored)
   if points[0]==nil then table.insert(complete,1,0) end
   if points[1]==nil then table.insert(complete,1) end
   compiled[key]={Values=points,Authored=authored,Complete=complete}
  end
  frames[name]=compiled
 end)
 local function visit(n) if n.Kind=='Element' then table.insert(nodes,n) end;for _,c in n.Children or {} do visit(c) end end;visit(document.Root)
 local self={Animations={},Transitions={},Time=0}
 local function current(t,time,key,context)
  local p=math.clamp((time-t.Start-t.Delay)/math.max(t.Duration,1e-9),0,1)
  return Value.mix(key,t.From,t.Target,Timing.ease(t.Ease,p),context)
 end
 function self:Sample(time,output,style,transitionTime)
  transitionTime=transitionTime or time
  if time<self.Time then self.Animations={};self.Transitions={} end;self.Time=time
  local context={Width=480,Height=320,FontSize=16,RootFontSize=16}
  for _,node in nodes do
   if ({style=true,defs=true,animate=true,animateColor=true,animateTransform=true,animateMotion=true,set=true,mpath=true})[node.Name] then continue end
   local computed=style(node);local v=computed.Values;local name=v['animation-name']
   if name~='none' then
    if name:find(',',1,true) then report('css-animation-multiple-unimplemented',name)
    elseif frames[name] then
     local record=self.Animations[node]
     if not record or record.Name~=name then record={Name=name,Start=if record then time else 0,Paused=0};self.Animations[node]=record end
     if v['animation-play-state']=='paused' then record.PauseAt=record.PauseAt or time
     elseif record.PauseAt then record.Paused+=time-record.PauseAt;record.PauseAt=nil end
     local delay=Timing.clock(v['animation-delay']) or 0
     local a={dur=v['animation-duration'],repeatCount=if v['animation-iteration-count']=='infinite' then 'indefinite' else v['animation-iteration-count'],fill=if v['animation-fill-mode']=='forwards' or v['animation-fill-mode']=='both' then 'freeze' else 'remove'}
     local localTime=(record.PauseAt or time)-record.Paused
     local p,iteration=Timing.phase(a,localTime,record.Start+delay)
     if p==nil and localTime<record.Start+delay and (v['animation-fill-mode']=='backwards' or v['animation-fill-mode']=='both') then p=0;iteration=0 end
     if p~=nil then
      local dir=v['animation-direction'];if dir=='reverse' or (dir=='alternate' and iteration%2==1) or (dir=='alternate-reverse' and iteration%2==0) then p=1-p end
      output[node]=output[node] or {}
      for key,points in frames[name] do
       local underlying=v[key] or node.Attributes[key]
       local times=if underlying then points.Complete else points.Authored
       local i=1;while i<#times and p>=times[i+1] do i+=1 end
       local left,right=times[i],times[math.min(i+1,#times)]
       local from=points.Values[left] or underlying;local to=points.Values[right] or underlying
       if from and to then
        output[node][key]=Value.mix(key,from,to,Timing.ease(v['animation-timing-function'],if left==right then 0 else (p-left)/(right-left)),context)
        if key=='transform' then output[node]._transformCSS='true' end
       end
      end
     end
    else report('css-animation-keyframes-unavailable',name) end
   elseif self.Animations[node] then self.Animations[node]=nil end
   local duration=Timing.clock(v['transition-duration']) or 0
   if duration>0 then
    local transitions=self.Transitions[node] or {};self.Transitions[node]=transitions
    local properties={}
    if v['transition-property']=='all' then properties={'fill','stroke','opacity','transform','x','y','cx','cy','r','width','height'}
    else for property in v['transition-property']:gmatch('[^,]+') do table.insert(properties,property:match('^%s*(.-)%s*$')) end end
    for _,key in properties do
     local target=v[key];if not target then continue end
     local old=transitions[key]
     if not old then old={Target=target,From=target,Start=transitionTime,Duration=0,Delay=0,Ease='linear'};transitions[key]=old end
     if target~=old.Target then
      old={Target=target,From=current(old,transitionTime,key,context),Start=transitionTime,Duration=duration,Delay=Timing.clock(v['transition-delay']) or 0,Ease=v['transition-timing-function']};transitions[key]=old
     end
     if transitionTime<old.Start+old.Delay+old.Duration then
      output[node]=output[node] or {};output[node][key]=current(old,transitionTime,key,context)
      if key=='transform' then output[node]._transformCSS='true' end
     end
    end
   end
  end
  return output
 end
 return self
end
return CSS
