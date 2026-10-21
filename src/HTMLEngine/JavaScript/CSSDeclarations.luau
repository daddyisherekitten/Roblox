--!strict
-- Ordered declaration blocks for rule CSSOM objects. Accepted values use the
-- renderer's CSS profile; this is not an independent permissive CSS parser.
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local QuirkyValues=require(script.Parent.Parent.CSS.QuirkyValues)
local DocumentMode=require(script.Parent.Parent.DOM.DocumentMode)
local InlineStyle=require(script.Parent.Parent.CSS.InlineStyle)
local Properties=require(script.Parent.Parent.CSS.Properties)
local Color=require(script.Parent.Parent.CSS.Color)
local Anchor=require(script.Parent.Parent.CSS.AnchorPosition)
local PositionArea=require(script.Parent.Parent.CSS.PositionArea)
local VMModel=require(script.Parent.VM)
local Declarations={}
local function trim(s)return s:match('^%s*(.-)%s*$')or''end
local sides={'top','right','bottom','left'}
local expansions={margin={},padding={},inset={'top','right','bottom','left'},['border-width']={},['border-color']={},['border-style']={},gap={'row-gap','column-gap'},overflow={'overflow-x','overflow-y'},['position-try']={'position-try-order','position-try-fallbacks'}}
for _,side in sides do
 table.insert(expansions.margin,'margin-'..side);table.insert(expansions.padding,'padding-'..side)
 for _,part in {'width','color','style'}do table.insert(expansions['border-'..part],'border-'..side..'-'..part)end
end
local function name(s)return if s:sub(1,2)=='--'then s else s:lower()end
local function tokens(s)
 local out,index={},1
 while index<=#s do local token,nextIndex=Syntax.scan(s,index,' \t\r\n\f');index=nextIndex;if token~=''then table.insert(out,token)end end
 return out
end
local function canonical(property,value,compiled)
 value=trim(value)
 if property:sub(1,2)=='--'then return value end
 if property=='position'or property=='position-anchor'then
  local part=compiled and compiled.Normal[1]
  local parsed=part and(part.Wide or part.Value)
  if type(parsed)=='string'then return if parsed:sub(1,2)=='--'then Syntax.serializeIdentifier(parsed)else parsed end
 end
 if property=='position-try-order'or property=='position-try-fallbacks'then
  local keyword,after=Syntax.identifier(value)
  if keyword and after>#value and ({initial=true,inherit=true,unset=true,revert=true,['revert-layer']=true})[keyword:lower()]then return keyword:lower()end
 end
 if property=='position-try-order'then return Anchor.order(value)or value end
 if property=='position-try-fallbacks'then local recipes=Anchor.tries(value);return if recipes then Anchor.serializeTries(recipes)else value end
 if property=='position-area'then return PositionArea.parse(value)or value end
 if property=='opacity'and tonumber(value)then return tostring(tonumber(value))end
 -- CSSOM keeps color keywords, but serializes literal sRGB colors.
 if(property=='color'or property:find('color',1,true))and(value:sub(1,1)=='#'or value:lower():match('^[rh][gs][bl]a?%('))then
  local c,a=Color.parse(value:lower());if c then
   local r,g,b=math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)
   return if not a or a==1 then string.format('rgb(%d, %d, %d)',r,g,b)else string.format('rgba(%d, %d, %d, %s)',r,g,b,tostring(a))
  end
 end
 local pixel=value:match('^([+%-]?%d*%.?%d+)[Pp][Xx]$')
 if pixel then return tostring(tonumber(pixel))..'px'end
 if value=='0'and Properties[property]and(Properties[property].Kind=='length'or Properties[property].Kind=='font-size'or property:match('margin')or property:match('padding')or property=='width'or property=='height'or property:match('^min%-')or property:match('^max%-')or property=='top'or property=='right'or property=='bottom'or property=='left')then return'0px'end
 return value
