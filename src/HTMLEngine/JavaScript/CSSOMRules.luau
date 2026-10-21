--!strict
-- Rule-specific parsing and interfaces share CSSOM ownership, lists and dirty
-- publication. The CSSRule type number alone does not identify newer rules.
local Syntax=require(script.Parent.Parent.CSS.Syntax)
local ScopeRules=require(script.Parent.Parent.CSS.ScopeRules)
local Nesting=require(script.Parent.Parent.CSS.Nesting)
local Descriptors=require(script.Parent.CSSOMDescriptors)
local Declarations=require(script.Parent.CSSDeclarations)
local Anchor=require(script.Parent.Parent.CSS.AnchorPosition)
local Prelude=require(script.Parent.Parent.CSS.StylesheetPrelude)
local Layers=require(script.Parent.Parent.CSS.CascadeLayers)
local Rules={}
local trim=Syntax.trim
local function identifier(s)return s:match('^[%a_%-][%w_%-]*$')~=nil end
local function keyText(source)
 local parts,index={},1
 while index<=#source do
  local part,nextIndex=Syntax.scan(source,index,',');index=nextIndex;part=trim(part):lower()
  local number=if part=='from'then 0 elseif part=='to'then 100 else tonumber(part:match('^([+-]?%d*%.?%d+)%%$'))
  if not number or number<0 or number>100 then return nil end;table.insert(parts,tostring(number)..'%')
 end
 return if #parts>0 then table.concat(parts,', ')else nil
