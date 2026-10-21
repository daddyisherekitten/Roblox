--!strict
-- One live selection per browsing document. Range owns boundary adjustments;
-- this controller owns direction, identity, event tasks and native paint.
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Navigation=require(script.Parent.SelectionNavigation)
local Selection={}
-- A live wrapper privately retains its implementation record. The shared
-- lookup authenticates borrowed Web-IDL methods without rooting either side
-- of the wrapper/realm cycle (Luau weak-key tables are not ephemerons).
local sharedSelections=setmetatable({},{__mode='kv'})
function Selection.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U,N=VM.Undefined,VM.Null
 local ranges=assert(options.Ranges);local document=options.Unwrap(options.Document)
 local api={Alive=true,PendingPaint=false};local current=nil;local direction='none';local queued=false;local painting=false
 local cross=nil;local publicScope=nil;local scrollPending=false
 local prototype=vm.Object({});local value=vm.Object({},prototype);value.SelectionState=true
 local views=setmetatable({},{__mode='k'});views[value]=document
 local rootViews=setmetatable({},{__mode='kv'})
 local operations,getters={},{}
 local owner={VM=vm,Operations=operations,Getters=getters}
 local function register(target)
  target.SelectionOwner=owner;sharedSelections[target]=owner
 end
 register(value)
 local function check()assert(api.Alive and vm.Alive,'JavaScript selection disposed')end
 local function fail(name,message)VM.throw(if options.Events and name~='TypeError'then options.Events:DOMException(message,name)else VM.error(name,message))end
 local function receiver(target)
  check();local origin=sharedSelections[target]
  if not origin or not origin.VM.Alive then fail('TypeError','Selection called on incompatible receiver')end
  return origin
 end
 local function arg(args,index)return if args[index]==nil then U else args[index]end
 local function required(args,count)if #args<count then fail('TypeError','Not enough Selection arguments')end end
 local function uint(item)
  local number=VM.number(vm.ToPrimitive(item,'number'))
  if number~=number or math.abs(number)==math.huge or number==0 then return 0 end
  return(if number<0 then math.ceil(number)else math.floor(number))%4294967296
 end
 local function node(item,nullable)
  if nullable and(item==U or item==N)then return nil end
  return options.Unwrap(item)
 end
 local function state()
  if cross then
   local a,f=ranges.State(cross.Anchor),ranges.State(cross.Focus)
   return if direction=='backward'then {StartNode=f.StartNode,StartOffset=f.StartOffset,EndNode=a.StartNode,EndOffset=a.StartOffset}
    else {StartNode=a.StartNode,StartOffset=a.StartOffset,EndNode=f.StartNode,EndOffset=f.StartOffset}
  end
  return if current then ranges.State(current)else nil
 end
 local function collapsed(s)return s.StartNode==s.EndNode and s.StartOffset==s.EndOffset end
 local function connected(s)return s~=nil and ShadowTree.Connected(s.StartNode,document)and ShadowTree.Connected(s.EndNode,document)end
 local function endpoints(s)
  if direction~='forward'then return s.EndNode,s.EndOffset,s.StartNode,s.StartOffset end
  return s.StartNode,s.StartOffset,s.EndNode,s.EndOffset
 end
 local function define(target,key,d)vm.DefineProperty(target,key,vm.Object(d,N))end
 local function native(name,length,fn)
  local f={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,VMOwner=vm,Call=function(args,target)check();return fn(args,target)end}
  define(f,'length',{value=length,configurable=true});define(f,'name',{value=name,configurable=true});return f
 end
 local function method(name,length,fn)
  local f=native(name,length,function(args,target)
   local origin=receiver(target)
   if origin~=owner then return origin.VM:Call(assert(origin.Operations[name],'Missing Selection operation'),args,target)end
   return fn(args,target)
  end)
  operations[name]=f
  define(prototype,name,{value=f,writable=true,enumerable=true,configurable=true});return f
 end
 local function accessor(name,fn)
  local getter=native('get '..name,0,function(_,target)
   local origin=receiver(target)
   if origin~=owner then return origin.VM:Call(assert(origin.Getters[name],'Missing Selection getter'),{},target)end
   return fn(target)
  end)
  getters[name]=getter
  define(prototype,name,{get=getter,enumerable=true,configurable=true})
 end
 local function changed()
  api.PendingPaint=true
  if options.SchedulePaint then options.SchedulePaint()end
  if not queued then
   queued=true
   local ok,message=pcall(options.QueueTask,function()
    if not api.Alive then return end;queued=false
    options.Events:Dispatch(options.TargetFor(document),options.Events:NewEvent('selectionchange',{},'Event'),true)
   end)
   if not ok then queued=false;error(message,0)end
  end
 end
 local function associate(range,newDirection,scope)
  current=range;cross=nil;publicScope=scope;direction=newDirection or direction;changed()
 end
 local function clear()
  if current then current=nil;cross=nil;publicScope=nil;direction='none';changed()end
 end
 local function validateOffset(target,offset)
  if target.Kind=='DocumentType'or target.Kind=='Attr'then fail('InvalidNodeTypeError','Invalid selection boundary node')end
  if offset>ranges.Length(target)then fail('IndexSizeError','Selection offset exceeds node length')end
 end
 local function compareComposed(a,ao,b,bo)
  if ranges.Root(a)==ranges.Root(b)then return ranges.Compare(a,ao,b,bo)end
  local function chain(node)
   local result={};while node do vm.Step();table.insert(result,1,node);node=node.Parent or(if node.Kind=='ShadowRoot'then node.Host else nil)end;return result
  end
  local left,right=chain(a),chain(b);local i=1
  while left[i]and right[i]and left[i]==right[i]do i+=1 end
  if i>#left then local child=right[i];return if child.Kind=='ShadowRoot'or ranges.Index(child)>=ao then -1 else 1 end
  if i>#right then local child=left[i];return if child.Kind=='ShadowRoot'or ranges.Index(child)>=bo then 1 else -1 end
  local li=if left[i].Kind=='ShadowRoot'then -1 else ranges.Index(left[i])
  local ri=if right[i].Kind=='ShadowRoot'then -1 else ranges.Index(right[i])
  return if li<ri then -1 else 1
 end
 local function setBase(anchor,anchorOffset,focus,focusOffset,scope)
  validateOffset(anchor,anchorOffset);validateOffset(focus,focusOffset)
  if not ShadowTree.Connected(anchor,document)or not ShadowTree.Connected(focus,document)then return end
  local order=compareComposed(anchor,anchorOffset,focus,focusOffset)
  local nextDirection=if order>0 then 'backward'else 'forward'
  if ranges.Root(anchor)~=ranges.Root(focus)then
   local a,f=ranges.New(anchor,anchorOffset,anchor,anchorOffset),ranges.New(focus,focusOffset,focus,focusOffset)
   current=f;cross={Anchor=a,Focus=f};direction=nextDirection;publicScope=scope;changed()
  else
   local r=if order<=0 then ranges.New(anchor,anchorOffset,focus,focusOffset)else ranges.New(focus,focusOffset,anchor,anchorOffset)
   associate(r,nextDirection,scope)
  end
 end
 local function visibleState(target)
  local s=state();if not connected(s)then return nil end
  local scope=views[target]
  if scope~=document and not ShadowTree.InclusiveDescendant(s.StartNode,scope)and not ShadowTree.InclusiveDescendant(s.EndNode,scope)then return nil end
  return s
 end
 local function pointInScope(n,o,scope)
  local root=ranges.Root(n)
  while root.Kind=='ShadowRoot'and root~=scope do vm.Step();local host=root.Host
   if not host.Parent then return nil,0 end
   n,o=host.Parent,ranges.Index(host);root=ranges.Root(n)
  end
  return n,o
 end
 local function publicEndpoints(target)
  local s=visibleState(target);if not s then return nil,0,nil,0 end
  if target==value and cross then return endpoints(ranges.State(current))end
  local a,ao,f,fo=endpoints(s);local scope=views[target]
  if scope~=document or publicScope then a,ao=pointInScope(a,ao,scope);f,fo=pointInScope(f,fo,scope)end
  return a,ao,f,fo
 end
 accessor('anchorNode',function(target)local a=publicEndpoints(target);return if a then options.Wrap(a)else N end)
 accessor('anchorOffset',function(target)local _,a=publicEndpoints(target);return a end)
 accessor('focusNode',function(target)local _,_,f=publicEndpoints(target);return if f then options.Wrap(f)else N end)
 accessor('focusOffset',function(target)local _,_,_,f=publicEndpoints(target);return f end)
 accessor('isCollapsed',function(target)local a,ao,f,fo=publicEndpoints(target);return not a or a==f and ao==fo end)
 accessor('rangeCount',function(target)return if visibleState(target)then 1 else 0 end)
 accessor('type',function(target)local s=visibleState(target);return if not s then 'None'elseif collapsed(s)then 'Caret'else 'Range'end)
 accessor('direction',function()return if current then direction else 'none'end)
 method('getRangeAt',1,function(args,target)
  required(args,1);local index=uint(arg(args,1));if index~=0 or not visibleState(target)then fail('IndexSizeError','Selection range index is out of bounds')end
  if target==value and not publicScope then return current end
  local a,ao,f,fo=publicEndpoints(target)
  return if compareComposed(a,ao,f,fo)<=0 then ranges.New(a,ao,f,fo)else ranges.New(f,fo,a,ao)
 end)
 method('addRange',1,function(args)
  required(args,1);local range=arg(args,1);local s=ranges.State(range)
  if connected(s)and not connected(state())then associate(range,if collapsed(s)then 'none'else 'forward')end;return U
 end)
 method('removeRange',1,function(args)
  required(args,1);local range=arg(args,1);ranges.State(range)
  if current~=range then fail('NotFoundError','Range is not associated with this selection')end;clear();return U
 end)
 method('removeAllRanges',0,function()clear();return U end)
 method('empty',0,function()clear();return U end)
 local collapse=method('collapse',1,function(args,receiverValue)
  required(args,1);local target=node(arg(args,1),true);local offset=uint(arg(args,2))
  if not target then clear();return U end;validateOffset(target,offset)
  if ShadowTree.Connected(target,document)then associate(ranges.New(target,offset,target,offset),'none',if views[receiverValue]~=document then views[receiverValue]else nil)end;return U
 end)
 method('setPosition',1,function(args,target)return collapse.Call(args,target)end)
 for _,name in {'collapseToStart','collapseToEnd'}do method(name,0,function(_,target)
  local s=state();if not s then fail('InvalidStateError','Selection is empty')end
  local n,o=if name=='collapseToStart'then s.StartNode else s.EndNode,if name=='collapseToStart'then s.StartOffset else s.EndOffset
  associate(ranges.New(n,o,n,o),'none',if views[target]~=document then views[target]else nil);return U
 end)end
 method('extend',1,function(args,receiverValue)
  required(args,1);local target=node(arg(args,1));local offset=uint(arg(args,2))
  if not ShadowTree.Connected(target,document)then return U end
  local s=state();if not s then fail('InvalidStateError','Selection is empty')end
  validateOffset(target,offset);local anchor,ao=endpoints(s)
  setBase(anchor,ao,target,offset,if views[receiverValue]~=document then views[receiverValue]else nil);return U
 end)
 method('setBaseAndExtent',4,function(args,target)
  required(args,4);local anchor=node(arg(args,1));local ao=uint(arg(args,2));local focus=node(arg(args,3));local fo=uint(arg(args,4))
  setBase(anchor,ao,focus,fo,if views[target]~=document then views[target]else nil);return U
 end)
 method('selectAllChildren',1,function(args,receiverValue)
  required(args,1);local target=node(arg(args,1))
  if target.Kind=='DocumentType'then fail('InvalidNodeTypeError','Cannot select a document type')end
  if ShadowTree.Connected(target,document)then associate(ranges.New(target,0,target,#target.Children),'forward',if views[receiverValue]~=document then views[receiverValue]else nil)end;return U
 end)
 method('getComposedRanges',0,function(args)
  local init=arg(args,1);local permitted={}
  if init~=U and init~=N then
   if not vm.ObjectModel.IsObject(init)then fail('TypeError','Selection options must be a dictionary')end
   local roots=vm.Get(init,'shadowRoots')
   if roots~=U then
    if not vm.ObjectModel.IsObject(roots)then fail('TypeError','shadowRoots must be an iterable object')end
    local nextValue=vm.Iterator(roots);local count=0
    while true do vm.Step();local more,entry=nextValue();if not more then break end
     local root=node(entry);if root.Kind~='ShadowRoot'then fail('TypeError','shadowRoots requires ShadowRoot nodes')end
     table.insert(permitted,root)
     count+=1;if count>16384 then fail('RangeError','Selection shadow-root budget exceeded')end
    end
   end
  end
  local s=state();if not s then return vm.Array({})end
  local function rescope(container,offset,last)
   local root=ranges.Root(container)
   while root.Kind=='ShadowRoot'do
    local allowed=false;for _,entry in permitted do if ShadowTree.InclusiveDescendant(entry,root)then allowed=true;break end end
    if allowed then break end
    local host=root.Host;if not host.Parent then break end
    container,offset=host.Parent,ranges.Index(host)+(if last then 1 else 0);root=ranges.Root(container)
   end
   return container,offset
  end
  local sn,so=rescope(s.StartNode,s.StartOffset,false);local en,eo=rescope(s.EndNode,s.EndOffset,true)
  return vm.Array({ranges.NewStatic({StartNode=sn,StartOffset=so,EndNode=en,EndOffset=eo})})
 end)
 -- Tree-edge boundary points can represent the same visible position.
 -- Keep this structural equivalence separate from raw Range point ordering.
 local function equivalent(an,ao,bn,bo)
  if an==bn and ao==bo then return true end
  local points,seen,work={},{},{{an,ao}}
  while #work>0 do
   vm.Step();local p=table.remove(work);local n,o=p[1],p[2]
   local visited=seen[n];if not visited then visited={};seen[n]=visited end
   if visited[o]then continue end;visited[o]=true;table.insert(points,p)
   if #points>512 then fail('RangeError','Selection boundary budget exceeded')end
   if n.Parent then local index=assert(table.find(n.Parent.Children,n))-1
    if o==0 then table.insert(work,{n.Parent,index})end
    if o==ranges.Length(n)then table.insert(work,{n.Parent,index+1})end
   end
  end
  work={{bn,bo}};seen={};local total=0
  while #work>0 do
   vm.Step();total+=1;if total>512 then fail('RangeError','Selection boundary budget exceeded')end
   local p=table.remove(work);local n,o=p[1],p[2];local visited=seen[n];if not visited then visited={};seen[n]=visited end
   if visited[o]then continue end;visited[o]=true
   for _,q in points do if n==q[1]and o==q[2]then return true end end
   if n.Parent then local index=assert(table.find(n.Parent.Children,n))-1
    if o==0 then table.insert(work,{n.Parent,index})end
    if o==ranges.Length(n)then table.insert(work,{n.Parent,index+1})end
   end
  end;return false
 end
 method('containsNode',1,function(args)
  required(args,1);local target=node(arg(args,1));local partial=VM.truth(arg(args,2));local s=state()
  if not connected(s)or ranges.Root(target)~=ranges.Root(s.StartNode)or ranges.Root(target)~=ranges.Root(s.EndNode)then return false end
  local length=ranges.Length(target)
  local function compare(an,ao,bn,bo)return if equivalent(an,ao,bn,bo)then 0 else ranges.Compare(an,ao,bn,bo)end
  if partial then return compare(s.StartNode,s.StartOffset,target,length)<=0 and compare(s.EndNode,s.EndOffset,target,0)>=0 end
  return compare(s.StartNode,s.StartOffset,target,0)<=0 and compare(s.EndNode,s.EndOffset,target,length)>=0
 end)
 local rangePrototype=vm.Get(globals.Range,'prototype')
 local rangeString=vm.Get(rangePrototype,'toString');local rangeDelete=vm.Get(rangePrototype,'deleteContents')
 method('deleteFromDocument',0,function()
  if connected(state())then vm:Call(rangeDelete,{},current)end;return U
 end)
 method('toString',0,function()
  if options.ControlText then local text=options.ControlText();if text~=nil then return text end end
  local s=state();if not s then return ''end
  if cross then
   local sn,so=pointInScope(s.StartNode,s.StartOffset,document);local en,eo=pointInScope(s.EndNode,s.EndOffset,document)
   local root=ranges.Root(s.EndNode);if root.Kind=='ShadowRoot'and root.Host and root.Host.Parent then eo+=1 end
   if options.RenderedText then return options.RenderedText({StartNode=sn,StartOffset=so,EndNode=en,EndOffset=eo,TrailingBlockBreaks=true})end
   local r=ranges.New(sn,so,en,eo);return vm:Call(rangeString,{},r)
  end
  if options.RenderedText then return options.RenderedText(s)end
  return vm:Call(rangeString,{},current)
 end)
 local navigation=Navigation.new(vm,{Ranges=ranges,StyleFor=options.StyleFor,MoveVisual=options.MoveVisual})
 local ALTER={move=true,extend=true};local DIRECTIONS={forward=true,backward=true,left=true,right=true}
 local GRANULARITIES={character=true,word=true,sentence=true,line=true,paragraph=true,lineboundary=true,sentenceboundary=true,paragraphboundary=true,documentboundary=true}
 local function domString(item)
  local primitive=vm.ToPrimitive(item,'string');if type(primitive)=='table'and primitive.Kind=='symbol'then fail('TypeError','Cannot convert Symbol to DOMString')end
  return VM.string(primitive):lower()
 end
 method('modify',0,function(args,target)
  local alter,moveDirection,granularity=domString(arg(args,1)),domString(arg(args,2)),domString(arg(args,3))
  if not ALTER[alter]or not DIRECTIONS[moveDirection]or not GRANULARITIES[granularity]then return U end
  local s=state();if not connected(s)then return U end
  local a,ao,f,fo=endpoints(s)
  local forward=moveDirection=='forward'or moveDirection=='right'
  if moveDirection=='left'or moveDirection=='right'then if navigation:Direction(f)=='rtl'then forward=not forward end end
  local n,o
  if alter=='move'and not collapsed(s)and granularity=='character'then
   n,o=if forward then s.EndNode else s.StartNode,if forward then s.EndOffset else s.StartOffset
  else n,o=navigation:Move(f,fo,forward,granularity)end
  if alter=='move'then associate(ranges.New(n,o,n,o),'none',if views[target]~=document then views[target]else nil)
  else setBase(a,ao,n,o,if views[target]~=document then views[target]else nil)end
  scrollPending=true;return U
 end)
 define(prototype,vm.SymbolToStringTag,{value='Selection',configurable=true})
 local constructor=native('Selection',0,function()fail('TypeError','Illegal Selection constructor')end)
 constructor.Construct=function()fail('TypeError','Illegal Selection constructor')end
 define(constructor,'prototype',{value=prototype});define(prototype,'constructor',{value=constructor,writable=true,configurable=true})
 globals.Selection=constructor;vm.Global.Bindings.Selection={Value=constructor}
 local getWindow=native('getSelection',0,function(_,target)
  if target~=nil and target~=U and target~=N and target~=globals.window then fail('TypeError','Window.getSelection called on incompatible receiver')end
  return value
 end)
 local getDocument=native('getSelection',0,function(_,target)
  local n=node(target);if n.Kind~='Document'and n.Kind~='ShadowRoot'then fail('TypeError','getSelection requires a document or shadow root')end
  if n==document then return value end
  if n.Kind~='ShadowRoot'or(n.OwnerDocument or ShadowTree.Root(n,true))~=document then return N end
  if not rootViews[n]then local view=vm.Object({},prototype);view.SelectionState=true;views[view]=n;rootViews[n]=view;register(view)end
  return rootViews[n]
 end)
 globals.getSelection=getWindow;vm.Global.Bindings.getSelection={Value=getWindow}
 api.Value=value
 function api:DocumentMethod(key)return if key=='getSelection'then getDocument else nil end
 function api:RangeChanged(range,kind)
  if self.Alive and(current==range or cross and(cross.Anchor==range or cross.Focus==range))then
   if kind=='content'then self.PendingPaint=true;if options.SchedulePaint then options.SchedulePaint()end
   else changed()end
  end
 end
 function api:FlushPaint()
  check();if not self.PendingPaint or painting then return end;self.PendingPaint=false;painting=true
  local ok,result=pcall(function()
   local s=state();if options.Adapter then
    if connected(s)then local a,ao,f,fo=endpoints(s);options.Adapter:Apply(a,ao,f,fo)
     if scrollPending and options.Adapter.ScrollFocus then scrollPending=false;options.Adapter:ScrollFocus(f,fo)end
    else options.Adapter:Clear()end
   end
  end);painting=false;if not ok then error(result,0)end
 end
 function api:NativeChange(anchor,ao,focus,fo)
  check();if painting then return true end
  if not anchor or not focus then
   -- Clicking a nonselectable surface cannot disassociate a user selection.
   -- Explicit script removeAllRanges remains the path that empties it.
   if current then self.PendingPaint=true;return false end;return true
  end
  validateOffset(anchor,ao);validateOffset(focus,fo)
  if not ShadowTree.Connected(anchor,document)or not ShadowTree.Connected(focus,document)then return false end
  local previous=state()
  if connected(previous)then local a,o,f,p=endpoints(previous);if a==anchor and o==ao and f==focus and p==fo then return true end end
  if not previous or collapsed(previous)then
   local start=if compareComposed(anchor,ao,focus,fo)<=0 then anchor else focus
   local event=options.Events:NewEvent('selectstart',{bubbles=true,cancelable=true},'Event')
   if not options.Events:Dispatch(options.TargetFor(start),event,true)then self.PendingPaint=true;return false end
   -- The selectstart listener may remove either proposed endpoint.
   if not ShadowTree.Connected(anchor,document)or not ShadowTree.Connected(focus,document)or ao>ranges.Length(anchor)or fo>ranges.Length(focus)then self.PendingPaint=true;return false end
  end
  setBase(anchor,ao,focus,fo);scrollPending=true;return true
 end
 function api:Snapshot()
  local s=state();if not connected(s)then return nil end
  local a,ao,f,fo=endpoints(s)
  return {AnchorNode=a,AnchorOffset=ao,FocusNode=f,FocusOffset=fo,
   StartNode=s.StartNode,StartOffset=s.StartOffset,EndNode=s.EndNode,EndOffset=s.EndOffset,Direction=direction}
 end
 function api:CurrentRange()return if not cross and connected(state())then current else nil end
 function api:SetRaw(a,ao,f,fo)
  check();setBase(a,ao,f,fo);scrollPending=true
 end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false;current=nil;cross=nil;publicScope=nil;queued=false;self.PendingPaint=false
  for target in views do sharedSelections[target]=nil;target.SelectionOwner=nil end
  navigation:Destroy();table.clear(views);table.clear(rootViews);table.clear(operations);table.clear(getters)
  self.Value=nil;rangeString=nil;rangeDelete=nil;table.clear(options)
 end
 return api
end
return Selection