end
local function shorthandValue(key,entries)
 local values,pending={},nil
 for _,entry in entries do
  table.insert(values,entry.Value)
  if entry.PendingShorthand then
   if entry.PendingShorthand~=key or pending and pending~=entry.Value then return nil end
   pending=entry.Value
  elseif pending then return nil end
 end
 if pending then
  for _,entry in entries do if entry.PendingShorthand~=key then return nil end end
  return pending
 end
 if key=='position-try'then
  for _,value in values do if Syntax.findFunction(value,1,'var')then return nil end end
  if values[1]==values[2]then return values[1]end
  for _,value in values do
   if ({initial=true,inherit=true,unset=true,revert=true,['revert-layer']=true})[value]then return nil end
  end
  return (if values[1]=='normal'then ''else values[1]..' ')..values[2]
 end
 if #values==4 then if values[4]==values[2]then table.remove(values,4)end;if #values==3 and values[3]==values[1]then table.remove(values,3)end end
 if #values==2 and values[1]==values[2]then table.remove(values,2)end
 return table.concat(values,' ')
end
local function valid(property,value)
 if property:sub(1,2)=='--'then return value~=''end
 if not Properties[property]then return false end
 local compiled=InlineStyle.compile(property..':'..value);local count=#compiled.Normal+#compiled.Important
 if count==0 or #compiled.Important~=0 then return false end
 for _,entry in compiled.Normal do if entry.Error then return false end end
 return true,compiled
