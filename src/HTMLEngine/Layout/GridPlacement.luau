--!strict
--!optimize 2
local Values=require(script.Parent.Parent.CSS.GridValues)
local Placement={}
local LIMIT=Values.Limit
function Placement.line(spec: any,axis: any,ending: boolean?): number?
 if not spec or spec.Auto or spec.Span then return nil end
 local n=spec.Number or 1
 if spec.Name then
  local list=axis.Names[spec.Name..(if ending then '-end' else '-start')]
  if not spec.Number and list then return list[1] end
  list=axis.Names[spec.Name] or {}
  local found=list[if n>0 then n else #list+n+1]
  if found then return found end
  return if n>0 then axis.Explicit+1+math.max(1,n-#list) else 1-math.max(1,-n-#list)
 end
 return if n>0 then n else axis.Explicit+2+n
end
local function spanEnd(start,spec,axis,reverse)
 local count=spec.Number or 1
 if not spec.Name then return start+(if reverse then -count else count) end
 local names={};for _,n in axis.Names[spec.Name] or {} do names[n]=true end
 local at=start
 for _=1,LIMIT*3 do
  at+=if reverse then -1 else 1
  if names[at] or at<1 or at>axis.Explicit+1 then count-=1;if count==0 then return at end end
 end
 return start+(if reverse then -1 else 1)
end
function Placement.pair(startSpec,endSpec,axis)
 local a,b=Placement.line(startSpec,axis),Placement.line(endSpec,axis,true)
 if a and b then if a==b then b=a+1 elseif b<a then a,b=b,a end
 elseif a then b=if endSpec and endSpec.Span then spanEnd(a,endSpec,axis,false) else a+1
 elseif b then a=if startSpec and startSpec.Span then spanEnd(b,startSpec,axis,true) else b-1 end
 local span=if a and b then b-a elseif startSpec and startSpec.Span then startSpec.Number or 1 elseif endSpec and endSpec.Span then endSpec.Number or 1 else 1
 return a,math.min(LIMIT,span)
end
function Placement.build(box: any,cols: any,rows: any): any
 local flow=box.Style.GridAutoFlow or {Axis='row'};local column=flow.Axis=='column'
 local major,minor=if column then cols else rows,if column then rows else cols
 major.First,major.Last=1,math.max(1,major.Explicit);minor.First,minor.Last=1,math.max(1,minor.Explicit)
 local items={}
 for i,child in box.FlowChildren or box.Children do
  if child.Kind~='Words' and child.Style.Position=='absolute' then continue end
  local s=if child.Kind=='Words' then {} else child.Style
  local c,cs=Placement.pair(s.GridColumnStart,s.GridColumnEnd,cols);local r,rs=Placement.pair(s.GridRowStart,s.GridRowEnd,rows)
  if flow.Axis=='none' then
   local default=box.Style.GridAutoPosition or {}
   c=c or Placement.line(default.Column,cols) or 1;r=r or Placement.line(default.Row,rows) or 1
  end
  if cols.Subgrid then if c then c=math.clamp(c,1,math.max(1,cols.Explicit)) end;cs=math.min(cs,cols.Explicit-(c or 1)+1) end
  if rows.Subgrid then if r then r=math.clamp(r,1,math.max(1,rows.Explicit)) end;rs=math.min(rs,rows.Explicit-(r or 1)+1) end
  table.insert(items,{Box=child,Index=i,Order=s.Order or 0,A=if column then c else r,B=if column then r else c,AS=if column then cs else rs,BS=if column then rs else cs})
 end
 table.sort(items,function(a,b) return if a.Order==b.Order then a.Index<b.Index else a.Order<b.Order end)
 for _,v in items do
  if v.A then major.First=math.min(major.First,v.A);major.Last=math.max(major.Last,v.A+v.AS-1) end
  if v.B then minor.First=math.min(minor.First,v.B);minor.Last=math.max(minor.Last,v.B+v.BS-1) end
 end
 for _,v in items do if not v.B then minor.Last=math.max(minor.Last,minor.First+v.BS-1) end end
 assert(major.Last-major.First<LIMIT and minor.Last-minor.First<LIMIT,'CSS Grid track limit exceeded')
 local occupied={}
 local function fits(a,b,as,bs)
  for r=a,a+as-1 do for c=b,b+bs-1 do if occupied[r] and occupied[r][c] then return false end end end
  return true
 end
 local function occupy(v)
  assert(v.A+v.AS-major.First<=LIMIT and v.B+v.BS-minor.First<=LIMIT,'CSS Grid track limit exceeded')
  major.Last=math.max(major.Last,v.A+v.AS-1);minor.Last=math.max(minor.Last,v.B+v.BS-1)
  for r=v.A,v.A+v.AS-1 do occupied[r]=occupied[r] or {};for c=v.B,v.B+v.BS-1 do occupied[r][c]=true end end
 end
 for _,v in items do if v.A and v.B then occupy(v) end end
 local ends={}
 for _,v in items do if v.A and not v.B then
  local b=if flow.Dense then minor.First else ends[v.A] or minor.First
  while not fits(v.A,b,v.AS,v.BS) do b+=1;assert(b-minor.First<LIMIT,'CSS Grid placement limit exceeded') end
  v.B=b;occupy(v);ends[v.A]=b+v.BS
 end end
 local a,b=major.First,minor.First
 for _,v in items do if not v.A then
  if flow.Dense then a,b=major.First,minor.First end
  if v.B then
   if v.B<b then a+=1 end;b=v.B
   while not fits(a,b,v.AS,v.BS) do a+=1;assert(a-major.First<LIMIT,'CSS Grid placement limit exceeded') end
  else
   while true do
    if b+v.BS-1>minor.Last then b=minor.First;a+=1 end
    assert(a-major.First<LIMIT,'CSS Grid placement limit exceeded')
    if fits(a,b,v.AS,v.BS) then break end;b+=1
   end
  end
  v.A,v.B=a,b;occupy(v)
 end end
 for _,v in items do v.Column,v.Row=if column then v.A else v.B,if column then v.B else v.A;v.Columns,v.Rows=if column then v.AS else v.BS,if column then v.BS else v.AS end
 return items
end
return Placement
