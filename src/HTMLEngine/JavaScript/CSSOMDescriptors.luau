--!strict
-- Descriptor blocks have their own grammar; treating them as element styles
-- silently loses src, symbols and registration descriptors during CSSOM edits.
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Declarations=require(script.Parent.CSSDeclarations)
local Anchor=require(script.Parent.Parent.CSS.AnchorPosition)
local Descriptors={}
local function trim(s)return s:match('^%s*(.-)%s*$')or''end
local sets={
 font={['font-family']=true,src=true,['font-style']=true,['font-weight']=true,['font-stretch']=true,['font-display']=true,['unicode-range']=true,['font-feature-settings']=true,['font-variation-settings']=true,['font-named-instance']=true,['font-language-override']=true,['size-adjust']=true,['ascent-override']=true,['descent-override']=true,['line-gap-override']=true},
 counter={system=true,symbols=true,['additive-symbols']=true,negative=true,prefix=true,suffix=true,range=true,pad=true,fallback=true,['speak-as']=true},
 property={syntax=true,inherits=true,['initial-value']=true},
 page={size=true,marks=true,bleed=true,['page-orientation']=true},
 palette={['font-family']=true,['base-palette']=true,['override-colors']=true},
}
local function valid(kind,name,value)
 if value==''or value:find('[{}]')then return false end
 if kind=='property'then
  if name=='inherits'then return value=='true'or value=='false'end
  if name=='syntax'then return value:match('^"[^"]+"$')~=nil or value:match("^'[^']+'$")~=nil end
  return name=='initial-value'and not value:match('^var%(')
 elseif kind=='font'then
  if name=='font-display'then return ({auto=true,block=true,swap=true,fallback=true,optional=true})[value]or false end
  if name=='src'then return value:match('^url%(')~=nil or value:match('^local%(')~=nil end
  if name=='font-family'then return not value:find(',')and value~='initial'and value~='inherit'end
  if name:match('override$')or name=='size-adjust'then return value=='normal'or value:match('^%d*%.?%d+%%$')~=nil end
 elseif kind=='counter'then
  if name=='system'then return ({cyclic=true,numeric=true,alphabetic=true,symbolic=true,additive=true,fixed=true})[value]or value:match('^fixed%s+[+-]?%d+$')~=nil or value:match('^extends%s+[%a_%-][%w_%-]*$')~=nil end
  if name=='fallback'then return value:match('^[%a_%-][%w_%-]*$')~=nil end
 elseif kind=='palette'and name=='base-palette'then return value=='light'or value=='dark'or value:match('^%d+$')~=nil end
 return true
end
function Descriptors.parser(kind,quirks)
 return function(source,step)
  local entries,positions={},{}
  for _,declaration in Syntax.declarations(source)do
   if step then step()end
   if declaration.Important then continue end
   local header,after,colon=Syntax.scan(declaration.Text,1,':');header=trim(header)
   local name,ending=Syntax.identifier(header)
   if colon~=':'or not name or ending<=#header then continue end;name=name:lower();local value=trim(declaration.Text:sub(after))
   if sets[kind]and sets[kind][name]then
    if not valid(kind,name,value)then continue end
    if kind=='page'and(name=='size'or name=='page-orientation'or name=='marks')then value=value:lower()end
    local at=positions[name];local entry={Name=name,Value=value,Important=false}
    if at then entries[at]=entry else table.insert(entries,entry);positions[name]=#entries end
   elseif kind=='page'or kind=='keyframe'or kind=='position-try'and Anchor.acceptedProperty(name)then
    for _,entry in Declarations.parse(name..':'..value,step,quirks)do
     local at=positions[entry.Name];if at then entries[at]=entry else table.insert(entries,entry);positions[entry.Name]=#entries end
    end
   end
  end
  return entries
 end
end
return Descriptors
