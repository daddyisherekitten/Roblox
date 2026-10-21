--!strict
--!optimize 2
local Values=require(script.Parent.Parent.CSS.GridValues)
local LengthExpression=require(script.Parent.Parent.CSS.LengthExpression)
local Tracks={}
local BoxAlignment=require(script.Parent.BoxAlignment)
local AUTO={Kind='auto'}
function Tracks.length(v: any,size: number?,style: any,viewport: any?): number?
 if not v then return nil end
 if v.Kind=='expression' then
  local w,h=if viewport then viewport[1] else size or 0,if viewport then viewport[2] else 0
  local parsed=LengthExpression.parse(v.Source,{FontSize=style.FontSize or 16,RootFontSize=style.RootFontSize or 16,ViewportWidth=w,ViewportHeight=h})
  if not parsed or (parsed.Percent and size==nil) then return nil end
  return LengthExpression.resolve(parsed,size or 0)
 end
 if v.Kind~='length' then return nil end
 local n,u=v.Value,v.Unit
 if u=='%' then return if size then size*n/100 else nil end
 if u=='em' then return n*(style.FontSize or 16) elseif u=='rem' then return n*(style.RootFontSize or 16)
 elseif u=='ch' then return n*(style.FontSize or 16)*.5 end
 if u=='vw' or u=='vh' or u=='vmin' or u=='vmax' then
  local w,h=if viewport then viewport[1] else size or 0,if viewport then viewport[2] else 0
  return n/100*(if u=='vw' then w elseif u=='vh' then h elseif u=='vmin' then math.min(w,h) else math.max(w,h))
 end
 return n
