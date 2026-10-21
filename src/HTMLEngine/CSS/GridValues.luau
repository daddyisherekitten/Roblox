--!strict
--!optimize 2
-- Grid syntax stays data-only; percentages and font units resolve during layout.
local Grid = {}
local LengthExpression=require(script.Parent.LengthExpression)
local AlignmentValues=require(script.Parent.AlignmentValues)
Grid.Limit = 512
local function trim(s) return s:match('^%s*(.-)%s*$') end
function Grid.tokens(s: string, delimiter: string?): any?
 local out, start, depth, square, quote = {}, 1, 0, 0, nil
 for i=1,#s do
  local c=s:sub(i,i)
  if quote then if c==quote then quote=nil end
  elseif c=='"' or c=="'" then quote=c
  elseif c=='(' then depth+=1
  elseif c==')' then depth-=1
  elseif c=='[' then square+=1
  elseif c==']' then square-=1 end
  if depth<0 or square<0 then return nil end
  if not quote and depth==0 and square==0 and (if delimiter then c==delimiter else c:match('%s')~=nil) then
   local v=trim(s:sub(start,i-1));if v~='' then table.insert(out,v) elseif delimiter then return nil end;start=i+1
  end
 end
 if quote or depth~=0 or square~=0 then return nil end
 local v=trim(s:sub(start));if v~='' then table.insert(out,v) elseif delimiter then return nil end
 return out
end
local function ident(s)
 return s:match('^[%a_%-][%w_%-]*$')~=nil and not ({auto=true,span=true,none=true,inherit=true,initial=true,unset=true})[s]
end
local function length(s)
 if s=='0' then return {Kind='length',Value=0,Unit='px'} end
 local n,u=s:match('^([+]?%d*%.?%d+)([%a%%]+)$');n=tonumber(n)
 if n and n<=100000 and ({px=true,['%']=true,em=true,rem=true,ch=true,vw=true,vh=true,vmin=true,vmax=true})[u] then return {Kind='length',Value=n,Unit=u} end
 if s:match('^[%a]+%s*%(') and LengthExpression.parse(s,{FontSize=16,RootFontSize=16,ViewportWidth=100,ViewportHeight=100}) then
  return {Kind='expression',Source=s}
 end
 return nil
end
local function breadth(s,flex)
 if s=='auto' or s=='min-content' or s=='max-content' then return {Kind=s} end
 local n=s:match('^([+]?%d*%.?%d+)fr$')
 if n then n=tonumber(n);return if flex and n<=100000 then {Kind='fr',Value=n} else nil end
 return length(s)
end
local function track(s)
 local args=s:match('^minmax%((.*)%)$')
 if args then
  local t=Grid.tokens(args,',');if not t or #t~=2 then return nil end
  local a,b=breadth(t[1],false),breadth(t[2],true)
  return if a and b then {Kind='minmax',Min=a,Max=b} else nil
 end
 args=s:match('^fit%-content%((.*)%)$')
 if args then local v=length(trim(args));return if v then {Kind='fit-content',Max=v} else nil end
 return breadth(s,true)