end
function Rules.install(vm,c)
 local U,N=vm.Model.Undefined,vm.Model.Null;local api={};local protos={}
 local families={
  CSSKeyframesRule='CSSRule',CSSKeyframeRule='CSSRule',CSSFontFaceRule='CSSRule',CSSPageRule='CSSGroupingRule',CSSMarginRule='CSSRule',
  CSSImportRule='CSSRule',CSSNamespaceRule='CSSRule',CSSLayerStatementRule='CSSRule',CSSLayerBlockRule='CSSGroupingRule',
  CSSContainerRule='CSSConditionRule',CSSScopeRule='CSSGroupingRule',CSSStartingStyleRule='CSSGroupingRule',CSSPropertyRule='CSSRule',CSSCounterStyleRule='CSSRule',CSSFontPaletteValuesRule='CSSRule',
  CSSNestedDeclarations='CSSRule',CSSPositionTryRule='CSSRule',
 }
 for name,parent in families do local proto=vm.Object({},c.Prototypes[parent]);protos[name]=proto;c.Interface(name,proto,parent)end
 local tryDescriptors=vm.Object({},c.Declarations().Prototype);c.Interface('CSSPositionTryDescriptors',tryDescriptors,'CSSStyleDeclaration')
 local function own(value,family)local s=c.State(value,'rule');if s.Family~=family then c.Fail('TypeError','Incompatible '..family..' receiver')end;return s end
 local function parsedFrame(source)
  local header,index,delim=Syntax.scan(source,1,'{');if delim~='{'then return nil end
  local body,following,closing=Syntax.scan(source,index,'}');if closing~='}'or trim(source:sub(following))~=''then return nil end
  local key=keyText(header);if not key then return nil end
  return {Type=8,Family='CSSKeyframeRule',Key=key,Entries=Descriptors.parser('keyframe',c.Quirks)(body,c.Step),Descriptor='keyframe'}
 end
 function api:Parse(header,body,delimiter,depth,counter,nested,namespaces)
  local keyword,condition=Syntax.atRule(header);if not keyword then return nil end
  if delimiter==';'then
   if keyword=='layer'then local names={};for _,name in string.split(condition,',')do name=Layers.name(trim(name));if not name then return nil end;table.insert(names,name)end;return {Type=0,Family='CSSLayerStatementRule',Names=names}end
   if keyword=='namespace'then
    local prefix,uri=Prelude.namespace(condition)
    if prefix~=nil and uri~=nil then return {Type=10,Family='CSSNamespaceRule',Prefix=prefix,URI=uri}end
   elseif keyword=='import'then
    local imported=Prelude.import(condition)
    if imported then return {Type=3,Family='CSSImportRule',Href=imported.Href,Layer=imported.Layer,Supports=imported.Supports,Media=c.MediaParts(imported.Media),Opaque=header..';'}end
   end
   return nil
  elseif delimiter~='{'then return nil end
  if keyword=='keyframes'or keyword=='-webkit-keyframes'then
   local name=condition:match('^"(.-)"$')or condition:match("^'(.-)'$")or condition;if not identifier(name)then return nil end
   local children,index={},1
   while index<=#body do
    c.Step();local h,nextIndex,d=Syntax.scan(body,index,'{');if d~='{'then break end;local b,following=Syntax.scan(body,nextIndex,'}');index=following
    local frame=parsedFrame(h..'{'..b..'}');if frame then counter.Count+=1;if counter.Count>4096 then c.Fail('RangeError','CSSOM rule parse budget exceeded')end;table.insert(children,frame)end
   end
   return {Type=7,Family='CSSKeyframesRule',Name=name,Rules=children}
  elseif keyword=='position-try'and Anchor.name(condition)then return {Type=0,Family='CSSPositionTryRule',Name=Anchor.name(condition),Descriptor='position-try',Entries=Descriptors.parser('position-try',c.Quirks)(body,c.Step)}
  elseif keyword=='font-face'then return {Type=5,Family='CSSFontFaceRule',Descriptor='font',Entries=Descriptors.parser('font')(body,c.Step)}
  elseif keyword=='page'then
   if condition~=''and not condition:match('^[%w_%-:%s,]+$')then return nil end
   local declarationParts,children,index={},{},1
   while index<=#body do
    local h,nextIndex,d=Syntax.scan(body,index,';{');index=nextIndex
    if d=='{'then local b,following=Syntax.scan(body,index,'}');index=following;local margin=trim(h):match('^@([%a%-]+)$');if margin then table.insert(children,{Type=9,Family='CSSMarginRule',Name=margin,Descriptor='page',Entries=Descriptors.parser('page',c.Quirks)(b,c.Step)})end
    elseif trim(h)~=''then table.insert(declarationParts,h..';')end
   end
   return {Type=6,Family='CSSPageRule',Selector=condition,Descriptor='page',Entries=Descriptors.parser('page',c.Quirks)(table.concat(declarationParts),c.Step),Rules=children}
  elseif keyword=='container'then
   local name,query=condition:match('^([%a_%-][%w_%-]*)%s+(.+)$');if not name then name='';query=condition end
   if query:sub(1,1)~='('and not query:match('^style%(')and not query:match('^not%s')then return nil end
   return {Type=0,Family='CSSContainerRule',Name=name,Query=query,Condition=condition,Rules=c.Parse(body,false,depth+1,counter,nested,namespaces)}
  elseif keyword=='layer'then
   if condition~=''and not Layers.valid(condition)then return nil end
   return {Type=0,Family='CSSLayerBlockRule',Name=if condition==''then''else Layers.name(condition),Rules=c.Parse(body,false,depth+1,counter,nested,namespaces)}
  elseif keyword=='scope'then
   local scope=ScopeRules.parse(condition,nil,{Kind='Document'},if nested==true then '*'else nil,namespaces,nested=='scope');if not scope then return nil end
   if nested==true and scope.StartText then scope.StartText=Nesting.selector(scope.StartText);if not scope.StartText then return nil end end
   return {Type=0,Family='CSSScopeRule',Start=if scope.StartText then Nesting.format(scope.StartText)else nil,End=if scope.FinishText then Nesting.format(scope.FinishText)else nil,Rules=c.Parse(body,false,depth+1,counter,'scope',namespaces)}
  elseif keyword=='starting-style'and condition==''then return {Type=0,Family='CSSStartingStyleRule',Rules=c.Parse(body,false,depth+1,counter,nested,namespaces)}
  elseif keyword=='property'and condition:match('^%-%-[%w_%-]+$')then
   local entries=Descriptors.parser('property')(body,c.Step);local properties={};for _,e in entries do properties[e.Name]=e.Value end
   if not properties.syntax or not properties.inherits or properties.syntax~='"*"'and properties.syntax~="'*'"and not properties['initial-value']then return nil end
   return {Type=0,Family='CSSPropertyRule',Name=condition,Descriptor='property',Entries=entries}
  elseif keyword=='counter-style'and identifier(condition)and condition~='none'and condition~='decimal'then return {Type=11,Family='CSSCounterStyleRule',Name=condition,Descriptor='counter',Entries=Descriptors.parser('counter')(body,c.Step)}
  elseif keyword=='font-palette-values'and condition:match('^%-%-[%w_%-]+$')then return {Type=0,Family='CSSFontPaletteValuesRule',Name=condition,Descriptor='palette',Entries=Descriptors.parser('palette')(body,c.Step)}end
  return nil
 end
 function api:Initialize(raw,s,value)
  s.Family=raw.Family;s.Name=raw.Name;s.Key=raw.Key;s.Query=raw.Query;s.Names=raw.Names;s.Start=raw.Start;s.End=raw.End;s.Href=raw.Href;s.Prefix=raw.Prefix;s.URI=raw.URI;s.Descriptor=raw.Descriptor
  if raw.Descriptor then s.Style=c.Declarations():New(raw.Entries,value,function()c.Dirty(s)end,{Parse=Descriptors.parser(raw.Descriptor,c.Quirks),SetterPriority=raw.Descriptor=='position-try',Prototype=if raw.Descriptor=='position-try'then tryDescriptors else nil})end
  if raw.Family=='CSSNestedDeclarations'then s.Style=c.Declarations():New(raw.Entries,value,function()c.Dirty(s)end,{Parse=c.ParseDeclarations})end
  if raw.Family=='CSSImportRule'then s.Layer=raw.Layer;s.Supports=raw.Supports;s.Media=c.NewMedia(raw.Media,function()c.Dirty(s)end)end
  if raw.Type==7 then c.Indexed(value,protos.CSSKeyframesRule,function()return s.Rules end)end
 end
 function api:Prototype(raw)return protos[raw.Family]end
 local function declaration(s)return Declarations.serialize(c.Declarations():Entries(s.Style))end
 function api:Serialize(s)
  local family=s.Family;if not family then return nil end
  if family=='CSSNestedDeclarations'then return declaration(s)end
  if family=='CSSKeyframeRule'then return s.Key..' { '..declaration(s)..' }'end
  if family=='CSSImportRule'then return '@import url("'..s.Href:gsub('"','\\"')..'")'..(if s.Layer==nil then''elseif s.Layer==''then' layer'else' layer('..s.Layer..')')..(if s.Supports then' supports('..s.Supports..')'else'')..(if #c.State(s.Media,'media').Parts>0 then' '..table.concat(c.State(s.Media,'media').Parts,', ')else'')..';'end
  if family=='CSSNamespaceRule'then return '@namespace '..(if s.Prefix==''then''else s.Prefix..' ')..'url("'..s.URI:gsub('"','\\"')..'");'end
  if family=='CSSLayerStatementRule'then return '@layer '..table.concat(s.Names,', ')..';'end
  local header=if family=='CSSKeyframesRule'then'@keyframes '..s.Name elseif family=='CSSFontFaceRule'then'@font-face' elseif family=='CSSPageRule'then'@page'..(if s.Selector==''then''else' '..s.Selector)elseif family=='CSSMarginRule'then'@'..s.Name
   elseif family=='CSSLayerBlockRule'then'@layer'..(if s.Name==''then''else' '..s.Name)elseif family=='CSSContainerRule'then'@container '..s.Condition elseif family=='CSSScopeRule'then'@scope'..(if s.Start then' ('..s.Start..')'else'')..(if s.End then' to ('..s.End..')'else'')
   elseif family=='CSSStartingStyleRule'then'@starting-style'elseif family=='CSSPropertyRule'then'@property '..s.Name elseif family=='CSSPositionTryRule'then'@position-try '..s.Name elseif family=='CSSCounterStyleRule'then'@counter-style '..s.Name else'@font-palette-values '..s.Name
  local body=if s.Style then declaration(s)else'';if s.Rules then local nested=c.Serialize(s.Rules);body..=(if body==''then''else'\n')..nested end
  return header..' { '..body..' }'
 end
 local function attr(family,key,field,writable,validate)
  c.Accessor(protos[family],key,function(v)local s=own(v,family);return s[field]or''end,if writable then function(v,item)local s=own(v,family);local text=c.String(item);if not validate or validate(text)then s[field]=text;c.Dirty(s)end end else nil)
 end
 for _,family in {'CSSKeyframesRule','CSSLayerBlockRule','CSSMarginRule','CSSPropertyRule','CSSCounterStyleRule','CSSFontPaletteValuesRule','CSSPositionTryRule'}do attr(family,'name','Name',family=='CSSKeyframesRule'or family=='CSSCounterStyleRule',identifier)end
 for _,family in {'CSSFontFaceRule','CSSPageRule','CSSMarginRule','CSSKeyframeRule','CSSNestedDeclarations','CSSPositionTryRule'}do c.Accessor(protos[family],'style',function(v)return own(v,family).Style end,function(v,item)own(v,family);vm.ObjectModel.Set(vm.Get(v,'style'),'cssText',item,false)end)end
 for _,family in {'CSSKeyframesRule','CSSPageRule'}do c.Accessor(protos[family],'cssRules',function(v)return own(v,family).List end)end
 c.Accessor(protos.CSSKeyframesRule,'length',function(v)return #own(v,'CSSKeyframesRule').Rules end)
 c.Accessor(protos.CSSKeyframeRule,'keyText',function(v)return own(v,'CSSKeyframeRule').Key end,function(v,item)local s=own(v,'CSSKeyframeRule');local key=keyText(c.String(item));if not key then c.Fail('SyntaxError','Invalid keyframe selector')end;s.Key=key;c.Dirty(s)end)
 c.Method(protos.CSSKeyframesRule,'appendRule',1,function(args,v)local s=own(v,'CSSKeyframesRule');c.Required(args,1);local source=c.String(args[1]);c.Budget(source);local raw=parsedFrame(source);if raw then if #s.Rules>=4096 then c.Fail('RangeError','CSSOM keyframe rule budget exceeded')end;table.insert(s.Rules,c.NewRule(raw,s.Sheet,v));c.Dirty(s)end;return U end)
 local function find(s,source)local key=keyText(source);if key then for index=#s.Rules,1,-1 do if c.State(s.Rules[index],'rule').Key==key then return index end end end;return nil end
 c.Method(protos.CSSKeyframesRule,'findRule',1,function(args,v)local s=own(v,'CSSKeyframesRule');c.Required(args,1);local index=find(s,c.String(args[1]));return if index then s.Rules[index]else N end)
 c.Method(protos.CSSKeyframesRule,'deleteRule',1,function(args,v)local s=own(v,'CSSKeyframesRule');c.Required(args,1);local index=find(s,c.String(args[1]));if index then c.Attach(table.remove(s.Rules,index),nil,nil);c.Dirty(s)end;return U end)
 attr('CSSContainerRule','containerName','Name',false);attr('CSSContainerRule','containerQuery','Query',false)
 attr('CSSImportRule','href','Href',false);c.Accessor(protos.CSSImportRule,'media',function(v)return own(v,'CSSImportRule').Media end);c.Accessor(protos.CSSImportRule,'styleSheet',function(v)return c.ImportSheet(own(v,'CSSImportRule'))end)
 for key,field in {layerName='Layer',supportsText='Supports'}do c.Accessor(protos.CSSImportRule,key,function(v)local result=own(v,'CSSImportRule')[field];return if result~=nil then result else N end)end
 attr('CSSNamespaceRule','prefix','Prefix',false);attr('CSSNamespaceRule','namespaceURI','URI',false)
 c.Accessor(protos.CSSLayerStatementRule,'nameList',function(v)return vm.Array(table.clone(own(v,'CSSLayerStatementRule').Names))end)
 for key,field in {start='Start',['end']='End'}do c.Accessor(protos.CSSScopeRule,key,function(v)return own(v,'CSSScopeRule')[field]or N end)end
 c.Accessor(protos.CSSPageRule,'selectorText',function(v)return own(v,'CSSPageRule').Selector end,function(v,item)local s=own(v,'CSSPageRule');local text=c.String(item);if text==''or text:match('^[%w_%-:%s,]+$')then s.Selector=text;c.Dirty(s)end end)
 local function descriptor(family,key,name,readOnly)
  c.Accessor(protos[family],key,function(v)local style=own(v,family).Style;return vm:Call(vm.Get(style,'getPropertyValue'),{name},style)end,if readOnly then nil else function(v,item)local style=own(v,family).Style;vm:Call(vm.Get(style,'setProperty'),{name,c.String(item)},style)end)
 end
 c.Accessor(protos.CSSPropertyRule,'syntax',function(v)local style=own(v,'CSSPropertyRule').Style;local text=vm:Call(vm.Get(style,'getPropertyValue'),{'syntax'},style);return text:sub(2,-2)end)
 descriptor('CSSPropertyRule','initialValue','initial-value',true)
 c.Accessor(protos.CSSPropertyRule,'inherits',function(v)local style=own(v,'CSSPropertyRule').Style;return vm:Call(vm.Get(style,'getPropertyValue'),{'inherits'},style)=='true'end)
 for key,name in {system='system',symbols='symbols',additiveSymbols='additive-symbols',negative='negative',prefix='prefix',suffix='suffix',range='range',pad='pad',fallback='fallback',speakAs='speak-as'}do descriptor('CSSCounterStyleRule',key,name,false)end
 for key,name in {fontFamily='font-family',basePalette='base-palette',overrideColors='override-colors'}do descriptor('CSSFontPaletteValuesRule',key,name,true)end
 return api
end
return Rules
