--!strict
-- Legacy grammar is property-scoped. Never enable it in the general length or
-- color parser: functions, modern properties and most shorthands stay strict.
local Syntax=require(script.Parent.Syntax)
local Quirky={}
local lengths={['background-position']=true,['border-spacing']=true,['border-width']=true,
 bottom=true,clip=true,['font-size']=true,height=true,left=true,['letter-spacing']=true,
 margin=true,['max-height']=true,['max-width']=true,['min-height']=true,['min-width']=true,
 padding=true,right=true,['text-indent']=true,top=true,['vertical-align']=true,width=true,['word-spacing']=true}
local colors={['background-color']=true,['border-color']=true,color=true}
for _,side in {'top','right','bottom','left'}do
 lengths['border-'..side..'-width']=true;lengths['margin-'..side]=true;lengths['padding-'..side]=true
 colors['border-'..side..'-color']=true
end
table.freeze(lengths);table.freeze(colors)
local function numericToken(source)
 local mantissa,after=source:match('^([+%-]?%d*%.%d+)()')
 local integer=mantissa==nil
 if not mantissa then mantissa,after=source:match('^([+%-]?%d+)()')end
 if not mantissa then return nil end
 local exponent,ending=source:sub(after):match('^([eE][+%-]?%d+)()')
 if exponent then mantissa..=exponent;after+=ending-1;integer=false end
 local value=tonumber(mantissa)
 if not value or value~=value or math.abs(value)==math.huge then return nil end
 return value,after,integer
end
local function number(source)
 local value,after=numericToken(source);return if value and after>#source then value else nil
end
local function length(source)
 local value=number(source);return if value then tostring(if value==0 then 0 else value)..'px'else source
end
local function color(source)
 local value,finish=Syntax.identifier(source)
 local hex
 if value and finish>#source then
  if (#value==3 or #value==6)and value:match('^%x+$')then hex=value end
 else
  local value,after,integer=numericToken(source)
  if value and integer then
   local unit=source:sub(after)
   if unit~=''then local decoded,ending=Syntax.identifier(unit);if not decoded or ending<=#unit then return source end;unit=decoded end
   hex=tostring(value)..unit
   if #hex<6 then hex=string.rep('0',6-#hex)..hex end
   if #hex~=6 or not hex:match('^%x+$')then hex=nil end
  end
 end
 return if hex then '#'..hex else source
end
function Quirky.value(property:string,source:string,enabled:boolean?):string
 if not enabled then return source end
 source=source:match('^%s*(.-)%s*$')or''
 if colors[property]then
  if property=='border-color'then
   local parts,index={},1
   while index<=#source do local token,after=Syntax.scan(source,index,' \t\r\n\f');index=after;if token~=''then table.insert(parts,color(token))end end
   return table.concat(parts,' ')
  end
  return color(source)
 end
 if not lengths[property]then return source end
 local rectangle=property=='clip'and source:lower():match('^rect%((.*)%)$')
 if property=='clip'and not rectangle then return source end
 local parts,index={},1;local text=rectangle or source
 local comma=rectangle and text:find(',',1,true)~=nil
 while index<=#text do
  local token,after,delimiter=Syntax.scan(text,index,if comma then ','else ' \t\r\n\f');index=after
  token=token:match('^%s*(.-)%s*$')or''
  if comma and(token==''or delimiter==','and index>#text)then return source end
  if token~=''then table.insert(parts,length(token))end
 end
 if rectangle and #parts~=4 then return source end
 return if rectangle then 'rect('..table.concat(parts,', ')..')'else table.concat(parts,' ')
end
return Quirky
