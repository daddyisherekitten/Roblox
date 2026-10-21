--!strict
-- Same-document URL/history state. Document loads/reloads are host requests;
-- accepting a request never fabricates a loaded document or lifecycle event.
local Strings=require(script.Parent.Strings)
local Navigation={}
function Navigation.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null;local events=assert(options.Events);local clone=assert(options.Clone,'Navigation requires StructuredClone')
 local api={Alive=true};local locationProto=vm.Object({});local historyProto=vm.Object({});local location=vm.Object({},locationProto);local history=vm.Object({},historyProto)
 local urlConstructor=vm.Global.Bindings.URL.Value;local eventStates=setmetatable({},{__mode='kv'});local entries={};local index=1;local state=N;local restoration='auto';local maxEntries=options.MaxEntries or 256
 local function check()assert(api.Alive and vm.Alive,'JavaScript navigation disposed')end
 local function fail(name,message)VM.throw(if name=='TypeError'then VM.error(name,message)else events:DOMException(message,name))end
 local function active()if options.IsFullyActive and not options.IsFullyActive()then fail('SecurityError','Document is not fully active')end end
 local function arg(args,i)return if args[i]==nil then U else args[i]end
 local function text(value)
  value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then fail('TypeError','Cannot convert a Symbol to navigation text')end
  local result=VM.string(value);if #result>65536 then fail('TypeError','Navigation text budget exceeded')end;return result
 end
 local function usv(value)
  local units=Strings.units(text(value));local i=1;while i<=#units do local a,b=units[i],units[i+1]
   if a>=0xd800 and a<=0xdbff and b and b>=0xdc00 and b<=0xdfff then i+=2 elseif a>=0xd800 and a<=0xdfff then units[i]=0xfffd;i+=1 else i+=1 end
  end;return Strings.fromUnits(units)
 end
 local function required(args,n,name)if #args<n then fail('TypeError',name..' requires '..n..' arguments')end end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,VM.Null))end
 local function native(name,n,fn)
  local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}
  define(value,'length',{value=n,configurable=true});define(value,'name',{value=name,configurable=true});return value
 end
 local function method(target,name,n,fn,unforgeable)define(target,name,{value=native(name,n,fn),writable=not unforgeable,enumerable=true,configurable=not unforgeable})end
 local function accessor(target,name,read,write,unforgeable)
  define(target,name,{get=native('get '..name,0,function(_,receiver)return read(receiver)end),
   set=if write then native('set '..name,1,function(args,receiver)write(receiver,arg(args,1));return U end)else U,enumerable=true,configurable=not unforgeable})
 end
 local function brand(receiver,expected,name)if receiver~=expected then fail('TypeError',name..' called on incompatible receiver')end end
 local function parse(input,base,errorName)
  local ok,result=pcall(function()return vm:Construct(urlConstructor,if base then {input,base}else {input})end)
  if not ok then fail(errorName or 'SyntaxError','Invalid navigation URL')end;return result
 end
 local current=parse(options.URL or 'about:blank',nil)
 local function href(value)return vm.Get(value or current,'href')end
 local function hash(value)return vm.Get(value or current,'hash')end
 local function withoutHash(value)return href(value):gsub('#.*$','')end
 local function changed(kind)
  if options.URLChanged then options.URLChanged(href(),kind)end
 end
 local function queue(fn)assert(options.QueueTask,'Navigation requires a queued task adapter');options.QueueTask(function()if api.Alive then fn()end end)end
 local function event(typeName,proto,values,trusted)
  local value=events:NewEvent(typeName,values);value.Prototype=proto;value.NavigationEventState=values;eventStates[value]={Values=values,Prototype=proto};return value
 end
 local eventProto=vm.Get(globals.Event,'prototype');local hashProto=vm.Object({},eventProto);local popProto=vm.Object({},eventProto);vm.Prototypes.HashChangeEvent,vm.Prototypes.PopStateEvent=hashProto,popProto
 local function eventBrand(receiver,name,proto)local r=eventStates[receiver];if not r or r.Prototype~=proto then fail('TypeError',name..' called on incompatible receiver')end;return r.Values end
 for _,item in {{hashProto,'oldURL','HashChangeEvent'},{hashProto,'newURL','HashChangeEvent'},{popProto,'state','PopStateEvent'},{popProto,'hasUAVisualTransition','PopStateEvent'}}do
  accessor(item[1],item[2],function(receiver)return eventBrand(receiver,item[3]..'.'..item[2],item[1])[item[2]]end)
 end
 for _,item in {{'HashChangeEvent',hashProto},{'PopStateEvent',popProto}}do
  local name,proto=item[1],item[2];if vm.SymbolToStringTag then define(proto,vm.SymbolToStringTag,{value=name,configurable=true})end
  local ctor=native(name,1,function()fail('TypeError',name..' requires new')end)
  ctor.Construct=function(args)
   required(args,1,name);local typeName=text(args[1]);local init=arg(args,2);if init~=U and init~=N and not vm.ObjectModel.IsObject(init)then fail('TypeError','Event options must be a dictionary')end
   local values={};local fields=if name=='HashChangeEvent'then {'bubbles','cancelable','composed','newURL','oldURL'}else {'bubbles','cancelable','composed','hasUAVisualTransition','state'}
   for _,field in fields do local value=if init==U or init==N then U else vm.Get(init,field)
    values[field]=if field=='state'then(if value==U then N else value)elseif field=='oldURL'or field=='newURL'then(if value==U then ''else usv(value))else VM.truth(value)
   end;return event(typeName,proto,values)
  end
  define(ctor,'prototype',{value=proto});define(proto,'constructor',{value=ctor,writable=true,configurable=true});globals[name]=ctor;vm.Global.Bindings[name]={Value=ctor}
 end
 local function fireHash(oldURL,newURL)queue(function()events:Dispatch(options.Window,event('hashchange',hashProto,{oldURL=oldURL,newURL=newURL}),true)end)end
 local function append(entry)
  for i=#entries,index+1,-1 do entries[i]=nil end;table.insert(entries,entry);index=#entries
  if #entries>maxEntries then table.remove(entries,2);index-=1 end
 end
 entries[1]={URL=href(),State=nil,Restoration='auto'}
 local function captureScroll()if options.CaptureScroll then entries[index].Scroll=options.CaptureScroll()end end
 local function external(target,kind)
  if options.IsUnloading and options.IsUnloading()then return end
  active();if not options.Navigate then fail('NotSupportedError','Document navigation requires a host adapter')end
  local accepted=options.Navigate({URL=href(target),Kind=kind,SameDocument=false})
  if accepted==false then fail('NotSupportedError','The host cannot perform this navigation')end
 end
 local function navigate(target,kind,fragmentChange)
  if options.IsUnloading and options.IsUnloading()then return end
  active();local oldURL=href();local newURL=href(target)
  if(fragmentChange or target.Record.Fragment~=nil)and withoutHash(target)==withoutHash(current)then
   if newURL==oldURL then if options.ScrollToFragment then options.ScrollToFragment(vm.Get(target,'hash'))end;return end
   captureScroll()
   local entry={URL=newURL,State=nil,Restoration=restoration}
   if kind=='replace'then entries[index]=entry else append(entry)end
   current=target;state=N;changed(kind);if options.ScrollToFragment then options.ScrollToFragment(hash())end;fireHash(oldURL,newURL)
  else external(target,kind)end
 end
 local function setLocation(receiver,key,value)
  brand(receiver,location,'Location.'..key);local converted=usv(value);local target=parse(href(),nil)
  if key=='href'then target=parse(converted,href())else
   -- Location's hash setter retains an empty fragment, unlike URL.hash="".
   vm.Set(target,key,if key=='hash'and converted==''then '#'else converted);if key=='hash'and href(target)==href()then return end
  end;navigate(target,'assign',key=='hash')
 end
 for _,name in {'href','origin','protocol','host','hostname','port','pathname','search','hash'}do
  accessor(location,name,function(receiver)brand(receiver,location,'Location.'..name);return vm.Get(current,name)end,
   if name~='origin'then function(receiver,value)setLocation(receiver,name,value)end else nil,true)
 end
 for _,kind in {'assign','replace'}do method(location,kind,1,function(args,receiver)brand(receiver,location,'Location.'..kind);required(args,1,kind);navigate(parse(usv(args[1]),href()),kind);return U end,true)end
 method(location,'reload',0,function(_,receiver)brand(receiver,location,'Location.reload');external(current,'reload');return U end,true)
 method(location,'toString',0,function(_,receiver)brand(receiver,location,'Location.toString');return href()end,true)
 define(location,'valueOf',{value=vm.Get(vm.Prototypes.Object,'valueOf')})
 if vm.SymbolToPrimitive then define(location,vm.SymbolToPrimitive,{value=U})end
 if vm.SymbolToStringTag then define(locationProto,vm.SymbolToStringTag,{value='Location',configurable=true});define(historyProto,vm.SymbolToStringTag,{value='History',configurable=true})end
 local function illegal(name,proto)
  local ctor=native(name,0,function()fail('TypeError','Illegal '..name..' constructor')end);ctor.Construct=function()fail('TypeError','Illegal '..name..' constructor')end
  define(ctor,'prototype',{value=proto});define(proto,'constructor',{value=ctor,writable=true,configurable=true});globals[name]=ctor;vm.Global.Bindings[name]={Value=ctor}
 end
 illegal('Location',locationProto);illegal('History',historyProto);vm.Prototypes.Location,vm.Prototypes.History=locationProto,historyProto
 accessor(historyProto,'length',function(receiver)brand(receiver,history,'History.length');active();return #entries end)
 accessor(historyProto,'state',function(receiver)brand(receiver,history,'History.state');active();return state end)
 accessor(historyProto,'scrollRestoration',function(receiver)brand(receiver,history,'History.scrollRestoration');active();return restoration end,function(receiver,value)
  brand(receiver,history,'History.scrollRestoration');local converted=text(value);if converted~='auto'and converted~='manual'then return end;active();restoration=converted;entries[index].Restoration=converted
 end)
 local function canRewrite(target)
  for _,key in {'protocol','username','password','host'}do if vm.Get(target,key)~=vm.Get(current,key)then return false end end
  local protocol=vm.Get(target,'protocol');if protocol=='http:'or protocol=='https:'then return true end
  if vm.Get(target,'pathname')~=vm.Get(current,'pathname')then return false end
  return protocol=='file:'or vm.Get(target,'search')==vm.Get(current,'search')
 end
 for _,kind in {'push','replace'}do method(historyProto,kind..'State',2,function(args,receiver)
  brand(receiver,history,'History.'..kind..'State');required(args,2,kind..'State');text(args[2]);local targetURL=if args[3]==nil or args[3]==U or args[3]==N then nil else usv(args[3])
  active();local wire=clone:Serialize(args[1]);local target=current
  if targetURL and targetURL~=''then target=parse(targetURL,href(),'SecurityError');if not canRewrite(target)then fail('SecurityError','History URL cannot change document origin/components')end end
  captureScroll();local entry={URL=href(target),State=wire,Restoration=restoration,Scroll=entries[index].Scroll};if kind=='replace'then entries[index]=entry else append(entry)end
  current=target;state=clone:Deserialize(wire);changed(kind..'State');return U
 end)end
 local function traverse(delta)
  active();if delta==0 then external(current,'reload');return end
  queue(function()
   active();local nextIndex=index+delta;if nextIndex<1 or nextIndex>#entries then return end
   captureScroll()
   local previous=entries[index];local nextEntry=entries[nextIndex];local oldURL=href();index=nextIndex;current=parse(nextEntry.URL,nil);state=if nextEntry.State then clone:Deserialize(nextEntry.State)else N;restoration=nextEntry.Restoration;changed('traverse')
   events:Dispatch(options.Window,event('popstate',popProto,{state=state,hasUAVisualTransition=false}),true)
   if parse(previous.URL,nil).Record.Fragment~=current.Record.Fragment then events:Dispatch(options.Window,event('hashchange',hashProto,{oldURL=oldURL,newURL=href()}),true)end
   if restoration=='auto'and options.RestoreScroll then options.RestoreScroll(nextEntry)end
  end)
 end
 method(historyProto,'go',0,function(args,receiver)brand(receiver,history,'History.go');local n=VM.number(vm.ToPrimitive(arg(args,1),'number'));n=if n~=n or math.abs(n)==math.huge then 0 elseif n<0 then math.ceil(n)else math.floor(n);n=n%4294967296;if n>=2147483648 then n-=4294967296 end;traverse(n);return U end)
 method(historyProto,'back',0,function(_,receiver)brand(receiver,history,'History.back');traverse(-1);return U end)
 method(historyProto,'forward',0,function(_,receiver)brand(receiver,history,'History.forward');traverse(1);return U end)
 globals.location,globals.history=location,history
 vm.Global.Bindings.location={Get=function()return location end,Set=function(value)setLocation(location,'href',value)end}
 vm.Global.Bindings.history={Value=history,Set=function(_,strict)if strict then fail('TypeError','history is read-only')end end}
 function api.WindowGet(key)return if key=='location'then location elseif key=='history'then history else nil end
 function api:GetURL()return href()end
 function api:SetLocation(value)setLocation(location,'href',value)end
 function api:CommitNavigation(value,replace)
  check();local target=parse(value,nil);local entry={URL=href(target),State=nil,Restoration='auto'};if replace then entries[index]=entry else append(entry)end;current=target;state=N;restoration='auto';changed('commit')
 end
 function api:Destroy()self.Alive=false;table.clear(entries);table.clear(eventStates)end
 return api
end
return Navigation
