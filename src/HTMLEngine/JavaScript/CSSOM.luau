--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- A realm owns CSS object identities; the renderer compiles their source overlay.
-- CSSOM writes never rewrite a <style> node or generate DOM mutation records.
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local Selectors=require(script.Parent.Parent.CSS.Selectors)
local ShadowSelectors=require(script.Parent.Parent.CSS.ShadowSelectors)
local Nesting=require(script.Parent.Parent.CSS.Nesting)
local ScopeRules=require(script.Parent.Parent.CSS.ScopeRules)
local MediaQueries=require(script.Parent.Parent.CSS.MediaQueries)
local Declarations=require(script.Parent.CSSDeclarations)
local DocumentMode=require(script.Parent.Parent.DOM.DocumentMode)
local RuleFamilies=require(script.Parent.CSSOMRules)
local Strings=require(script.Parent.Strings)
local Stylesheet=require(script.Parent.Parent.CSS.Stylesheet)
local URL=require(script.Parent.Parent.Navigation.URL)
local CSSOM={}
local trim=Syntax.trim
function CSSOM.install(vm,globals,options)
 options=table.clone(options);local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local document=options.Unwrap(options.Document)
 local quirks=DocumentMode.quirks(document)
 local function parseDeclarations(source,step)return Declarations.parse(source,step,quirks)end
 local api={Alive=true};local states=setmetatable({},{__mode='kv'});local associations={};local invalid=setmetatable({},{__mode='k'});local roots,adoptionUse={},{};local syncing=false;local needsSync=true
 local prototypes,constructors={},{};local retainedEstimate=0;local declarations
 local function check()assert(api.Alive and vm.Alive,'JavaScript CSSOM disposed')end
 local function step()check();vm.Step()end
 local function exception(name,message)return if options.Events and name~='TypeError'and name~='RangeError'then options.Events:DOMException(message,name)else VM.error(name,message)end
 local function fail(name,message)VM.throw(exception(name,message))end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,N))end
 local function native(name,length,fn)
  local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,target)check();return fn(args,target)end}
  define(value,'length',{value=length,configurable=true});define(value,'name',{value=name,configurable=true});return value
 end
 local function method(proto,name,length,fn)local f=native(name,length,fn);define(proto,name,{value=f,writable=true,enumerable=true,configurable=true});return f end
 local function accessor(proto,name,get,set)
  define(proto,name,{get=native('get '..name,0,function(_,v)return get(v)end),set=if set then native('set '..name,1,function(args,v)set(v,args[1]);return U end)else U,enumerable=true,configurable=true})
 end
 local function interface(name,proto,parent,construct)
  prototypes[name]=proto;local c=native(name,0,function()fail('TypeError',name..' requires construction')end)
  c.Construct=if construct then function(args,newTarget)check();return construct(args,newTarget)end else function()fail('TypeError','Illegal '..name..' constructor')end
  if parent then c.Prototype=constructors[parent]end
  define(c,'prototype',{value=proto});define(proto,'constructor',{value=c,writable=true,configurable=true});define(proto,vm.SymbolToStringTag,{value=name,configurable=true})
  constructors[name]=c;globals[name]=c;vm.Global.Bindings[name]={Value=c};return c
 end
 local function stringValue(value)
  local primitive=vm.ToPrimitive(if value==nil then U else value,'string')
  if type(primitive)=='table'and primitive.Kind=='symbol'then fail('TypeError','Cannot convert Symbol to CSSOMString')end
  return VM.string(primitive)
 end
 local function usv(value)local out={};for code in Strings.codes(value)do table.insert(out,utf8.char(if code>=0xd800 and code<=0xdfff then 0xfffd else code))end;return table.concat(out)end
 local function uint(value)
  local p=vm.ToPrimitive(if value==nil then U else value,'number');if type(p)=='table'and(p.Kind=='symbol'or p.Kind=='bigint')then fail('TypeError','Cannot convert CSSOM index')end
  local number=VM.number(p);if number~=number or number==0 or math.abs(number)==math.huge then return 0 end
  return(if number<0 then math.ceil(number)else math.floor(number))%4294967296
 end
 local function required(args,n)if #args<n then fail('TypeError','Not enough CSSOM arguments')end end
 local function sourceBudget(source)if #source>1048576 then fail('RangeError','CSSOM source byte budget exceeded')end end
 local function state(value,kind)
  check();local s=states[value];if not s or kind and s.Kind~=kind then fail('TypeError','Incompatible CSSOM receiver')end;return s
 end
 local function allocate(kind,proto,data)
  if retainedEstimate>=16384 then local count=0;for _ in states do step();count+=1 end;retainedEstimate=count;if count>=16384 then fail('RangeError','CSSOM retained object budget exceeded')end end
  retainedEstimate+=1;local value=vm.Object({},proto);value.CSSOMBrand=true;data.Kind=kind;data.Value=value;value.CSSOMState=data;states[value]=data;return value
 end
 local function changed()if options.Adapter then options.Adapter:Changed()elseif options.Changed then options.Changed()end end
 local serializeRule,serializeRules,sync,newRule,newSheet,newMedia;local ruleFamilies;local importSheet
 local importedAssociations=setmetatable({},{__mode='kv'})
 local function dirty(s)
  local sheet=if s.Kind=='sheet'then s elseif s.Sheet then s.Sheet else nil
  if sheet then
   sheet.Overlay=true;local root=sheet
   while root.ParentSheet do root=root.ParentSheet end
   if root.Node and associations[root.Node]==root or api:IsAdopted(root.Value)then changed()end
  end
 end
 local function mediaParts(source)
  sourceBudget(source);local out={};local compiled=MediaQueries.compile(source)
  if not compiled then fail('RangeError','CSSOM media query budget exceeded')end
  for _,part in compiled do step();table.insert(out,part.Text)end
  return out
 end
 local function indexedFacade(value,proto,items)
  local backing=vm.Object({},proto)
  value.Get=function(key)local i=vm.ObjectModel.Index(key);return if i then items()[i+1]or U else vm.ObjectModel.Get(backing,key,value)end
  value.GetOwnPropertyDescriptor=function(key)local i=vm.ObjectModel.Index(key);local item=if i then items()[i+1]else nil;return if item~=nil then{Value=item,Writable=false,Enumerable=true,Configurable=true}else vm.ObjectModel.Own(backing,key)end
  value.Keys=function(enumerable)local keys={};for i in items()do table.insert(keys,tostring(i-1))end;for _,key in vm.ObjectModel.OwnKeys(backing,enumerable)do table.insert(keys,key)end;return keys end
  value.Set=function(key,item,strict)if vm.ObjectModel.Index(key)then if strict then fail('TypeError','CSSOM list indices are read-only')end;return false end;return vm.ObjectModel.Set(backing,key,item,strict,value)end
  value.DefineProperty=function(key,d,strict)if vm.ObjectModel.Index(key)then if strict then fail('TypeError','CSSOM list indices are read-only')end;return false end;return vm.ObjectModel.DefineOwn(backing,key,vm.ObjectModel.ToDescriptor(d))end
  value.Delete=function(key)local i=vm.ObjectModel.Index(key);if i and items()[i+1]~=nil then return false end;return vm.ObjectModel.Delete(backing,key,false)end
  value.GetPrototype=function()return vm.ObjectModel.GetPrototype(backing)end
  value.SetPrototype=function(p)return vm.ObjectModel.SetPrototypeInternal(backing,p)end
  value.PreventExtensions=function()return false end
  value.Values=nil
 end
 local function list(kind,proto,entries,synchronize)
  local value=allocate(kind,proto,{Entries=entries,Sync=synchronize})
  local function items()local s=state(value,kind);if s.Sync then s.Sync()end;return s.Entries()end
  indexedFacade(value,proto,items)
  return value
 end
 local function selector(source,nested,namespaces)
  if nested==true then source=Nesting.selector(source);if not source then return nil end end
  local out={};for _,entry in Selectors.list(source)do
   step();entry=trim(entry);if entry==''then return nil end
   local pseudo=entry:match('::([%a%-]+)%s*$')
   if pseudo and not({before=true,after=true,marker=true,['scroll-marker']=true,backdrop=true,placeholder=true,selection=true})[pseudo]then return nil end
   local test=entry:gsub('::[%a%-]+%s*$','');if test==''then test='*'end
   local scopeExemption
   if nested==true then test=Nesting.resolve(test,'*');if not test then return nil end
   elseif nested=='scope'then test,scopeExemption=ScopeRules.selector(test)
   elseif test:find('&',1,true)then test,scopeExemption=ScopeRules.selector(test);if scopeExemption then return nil end end
   if not Selectors.compile(test,nil,namespaces,nil,scopeExemption)and not ShadowSelectors.valid(test)then return nil end
   table.insert(out,Nesting.format(entry))
  end;return if #out>0 then table.concat(out,', ')else nil
 end
 local function appendDeclarations(children,source,counter)
  local entries=parseDeclarations(source,step);if #entries==0 then return end
  local last=children[#children]
  if last and last.Family=='CSSNestedDeclarations'then last.Entries=parseDeclarations(Declarations.serialize(last.Entries)..source,step)
  else counter.Count+=1;if counter.Count>4096 then fail('RangeError','CSSOM rule parse budget exceeded')end;table.insert(children,{Type=0,Family='CSSNestedDeclarations',Entries=entries})end
 end
 local function parse(source,single,depth,counter,nested,namespaces)
  sourceBudget(source);depth=depth or 0;counter=counter or{Count=0};if depth>32 then fail('RangeError','CSSOM rule nesting budget exceeded')end
  source=Syntax.preprocess(source)
  namespaces=namespaces or{}
  if nested and not single then
   local children={}
   for _,part in Nesting.body(source)do
    if part.Kind=='Declarations'then
     appendDeclarations(children,part.Source,counter)
    else local parsed=parse(part.Source,true,depth,counter,nested,namespaces);if parsed then table.insert(children,parsed[1])end end
   end
   return children
  end
  local out,index,preludePhase={},1,0
  while index<=#source do
   step();local header,nextIndex,delimiter=Syntax.scan(source,index,'{;}',nil,true);index=nextIndex;header=trim(header)
   if header==''and delimiter==''then break end
   if header==''then if single then return nil end;continue end
   local body='';if delimiter=='{'then local after;body,after=Syntax.scan(source,index,'}',true);index=after end
   local atName,atPrelude=Syntax.atRule(header)
   if atName then header='@'..atName..(if atPrelude==''then''else' '..atPrelude)end
   local lower=header:lower();local record
   if ruleFamilies then record=ruleFamilies:Parse(header,body,delimiter,depth,counter,nested,namespaces)end
   if not record and delimiter=='{'then
    local kind,condition=Syntax.atRule(header)
    if kind=='media'then record={Type=4,Media=mediaParts(condition),Rules=parse(body,false,depth+1,counter,nested,namespaces)}
    elseif kind=='supports'then
     if condition:sub(1,1)=='('or condition:lower():match('^not%s')or condition:lower():match('^selector%(')then record={Type=12,Condition=trim(condition),Rules=parse(body,false,depth+1,counter,nested,namespaces)}end
    elseif kind=='font-face'then record={Type=5,Opaque='@font-face { '..body..' }'}
    elseif kind=='keyframes'or kind=='-webkit-keyframes'then record={Type=7,Opaque=header..' { '..body..' }'}
    elseif kind=='container'then record={Type=0,Opaque=header..' { '..body..' }'}
    elseif not kind then local selected=selector(header,nested,namespaces);if selected then
     local parts=Nesting.body(body);local initial='';if parts[1]and parts[1].Kind=='Declarations'then initial=table.remove(parts,1).Source end
     local children={};for _,part in parts do
      if part.Kind=='Declarations'then
       if #children==0 then initial..=part.Source else appendDeclarations(children,part.Source,counter)end
      else local parsed=parse(part.Source,true,depth+1,counter,true,namespaces);if parsed then table.insert(children,parsed[1])end end
     end
     record={Type=1,Selector=selected,Entries=parseDeclarations(initial,step),Rules=children}
    end end
   end
   if record and not single then
    if record.Type==3 and(depth>0 or preludePhase>0)or record.Type==10 and(depth>0 or preludePhase>1)then record=nil
    elseif record.Type==10 then preludePhase=1;namespaces[record.Prefix]=record.URI
    elseif record.Type~=3 and record.Family~='CSSLayerStatementRule'then preludePhase=2 end
   end
   if record then counter.Count+=1;if counter.Count>4096 then fail('RangeError','CSSOM rule parse budget exceeded')end;table.insert(out,record)
   elseif single then return nil end
   if single and #out>1 then return nil end
  end
  return if single and #out~=1 then nil else out
 end
 local function attach(rule,sheet,parent)
  local s=state(rule,'rule');s.Sheet=sheet;s.Parent=parent
  if s.Rules then for _,child in s.Rules do attach(child,sheet,rule)end end
 end
 serializeRules=function(rules)local parts={};for _,rule in rules do step();table.insert(parts,serializeRule(state(rule,'rule')))end;return table.concat(parts,'\n')end
 serializeRule=function(s)
  if ruleFamilies then local result=ruleFamilies:Serialize(s);if result then return result end end
  if s.Type==1 then local text=Declarations.serialize(declarations:Entries(s.Style));local children=serializeRules(s.Rules or{});if children~=''then text..=(if text==''then''else' ')..children end;return s.Selector..' { '..text..(if text==''then''else' ')..'}'end
  if s.Type==4 or s.Type==12 then local condition=if s.Type==4 then table.concat(state(s.Media,'media').Parts,', ')else s.Condition;local body=serializeRules(s.Rules)
   return(if s.Type==4 then'@media 'else'@supports ')..condition..' {\n'..(if body==''then''else'  '..body:gsub('\n','\n  ')..'\n')..'}'
  end
  return s.Opaque
 end
 local sheetProto=vm.Object({});interface('StyleSheet',sheetProto)
 local cssSheetProto=vm.Object({},sheetProto)
 local ruleProto=vm.Object({});interface('CSSRule',ruleProto)
 local groupingProto=vm.Object({},ruleProto);interface('CSSGroupingRule',groupingProto,'CSSRule')
 local styleRuleProto=vm.Object({},groupingProto);interface('CSSStyleRule',styleRuleProto,'CSSGroupingRule')
 local conditionalProto=vm.Object({},groupingProto);interface('CSSConditionRule',conditionalProto,'CSSGroupingRule')
 local mediaRuleProto=vm.Object({},conditionalProto);interface('CSSMediaRule',mediaRuleProto,'CSSConditionRule')
 local supportsRuleProto=vm.Object({},conditionalProto);interface('CSSSupportsRule',supportsRuleProto,'CSSConditionRule')
 local mediaProto=vm.Object({});interface('MediaList',mediaProto)
 local ruleListProto=vm.Object({});interface('CSSRuleList',ruleListProto)
 local sheetListProto=vm.Object({});interface('StyleSheetList',sheetListProto)
 for _,proto in {mediaProto,ruleListProto,sheetListProto}do define(proto,vm.SymbolIterator,{value=vm.Get(vm.Prototypes.Array,'values'),writable=true,configurable=true})end
 for name,value in {STYLE_RULE=1,CHARSET_RULE=2,IMPORT_RULE=3,MEDIA_RULE=4,FONT_FACE_RULE=5,PAGE_RULE=6,KEYFRAMES_RULE=7,KEYFRAME_RULE=8,MARGIN_RULE=9,NAMESPACE_RULE=10}do define(ruleProto,name,{value=value,enumerable=true});define(constructors.CSSRule,name,{value=value,enumerable=true})end
 for _,pair in {{ruleListProto,'rulelist'},{sheetListProto,'sheetlist'}}do local proto,kind=pair[1],pair[2]
  accessor(proto,'length',function(v)local s=state(v,kind);if s.Sync then s.Sync()end;return #s.Entries()end)
  method(proto,'item',1,function(args,v)local s=state(v,kind);required(args,1);local i=uint(args[1]);if s.Sync then s.Sync()end;return s.Entries()[i+1]or N end)
 end
 newMedia=function(parts,changedCallback)
  local value=allocate('media',mediaProto,{Parts=parts,Changed=changedCallback})
  indexedFacade(value,mediaProto,function()return state(value,'media').Parts end);return value
 end
 local function mediaWrite(s,parts)
  if table.concat(s.Parts,', ')~=table.concat(parts,', ')then s.Parts=parts;s.Changed()end
 end
 accessor(mediaProto,'mediaText',function(v)return table.concat(state(v,'media').Parts,', ')end,function(v,item)mediaWrite(state(v,'media'),mediaParts(if item==N then''else stringValue(item)))end)
 accessor(mediaProto,'length',function(v)return #state(v,'media').Parts end)
 method(mediaProto,'item',1,function(args,v)local s=state(v,'media');required(args,1);return s.Parts[uint(args[1])+1]or N end)
 method(mediaProto,'appendMedium',1,function(args,v)local s=state(v,'media');required(args,1);local parts=mediaParts(stringValue(args[1]));if #parts~=1 or table.find(s.Parts,parts[1])then return U end;local nextParts=table.clone(s.Parts);table.insert(nextParts,parts[1]);mediaWrite(s,nextParts);return U end)
 method(mediaProto,'deleteMedium',1,function(args,v)local s=state(v,'media');required(args,1);local parts=mediaParts(stringValue(args[1]));if #parts~=1 then return U end;local nextParts={};for _,part in s.Parts do if part~=parts[1]then table.insert(nextParts,part)end end;if #nextParts==#s.Parts then fail('NotFoundError','Media query not found')end;mediaWrite(s,nextParts);return U end)
 method(mediaProto,'toString',0,function(_,v)return table.concat(state(v,'media').Parts,', ')end)
 declarations=Declarations.install(vm,globals,{Check=check,Fail=fail,Step=step,String=stringValue,Uint=uint,SourceBudget=sourceBudget,Required=required,Accessor=accessor,Method=method,Interface=function(n,p)interface(n,p)end})
 api.Declarations=declarations
 ruleFamilies=RuleFamilies.install(vm,{Prototypes=prototypes,Interface=interface,State=state,Fail=fail,Accessor=accessor,Method=method,Step=step,String=stringValue,Required=required,Budget=sourceBudget,MediaParts=mediaParts,Parse=parse,Dirty=dirty,Indexed=indexedFacade,Attach=attach,
  Declarations=function()return declarations end,ParseDeclarations=parseDeclarations,Quirks=quirks,NewMedia=function(...)return newMedia(...)end,NewRule=function(...)return newRule(...)end,Serialize=function(...)return serializeRules(...)end,ImportSheet=function(s)return importSheet(s)end})
 newRule=function(raw,sheet,parent)
  local proto=ruleFamilies:Prototype(raw)or(if raw.Type==1 then styleRuleProto elseif raw.Type==4 then mediaRuleProto elseif raw.Type==12 then supportsRuleProto else ruleProto)
  local value=allocate('rule',proto,{Type=raw.Type,Selector=raw.Selector,Condition=raw.Condition,Opaque=raw.Opaque,Sheet=sheet,Parent=parent});local s=states[value]
  if raw.Type==1 then s.Style=declarations:New(raw.Entries,value,function()dirty(s)end,{Parse=parseDeclarations});s.Rules={};for _,child in raw.Rules or{}do table.insert(s.Rules,newRule(child,sheet,value))end;s.List=list('rulelist',ruleListProto,function()return s.Rules end)
  elseif raw.Rules then s.Rules={};for _,child in raw.Rules do table.insert(s.Rules,newRule(child,sheet,value))end;s.List=list('rulelist',ruleListProto,function()return s.Rules end)
   if raw.Type==4 then s.Media=newMedia(raw.Media,function()dirty(s)end)end
  end;ruleFamilies:Initialize(raw,s,value);return value
 end
 local function materialize(s)
  if s.Resource and s.Resource.Generation==s.ResourceGeneration and not s.Overlay and s.Resource.Source~=nil and s.Resource.Source~=s.Source then
   for _,rule in s.Rules do attach(rule,nil,nil)end
   s.Source=s.Resource.Source;s.Materialized=false
  end
  if s.Materialized then return end
  local values={}
  local importIndex=0
  for _,raw in parse(s.Source,false)do if not s.Constructed or raw.Type~=3 then
   local value=newRule(raw,s,nil)
   if raw.Type==3 then importIndex+=1;states[value].ImportRecord=s.Resource and s.Resource.Imports[importIndex]end
   table.insert(values,value)
  end end
  s.Rules=values;s.Materialized=true
 end
 newSheet=function(source,node,constructed,metadata,proto)
  local value=allocate('sheet',proto or cssSheetProto,{Node=node,Constructed=constructed,OwnerDocument=document,Disabled=metadata.Disabled or false,OriginClean=metadata.OriginClean~=false,Href=metadata.Href,Title=metadata.Title,Rules={},Source=source,OwnerMedia=metadata.Media or'',OwnerDisabled=metadata.Disabled or false,OwnerTitle=metadata.Title,Overlay=false,Locked=false});local s=states[value]
  s.Materialized=source=='';s.Resource=metadata.Resource;s.ResourceGeneration=metadata.Resource and metadata.Resource.Generation;s.ParentSheet=metadata.ParentSheet;s.OwnerRule=metadata.OwnerRule;s.BaseURL=metadata.SourceURL or metadata.Resource and metadata.Resource.ResponseURL
  s.Media=newMedia(mediaParts(metadata.Media or''),function()dirty(s)end);s.List=list('rulelist',ruleListProto,function()materialize(s);return s.Rules end)
  return s
 end
 importSheet=function(rule)
	local parent=rule.Sheet;if not parent then return if rule.ImportSheet then rule.ImportSheet.Value else N end
  local resource=parent.Resource;local imported
  if resource then
   imported=rule.ImportRecord
   if not imported or imported.Blocked or imported.Cyclic or imported.Source==nil then return N end
  else
   -- Packaged CSSOM sheets use the same URL/base resolution as rendering.
   local href=rule.Href;local base=parent.BaseURL or parent.Href or options.URL or 'about:blank';local resolved=URL.resolve(base,href)
   local sources=options.Sources;local source=sources and(sources[resolved.URL]or sources[href]or sources[resolved.Path])
   if source==nil then return N end
   if not rule.MappedImport or rule.MappedImport.Source~=source then rule.MappedImport={Source=source,URL=resolved.URL,ResponseURL=resolved.URL}end
   imported=rule.MappedImport
  end
  if rule.ImportResource~=imported then
   local sheet=newSheet(imported.Source,nil,false,{Href=imported.URL,Media=rule.Media and table.concat(state(rule.Media,'media').Parts,', ')or'',Resource=if resource then imported else nil,OriginClean=imported.OriginClean,ParentSheet=parent,OwnerRule=rule.Value})
   sheet.Media=rule.Media;rule.ImportResource=imported;rule.ImportSheet=sheet;importedAssociations[imported]=sheet
  end
  return rule.ImportSheet.Value
 end
 interface('CSSStyleSheet',cssSheetProto,'StyleSheet',function(args,newTarget)
  local init=args[1];if init~=nil and init~=U and init~=N and not vm.ObjectModel.IsObject(init)then fail('TypeError','CSSStyleSheet options must be a dictionary')end
  local base,disabled,media=nil,false,''
  if init~=nil and init~=U and init~=N then
   local value=vm.Get(init,'baseURL');if value~=U and value~=N then base=stringValue(value)end
   value=vm.Get(init,'disabled');if value~=U then disabled=VM.truth(value)end
   value=vm.Get(init,'media');if value~=U then local s=states[value];media=if s and s.Kind=='media'then table.concat(s.Parts,', ')else stringValue(value)end
  end
  local p=vm.Get(newTarget,'prototype');if not vm.ObjectModel.IsObject(p)then p=cssSheetProto end
  local s=newSheet('',nil,true,{Disabled=disabled,Media=media},p);s.BaseURL=base;return s.Value
 end)
 accessor(sheetProto,'type',function(v)state(v,'sheet');return'text/css'end)
 accessor(sheetProto,'href',function(v)local s=state(v,'sheet');sync();return s.Href or N end)
 accessor(sheetProto,'ownerNode',function(v)local s=state(v,'sheet');sync();return if s.Node then options.Wrap(s.Node)else N end)
 accessor(sheetProto,'parentStyleSheet',function(v)local s=state(v,'sheet');return if s.ParentSheet then s.ParentSheet.Value else N end)
 accessor(sheetProto,'title',function(v)local s=state(v,'sheet');sync();return if s.Title and s.Title~=''then s.Title else N end)
 accessor(sheetProto,'disabled',function(v)local s=state(v,'sheet');sync();return s.Disabled end,function(v,item)local s=state(v,'sheet');local value=VM.truth(item);sync();if s.Disabled~=value then s.Disabled=value;dirty(s)end end)
 local function forward(v,key,targetKey,item)
  local target=vm.Get(v,key);if not vm.ObjectModel.IsObject(target)then fail('TypeError','CSSOM forwarded property requires an object')end
  vm.ObjectModel.Set(target,targetKey,item,false)
 end
 accessor(sheetProto,'media',function(v)local s=state(v,'sheet');sync();return s.Media end,function(v,item)state(v,'sheet');forward(v,'media','mediaText',item)end)
 accessor(cssSheetProto,'ownerRule',function(v)return state(v,'sheet').OwnerRule or N end)
 local function exposedRules(v)
  sync();local s=state(v,'sheet');if not s.OriginClean then fail('SecurityError','Stylesheet rules are not origin-clean')end;return s.List
 end
 accessor(cssSheetProto,'cssRules',exposedRules)
 accessor(cssSheetProto,'rules',exposedRules)
 accessor(ruleProto,'type',function(v)return state(v,'rule').Type end)
 accessor(ruleProto,'cssText',function(v)return serializeRule(state(v,'rule'))end,function(v,item)state(v,'rule');stringValue(item)end)
 accessor(ruleProto,'parentRule',function(v)return state(v,'rule').Parent or N end)
 accessor(ruleProto,'parentStyleSheet',function(v)local s=state(v,'rule');return if s.Sheet then s.Sheet.Value else N end)
 local function nestedContext(s)
  while s do if s.Type==1 then return true elseif s.Family=='CSSScopeRule'then return 'scope'end;s=if s.Parent then state(s.Parent,'rule')else nil end;return false
 end
 local function sheetNamespaces(s)
  local namespaces={};if not s then return namespaces end;materialize(s)
  for _,value in s.Rules do local rule=state(value,'rule');if rule.Type==10 then namespaces[rule.Prefix]=rule.URI end end
  return namespaces
 end
 accessor(styleRuleProto,'selectorText',function(v)local s=state(v,'rule');if s.Type~=1 then fail('TypeError','selectorText requires CSSStyleRule')end;return s.Selector end,function(v,item)local s=state(v,'rule');if s.Type~=1 then fail('TypeError','selectorText requires CSSStyleRule')end;local selected=selector(stringValue(item),s.Parent and nestedContext(state(s.Parent,'rule')),sheetNamespaces(s.Sheet));if selected and selected~=s.Selector then s.Selector=selected;dirty(s)end end)
 accessor(styleRuleProto,'style',function(v)local s=state(v,'rule');if s.Type~=1 then fail('TypeError','style requires CSSStyleRule')end;return s.Style end,function(v,item)local s=state(v,'rule');if s.Type~=1 then fail('TypeError','style requires CSSStyleRule')end;forward(v,'style','cssText',item)end)
 accessor(groupingProto,'cssRules',function(v)local s=state(v,'rule');if not s.List then fail('TypeError','cssRules requires a grouping rule')end;return s.List end)
 accessor(conditionalProto,'conditionText',function(v)local s=state(v,'rule');if s.Type~=4 and s.Type~=12 and s.Family~='CSSContainerRule'then fail('TypeError','conditionText requires CSSConditionRule')end;return if s.Type==4 then table.concat(state(s.Media,'media').Parts,', ')else s.Condition end)
 accessor(mediaRuleProto,'media',function(v)local s=state(v,'rule');if s.Type~=4 then fail('TypeError','media requires CSSMediaRule')end;return s.Media end,function(v,item)local s=state(v,'rule');if s.Type~=4 then fail('TypeError','media requires CSSMediaRule')end;forward(v,'media','mediaText',item)end)
 local function editable(v,kind)
  local s=state(v,kind);if kind=='sheet'then if not s.OriginClean then fail('SecurityError','Stylesheet rules are not origin-clean')end;if s.Locked then fail('NotAllowedError','Stylesheet is being replaced')end;materialize(s)end;return s
 end
 local function insert(args,v,kind)
  state(v,kind);required(args,1);local source=stringValue(args[1]);local index=uint(args[2]);local s=editable(v,kind)
  if not s.Rules then fail('TypeError','Rule does not contain child rules')end
  if index>#s.Rules then fail('IndexSizeError','CSS rule index exceeds length')end
  local sheet=if kind=='sheet'then s else s.Sheet
  local raws=parse(source,true,nil,nil,kind=='rule'and nestedContext(s),sheetNamespaces(sheet))
  if not raws then fail('SyntaxError','Expected one supported CSS rule')end
  local raw=raws[1]
  if raw.Type==3 and(kind=='rule'or s.Constructed)then fail(if s.Constructed then'SyntaxError'else'HierarchyRequestError','Import rules require a nonconstructed stylesheet')end
  if raw.Type==10 and kind=='rule'then fail('HierarchyRequestError','Namespace rules require a stylesheet')end
  if kind=='sheet'then
   for i,value in s.Rules do
    local old=state(value,'rule');local prelude=old.Type==3 or old.Family=='CSSLayerStatementRule'
    if raw.Type==3 and i<=index and not prelude or raw.Type~=3 and raw.Family~='CSSLayerStatementRule'and i>index and old.Type==3 then fail('HierarchyRequestError','Imports must precede other rules')end
    if raw.Type==10 and i<=index and old.Type~=3 and old.Type~=10 and old.Family~='CSSLayerStatementRule'or raw.Type~=3 and raw.Type~=10 and raw.Family~='CSSLayerStatementRule'and i>index and old.Type==10 then fail('HierarchyRequestError','Namespaces must precede body rules')end
   end
   for _,value in s.Rules do
    local old=state(value,'rule')
    if raw.Type==10 and old.Type~=3 and old.Type~=10 then fail('InvalidStateError','Namespace mutation requires only import and namespace rules')end
   end
  end
  if #s.Rules>=4096 then fail('RangeError','CSSOM rule list budget exceeded')end
  local rule=newRule(raw,sheet,if kind=='rule'then v else nil);table.insert(s.Rules,index+1,rule)
  if raw.Type==3 then
   if not sheet.Resource then sheet.Resource={Node=sheet.Node,URL=sheet.BaseURL or sheet.Href or options.URL or 'about:blank',Source=sheet.Source,Imports={}}end
   local ordinal=1;for i=1,index do if state(s.Rules[i],'rule').Type==3 then ordinal+=1 end end
   local root=sheet;while root.ParentSheet do root=root.ParentSheet end
   local resource=options.InsertImport and options.InsertImport(sheet.Resource,{Href=raw.Href,Layer=raw.Layer,Supports=raw.Supports,Media=table.concat(raw.Media,', ')},ordinal,root.Node)
   states[rule].ImportRecord=resource
  end
  dirty(s);return index
 end
 local function delete(args,v,kind)
  state(v,kind);required(args,1);local index=uint(args[1]);local s=editable(v,kind);if not s.Rules then fail('TypeError','Rule does not contain child rules')end
  if index>=#s.Rules then fail('IndexSizeError','CSS rule index exceeds length')end
  local old=state(s.Rules[index+1],'rule')
  if old.Type==10 then for _,value in s.Rules do local entry=state(value,'rule');if entry.Type~=3 and entry.Type~=10 then fail('InvalidStateError','Namespace mutation requires only import and namespace rules')end end end
  local removed=table.remove(s.Rules,index+1)
  if old.Type==3 and old.ImportRecord and s.Resource and options.RemoveImport then options.RemoveImport(s.Resource,old.ImportRecord)end
  if old.ImportSheet then old.ImportSheet.ParentSheet=nil end
  attach(removed,nil,nil);dirty(s);return U
 end
 for _,pair in {{cssSheetProto,'sheet'},{groupingProto,'rule'}}do local p,k=pair[1],pair[2];method(p,'insertRule',1,function(args,v)return insert(args,v,k)end);method(p,'deleteRule',1,function(args,v)return delete(args,v,k)end)end
 local function replacement(s,text)
  local raw=parse(text,false);local nextRules={};for _,entry in raw do if entry.Type~=3 then table.insert(nextRules,newRule(entry,s,nil))end end
  for _,rule in s.Rules do attach(rule,nil,nil)end;s.Rules=nextRules;s.Materialized=true;s.Overlay=true;dirty(s)
 end
 method(cssSheetProto,'replaceSync',1,function(args,v)
  local s=state(v,'sheet');required(args,1);local text=usv(stringValue(args[1]));if not s.Constructed or s.Locked then fail('NotAllowedError','Only an unlocked constructed stylesheet can be replaced')end;replacement(s,text);return U
 end)
 method(cssSheetProto,'replace',1,function(args,v)
  local promise,resolve,reject=options.CreatePromise();local locked
  local ok,result=pcall(function()
   local s=state(v,'sheet');required(args,1);local text=usv(stringValue(args[1]))
   if not s.Constructed or s.Locked then fail('NotAllowedError','Only an unlocked constructed stylesheet can be replaced')end
   s.Locked=true;locked=s
   options.QueueTask(function()
    if not api.Alive then return end
    local success,message=pcall(function()replacement(s,text)end);s.Locked=false;if success then resolve({v})else reject({VM.exceptionValue(message)})end
   end)
  end)
  if not ok then if locked then locked.Locked=false end;reject({VM.exceptionValue(result)})end;return promise
 end)
 local function connected(raw)
  local current=raw;while current and(current.Parent or current.Kind=='ShadowRoot'and current.Host)do step();current=current.Parent or current.Host end;return current==document
 end
 local function validRoot(raw)
  return raw==document or type(raw)=='table'and raw.Kind=='ShadowRoot'and(raw.OwnerDocument==document or raw.OwnerDocument==nil and connected(raw))
 end
 local function rootOf(raw)local current=raw;while current and current.Parent do step();current=current.Parent end;return current end
 local function fallbackSources(raw)
  if not connected(raw)then return{}end
  return Stylesheet.sources(raw,nil,options.Sources,if options.GetBaseURL then options.GetBaseURL()else options.URL)
 end
 local ensureRoot
 local function discoverRoots()
  local pending={document};local seen={};local count=0
  while #pending>0 do
   step();local node=table.remove(pending);if seen[node]then continue end;seen[node]=true;count+=1
   if count>32768 then fail('RangeError','CSSOM source node budget exceeded')end
   if node.InternalShadowRoot then ensureRoot(node.InternalShadowRoot);table.insert(pending,node.InternalShadowRoot)end
   for _,child in node.Children or{}do table.insert(pending,child)end
  end
 end
 sync=function()
  check();if syncing or not needsSync then return end;syncing=true
  local ok,message=pcall(function()
   discoverRoots();local seen={}
   for raw,root in roots do
    local sources=if options.Adapter then options.Adapter:Sources(raw)else fallbackSources(raw);local nextSheets={}
    for _,source in sources do
    step();local node=source.Node;local key=node or(if raw==document then api else raw);seen[key]=true;local s=associations[key]
    if s and(invalid[key]or s.Source~=source.Source or s.Root~=raw or s.ResourceVersion~=source.ResourceVersion)then s.Node=nil;associations[key]=nil;s=nil end;invalid[key]=nil
    if not s then s=newSheet(source.Source,node,false,source);associations[key]=s;s.Synthetic=source.Synthetic;s.Root=raw;s.ResourceVersion=source.ResourceVersion end
    local media=source.Media or'';if media~=s.OwnerMedia then s.OwnerMedia=media;state(s.Media,'media').Parts=mediaParts(media)end
    if source.Disabled~=s.OwnerDisabled then s.OwnerDisabled=source.Disabled;s.Disabled=source.Disabled or false end
    if source.Title~=s.OwnerTitle then s.OwnerTitle=source.Title;s.Title=source.Title end
    if not source.Synthetic then table.insert(nextSheets,s.Value)end
    end
    root.Sheets=nextSheets
   end
   for key,s in associations do if not seen[key]then s.Node=nil;associations[key]=nil end end
   needsSync=false
  end);syncing=false;if not ok then error(message,0)end
 end
 function api:IsAdopted(value)return(adoptionUse[value]or 0)>0 end
 local function convertSheet(v)
  local s=states[v]
  if not s and type(v)=='table'and v.CSSOMBrand and type(v.CSSOMState)=='table'and v.CSSOMState.Kind=='sheet'then s=v.CSSOMState end
  if not s or s.Kind~='sheet'then fail('TypeError','Expected CSSStyleSheet')end;return s
 end
 local function adoptionCheck(s)if not s.Constructed or s.OwnerDocument~=document then fail('NotAllowedError','Only sheets constructed in this document can be adopted')end end
 ensureRoot=function(raw)
  local root=roots[raw];if root then return root end
  if not validRoot(raw)then fail('NotAllowedError','Stylesheet root belongs to another document')end
  local count=0;for _ in roots do count+=1 end;if count>=8192 then fail('RangeError','CSSOM stylesheet root budget exceeded')end
  root={Raw=raw,Adopted={},Sheets={}};roots[raw]=root;needsSync=true
  root.SheetsList=list('sheetlist',sheetListProto,function()return root.Sheets end,sync)
  local backing=vm.Array({});local observable=vm.Array({});observable.CSSOMBrand=true
  root.Backing,root.Observable=backing,observable
  local function adoptedCommit()
   for _,value in root.Adopted do local count=(adoptionUse[value]or 1)-1;adoptionUse[value]=if count>0 then count else nil end
   root.Adopted=table.clone(backing.Items)
   for _,value in root.Adopted do adoptionUse[value]=(adoptionUse[value]or 0)+1 end
   changed()
  end
  root.Commit=adoptedCommit
 local function setAdoptedIndex(index,value)
  local length=backing.Length or #backing.Items;if index>length then return false end
  if index>=4096 then fail('RangeError','CSSOM adopted sheet budget exceeded')end
  local s=convertSheet(value);adoptionCheck(s);vm.ObjectModel.DefineOwn(backing,tostring(index),{Value=value,Writable=true,Enumerable=true,Configurable=true});adoptedCommit();return true
 end
 local function setAdoptedLength(value)
  local first=uint(value);local second=VM.number(vm.ToPrimitive(value,'number'));if first~=second then fail('RangeError','Invalid adoptedStyleSheets length')end
  local length=backing.Length or #backing.Items;if first>length then return false end
  vm.ObjectModel.DefineOwn(backing,'length',{Value=first});adoptedCommit();return true
 end
 vm.ObjectModel.Exotic[observable]={
  Get=function(_,key,receiver)return vm.ObjectModel.Get(backing,key,receiver or observable)end,
  Has=function(_,key)return vm.ObjectModel.Has(backing,key)end,
  Own=function(_,key)return vm.ObjectModel.Own(backing,key)end,
  OwnKeys=function()return vm.ObjectModel.OwnKeys(backing,false)end,
  GetPrototype=function()return vm.ObjectModel.GetPrototype(backing)end,
  SetPrototype=function(_,p)return vm.ObjectModel.SetPrototypeInternal(backing,p)end,
  IsExtensible=function()return true end,PreventExtensions=function()return false end,
  Set=function(_,key,value,receiver)
   local i=vm.ObjectModel.Index(key);if i then return setAdoptedIndex(i,value)elseif key=='length'then return setAdoptedLength(value)end
   return vm.ObjectModel.Set(backing,key,value,false,if receiver==observable then backing else receiver)
  end,
  Define=function(_,key,d)
   local i=vm.ObjectModel.Index(key)
   if i then
    if d.Accessor or d.Get~=nil or d.Set~=nil or d.Configurable==false or d.Enumerable==false or d.Writable==false then return false end
    if d.Value==nil then return true end;return setAdoptedIndex(i,d.Value)
   elseif key=='length'then
    if d.Accessor or d.Get~=nil or d.Set~=nil or d.Configurable==true or d.Enumerable==true or d.Writable==false then return false end
    return if d.Value==nil then true else setAdoptedLength(d.Value)
   end
   return vm.ObjectModel.DefineOwn(backing,key,d)
  end,
  Delete=function(_,key)
   local i=vm.ObjectModel.Index(key);if i then local length=backing.Length or #backing.Items;if i~=length-1 then return false end;return setAdoptedLength(length-1)end
   return vm.ObjectModel.Delete(backing,key,false)
  end,
  }
  return root
 end
 ensureRoot(document)
 function api:DocumentGet(raw,key)
  if not validRoot(raw)then return nil end
  if key=='styleSheets'then local root=ensureRoot(raw);sync();return root.SheetsList elseif key=='adoptedStyleSheets'then return ensureRoot(raw).Observable end;return nil
 end
 function api:InlineDeclaration(raw,read,write)
  local inlineQuirks=DocumentMode.quirks(raw)
  return declarations:New({},nil,nil,{Read=read,Write=write,Parse=function(source,step)return Declarations.parse(source,step,inlineQuirks)end})
 end
 function api:DocumentSet(raw,key,value,strict)
  if not validRoot(raw)then return false end
  if key=='styleSheets'then if strict then fail('TypeError','Document.styleSheets is read-only')end;return true elseif key~='adoptedStyleSheets'then return false end
  if not vm.ObjectModel.IsObject(value)then fail('TypeError','adoptedStyleSheets requires an iterable')end
  local values={};local iterator=vm.Iterator(value)
  while true do step();local more,item=iterator();if not more then break end;convertSheet(item);table.insert(values,item);if #values>4096 then fail('RangeError','CSSOM adopted sheet budget exceeded')end end
  local root=ensureRoot(raw);local backing=root.Backing
  vm.ObjectModel.DefineOwn(backing,'length',{Value=0});root.Commit()
  for i,item in values do adoptionCheck(convertSheet(item));vm.ObjectModel.DefineOwn(backing,tostring(i-1),{Value=item,Writable=true,Enumerable=true,Configurable=true});root.Commit()end;return true
 end
 function api:NodeGet(raw,key)
  if not ElementNames.style(raw)and not ElementNames.html(raw,'link')then return nil end
  local owner=rootOf(raw);if validRoot(owner)then ensureRoot(owner)end
  if key=='sheet'then sync();local s=associations[raw];return if s then s.Value else N end
  if key=='disabled'then if ElementNames.html(raw,'link')then return raw.Attributes.disabled~=nil end;sync();local s=associations[raw];return if s then s.Disabled else false end
  return nil
 end
 function api:NodeSet(raw,key,value,strict)
  if not ElementNames.style(raw)and not ElementNames.html(raw,'link')then return false end
  if key=='sheet'then if strict then fail('TypeError','Element.sheet is read-only')end;return true elseif key~='disabled'then return false end
  if ElementNames.html(raw,'link')then return false end
  sync();local s=associations[raw];if s then local disabled=VM.truth(value);if s.Disabled~=disabled then s.Disabled=disabled;dirty(s)end end;return true
 end
 function api:ResourceChanged()
  needsSync=true;changed()
 end
 function api:NotifyMutation(record)
  if not api.Alive then return end
  local raw=record.Target or record.target;if not raw then return end
  local affected=false;local kind=record.Type or record.type
  if kind=='childList'then needsSync=true end
  if kind=='attributes'and not(record.AttributeNamespace or record.attributeNamespace)and (ElementNames.style(raw)or ElementNames.html(raw,'link'))then
   needsSync=true;affected=true
   local name=record.AttributeName or record.attributeName
   if name=='type'or ElementNames.html(raw,'link')and(name=='href'or name=='rel')then invalid[raw]=true end
   local s=associations[raw]
   if s and name=='media'then s.OwnerMedia=nil end
   if s and name=='title'then s.OwnerTitle=nil end
  end
  local inlineOwner=Stylesheet.styleMutationOwner(record)
  if inlineOwner then invalid[inlineOwner]=true;needsSync=true;affected=true end
  local function invalidate(nodes)
   local pending={};for _,node in nodes or{}do table.insert(pending,node)end;local count=0
   while #pending>0 do
    local node=table.remove(pending);count+=1;if count>32768 then fail('RangeError','CSSOM source mutation node budget exceeded')end
    if ElementNames.style(node)or ElementNames.html(node,'link')then
     local s=associations[node];if s then s.Node=nil;invalid[node]=true end;needsSync=true;affected=true
    end
    for _,child in node.Children do table.insert(pending,child)end
    if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end
   end
  end
  invalidate(record.RemovedNodes or record.removedNodes);invalidate(record.AddedNodes or record.addedNodes)
  if affected then changed()end
 end
 function api:RenderSource(node,raw)
  sync();local s=associations[node or(if raw and raw~=document then raw else api)];if not s or not s.Overlay then return nil end
  materialize(s)
  return {Node=s.Node,Source=serializeRules(s.Rules),Disabled=s.Disabled,Href=s.Href,SourceURL=s.BaseURL,Resource=s.Resource,Media=table.concat(state(s.Media,'media').Parts,', ')}
 end
 function api:RenderImport(resource)
  local s=importedAssociations[resource];if not s or not s.Overlay then return nil end
  materialize(s);return {Source=serializeRules(s.Rules),Disabled=s.Disabled}
 end
 function api:RenderAdopted(raw)
  if not validRoot(raw)then return{}end;local root=roots[raw];if not root then return{}end
  local out={};for _,value in root.Adopted do local s=state(value,'sheet');materialize(s);table.insert(out,{Source=serializeRules(s.Rules),Disabled=s.Disabled,Media=table.concat(state(s.Media,'media').Parts,', ')})end;return out
 end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false;declarations:Destroy()
  for value,s in states do value.CSSOMState=nil;s.Node=nil;s.OwnerDocument=nil;s.Root=nil;s.Sheet=nil;s.Parent=nil;s.ParentSheet=nil;s.OwnerRule=nil;s.Resource=nil;s.ImportSheet=nil;s.ImportRecord=nil;s.ImportResource=nil;s.MappedImport=nil;s.Rules={};s.Source='';s.Opaque='';s.Selector='';s.Parts={};s.Media=nil;s.Style=nil;s.Sync=nil;s.Changed=nil;s.Entries=function()return{}end end
  for _,root in roots do
   vm.ObjectModel.Exotic[root.Observable]=nil;table.clear(root.Adopted);table.clear(root.Sheets);table.clear(root.Backing.Items);root.Backing.Length=0;root.Commit=nil
  end
  table.clear(states);table.clear(associations);table.clear(roots);table.clear(adoptionUse);table.clear(importedAssociations)
  if options.Adapter and options.Adapter.SetProvider then options.Adapter:SetProvider(nil)end;table.clear(options)
 end
 if options.Adapter then options.Adapter:SetProvider(api)end
 return api
end
return CSSOM
