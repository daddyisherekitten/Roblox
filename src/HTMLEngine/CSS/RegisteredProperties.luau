--!strict
-- Typed @property computed values. The supported grammar is explicit: scalar
-- length/percentage/number/integer/color/string/custom-ident, unions and lists.
local Syntax=require(script.Parent.Syntax)
local Length=require(script.Parent.LengthExpression)
local Color=require(script.Parent.Color)
local Properties={}
local TYPES={length=true,['length-percentage']=true,percentage=true,number=true,integer=true,color=true,string=true,['custom-ident']=true}
local function trim(value)return value:match('^%s*(.-)%s*$')or''end
local function ident(value)return value:match('^[%a_%-][%w_%-]*$')~=nil and not({initial=true,inherit=true,unset=true,revert=true,['revert-layer']=true,default=true})[value:lower()]end
function Properties.syntax(value)
 value=trim(value);if value=='*'then return{}end
 local branches,index={},1
 while index<=#value do local part,after,delimiter=Syntax.scan(value,index,'|');index=after;part=trim(part)
  local multiplier=part:match('[+#]$');if multiplier then part=trim(part:sub(1,-2))end
  local kind=part:match('^<([%a%-]+)>$')
  if kind and not TYPES[kind]or(not kind and not ident(part))then return nil end
  table.insert(branches,{Kind=kind,Literal=if kind then nil else part,Multiplier=multiplier});if #branches>32 then return nil end
  if delimiter==''then break elseif index>#value then return nil end
 end
 return if #branches>0 then branches else nil
end
local function decimal(value)
 if not value:match('^[+-]?%d*%.?%d+[eE]?[+-]?%d*$')then return nil end
 local n=tonumber(value);return if n and n==n and math.abs(n)<=100000 then n else nil
end
local factors={px=1,['in']=96,cm=96/2.54,mm=96/25.4,q=96/101.6,pt=96/72,pc=16}
local function lengths(value,context)
 return value:gsub('([+-]?%d*%.?%d+)(%a+)',function(raw,unit)
  local n=tonumber(raw);unit=unit:lower();local factor=factors[unit]
  if unit=='em'then factor=context.FontSize or 16 elseif unit=='rem'then factor=context.RootFontSize or 16
  elseif unit=='vw'then factor=(context.ViewportWidth or 0)/100 elseif unit=='vh'then factor=(context.ViewportHeight or 0)/100
  elseif unit=='vmin'then factor=math.min(context.ViewportWidth or 0,context.ViewportHeight or 0)/100 elseif unit=='vmax'then factor=math.max(context.ViewportWidth or 0,context.ViewportHeight or 0)/100 end
  return if factor then string.format('%.9fpx',n*factor)else raw..unit
 end)
end
local function numberValue(value)
 local n=decimal(value);if n then return n end
 if value:match('^calc%(')or value:match('^min%(')or value:match('^max%(')or value:match('^clamp%(')then
  local length=Length.parse('calc(('..value..') * 1px)');if length and not length.Percent then return length.Value end
 end
 return nil
end
local function quoted(value)
 local quote=value:sub(1,1);if quote~='"'and quote~="'"then return false end
 local index=2;while index<=#value do local char=value:sub(index,index)
  if char=='\\'then index+=2
  elseif char==quote then return index==#value
  elseif char=='\n'or char=='\r'or char=='\f'then return false
  else index+=1 end
 end
 return false
end
local function scalar(value,branch,context)
 local kind=branch.Kind
 if not kind then return if value==branch.Literal then value else nil end
 if kind=='string'then return if quoted(value)then value else nil end
 if kind=='custom-ident'then return if ident(value)then value else nil end
 if kind=='number'or kind=='integer'then local n=numberValue(value);return if n and(kind~='integer'or n==math.floor(n))then tostring(n)else nil end
 if kind=='percentage'then
  local raw=value:match('^(.-)%%$');local n=raw and decimal(raw);if n then return tostring(n)..'%'end
  -- Percentages have a known numeric scale at computed-value time; forbid
  -- length dimensions before evaluating the shared math parser at 100%.
  local numeric=value:lower():gsub('calc',''):gsub('clamp',''):gsub('min',''):gsub('max','')
  if numeric:find('%a')or not value:find('%%')then return nil end
  local parsed=Length.parse(value);return if parsed then tostring(Length.resolve(parsed,100))..'%'else nil
 end
 if kind=='color'then
  local color,alpha=Color.parse(value:lower());if color=='currentcolor'then color=context.Color;alpha=context.ColorAlpha or 1 end
  if not color or type(color)=='string'then return nil end
  return string.format('rgb(%.6f %.6f %.6f / %.6f)',color.R*255,color.G*255,color.B*255,alpha or 1)
 end
 local converted=lengths(value,context);local parsed=Length.parse(converted,context)
 if not parsed or(kind=='length'and parsed.Percent)then return nil end
 if not parsed.Percent then return string.format('%.9fpx',parsed.Value)end
 return if parsed.Expression then converted else tostring(parsed.Value)..'%'
end
function Properties.compute(registration,value,context)
 if value==nil then return nil end;value=trim(value);context=context or{}
 if #registration.Grammar==0 then return value end
 for _,branch in registration.Grammar do
  if not branch.Multiplier then local result=scalar(value,branch,context);if result then return result end
  else local result,index={},1;local valid=true
   while index<=#value do
    local part,after,delimiter=Syntax.scan(value,index,if branch.Multiplier=='#'then','else' \t\r\n');index=after;part=trim(part)
    if part==''and branch.Multiplier=='+'then continue end
    local item=scalar(part,branch,context);if not item then valid=false;break end;table.insert(result,item)
    if #result>256 or(delimiter==','and index>#value)then valid=false;break end
   end
   if valid and #result>0 then return table.concat(result,if branch.Multiplier=='#'then', 'else' ')end
  end
 end
 return nil
end
function Properties.parse(name,body)
 if not name:match('^%-%-[%w_%-]+$')then return nil,'Invalid @property name: '..name end
 local raw={};for _,entry in Syntax.declarations(body)do if not entry.Important then local key,value=entry.Text:match('^%s*([%a%-]+)%s*:%s*(.-)%s*$');if key then
  key=key:lower()
  if key=='syntax'then if quoted(value)and Properties.syntax(value:sub(2,-2))then raw[key]=value end
  elseif key=='inherits'then value=value:lower();if value=='true'or value=='false'then raw[key]=value end
  elseif key=='initial-value'and value~=''then raw[key]=value end
 end end end
 local syntax=raw.syntax;local quote=syntax and syntax:sub(1,1)
 if not syntax or(quote~='"'and quote~="'")or syntax:sub(-1)~=quote then return nil,'@property requires a quoted syntax descriptor: '..name end
 syntax=syntax:sub(2,-2);local grammar=Properties.syntax(syntax);if not grammar then return nil,'Unsupported @property syntax: '..syntax end
 if raw.inherits~='true'and raw.inherits~='false'then return nil,'@property requires inherits: true or false: '..name end
 local initial=raw['initial-value'];local result={Name=name,Syntax=syntax,Grammar=grammar,Inherits=raw.inherits=='true',Initial=initial}
 if #grammar>0 then
  if not initial or initial:lower():find('var(',1,true)or initial:lower():find('env(',1,true)or initial:lower():find('currentcolor',1,true)
   or initial:lower():match('[%d%.][er]?[clh]?em%f[%W]')or initial:lower():match('[%d%.]ex%f[%W]')or not Properties.compute(result,initial,{})then return nil,'Invalid or dependent @property initial-value: '..name end
 end
 return result,nil
end
return Properties