end
function Grid.tracks(s: string, implicit: boolean?, nested: boolean?): any?
 if s=='masonry' and not implicit and not nested then return {Items={},Masonry=true}end
 if s=='none' and not implicit then return {Items={}} end
 local tokens=Grid.tokens(s);if not tokens or #tokens==0 then return nil end
 local result={Items={}};local count,auto=0,false
 if tokens[1]=='subgrid' and not implicit then result.Subgrid=true;table.remove(tokens,1) end
 for _,token in tokens do
  local names=token:match('^%[(.*)%]$')
  if names then
   if implicit then return nil end
   local list=Grid.tokens(names);if not list then return nil end
   for _,name in list do if not ident(name) then return nil end end
   table.insert(result.Items,{Kind='names',Names=list})
  else
   local args=token:match('^repeat%((.*)%)$')
   if args then
    if implicit or nested or result.Subgrid then return nil end
    local pair=Grid.tokens(args,',');if not pair or #pair~=2 then return nil end
    local n=tonumber(pair[1]);local automatic=pair[1]=='auto-fill' or pair[1]=='auto-fit'
    if not automatic and (not n or n<1 or n%1~=0 or n>Grid.Limit) then return nil end
    if automatic and auto then return nil end
    local content=Grid.tracks(pair[2],false,true);if not content or content.Subgrid or #content.Items==0 then return nil end
    local tracks=0;for _,v in content.Items do if v.Kind~='names' then tracks+=1 end end
    if tracks==0 then return nil end
    auto=auto or automatic;count+=tracks*(n or 1)
    table.insert(result.Items,{Kind='repeat',Count=n,Mode=if automatic then pair[1] else nil,Items=content.Items})
   else
    if result.Subgrid then return nil end
    local v=track(token);if not v then return nil end;table.insert(result.Items,v);count+=1
   end
  end
  if count>Grid.Limit then return nil end
 end
 if count==0 and not result.Subgrid then return nil end
 if auto then
  local function fixed(v)
   if v.Kind=='names' then return true end
   if v.Kind=='repeat' then for _,t in v.Items do if not fixed(t) then return false end end;return true end
   return v.Kind=='length' or v.Kind=='expression' or (v.Kind=='minmax' and ((v.Min.Kind=='length' or v.Min.Kind=='expression') or (v.Max.Kind=='length' or v.Max.Kind=='expression')))
  end
  for _,v in result.Items do if not fixed(v) then return nil end end
 end
 return result
end
function Grid.line(s: string): any?
 if s=='auto' then return {Auto=true} end
 local ts=Grid.tokens(s);if not ts or #ts==0 or #ts>3 then return nil end
 local result={}
 for _,t in ts do
  if t=='span' then if result.Span then return nil end;result.Span=true
  elseif t:match('^[+%-]?%d+$') then
   local n=tonumber(t);if result.Number or n==0 or math.abs(n)>Grid.Limit then return nil end;result.Number=n
  elseif ident(t) then if result.Name then return nil end;result.Name=t
  else return nil end
 end
 if result.Span and ((result.Number and result.Number<0) or (not result.Number and not result.Name)) then return nil end
 return result
