--!strict
-- Early errors are checked for the entire script before any side effect.
local Validation={}
local STRICT_RESERVED={implements=true,interface=true,package=true,private=true,protected=true,public=true,static=true,yield=true,let=true}
local function fail(message)error('JavaScript syntax: '..message,0)end
local function bound(pattern,out)
 if pattern.Kind=='identifier'then table.insert(out,pattern.Name)
 elseif pattern.Pattern then bound(pattern.Pattern,out)
 elseif pattern.Kind=='array-pattern'then for _,item in pattern.Items do bound(item,out)end
 elseif pattern.Kind=='object-pattern'then for _,item in pattern.Properties do bound(item.Pattern,out)end end
end
function Validation.directive(items)
 for _,item in items do
  if item.Kind~='expression'or item.Value.Kind~='literal'or type(item.Value.Value)~='string'then break end
  if item.Value.Value=='use strict'and item.Value.DirectiveEligible~=false then return true end
 end
 return false
end
function Validation.check(ast,options)
 local visit
 local privateScopes={}
 if options and options.PrivateNames then table.insert(privateScopes,options.PrivateNames)end
 local function variables(node,out)
  if node.Kind=='function'or node.Kind=='function-declaration'or node.Kind=='class'or node.Kind=='class-declaration'then return end
  if node.Kind=='declare'and node.Mode=='var'then for _,entry in node.Entries do for _,name in entry.Names do out[name]=true end end end
  for key,value in node do
   if type(value)=='table'and key~='Params'then
    if value.Kind then variables(value,out)else for _,child in value do if type(child)=='table'and child.Kind then variables(child,out)elseif type(child)=='table'and child.Items then for _,item in child.Items do variables(item,out)end end end end
   end
  end
 end
 local function scope(items,parameters,catchParameter,functionScope,strict)
  local lexical,vars={},{}
  for _,item in items do
   variables(item,vars)
   if item.Kind=='declare'and item.Mode~='var'then for _,entry in item.Entries do for _,name in entry.Names do if lexical[name]then fail('Duplicate lexical declaration '..name)end;lexical[name]=true end end end
   if item.Kind=='class-declaration'then if lexical[item.Name]then fail('Duplicate lexical declaration '..item.Name)end;lexical[item.Name]=true end
   if item.Kind=='function-declaration'and not functionScope then
    -- Ordinary duplicate block functions are the explicit non-strict Annex-B
    -- exception. Async/generator declarations remain lexical in every mode.
    if lexical[item.Name]and(lexical[item.Name]~='ordinary-function'or strict or item.Value.Async or item.Value.Generator)then fail('Duplicate block function '..item.Name)end
    lexical[item.Name]=if not item.Value.Async and not item.Value.Generator then 'ordinary-function'else true
   end
  end
  if functionScope then for _,item in items do if item.Kind=='function-declaration'and lexical[item.Name]then fail('Lexical/function declaration conflict '..item.Name)end end end
  for name in lexical do if vars[name]or(parameters and parameters[name])or(catchParameter and catchParameter[name])then fail('Conflicting lexical declaration '..name)end end
 end
 visit=function(node,strict,noArguments)
  local kind=node.Kind
  if kind=='program'then
   node.Strict=node.Module==true or strict or Validation.directive(node.Items)
   if node.Module then
    local bindings,vars={},{}
    for _,entry in node.Imports do if bindings[entry.Local]then fail('Duplicate import binding '..entry.Local)end;bindings[entry.Local]=true end
    for _,item in node.Items do
     variables(item,vars)
     local names={}
     if item.Kind=='declare'and item.Mode~='var'then for _,entry in item.Entries do for _,name in entry.Names do table.insert(names,name)end end
     elseif item.Kind=='function-declaration'or item.Kind=='class-declaration'then table.insert(names,item.Name)end
     for _,name in names do if bindings[name]then fail('Duplicate module binding '..name)end;bindings[name]=true end
    end
    for name in vars do if bindings[name]then fail('Conflicting module binding '..name)end;bindings[name]=true end
    for _,entry in node.Exports do if entry.Local and not bindings[entry.Local]then fail('Export binding is not declared: '..entry.Local)end end
   end
   scope(node.Items,nil,nil,not node.Module,node.Strict);for _,item in node.Items do visit(item,node.Strict)end;return
  elseif kind=='class'then
   if node.Name and(node.Name=='eval'or node.Name=='arguments'or STRICT_RESERVED[node.Name])then fail('Forbidden class name '..node.Name)end
   table.insert(privateScopes,node.PrivateNames)
   if node.Heritage then visit(node.Heritage,true,noArguments)end
   for _,element in node.Elements do
    if element.Computed then visit(element.Key,true,noArguments)end
    if element.Value then visit(element.Value,true,element.Kind=='field')end
    if element.Body then visit(element.Body,true,true)end
   end
   table.remove(privateScopes);return
  elseif kind=='private-name'or(kind=='member'and node.Private)then
   local name=if kind=='private-name'then node.Name else node.Key.Value
   local found=false;for i=#privateScopes,1,-1 do if privateScopes[i][name]then found=true;break end end
   if not found then fail('Undeclared private name #'..name)end
  elseif kind=='function'then
   if not node.Arrow then noArguments=false end
   local ownStrict=Validation.directive(node.Body.Items);node.Strict=strict or ownStrict
   if node.Name and node.Strict and(node.Name=='eval'or node.Name=='arguments'or STRICT_RESERVED[node.Name])then fail('Forbidden strict function name '..node.Name)end
   local seen,simple={},true
   for _,param in node.Params do if param.Kind~='identifier'then simple=false end end
   if ownStrict and not simple then fail('Strict directive with non-simple parameters')end
   for _,param in node.Params do
    local names={};bound(param,names)
    for _,name in names do
     if seen[name]and(node.Strict or not simple or node.Arrow or node.Async or node.Generator or node.Method)then fail('Duplicate function parameter '..name)end
     if node.Strict and(name=='eval'or name=='arguments')then fail('Forbidden strict parameter '..name)end;seen[name]=true
     if node.Generator and name=='yield'then fail('Forbidden generator parameter yield')end
     if node.Strict and STRICT_RESERVED[name]then fail('Forbidden strict parameter '..name)end
    end
   end
   scope(node.Body.Items,seen,nil,true,node.Strict)
   for _,param in node.Params do visit(param,node.Strict,noArguments)end
   for _,item in node.Body.Items do visit(item,node.Strict,noArguments)end;return
  elseif kind=='identifier'then
   if noArguments and node.Name=='arguments'then fail('arguments is forbidden in class fields and static blocks')end
   if strict and STRICT_RESERVED[node.Name]then fail('Forbidden strict identifier '..node.Name)end
  elseif kind=='function-declaration'then
   if node.Single and(strict or node.Value.Async or node.Value.Generator)then fail('Function declaration requires a statement list')end
  elseif kind=='class-declaration'and(node.Name=='eval'or node.Name=='arguments'or STRICT_RESERVED[node.Name])then fail('Forbidden class binding '..node.Name)
  elseif kind=='block'then scope(node.Items,nil,nil,false,strict)
  elseif kind=='switch'then
   local items={};for _,case in node.Cases do for _,item in case.Items do table.insert(items,item)end end
   scope(items,nil,nil,false,strict)
  elseif kind=='for'or kind=='for-each'then
   if node.Init and node.Init.Kind=='declare'and node.Init.Mode~='var'then
    local seen,vars={},{};variables(node.Body,vars)
    for _,entry in node.Init.Entries do for _,name in entry.Names do if seen[name]or vars[name]then fail('Conflicting loop declaration '..name)end;seen[name]=true end end
   end
   if node.Body.Kind=='function-declaration'then fail('Function declaration is not a loop body')end
  elseif(kind=='while'or kind=='do')and node.Body.Kind=='function-declaration'then fail('Function declaration is not a loop body')
  elseif kind=='try'and node.Parameter then
   local names={};bound(node.Parameter,names);local set={}
   for _,name in names do if set[name]then fail('Duplicate catch binding '..name)end;set[name]=true end
   scope(node.Handler.Items,nil,set,false,strict)
   if node.Parameter.Kind~='identifier'then local vars={};variables(node.Handler,vars);for name in set do if vars[name]then fail('Catch/var binding conflict '..name)end end end
  elseif kind=='declare'then
   for _,entry in node.Entries do for _,name in entry.Names do
    if strict and(name=='eval'or name=='arguments'or STRICT_RESERVED[name])then fail('Forbidden strict binding '..name)end
    if node.Mode~='var'and name=='let'then fail('Lexical binding cannot be named let')end
   end end
  elseif kind=='unary'and node.Op=='delete'and strict then
   local target=node.Value;while target.Kind=='group'do target=target.Value end
   if target.Kind=='identifier'then fail('Cannot delete an identifier in strict mode')end
   if target.Kind=='member'and(target.Private or target.Object.Kind=='super')then fail('Cannot delete a private or super reference')end
  elseif(kind=='assign'or kind=='update')and strict then
   local target=node.Target;while target.Kind=='group'do target=target.Value end
   if target.Kind=='identifier'and(target.Name=='eval'or target.Name=='arguments')then fail('Forbidden strict assignment '..target.Name)end
   if target.Kind=='array-pattern'or target.Kind=='object-pattern'then local names={};bound(target,names);for _,name in names do if name=='eval'or name=='arguments'then fail('Forbidden strict assignment '..name)end end end
  elseif kind=='object'then
   local proto=false
   for _,property in node.Properties do
    if property.Cover then fail('Invalid object initializer')end
    if property.Key=='__proto__'and not property.Computed and not property.Method and not property.Accessor and not property.Shorthand then if proto then fail('Duplicate __proto__ setter')end;proto=true end
   end
  end
  for _,value in node do
   if type(value)=='table'then
    if value.Kind then visit(value,strict,noArguments)
    else for _,child in value do if type(child)=='table'then if child.Kind then visit(child,strict,noArguments)else for _,nested in child do if type(nested)=='table'then if nested.Kind then visit(nested,strict,noArguments)else for _,leaf in nested do if type(leaf)=='table'and leaf.Kind then visit(leaf,strict,noArguments)end end end end end end end end end
   end
  end
 end
 visit(ast,options and options.Strict==true,options and options.NoArguments==true)
end
return Validation
