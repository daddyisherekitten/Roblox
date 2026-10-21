--!strict
-- Realm-owned source-text module graphs, live bindings and namespace exotics.
-- Loading is an explicit host service; no HTTP or filesystem access is implicit.
local VM=require(script.Parent.VM)
local Syntax=require(script.Parent.Syntax)
local Strings=require(script.Parent.Strings)
local Modules={}
local U,N=VM.Undefined,VM.Null
local AMBIGUOUS={}
local function less(a,b)
 local left,right=Strings.units(a),Strings.units(b)
 for i=1,math.min(#left,#right)do if left[i]~=right[i]then return left[i]<right[i]end end
 return #left<#right
end
function Modules.install(vm: any,globals: any,options: any): any
 options=table.clone(options)
 local api={Alive=true,Records={},Count=0}
 local cancellations={}
 local importMap={Imports={},Scopes={}}
 local resolvedSpecifiers={}
 local parseJSON=vm.Get(globals.JSON,'parse')
 local function scopeMatches(base,scope)return base==scope or(scope:sub(-1)=='/'and base:sub(1,#scope)==scope)end
 local namespace,resolveExport,evaluateGraph
 local function fail(name,message)VM.throw(VM.error(name,message))end
 local function text(value)return VM.string(vm.ToPrimitive(value,'string'))end
 local function capability()return options.Promises:CreateCapability()end
 local function yes(resolve,value)resolve({value or U})end
 local function no(reject,value)reject({value})end
 local function await(value,fulfilled,rejected)
  options.Promises:Await(value,function(args)if api.Alive then fulfilled(args[1])end end,
   function(args)if api.Alive then rejected(args[1])end end)
 end
 local function url(value,base)
  return vm.Get(vm:Construct(globals.URL,{value,base or options.BaseURL or 'about:blank'}),'href')
 end
 local function mapped(specifier,map,base)
  if not map then return nil end
  local best=nil
  for key in map do
   if key==specifier or(key:sub(-1)=='/'and specifier:sub(1,#key)==key)then
    if not best or #key>#best then best=key end
   end
  end
  if not best then return nil end
  local target=map[best]
  if target==false or target==N then fail('TypeError','Import map blocked '..specifier)end
  if type(target)~='string'then fail('TypeError','Invalid import map target')end
  target=url(target,base)
  if best~=specifier then
   if target:sub(-1)~='/'then fail('TypeError','Import map prefix target must end in /')end
   local resolved=url(specifier:sub(#best+1),target)
   if resolved:sub(1,#target)~=target then fail('TypeError','Import map prefix backtracking')end
   target=resolved
  end
  return target
 end
 function api:RegisterImportMap(value,documentBase)
  documentBase=documentBase or options.BaseURL or 'about:blank'
  local function normalizeKey(key)
   if key:match('^[%a][%w+%.%-]*:')or key:sub(1,1)=='/'or key:sub(1,2)=='./'or key:sub(1,3)=='../'then return url(key,documentBase)end
   return key
  end
  local function merge(target,incoming,scope)
   for key,raw in incoming or {}do
    if type(key)~='string'or key==''then continue end
    local normalized=normalizeKey(key)
    if target[normalized]~=nil then continue end
    local locked=false
    for _,entry in resolvedSpecifiers do
     if(not scope or scopeMatches(entry.Base,scope))and(entry.Specifier==normalized or(normalized:sub(-1)=='/'and entry.Specifier:sub(1,#normalized)==normalized))then locked=true;break end
    end
    if locked then continue end
    if type(raw)=='string'then
     local ok,address=pcall(url,raw,documentBase)
     target[normalized]=if ok and(normalized:sub(-1)~='/'or address:sub(-1)=='/')then address else false
    else target[normalized]=false end
   end
  end
  merge(importMap.Imports,value.Imports)
  for scope,entries in value.Scopes or {}do
   local ok,address=pcall(url,scope,documentBase)
   if ok then importMap.Scopes[address]=importMap.Scopes[address]or {};merge(importMap.Scopes[address],entries,address)end
  end
 end
 if options.ImportMap then api:RegisterImportMap(options.ImportMap)end
 function api:Resolve(specifier,base)
  specifier=text(specifier);base=base or(if options.GetBaseURL then options.GetBaseURL()else nil)or options.BaseURL or 'about:blank'
  local absolute=specifier:match('^[%a][%w+%.%-]*:')or specifier:sub(1,1)=='/'or specifier:sub(1,2)=='./'or specifier:sub(1,3)=='../'
  local normalized=if absolute then url(specifier,base)else specifier
  local map=importMap
  local function remember(result)
   assert(#resolvedSpecifiers<16384,'Module resolution budget exceeded')
   table.insert(resolvedSpecifiers,{Specifier=normalized,Base=base});return result
  end
  if map then
   local scopes={};for scope in map.Scopes or {}do
    local resolved=url(scope,options.BaseURL);if scopeMatches(base,resolved)then table.insert(scopes,{Name=scope,URL=resolved})end
   end
   table.sort(scopes,function(a,b)return #a.URL>#b.URL end)
   for _,scope in scopes do local result=mapped(normalized,map.Scopes[scope.Name],options.BaseURL);if result then return remember(result)end end
   local result=mapped(normalized,map.Imports,options.BaseURL);if result then return remember(result)end
  end
  if not absolute then fail('TypeError','Unmapped bare module specifier: '..specifier)end
  return remember(normalized)
 end
 local function moduleType(attributes)
  local kind='javascript'
  for key,value in attributes or {}do
   if key~='type'or value~='json'then fail('TypeError','Unsupported import attribute: '..key)end
   kind='json'
  end
  return kind
 end
 local function newRecord(href,kind,source)
  if api.Count>=(options.MaxModules or 256)then fail('RangeError','Module graph budget exceeded')end
  api.Count+=1
  local loaded,loadResolve,loadReject=capability()
  local evaluated,evalResolve,evalReject=capability()
  local record={URL=href,Type=kind,Source=source,Status='loading',Loaded=loaded,LoadResolve=loadResolve,LoadReject=loadReject,
   Evaluated=evaluated,EvalResolve=evalResolve,EvalReject=evalReject,Dependencies={},Requests={},Inline=source~=nil}
  -- A cached evaluation rejection is internal until import/Run observes it.
  await(evaluated,function()end,function()end)
  api.Records[href..'\0'..kind]=record;return record
 end
 local function compile(record,source)
  assert(#source<=65536,'Module source budget exceeded')
  if record.Type=='json'then
   local value=vm:Call(parseJSON,{source},globals.JSON)
   record.AST={Kind='program',Module=true,Strict=true,Imports={},Requests={},Exports={{Name='default',Local='*default*'}},
    Items={{Kind='declare',Mode='const',Entries={{Name='*default*',Names={'*default*'},Pattern={Kind='identifier',Name='*default*'},Value={Kind='literal',Value=value}}}}}}
  else
   local ok,ast=pcall(Syntax.parseModule,source)
   if not ok then fail('SyntaxError',tostring(ast))end;record.AST=ast
  end
  local visited={}
  local function topAwait(node)
   if type(node)~='table'or visited[node]or node.Kind=='function'or node.Kind=='literal'then return false end
   visited[node]=true
   if node.Kind=='await'or(node.Kind=='for-each'and node.Await)or(node.Kind=='declare'and node.Mode=='await-using')then return true end
   for _,value in node do if type(value)=='table'and topAwait(value)then return true end end
   return false
  end
  record.AST.HasTopLevelAwait=topAwait(record.AST.Items)
  record.Source=nil;record.Status='loaded';yes(record.LoadResolve,record)
 end
 local function loadRecord(href,kind,source,sourceURL)
  local key=href..'\0'..kind;local existing=api.Records[key]
  if existing then return existing end
  local record=newRecord(href,kind,source)
  if sourceURL then record.URL=sourceURL end
  local completed=false
  local function finish(ok,result)
   if completed or not api.Alive then return end;completed=true
   cancellations[record]=nil
   options.QueueTask(function()
    if not api.Alive then return end
    if not ok then record.Status='errored';record.Error=if type(result)=='table'then result else VM.error('TypeError',tostring(result));no(record.LoadReject,record.Error);return end
    local good,message=pcall(function()
     local text=if type(result)=='table'then result.Source else result
     if type(text)~='string'then fail('TypeError','Module loader returned no source')end
     if type(result)=='table'and result.MIME then
      local mime=result.MIME:lower():match('^%s*([^; ]+)')
      if kind=='json'and mime~='application/json'and mime~='text/json'and not(mime and mime:match('%+json$'))then fail('TypeError','Invalid JSON module MIME type')end
      if kind=='javascript'and mime~='text/javascript'and mime~='application/javascript'and mime~='text/ecmascript'and mime~='application/ecmascript'then fail('TypeError','Invalid JavaScript module MIME type')end
     end
     compile(record,text)
    end)
    if not good then record.Status='errored';record.Error=VM.exceptionValue(message);no(record.LoadReject,record.Error)end
   end)
  end
  local supplied=source or(options.Sources and options.Sources[href])
  if supplied~=nil then finish(true,supplied)
  elseif options.LoadScript then
   local ok,cancel=pcall(options.LoadScript,href,finish,{Type=kind,Module=true})
   if not ok then finish(false,VM.exceptionValue(cancel))
   elseif not completed and type(cancel)=='function'then cancellations[record]=cancel end
  else finish(false,VM.error('NotSupportedError','External module loading requires a host resource loader'))end
  return record
 end
 local function exportNames(record,seen,names)
  if seen[record]then return end;seen[record]=true
  for _,entry in record.AST.Exports do
   if entry.Name then names[entry.Name]=true
   elseif entry.Star then local inherited={};exportNames(record.Requests[entry.From],table.clone(seen),inherited);for name in inherited do if name~='default'then names[name]=true end end end
  end
 end
 resolveExport=function(record,name,seen)
  seen=seen or {};local visited=seen[record]
  if visited and visited[name]then return nil end
  if not visited then visited={};seen[record]=visited end;visited[name]=true
  for _,entry in record.AST.Exports do if entry.Name==name then
   if entry.Local then
    for _,import in record.AST.Imports do if import.Local==entry.Local then
     local dependency=record.Requests[import.From]
     return if import.Namespace then {Record=dependency,Namespace=true}else resolveExport(dependency,import.Import,seen)
    end end
    return {Record=record,Name=entry.Local}
   end
   local dependency=record.Requests[entry.From]
   return if entry.Star then {Record=dependency,Namespace=true}else resolveExport(dependency,entry.Import,seen)
  end end
  if name=='default'then return nil end
  local found=nil
  for _,entry in record.AST.Exports do if entry.Star and not entry.Name then
   local candidate=resolveExport(record.Requests[entry.From],name,seen)
   if candidate==AMBIGUOUS then return AMBIGUOUS end
   if candidate then
    if found and(found.Record~=candidate.Record or found.Name~=candidate.Name or found.Namespace~=candidate.Namespace)then return AMBIGUOUS end
    found=candidate
   end
  end end
  return found
 end
 local function read(binding)
  return if binding.Namespace then namespace(binding.Record)else vm:ReadModuleBinding(binding.Record.ScopeRecord,binding.Name)
 end
 namespace=function(record)
  if record.Namespace then return record.Namespace end
  local names={};exportNames(record,{},names)
  local keys,bindings={},{}
  for name in names do local binding=resolveExport(record,name);if binding and binding~=AMBIGUOUS then bindings[name]=binding;table.insert(keys,name)end end
  table.sort(keys,less)
  local tag=vm.SymbolToStringTag;local result=vm.Object({},N);record.Namespace=result
  local function own(_,key)
   if bindings[key]then return {Value=read(bindings[key]),Writable=true,Enumerable=true,Configurable=false}end
   if key==tag then return {Value='Module',Writable=false,Enumerable=false,Configurable=false}end
   return nil
  end
  vm.ObjectModel.Exotic[result]={Own=own,GetPrototype=function()return N end,SetPrototype=function(_,value)return value==N end,
   IsExtensible=function()return false end,PreventExtensions=function()return true end,
   Get=function(_,key)return if bindings[key]then read(bindings[key])elseif key==tag then 'Module'else U end,
   Has=function(_,key)return bindings[key]~=nil or key==tag end,
   OwnKeys=function()local out=table.clone(keys);table.insert(out,tag);return out end,
   Delete=function(_,key)return bindings[key]==nil and key~=tag end,
   Set=function()return false end,
   Define=function(_,key,descriptor)
    local current=own(result,key);if not current then return false end
    if descriptor.Get~=nil or descriptor.Set~=nil or descriptor.Configurable==true then return false end
    if descriptor.Enumerable~=nil and descriptor.Enumerable~=current.Enumerable then return false end
    if descriptor.Writable~=nil and descriptor.Writable~=current.Writable then return false end
    if descriptor.Value~=nil and not vm.ObjectModel.SameValue(descriptor.Value,current.Value)then return false end
    return true
   end}
  return result
 end
 local function link(records)
  for _,record in records do if not record.ScopeRecord then
   local meta=vm.Object({url=record.URL},N)
   vm.DefineProperty(meta,'resolve',vm.Object({value=function(args)return api:Resolve(args[1]or U,record.URL)end,writable=true,enumerable=true,configurable=true},VM.Null))
   record.ScopeRecord=vm:CreateModule(record.AST,meta,record.URL)
  end end
  for _,record in records do if record.Status=='loaded'then
   for _,entry in record.AST.Imports do
    local dependency=record.Requests[entry.From]
    local binding=if entry.Namespace then {Record=dependency,Namespace=true}else resolveExport(dependency,entry.Import)
    if not binding or binding==AMBIGUOUS then fail('SyntaxError','Missing or ambiguous export '..(entry.Import or '*')..' in '..dependency.URL)end
    vm:SetModuleImport(record.ScopeRecord,entry.Local,function()return read(binding)end)
   end
   for _,entry in record.AST.Exports do if entry.Name and entry.From and not entry.Star then
    local binding=resolveExport(record,entry.Name);if not binding or binding==AMBIGUOUS then fail('SyntaxError','Invalid re-export '..entry.Name)end
   end end
   record.Status='linked'
  end end
 end
 evaluateGraph=function(root,records)
  -- Cycle roots share completion, but bodies retain depth-first source order.
  -- Hoisting every external SCC dependency before its member bodies would
  -- incorrectly reorder observable side effects in synchronous cycles.
  local nextIndex,stack,components=0,{},{}
  local function visit(record)
   if record.Component then return end
   nextIndex+=1;record.Index,record.Low,record.OnStack=nextIndex,nextIndex,true;table.insert(stack,record)
   for _,dependency in record.Dependencies do
    if not dependency.Component then
     if not dependency.Index then visit(dependency);record.Low=math.min(record.Low,dependency.Low)
     elseif dependency.OnStack then record.Low=math.min(record.Low,dependency.Index)end
    end
   end
   if record.Low==record.Index then
    local component={Members={},Remaining=0}
    repeat local member=table.remove(stack);member.OnStack=false;member.Component=component;table.insert(component.Members,member)until member==record
    component.Remaining=#component.Members
    table.insert(components,component)
   end
  end
  visit(root)
  for _,component in components do
   local cyclic=#component.Members>1 or table.find(component.Members[1].Dependencies,component.Members[1])~=nil
   if cyclic then for _,record in component.Members do
    if record.AST.HasTopLevelAwait then component.Invalid=VM.error('NotSupportedError','Top-level await in a cyclic module graph requires an async-cycle evaluator')end
   end end
   for _,record in component.Members do
    record.BodyPromise,record.BodyResolve,record.BodyReject=capability()
    await(record.BodyPromise,function()end,function()end)
   end
  end
  local function start(record)
   if record.EvaluationStarted then return end;record.EvaluationStarted=true
   local component=record.Component
   record.Status='evaluating';record.InEvaluationStack=true
   local function reject(value)
    if component.Done then return end;component.Done=true;component.Error=value
    for _,member in component.Members do
     member.Status='errored';member.Error=value;member.BodyDone=true
     member.InEvaluationStack=false
     no(member.BodyReject,value);no(member.EvalReject,value)
    end
   end
   local function run()
    if component.Done then return end
    local function done()
     if component.Done then return end
     record.BodyDone=true;yes(record.BodyResolve,U);component.Remaining-=1
     if component.Remaining==0 then
      component.Done=true
      for _,member in component.Members do member.Status='evaluated';yes(member.EvalResolve,namespace(member))end
     end
    end
    local ok,result=pcall(vm.EvaluateModule,vm,record.ScopeRecord)
    if not ok then reject(VM.exceptionValue(result));return end
    if record.AST.HasTopLevelAwait then await(result,done,reject)else done()end
   end
   if component.Invalid then reject(component.Invalid);return end
   local remaining=0
   for _,target in record.Dependencies do
    if target.InEvaluationStack then continue end
    start(target)
    if target.BodyDone then if target.Error then reject(target.Error);return end
    else
     remaining+=1
     await(target.BodyPromise,function()remaining-=1;if remaining==0 then run()end end,reject)
    end
   end
   record.InEvaluationStack=false
   if remaining==0 then run()end
  end
  start(root)
 end
 function api:Prepare(specifier,base,attributes,inlineSource)
  local promise,resolve,reject=capability()
  local ok,root=pcall(function()
   local href=if inlineSource~=nil then specifier else self:Resolve(specifier,base)
   return loadRecord(href,moduleType(attributes),inlineSource,if inlineSource~=nil then base else nil)
  end)
  if not ok then no(reject,VM.exceptionValue(root));return promise end
  local pending,records,seen,failed=0,{},{},false
  local function rejectGraph(value)if failed then return end;failed=true;no(reject,value)end
  local collect
  local function finishGraph()
   if failed or pending~=0 then return end
   local good,message=pcall(function()link(records)end)
   if not good then rejectGraph(VM.exceptionValue(message));return end
   yes(resolve,root)
  end
  collect=function(record)
   if seen[record]then return end;seen[record]=true;pending+=1;table.insert(records,record)
   await(record.Loaded,function()
    local good,message=pcall(function()
     for _,request in record.AST.Requests do
      local dependency=loadRecord(api:Resolve(request.Specifier,record.URL),moduleType(request.Attributes))
      record.Requests[request]=dependency
      if not table.find(record.Dependencies,dependency)then table.insert(record.Dependencies,dependency)end
      collect(dependency)
     end
    end)
    pending-=1;if not good then rejectGraph(VM.exceptionValue(message))else finishGraph()end
   end,rejectGraph)
  end
  collect(root);return promise
 end
 function api:Evaluate(record)
  local ok,message=pcall(evaluateGraph,record,{})
  if not ok then no(record.EvalReject,VM.exceptionValue(message))end
  return record.Evaluated
 end
 function api:Run(specifier,base,attributes,inlineSource)
  local promise,resolve,reject=capability()
  await(self:Prepare(specifier,base,attributes,inlineSource),function(record)
   await(self:Evaluate(record),function(value)yes(resolve,value)end,function(value)no(reject,value)end)
  end,function(value)no(reject,value)end)
  return promise
 end
 vm.ModuleLoader=api
 vm.ImportModule=function(specifier,importOptions,base,referrerVM)
  local attributes={}
  local promise,resolve,reject=capability()
  local ok,result=pcall(function()
   specifier=text(specifier)
   if importOptions~=U and importOptions~=nil then
    if not vm.ObjectModel.IsObject(importOptions)then fail('TypeError','Import options must be an object')end
    local values=vm.Get(importOptions,'with')
    if values~=U then
     if not vm.ObjectModel.IsObject(values)then fail('TypeError','Import attributes must be an object')end
     for _,key in vm.OwnKeys(values,false)do if type(key)=='string'then
      local descriptor=vm.GetOwnPropertyDescriptor(values,key)
      if descriptor~=U and VM.truth(vm.Get(descriptor,'enumerable'))then
       local value=vm.Get(values,key);if type(value)~='string'then fail('TypeError','Import attribute must be a string')end;attributes[key]=value
      end
     end end
    end
   end
   -- The import expression's promise belongs to this VM. A non-null active
   -- script can belong to another realm; its settings select the module graph
   -- and import map independently of the function/promise realm.
   local loader=if referrerVM then referrerVM.ModuleLoader else api
   if not loader or not loader.Alive then fail('TypeError','Dynamic import requires a live referring module loader')end
   return loader:Run(specifier,base,attributes)
  end)
  -- HTML's completion of dynamic module fetching uses the networking task
  -- source even when the module map already contains this record.
  local function complete(resolveOrReject,value)
   options.QueueTask(function()if api.Alive then resolveOrReject(value)end end)
  end
  if ok then await(result,function(value)complete(function(v)yes(resolve,v)end,value)end,
   function(value)complete(function(v)no(reject,v)end,value)end)else no(reject,VM.exceptionValue(result))end
  return promise
 end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false;vm.ImportModule=nil;vm.ModuleLoader=nil
  for _,cancel in cancellations do pcall(cancel)end
  table.clear(cancellations);table.clear(self.Records);table.clear(resolvedSpecifiers);table.clear(importMap.Imports);table.clear(importMap.Scopes);table.clear(options)
 end
 return api
end
return Modules