end
function Grid.areas(s: string): any?
 if s=='none' then return {Rows=0,Columns=0,Names={}} end
 local ts=Grid.tokens(s);if not ts or #ts==0 then return nil end
 local out={Rows=#ts,Columns=0,Names={}};local cells={}
 for r,t in ts do
  local q=t:sub(1,1);if (q~='"' and q~="'") or t:sub(-1)~=q then return nil end
  local row={}
  local content=t:sub(2,-2);local i=1
  while i<=#content do
   local c=content:sub(i,i)
   if c:match('%s') then i+=1;continue end
   local word=if c=='.' then content:match('^%.+',i) else content:match('^[%w_%-]+',i)
   if not word then return nil end;table.insert(row,if c=='.' then '.' else word);i+=#word
  end
  if #row==0 or #row>Grid.Limit or r>Grid.Limit or (r>1 and #row~=out.Columns) then return nil end
  out.Columns=#row;cells[r]=row
  for c,name in row do if name~='.' then
   local a=out.Names[name];if a then a.R2=r+1;a.C2=math.max(a.C2,c+1);a.C1=math.min(a.C1,c) else out.Names[name]={R1=r,R2=r+1,C1=c,C2=c+1} end
  end end
 end
 for name,a in out.Names do for r=a.R1,a.R2-1 do for c=a.C1,a.C2-1 do if cells[r][c]~=name then return nil end end end end
 return out
end
Grid.Fields={['grid-template-columns']='GridColumns',['grid-template-rows']='GridRows',['grid-template-areas']='GridAreas',
 ['grid-auto-columns']='GridAutoColumns',['grid-auto-rows']='GridAutoRows',['grid-auto-flow']='GridAutoFlow',
 ['grid-column-start']='GridColumnStart',['grid-column-end']='GridColumnEnd',['grid-row-start']='GridRowStart',['grid-row-end']='GridRowEnd'}
function Grid.parse(key: string,s: string): any?
 if key=='GridColumns' or key=='GridRows' then return Grid.tracks(s) end
 if key=='GridAutoColumns' or key=='GridAutoRows' then return Grid.tracks(s,true) end
 if key=='GridAreas' then return Grid.areas(s) end
 if key=='GridAutoFlow' then
  if s=='none' then return {Axis='none'}end
  local t=Grid.tokens(s);if not t or #t==0 or #t>2 then return nil end
  local axis,dense=nil,false
  for _,v in t do if v=='dense' and not dense then dense=true elseif (v=='row' or v=='column') and not axis then axis=v else return nil end end
  return {Axis=axis or 'row',Dense=dense}
 end
 return Grid.line(s)
end
local resets={['grid-template-columns']='none',['grid-template-rows']='none',['grid-template-areas']='none',['grid-auto-columns']='auto',['grid-auto-rows']='auto',['grid-auto-flow']='row'}
function Grid.expand(key: string,s: string,properties: any?): any?
 local wide=s=='inherit' or s=='initial' or s=='unset'
 if key=='grid-row' or key=='grid-column' or key=='grid-area' then
  local fields=if key=='grid-area' then {'grid-row-start','grid-column-start','grid-row-end','grid-column-end'} else {key..'-start',key..'-end'}
  local t=if wide then {s} else Grid.tokens(s,'/');if not t or #t>#fields then return nil end
  for _,v in t do if not wide and not Grid.line(v) then return nil end end
  local function default(v) return if v and ident(v) then v else 'auto' end
  if not wide then if #fields==4 then t[2]=t[2] or default(t[1]);t[3]=t[3] or default(t[1]);t[4]=t[4] or default(t[2]) else t[2]=t[2] or default(t[1]) end end
  local out={};for i,f in fields do table.insert(out,{Name=f,Value=if wide then s else t[i]}) end;return out
 end
 if key=='place-items' or key=='place-self' or key=='place-content' then
  if properties and not wide and s~='revert'and s~='revert-layer'then return AlignmentValues.shorthand(s,key:sub(7),properties)end
  local t=Grid.tokens(s);if not t or #t<1 or #t>2 then return nil end
  local suffix=key:sub(7);return {{Name='align-'..suffix,Value=t[1]},{Name='justify-'..suffix,Value=t[2] or t[1]}}
 end
 if key~='grid' and key~='grid-template' then return nil end
 local out={};local values={}
 for f,v in resets do if key=='grid' or f:find('template',1,true) then values[f]=if wide then s else v end end
 if not wide and s~='none' then
  local sides=Grid.tokens(s,'/');if not sides or #sides>2 then return nil end
  local ts=Grid.tokens(sides[1]);if not ts then return nil end
  if s:find('auto%-flow') then
   if key~='grid' or #sides~=2 then return nil end
   local row=sides[1]:find('auto%-flow')~=nil;local spec=Grid.tokens(sides[if row then 1 else 2]);local sizes={};local dense=false;local seen=false
   for _,v in spec do if v=='auto-flow' and not seen then seen=true elseif v=='dense' and not dense then dense=true else table.insert(sizes,v) end end
   if not seen then return nil end
   values['grid-auto-flow']=(if row then 'row' else 'column')..(if dense then ' dense' else '')
   values[if row then 'grid-template-columns' else 'grid-template-rows']=sides[if row then 2 else 1]
   values[if row then 'grid-auto-rows' else 'grid-auto-columns']=if #sizes>0 then table.concat(sizes,' ') else 'auto'
  elseif sides[1]:find('["\']') then
   local areas,rows={},{};local i=1
   while i<=#ts do
    local v=ts[i]
    if v:sub(1,1)=='[' then table.insert(rows,v);i+=1;continue end
    if v:sub(1,1)~='"' and v:sub(1,1)~="'" then return nil end
    table.insert(areas,v);i+=1
    if ts[i] and track(ts[i]) then table.insert(rows,ts[i]);i+=1 else table.insert(rows,'auto') end
   end
   values['grid-template-areas']=table.concat(areas,' ');values['grid-template-rows']=table.concat(rows,' ');values['grid-template-columns']=sides[2] or 'none'
  else
   if #sides~=2 then return nil end
   values['grid-template-rows']=sides[1];values['grid-template-columns']=sides[2]
  end
 end
 for f,v in values do if not wide and not Grid.parse(Grid.Fields[f],v) then return nil end;table.insert(out,{Name=f,Value=v}) end
 return out
end
return Grid