end
function Tracks.expand(spec: any,size: number?,gap: number,style: any,areas: any,vertical: boolean?,inherited: any?,viewport: any?): any
 local axis={Definitions={},Names={},AutoFit={},Explicit=0,Gap=gap,Style=style,Size=size,Viewport=viewport}
 local function names(list,line)
  for _,name in list do axis.Names[name]=axis.Names[name] or {};if not table.find(axis.Names[name],line) then table.insert(axis.Names[name],line) end end
 end
 if spec and spec.Subgrid and inherited then
  axis.Subgrid=true
  local specified=if vertical then style.RowGapSpecified else style.GridGapSpecified
  axis.Gap=if gap==0 and not specified then inherited.Gap else gap
  local count=inherited.Count or #inherited.Sizes
  local difference=(axis.Gap-inherited.Gap)/2
  for i=1,count do
   -- Probes retain placement and line names, but never the stretched track
   -- sizes from a previous pass. Final tracks share the parent's gutter
   -- centres, with the subgrid's outer edges removed from its content box.
   local value=inherited.Sizes and inherited.Sizes[i]
   local before=if i==1 then inherited.Before or 0 else difference
   local after=if i==count then inherited.After or 0 else difference
   table.insert(axis.Definitions,if value then {Kind='length',Unit='px',Value=math.max(0,value-before-after)}else AUTO)
  end
  for name,lines in inherited.Names or {} do axis.Names[name]=table.clone(lines) end
  local at=1;for _,v in spec.Items do if v.Kind=='names' then names(v.Names,at);at+=1 end end
 else
  local function fixed(v)
   if v.Kind=='minmax' then return Tracks.length(v.Max,size,style,viewport) or Tracks.length(v.Min,size,style,viewport) or 0 end
   return Tracks.length(v,size,style,viewport) or 0
  end
  local outside,counts=0,0
  for _,v in (spec and spec.Items) or {} do
   if v.Kind=='repeat' and v.Count then for _,t in v.Items do if t.Kind~='names' then outside+=fixed(t)*v.Count;counts+=v.Count end end
   elseif v.Kind~='names' and v.Kind~='repeat' then outside+=fixed(v);counts+=1 end
  end
  local function append(items,repeating)
   for _,v in items do
    if v.Kind=='names' then names(v.Names,#axis.Definitions+1)
    elseif v.Kind=='repeat' then
     local n=v.Count
     if not n then
      local unit,k=0,0;for _,t in v.Items do if t.Kind~='names' then unit+=math.max(1,fixed(t));k+=1 end end
      n=if size then math.max(1,math.floor((size-outside-gap*math.max(0,counts-1))/(unit+gap*k))) else 1
      n=math.min(n,math.floor((Values.Limit-counts)/math.max(1,k)))
     end
     for _=1,n do append(v.Items,v.Mode=='auto-fit') end
    else
     assert(#axis.Definitions<Values.Limit,'CSS Grid track limit exceeded')
     table.insert(axis.Definitions,v);if repeating then axis.AutoFit[#axis.Definitions]=true end
    end
   end
  end
  append((spec and spec.Items) or {})
 end
 local areaCount=if areas then (if vertical then areas.Rows else areas.Columns) else 0
 while #axis.Definitions<areaCount do table.insert(axis.Definitions,AUTO) end
 axis.Explicit=#axis.Definitions
 for name,a in (areas and areas.Names) or {} do
  names({name..'-start'},if vertical then a.R1 else a.C1);names({name..'-end'},if vertical then a.R2 else a.C2)
 end
 return axis
end
function Tracks.initialize(axis,implicit,items,vertical)
 local cycle=(implicit and implicit.Items) or {AUTO};local tracks={}
 for i=axis.First,axis.Last do
  local def=axis.Definitions[i]
  if not def then local at=if i<1 then (i-1)%#cycle+1 else (i-axis.Explicit-1)%#cycle+1;def=cycle[at] end
  local min,max=def,def
  if def.Kind=='minmax' then min,max=def.Min,def.Max elseif def.Kind=='fr' or def.Kind=='fit-content' then min=AUTO end
  local lo=Tracks.length(min,axis.Size,axis.Style,axis.Viewport)
  local hi=Tracks.length(max,axis.Size,axis.Style,axis.Viewport)
  local cap=if def.Kind=='fit-content' then Tracks.length(def.Max,axis.Size,axis.Style,axis.Viewport) else nil
  local collapsed=false
  if axis.AutoFit[i] then
   collapsed=true
   for _,v in items do local a,n=if vertical then v.Row else v.Column,if vertical then v.Rows else v.Columns;if i>=a and i<a+n then collapsed=false;break end end
  end
  local t={Base=lo or 0,Limit=hi or math.huge,Desired=hi or 0,MinKind=if lo then 'fixed' else min.Kind,MaxKind=if hi then 'fixed' else max.Kind,Flex=if max.Kind=='fr' then max.Value else 0,Cap=cap,Collapsed=collapsed}
  if collapsed then t.Base=0;t.Limit=0;t.Desired=0;t.MinKind='fixed';t.MaxKind='fixed';t.Flex=0 end
  t.Limit=math.max(t.Base,t.Limit);tracks[i]=t
 end
 axis.Tracks=tracks
end
function Tracks.gap(axis,i)
 if i>=axis.Last then return 0 end
 return if axis.Tracks[i].Collapsed or axis.Tracks[i+1].Collapsed then 0 else axis.Gap
end
local function grow(axis,start,count,needed,field,predicate,capped)
 local used=0;local candidates={}
 for i=start,start+count-1 do local t=axis.Tracks[i];if not t then continue end;used+=t[field];if i<start+count-1 then used+=Tracks.gap(axis,i) end;if predicate(t) then table.insert(candidates,t) end end
 local remaining=needed-used
 for _=1,#candidates+1 do
  if remaining<=1e-7 or #candidates==0 then break end
  local share=remaining/#candidates;local nextList={}
  for _,t in candidates do
   local cap=if capped then math.max(t.Base,math.min(t.Limit,t.Cap or math.huge)) else t.Limit
   local add=math.max(0,math.min(share,cap-t[field]));t[field]+=add;remaining-=add
   if t[field]<cap-1e-7 then table.insert(nextList,t) end
  end
  candidates=nextList
 end
end
function Tracks.contribute(axis,start,count,minimum,maximum)
 -- Intrinsic minimums are collected before distributing leftover space to fr tracks.
 grow(axis,start,count,minimum,'Base',function(t) return t.MinKind~='fixed' and t.MinKind~='max-content' end,false)
 grow(axis,start,count,maximum,'Base',function(t) return t.MinKind=='max-content' end,false)
 for i=start,start+count-1 do local t=axis.Tracks[i];t.Limit=math.max(t.Base,t.Limit);t.Desired=math.max(t.Desired,t.Base) end
 grow(axis,start,count,maximum,'Desired',function(t) return t.MaxKind=='auto' or t.MaxKind=='max-content' or t.MaxKind=='fit-content' end,true)
 grow(axis,start,count,minimum,'Desired',function(t) return t.MaxKind=='min-content' end,true)
end
function Tracks.finish(axis,mode)
 local safety;mode,safety=BoxAlignment.split(mode)
 local used,gaps,flex=0,0,0
 for i=axis.First,axis.Last do local t=axis.Tracks[i];t.Size=t.Base;used+=t.Size;gaps+=Tracks.gap(axis,i);flex+=t.Flex end
 local space=axis.Size and math.max(0,axis.Size-gaps-used) or math.huge
 local candidates={}
 for i=axis.First,axis.Last do local t=axis.Tracks[i];if t.Flex==0 and t.Desired>t.Size then table.insert(candidates,t) end end
 for _=1,#candidates+1 do
  if #candidates==0 or space<=1e-7 then break end
  local share=space/#candidates;local rest={}
  for _,t in candidates do local add=math.min(t.Desired-t.Size,share);t.Size+=add;space-=if space==math.huge then 0 else add;if t.Size<t.Desired-1e-7 then table.insert(rest,t) end end;candidates=rest
 end
 if flex>0 then
  local unit=0
  if axis.Size then
   local active={};local remaining=axis.Size-gaps
   for i=axis.First,axis.Last do local t=axis.Tracks[i];if t.Flex>0 then table.insert(active,t) else remaining-=t.Size end end
   for _=1,#active+1 do
    local sum=0;for _,t in active do sum+=t.Flex end;unit=math.max(0,remaining/math.max(1,sum))
    local rest={};for _,t in active do if t.Base>unit*t.Flex then remaining-=t.Base else table.insert(rest,t) end end
    if #rest==#active then break end;active=rest
   end
  else
   for i=axis.First,axis.Last do local t=axis.Tracks[i];if t.Flex>0 then unit=math.max(unit,t.Base/math.min(1,t.Flex),t.Desired/math.max(1,t.Flex)) end end
  end
  for i=axis.First,axis.Last do local t=axis.Tracks[i];if t.Flex>0 then t.Size=math.max(t.Base,unit*t.Flex) end end
 end
 used=gaps;local stretch={};local visible=0
 for i=axis.First,axis.Last do local t=axis.Tracks[i];used+=t.Size;if not t.Collapsed then visible+=1 end;if t.MaxKind=='auto' and not t.Collapsed then table.insert(stretch,t) end end
 local free=if axis.Size then axis.Size-used else 0
 if (mode=='stretch' or mode=='normal') and free>0 and #stretch>0 then for _,t in stretch do t.Size+=free/#stretch end;used+=free;free=0 end
 mode=BoxAlignment.overflow(mode,safety,free)
 local offset,extra=0,0
 if mode=='end' or mode=='flex-end' then offset=free elseif mode=='center' then offset=free/2
 elseif mode=='space-between' and visible>1 then extra=math.max(0,free)/(visible-1)
 elseif mode=='space-around' and visible>0 then extra=math.max(0,free)/visible;offset=extra/2
 elseif mode=='space-evenly' and visible>0 then extra=math.max(0,free)/(visible+1);offset=extra end
 local position=offset;axis.Starts={};axis.Ends={}
 for i=axis.First,axis.Last do local t=axis.Tracks[i];axis.Starts[i]=position;position+=t.Size;axis.Ends[i]=position;position+=Tracks.gap(axis,i)+(if i<axis.Last and not t.Collapsed then extra else 0) end
 axis.Used=used;axis.Extent=position;axis.DistributedGap=axis.Gap+extra
 return used
end
function Tracks.slice(axis,start,count,before,after,probe)
 local out={Sizes=if probe then nil else {},Count=count,Names={},Gap=axis.DistributedGap or axis.Gap,Before=before,After=after}
 if out.Sizes then for i=start,start+count-1 do table.insert(out.Sizes,axis.Tracks[i].Size) end end
 for name,lines in axis.Names do for _,n in lines do if n>=start and n<=start+count then out.Names[name]=out.Names[name] or {};table.insert(out.Names[name],n-start+1) end end end
 return out
end
return Tracks
