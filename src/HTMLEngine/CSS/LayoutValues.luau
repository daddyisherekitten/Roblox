--!strict
local Tokens=require(script.Parent.GridValues)
local Length=require(script.Parent.LengthExpression)
local Values={}
Values.Aliases={['inset-area']='position-area'}
Values.SizeShorthands={['min-size']={'min-width','min-height'},['max-size']={'max-width','max-height'}}
Values.LegacyInsets={
 ['column-rule-edge-inset']={'column-rule-edge-inset-start','column-rule-edge-inset-end'},
 ['column-rule-interior-inset']={'column-rule-interior-inset-start','column-rule-interior-inset-end'},
}
function Values.expand(name,value)
 local fields=Values.SizeShorthands[name] or Values.LegacyInsets[name]
 local outset=name=='column-rule-outset'
 if outset then fields={'column-rule-inset'}end
 if not fields then return nil end
 local lower=value:lower()
 if lower=='initial' or lower=='inherit' or lower=='unset' then
  local parts={};for _,field in fields do table.insert(parts,{Name=field,Value=lower})end;return parts
 end
 local tokens=Tokens.tokens(value)
 if not tokens or #tokens<1 or #tokens>2 then return nil end
 if outset then
  local parts={}
  for _,v in tokens do
   if not Length.parse(v,{Validate=true,FontSize=16,RootFontSize=16,ViewportWidth=100,ViewportHeight=100}) then return nil end
   table.insert(parts,'calc(-1 * ('..v..'))')
  end
  return {{Name='column-rule-inset',Value=table.concat(parts,' ')}}
 end
 for _,v in tokens do
  if (name=='min-size' and v=='auto') or (name=='max-size' and v=='none') then continue end
  if not Length.parse(v,{Validate=true,FontSize=16,RootFontSize=16,ViewportWidth=100,ViewportHeight=100}) then return nil end
  if Values.SizeShorthands[name] and Length.resolve(Length.parse(v),100)<0 then return nil end
 end
 return {{Name=fields[1],Value=tokens[1]},{Name=fields[2],Value=tokens[2] or tokens[1]}}
end
function Values.parse(kind,value)
 if kind=='tracks-alignment' then
  local parts=Tokens.tokens(value,',');if not parts or #parts==0 or #parts>32 then return nil,false end
  local allowed={normal=true,start=true,['end']=true,center=true,stretch=true,['space-between']=true,['space-around']=true,['space-evenly']=true}
  for _,part in parts do if not allowed[part] then return nil,false end end
  return parts,true
 elseif kind=='grid-auto-position' then
  local parts=Tokens.tokens(value,'/');if not parts or #parts~=2 then return nil,false end
  local col,row=Tokens.line(parts[1]),Tokens.line(parts[2])
  return if row and col then {Row=row,Column=col} else nil,row~=nil and col~=nil
 end
 local parts=Tokens.tokens(value);if not parts or #parts==0 then return nil,false end
 local result={}
 if kind=='margin-trim' then
  if value=='none' then return {},true end
  if value=='block' then return {Start=true,End=true},true end
  for _,part in parts do
   local field=if part=='block-start' then 'Start' elseif part=='block-end' then 'End' else nil
   if not field or result[field] then return nil,false end;result[field]=true
  end
 elseif kind=='min-intrinsic-sizing' then
  if value=='legacy' then return {},true end
  for _,part in parts do
   local field=if part=='zero-if-scroll' then 'Scroll' elseif part=='zero-if-extrinsic' then 'Extrinsic' else nil
   if not field or result[field] then return nil,false end;result[field]=true
  end
 elseif kind=='color-scheme' then
  if value=='normal' then return {Light=true,Normal=true},true end
  local order={}
  for _,part in parts do
   local field=if part=='light' then 'Light' elseif part=='dark' then 'Dark' elseif part=='only' then 'Only' else nil
   if not field or result[field] then return nil,false end;result[field]=true
   if field~='Only'then table.insert(order,part)end
  end
  if not result.Light and not result.Dark then return nil,false end
  if result.Only then table.insert(order,'only')end
  result.Order=order
 else return nil,false end
 return result,true
end
return Values