end
local function logicalGroup(property)
 for _,family in {'margin','padding','border','inset'}do
  if property:sub(1,#family+1)==family..'-'then return family,property:find('inline',1,true)~=nil or property:find('block',1,true)~=nil end
 end
 if property=='top'or property=='right'or property=='bottom'or property=='left'then return'inset',false end
 for _,prefix in {'','min-','max-'}do
  local name=property:sub(#prefix+1)
  if property:sub(1,#prefix)==prefix and(name=='width'or name=='height'or name=='inline-size'or name=='block-size')then return prefix..'size',name=='inline-size'or name=='block-size'end
 end
 return nil,false
end
local function place(entries,entry,positions)
 local at=positions[entry.Name]
 if not at then
  if #entries>=4096 then VMModel.throw(VMModel.error('RangeError','CSSOM declaration property budget exceeded'))end
  table.insert(entries,entry);positions[entry.Name]=#entries;return
 end
 -- A reset-only longhand and its owner must serialize in their actual
 -- declaration order. Its old slot can precede an owner added later; keeping
 -- that slot would make a subsequent explicit setter reset itself on reparse.
 local previous=entries[at]
 local owner=entry.ResetBy or previous.ResetBy
 if owner and positions[owner]and positions[owner]>at then
  table.remove(entries,at);table.insert(entries,entry)
  for i=at,#entries do positions[entries[i].Name]=i end
  return
 end
 local group,logic=logicalGroup(entry.Name)
 if group then
  for i=at+1,#entries do local nextGroup,nextLogic=logicalGroup(entries[i].Name)
   if nextGroup==group and nextLogic~=logic then table.remove(entries,at);table.insert(entries,entry);for j=at,#entries do positions[entries[j].Name]=j end;return end
  end
 end
 entries[at]=entry
end
function Declarations.parse(source,step,quirks)
 local entries,positions={},{}
 for _,declaration in Syntax.declarations(source)do
  if step then step()end
  local text=trim(declaration.Text);local property,after=Syntax.identifier(text)
  local value=if property then text:sub(after):match('^%s*:%s*(.-)%s*$')else nil
  if not value then continue end;property=name(property)
  value=QuirkyValues.value(property,value,quirks)
  local accepted,compiled=valid(property,value);if not accepted then continue end
  local names,values=expansions[property],tokens(value);local pending
  if property=='position-try'then
   local parsed=Anchor.shorthand(value)
   if parsed then values={parsed.Order,Anchor.serializeTries(parsed.Fallbacks)}
   else
    local keyword,after=Syntax.identifier(value)
    if keyword and after>#value and ({initial=true,inherit=true,unset=true,revert=true,['revert-layer']=true})[keyword:lower()]then values={keyword:lower(),keyword:lower()}
    else values={value,value};pending=property end
   end
  elseif names and (#values==1 or #names==4 and #values<=4 or #names==2 and #values<=2)then
   values=if #names==4 then {values[1],values[2]or values[1],values[3]or values[1],values[4]or values[2]or values[1]}else{values[1],values[2]or values[1]}
  else names={property};values={value}end
  for i,key in names do
   local at=positions[key];local old=if at then entries[at]else nil
   if old and old.Important and not declaration.Important then continue end
   local entry={Name=key,Value=canonical(key,values[i],if key==property then compiled else nil),Important=declaration.Important,PendingShorthand=pending}
   place(entries,entry,positions)
  end
  local resetOnly=Properties[property]and Properties[property].ResetOnly
  if resetOnly then
   local wide=compiled.Normal[1]and compiled.Normal[1].Wide
   for _,key in resetOnly do
    local at=positions[key];local old=at and entries[at]
    if old and old.Important and not declaration.Important then continue end
    place(entries,{Name=key,Value=wide or 'normal',Important=declaration.Important,ResetBy=property},positions)
   end
  end
 end
 return entries
end
function Declarations.serialize(entries)
 local parts,byName,positions,used={},{},{},{}
 for i,entry in entries do byName[entry.Name]=entry;positions[entry.Name]=i end
 local shorthandOf={};for shorthand,names in expansions do for _,key in names do shorthandOf[key]=shorthand end end
 for _,entry in entries do
  if used[entry.Name]then continue end
  if entry.ResetBy then
   local owner=byName[entry.ResetBy]
   if owner and owner.Important==entry.Important then used[entry.Name]=true;continue end
  end
  local key,value=entry.Name,entry.Value;local shorthand=shorthandOf[key]
  if shorthand then
   local components,complete={},true;for _,name in expansions[shorthand]do local e=byName[name];if not e or e.Important~=entry.Important or used[name]then complete=false;break end;table.insert(components,e)end
   if complete then
    local first,last=math.huge,0;for _,name in expansions[shorthand]do first=math.min(first,positions[name]);last=math.max(last,positions[name])end
    local family=shorthand:match('^(border)')or shorthand
    for i=first,last do local name=entries[i].Name
     if name:find('inline',1,true)or name:find('block',1,true)then
      if name:sub(1,#family)==family or family=='inset'and name:sub(1,5)=='inset'then complete=false;break end
     end
    end
   end
   local serialized=complete and shorthandValue(shorthand,components)
   if serialized then
    key=shorthand;value=serialized;for _,name in expansions[shorthand]do used[name]=true end
   end
  end
  if key==entry.Name and entry.PendingShorthand then value=''end
  used[entry.Name]=true;table.insert(parts,key..': '..value..(if entry.Important then ' !important'else'')..';')
 end
 return table.concat(parts,' ')
end
function Declarations.install(vm,globals,tools)
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local proto=vm.Object({});local states=setmetatable({},{__mode='kv'});local api={}
 local function parseFor(s,source)return if s.Parse then s.Parse(source,tools.Step)else Declarations.parse(source,tools.Step)end
 local function refresh(s)
  if s.Read then
   local source=s.Read()
   if type(source)=='string'then if source~=s.Source then s.Source=source;s.Entries=parseFor(s,source)end
   else local entries={};for _,key in source.Names do table.insert(entries,{Name=key,Value=source.Values[key]or'',Important=false})end;s.Entries=entries end
  end
 end
 local function state(value,read)
  tools.Check();local s=states[value];if not s then tools.Fail('TypeError','CSSStyleDeclaration requires its own receiver')end
  if read then refresh(s)end
  return s
 end
 local function writable(s)if s.ReadOnly then tools.Fail('NoModificationAllowedError','Computed CSS declaration is read-only')end end
 local function normalize(value)return name(tools.String(value))end
 local function find(s,key)for _,entry in s.Entries do if entry.Name==key then return entry end end;return nil end
 local function get(s,key)
  refresh(s)
  local names=expansions[key];if not names then local e=find(s,key);return if e and not e.PendingShorthand then e.Value else ''end
  local components,priority={},nil
  for _,name in names do local e=find(s,name);if not e or priority~=nil and priority~=e.Important then return ''end;priority=e.Important;table.insert(components,e)end
  return shorthandValue(key,components)or ''
 end
 local function priority(s,key)
  if s.ReadOnly then return ''end;refresh(s)
  local names=expansions[key]or{key};for _,name in names do local e=find(s,name);if not e or not e.Important then return ''end end;return 'important'
 end
 local function commit(s,nextEntries,force)
  local old=Declarations.serialize(s.Entries);local text=Declarations.serialize(nextEntries)
  if old~=text or force then s.Entries=nextEntries;if s.Write then s.Write(text,force);s.Source=text end;s.Changed()end
 end
 local function remove(s,key)
  writable(s)
  local old=get(s,key);local remove={};for _,name in expansions[key]or{key}do remove[name]=true end
  for _,name in Properties[key]and Properties[key].ResetOnly or{}do remove[name]=true end
  local nextEntries={};for _,entry in s.Entries do if not remove[entry.Name]then table.insert(nextEntries,entry)end end;commit(s,nextEntries);return old
 end
 local function write(s,key,value,important)
  writable(s)
  refresh(s)
  if value==''then remove(s,key);return end
  if important~=''and important:lower()~='important'then return end
  -- setProperty parses one value. A value cannot smuggle another declaration
  -- or its priority through the declaration-block parser.
  local single,_,delimiter=Syntax.scan(value,1,if key:sub(1,2)=='--'then';!'else';!{}')
  if delimiter~=''or trim(single)~=trim(value)then return end
  local parsed=parseFor(s,key..':'..value..(if important==''or s.SetterPriority then''else' !important'))
  if s.SetterPriority and important~=''then local copy={};for _,entry in parsed do local part=table.clone(entry);part.Important=true;table.insert(copy,part)end;parsed=copy end
  if #parsed==0 then return end
  local nextEntries=table.clone(s.Entries);local positions={};for i,entry in nextEntries do positions[entry.Name]=i end
  for _,entry in parsed do place(nextEntries,entry,positions)end;commit(s,nextEntries)
 end
 tools.Accessor(proto,'cssText',function(v)local s=state(v);if s.ReadOnly then return''end;refresh(s);return Declarations.serialize(s.Entries)end,function(v,item)local s=state(v);local source=if item==N then''else tools.String(item);tools.SourceBudget(source);writable(s);refresh(s);commit(s,parseFor(s,source),s.Write~=nil)end)
 tools.Accessor(proto,'length',function(v)return #state(v,true).Entries end)
 tools.Accessor(proto,'parentRule',function(v)return state(v).Parent or N end)
 tools.Method(proto,'item',1,function(args,v)local s=state(v);tools.Required(args,1);local i=tools.Uint(args[1]);refresh(s);return if s.Entries[i+1]then s.Entries[i+1].Name else''end)
 tools.Method(proto,'getPropertyValue',1,function(args,v)local s=state(v);tools.Required(args,1);return get(s,normalize(args[1]))end)
 tools.Method(proto,'getPropertyPriority',1,function(args,v)local s=state(v);tools.Required(args,1);return priority(s,normalize(args[1]))end)
 tools.Method(proto,'setProperty',2,function(args,v)
  local s=state(v);tools.Required(args,2);local key=normalize(args[1]);local value=if args[2]==N then''else tools.String(args[2]);local important=if args[3]==nil or args[3]==U or args[3]==N then''else tools.String(args[3]);tools.SourceBudget(value);write(s,key,value,important);return U
 end)
 tools.Method(proto,'removeProperty',1,function(args,v)local s=state(v);tools.Required(args,1);return remove(s,normalize(args[1]))end)
 local attributes={cssFloat='float'}
 for key in Properties do attributes[key]=key;attributes[(key:gsub('%-([a-z])',string.upper))]=key end
 for key,property in attributes do tools.Accessor(proto,key,function(v)return get(state(v),property)end,function(v,item)local s=state(v);local text=if item==N then''else tools.String(item);tools.SourceBudget(text);write(s,property,text,'')end)end
 tools.Interface('CSSStyleDeclaration',proto)
 vm.DefineProperty(proto,vm.SymbolIterator,vm.Object({value=vm.Get(vm.Prototypes.Array,'values'),writable=true,configurable=true},N))
 api.Prototype=proto
 function api:New(entries,parent,changed,adapter)
  adapter=adapter or{}
  local prototype=adapter.Prototype or proto
  local value={Prototype=prototype,CSSOMBrand=true};local backing=vm.Object({},prototype);local s={Entries=entries,Parent=parent,Changed=changed or function()end,Read=adapter.Read,Write=adapter.Write,ReadOnly=adapter.ReadOnly,Parse=adapter.Parse,SetterPriority=adapter.SetterPriority};value.CSSDeclarationState=s;states[value]=s
  value.Get=function(key)local i=vm.ObjectModel.Index(key);local current=state(value,i~=nil);if i and current.Entries[i+1]then return current.Entries[i+1].Name end;return vm.ObjectModel.Get(backing,key,value)end
  value.GetOwnPropertyDescriptor=function(key)local i=vm.ObjectModel.Index(key);local current=state(value,i~=nil);if i and current.Entries[i+1]then return{Value=current.Entries[i+1].Name,Writable=false,Enumerable=true,Configurable=true}end;return vm.ObjectModel.Own(backing,key)end
  value.Keys=function(enumerable)local current=state(value,true);local keys={};for i in current.Entries do table.insert(keys,tostring(i-1))end;for _,key in vm.ObjectModel.OwnKeys(backing,enumerable)do table.insert(keys,key)end;return keys end
  value.Set=function(key,item,strict)
   if vm.ObjectModel.Index(key)then if strict then tools.Fail('TypeError','CSS declaration indices are read-only')end;return false end
   return vm.ObjectModel.Set(backing,key,item,strict,value)
  end
  value.DefineProperty=function(key,descriptor,strict)
   if vm.ObjectModel.Index(key)then if strict then tools.Fail('TypeError','CSS declaration indices are read-only')end;return false end
   return vm.ObjectModel.DefineOwn(backing,key,vm.ObjectModel.ToDescriptor(descriptor))
  end
  value.Delete=function(key)local i=vm.ObjectModel.Index(key);if i and state(value,true).Entries[i+1]~=nil then return false end;return vm.ObjectModel.Delete(backing,key,false)end
  value.PreventExtensions=function()return false end
  value.GetPrototype=function()return vm.ObjectModel.GetPrototype(backing)end
  value.SetPrototype=function(p)return vm.ObjectModel.SetPrototypeInternal(backing,p)end
  return value
 end
 function api:Entries(value)return state(value).Entries end
 -- Web Animations commits a set of sampled properties as one style-attribute
 -- update. Reuse the same ordered declaration storage and value validation.
 function api:CommitProperties(value,properties,force)
  local s=state(value,true);writable(s)
  local nextEntries,positions={},{}
  for i,entry in s.Entries do nextEntries[i]=table.clone(entry);positions[entry.Name]=i end
  for _,property in properties do
   tools.Step()
   local parsed=Declarations.parse(property.Name..':'..property.Value,tools.Step)
   if #parsed==0 then tools.Fail('NotSupportedError','Animated value cannot be represented by the CSS profile')end
   for _,entry in parsed do entry.Important=false;place(nextEntries,entry,positions)end
  end
  commit(s,nextEntries,force)
 end
 function api:NewComputed(read)return self:New({},nil,nil,{Read=read,ReadOnly=true})end
 function api:NewInline(node,attribute)
  local quirks=DocumentMode.quirks(node)
  return self:New({},nil,nil,{Read=function()return node.Attributes.style or''end,Write=function(source,force)attribute(node,'style',source,force)end,
   Parse=function(source,step)return Declarations.parse(source,step,quirks)end})
 end
 function api:Destroy()for value,s in states do value.CSSDeclarationState=nil;s.Entries={};s.Parent=nil;s.Read=nil;s.Write=nil;s.Parse=nil;s.Changed=function()end end;table.clear(states)end
 return api
end
return Declarations
