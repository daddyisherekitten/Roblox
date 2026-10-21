--!strict
-- CSSOM View over existing renderer data. The adapter owns native scrolling,
-- viewport notifications and one synchronous dirty-layout flush; this module
-- never schedules a render connection or recomputes an unchanged layout.
local Media=require(script.Parent.Parent.CSS.MediaQueries)
local Matrix=require(script.Parent.Parent.CSS.Matrix4)
local Transform=require(script.Parent.Parent.CSS.Transform2D)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Borders=require(script.Parent.Parent.Layout.BorderGeometry)
local Computed=require(script.Parent.ComputedStyle)
local Properties=require(script.Parent.Parent.CSS.Properties)
local GeometryMath=require(script.Parent.GeometryMath)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Geometry={}

function Geometry.install(vm: any,globals: any,adapter: any): any
 local VM=assert(vm.Model,'Geometry requires vm.Model');local U,N=VM.Undefined,VM.Null
 adapter=table.clone(adapter or {})
 local api={Alive=true};local flushing=false
 local geometryMath
 local rects,lists,styles,queries,mediaEvents={},{},{},{},{}
 for _,map in {rects,lists,styles,queries,mediaEvents}do setmetatable(map,{__mode='kv'})end
 local queryOrder=setmetatable({},{__mode='v'});local queryCount=0
 local eventHost=adapter.Events
 local readonlyProto,rectProto,listProto,styleProto,queryProto,mediaEventProto
 local function check()assert(api.Alive and vm.Alive,'JavaScript geometry disposed')end
 local function fail(name,message)VM.throw(if eventHost and name~='TypeError'and name~='RangeError'then eventHost:DOMException(message,name)else VM.error(name,message))end
 local function arg(args,index,default)return if args[index]==nil or args[index]==U then default or U else args[index]end
 local function object(value)return type(value)=='table'and value~=U and value~=N and value.Kind~='symbol'and value.Kind~='bigint'end
 local function number(value)return VM.number(vm.ToPrimitive(value,'number'))end
 local function text(value)
  value=vm.ToPrimitive(value,'string');if type(value)=='table'and value.Kind=='symbol'then fail('TypeError','Cannot convert Symbol to string')end
  local result=VM.string(value);if #result>65536 then fail('RangeError','JavaScript string budget exceeded')end;return result
 end
 local function finite(value)local n=number(value);return if n~=n or math.abs(n)==math.huge then 0 else n end
 local function integer(value)local n=number(value);return if n~=n or math.abs(n)==math.huge or n==0 then 0 elseif n<0 then math.ceil(n)else math.floor(n)end
 local function uint(value)return integer(value)%4294967296 end
 local function required(args,count,name)if #args<count then fail('TypeError',name..' requires '..count..' arguments')end end
 local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,VM.Null))end
 local function native(name,arity,fn)
  local value={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(args,receiver)check();return fn(args,receiver)end}
  define(value,'length',{value=arity,configurable=true});define(value,'name',{value=name,configurable=true});return value
 end
 local function method(proto,name,arity,fn)define(proto,name,{value=native(name,arity,fn),writable=true,enumerable=true,configurable=true})end
 local function accessor(proto,name,read,write)
  define(proto,name,{get=native('get '..name,0,function(_,receiver)return read(receiver)end),
   set=if write then native('set '..name,1,function(args,receiver)write(receiver,arg(args,1));return U end)else U,enumerable=true,configurable=true})
 end
 local function brand(map,value,name)check();local state=map[value];if not state then fail('TypeError',name..' called on incompatible receiver')end;return state end
 local function global(name,value)globals[name]=value;vm.Global.Bindings[name]={Value=value}end
 local function constructor(name,arity,proto,create)
  local value=native(name,arity,function()fail('TypeError',name..' requires new')end)
  value.Construct=function(args,newTarget)
   check();local prototype=vm.Get(newTarget or value,'prototype');if not object(prototype)then prototype=proto end
   local result=create(args);result.Prototype=prototype;return result
  end;define(value,'prototype',{value=proto});define(proto,'constructor',{value=value,writable=true,configurable=true});global(name,value);return value
 end
 function api:Flush()
  check();if flushing or not adapter.HasPending or not adapter.HasPending()then return end
  flushing=true;local ok,result=pcall(function()assert(adapter.Flush,'Geometry requires a synchronous Flush adapter');adapter.Flush()end);flushing=false
  if not ok then error(result,0)end
 end
 local function viewport()
  local view=if adapter.GetViewport then adapter.GetViewport()else {}
  return view or {}
 end
 local function tree()return if adapter.GetTree then adapter.GetTree()else nil end
 local function boxOf(node)local t=tree();return t and t.NodeBoxes and t.NodeBoxes[node]or adapter.GetBox and adapter.GetBox(node)end
 local function styleOf(node)local t=tree();return t and t.NodeStyles and t.NodeStyles[node]or boxOf(node)and boxOf(node).Style end
 local function element(value)
  local node=if adapter.Unwrap then adapter.Unwrap(value)elseif type(value)=='table'then value.DOMNode else nil
  if not node or node.Kind~='Element'then fail('TypeError','Expected an Element from this document')end;return node
 end
 local function wrap(node)return if node then(assert(adapter.Wrap,'Geometry requires Wrap'))(node)else N end
 local function isRoot(node)return node and node.Parent and node.Parent.Kind=='Document'end
 local function pageScroll(node)
  return isRoot(node)or(adapter.QuirksMode==true and node and node.Name=='body')
 end
 local function hidden(node)
  local current=node;local depth=0
  while current and current.Kind~='Document'do depth+=1;if depth>256 then fail('RangeError','Geometry ancestor budget exceeded')end
   local s=styleOf(current);if s and(s.Hidden or s.Display=='none')then return true end;current=ShadowTree.FlatParent(current)or(if current.Kind=='ShadowRoot'then current.Host else current.Parent)
  end
  return current==nil
 end
 local function ancestorBoxes(node)
  local result,seen={},{};local current=node
  while current do vm.Step();if #result>=256 then fail('RangeError','Geometry ancestor budget exceeded')end
   local box=boxOf(current);if box and not seen[box]then seen[box]=true;table.insert(result,box)end
   current=ShadowTree.FlatParent(current)or(if current.Kind=='ShadowRoot'then current.Host else current.Parent)
  end
  return result
 end
 local function scrollPosition(box)
  local position=box.ScrollGui and box.ScrollGui.CanvasPosition
  return if position then position.X or 0 else box.ScrollLeft or 0,if position then position.Y or 0 else box.ScrollTop or 0
 end
 local function size(box)return box.OuterWidth or box.Width or 0,box.OuterHeight or box.Height or 0 end
 local function localTransform(box)
  local s=box.Style or {};local width,height=size(box);local ref=Transform.layoutReference(s,width,height)
  local rw,rh,rx,ry=ref.W,ref.H,ref.X,ref.Y
  local m=Transform.matrix(box.TransformOverride or Transform.operations(s),rw,rh)
  local ox,oy=rw/2,rh/2;if s.TransformOrigin then ox,oy=Transform.origin(s.TransformOrigin,rw,rh)end
  return Matrix.around(m,rx+ox,ry+oy,if s.TransformOrigin and s.TransformOrigin.Z then Length.resolve(s.TransformOrigin.Z,0)else 0)
 end
 local function worldMatrix(node,transformed,scrolling)
  local chain=ancestorBoxes(node);local matrix=Matrix.identity();local fixed=false
  -- A viewport-fixed box leaves ordinary ancestor layout and scroll coordinates.
  local stop=#chain
  for i,box in chain do if box.Style and box.Style.Position=='fixed'and not box.FixedContainingBox then stop=i;fixed=true;break end end
  for i=stop,1,-1 do
   local box=chain[i];local x,y=box.PaintX or box.LayoutX or 0,box.PaintY or box.LayoutY or 0
   if fixed and i==stop then x,y=box.FixedViewportX or x,box.FixedViewportY or y end
   matrix=Matrix.multiply(matrix,Matrix.translate(x,y))
   if transformed then matrix=Matrix.multiply(matrix,localTransform(box))end
   if scrolling and i>1 then local sx,sy=scrollPosition(box);matrix=Matrix.multiply(matrix,Matrix.translate(-sx,-sy))end
  end
  if scrolling and not fixed then local view=viewport();matrix=Matrix.multiply(Matrix.translate(-(view.ScrollX or 0),-(view.ScrollY or 0)),matrix)end
  return matrix
 end
 local function project(matrix,x,y)
  local p=Matrix.point(matrix,x,y);if p.W==0 then return 0,0 end;return p.X/p.W,p.Y/p.W
 end
 local function projectedRect(matrix,width,height)
  local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
  for _,p in {{0,0},{width,0},{width,height},{0,height}}do local x,y=project(matrix,p[1],p[2]);left,top,right,bottom=math.min(left,x),math.min(top,y),math.max(right,x),math.max(bottom,y)end
  return {X=left,Y=top,Width=right-left,Height=bottom-top}
 end
 local function clientRects(node,untransformed)
  if hidden(node)then return {}end
  local callback=if untransformed then adapter.GetUntransformedClientRects else adapter.GetClientRects
  if callback then local list=callback(node);if list~=nil then if #list>4096 then fail('RangeError','Geometry fragment budget exceeded')end;return list end end
  local box=boxOf(node)
  if not box then
   local result={}
   for _,fragment in if adapter.GetLayoutFragments then adapter.GetLayoutFragments(node)else{}do
    if #result>=4096 then fail('RangeError','Geometry fragment budget exceeded')end
    local matrix=worldMatrix(fragment.Host,not untransformed,not untransformed)
    if not untransformed then local host=boxOf(fragment.Host);if host then local sx,sy=scrollPosition(host);matrix=Matrix.multiply(matrix,Matrix.translate(-sx,-sy))end end
    matrix=Matrix.multiply(matrix,Matrix.translate(fragment.X,fragment.Y))
    table.insert(result,projectedRect(matrix,fragment.Width,fragment.Height))
   end
   return result
  end
  local width,height=size(box);return {projectedRect(worldMatrix(node,not untransformed,not untransformed),width,height)}
 end
 local function union(list)
  if #list==0 then return {X=0,Y=0,Width=0,Height=0}end
  local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
  for _,r in list do
   left,top=math.min(left,r.X),math.min(top,r.Y);right,bottom=math.max(right,r.X+r.Width),math.max(bottom,r.Y+r.Height)
  end
  return {X=left,Y=top,Width=right-left,Height=bottom-top}
 end
 local function bounding(list)
  if #list==0 then return {X=0,Y=0,Width=0,Height=0}end
  local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge;local any=false
  local area=false;for _,r in list do if r.Width~=0 and r.Height~=0 then area=true;break end end
  if not area then return list[1]end
  for _,r in list do if r.Width==0 and r.Height==0 then continue end;any=true
   left,top=math.min(left,r.X),math.min(top,r.Y);right,bottom=math.max(right,r.X+r.Width),math.max(bottom,r.Y+r.Height)
  end
  return if any then {X=left,Y=top,Width=right-left,Height=bottom-top}else list[1]
 end
 readonlyProto=vm.Object({});rectProto=vm.Object({},readonlyProto);listProto=vm.Object({});styleProto=vm.Object({})
 local function rect(x,y,w,h,mutable)
  local state={x=x,y=y,width=w,height=h,Mutable=mutable};local value=vm.Object({},if mutable then rectProto else readonlyProto);value.GeometryState=state;rects[value]=state;return value
 end
 local function fromData(r,mutable)return rect(r.X or 0,r.Y or 0,r.Width or 0,r.Height or 0,mutable)end
 for _,name in {'x','y','width','height'}do
  accessor(readonlyProto,name,function(value)return brand(rects,value,'DOMRectReadOnly.'..name)[name]end)
  accessor(rectProto,name,function(value)local state=brand(rects,value,'DOMRect.'..name);if not state.Mutable then fail('TypeError','DOMRect requires mutable rectangle')end;return state[name]end,
   function(value,item)local state=brand(rects,value,'DOMRect.'..name);if not state.Mutable then fail('TypeError','DOMRect requires mutable rectangle')end;state[name]=number(item)end)
 end
 local function edges(state)
  return math.min(state.y,state.y+state.height),math.max(state.x,state.x+state.width),math.max(state.y,state.y+state.height),math.min(state.x,state.x+state.width)
 end
 for i,name in {'top','right','bottom','left'}do accessor(readonlyProto,name,function(value)return ({edges(brand(rects,value,'DOMRectReadOnly.'..name))})[i]end)end
 method(readonlyProto,'toJSON',0,function(_,value)local s=brand(rects,value,'DOMRectReadOnly.toJSON');local top,right,bottom,left=edges(s)
  return vm.Object({x=s.x,y=s.y,width=s.width,height=s.height,top=top,right=right,bottom=bottom,left=left},nil,{'x','y','width','height','top','right','bottom','left'})end)
 local function rectInit(value)
  if value~=U and value~=N and not object(value)then fail('TypeError','DOMRectInit must be a dictionary')end
  local result={};for _,name in {'height','width','x','y'}do local item=if value==U or value==N then U else vm.Get(value,name);result[name]=if item==U then 0 else number(item)end;return result
 end
 local function createRect(args,mutable)return rect(number(arg(args,1,0)),number(arg(args,2,0)),number(arg(args,3,0)),number(arg(args,4,0)),mutable)end
 local roConstructor=constructor('DOMRectReadOnly',0,readonlyProto,function(args)return createRect(args,false)end)
 local rectConstructor=constructor('DOMRect',0,rectProto,function(args)return createRect(args,true)end)
 vm.SetPrototype(rectConstructor,roConstructor)
 for _,entry in {{roConstructor,false},{rectConstructor,true}}do define(entry[1],'fromRect',{value=native('fromRect',0,function(args)local s=rectInit(arg(args,1));return rect(s.x,s.y,s.width,s.height,entry[2])end),writable=true,configurable=true,enumerable=true})end
 accessor(listProto,'length',function(value)return #brand(lists,value,'DOMRectList.length')end)
 method(listProto,'item',1,function(args,value)required(args,1,'DOMRectList.item');return brand(lists,value,'DOMRectList.item')[uint(args[1])+1]or N end)
 local function rectList(raw)
  local result=vm.Object({},listProto);local values={};result.GeometryState=values;lists[result]=values
  for i,r in raw do vm.Step();values[i]=fromData(r,true);define(result,tostring(i-1),{value=values[i],enumerable=true,configurable=true})end
  result.Iterator=function()local at=0;return function()at+=1;return at<=#values,values[at]or U end end
  if vm.SymbolIterator then define(result,vm.SymbolIterator,{value=native('values',0,function(_,receiver)
   local entries=brand(lists,receiver,'DOMRectList iterator');local at=0;local done=false;local iterator=vm.Object({},vm.Prototypes.Iterator)
   define(iterator,'next',{value=native('next',0,function(_,target)if target~=iterator then fail('TypeError','Invalid DOMRectList iterator')end
    if not done then at+=1;if at>#entries then done=true end end
    return vm.Object({value=if done then U else entries[at],done=done},nil,{'value','done'})end),writable=true,configurable=true})
   return iterator
  end),writable=true,configurable=true})end
  return result
 end
 local function offsetParent(node)
  local box=boxOf(node);local s=styleOf(node)or {}
  if hidden(node)or(not box and #clientRects(node,true)==0)or isRoot(node)or node.Name=='body'or(s.Position=='fixed'and not(box and box.FixedContainingBox))then return nil end
  local current=node.Parent
  while current and current.Kind~='Document'do
   local cs=styleOf(current)or {};local cb=boxOf(current)
   if cb and(current.Name=='body'or cs.Position and cs.Position~='static'or #Transform.operations(cs)>0 or cs.Contain and(cs.Contain.Layout or cs.Contain.Paint)or(s.Position==nil or s.Position=='static')and(current.Name=='table'or current.Name=='td'or current.Name=='th'))then return current end
   current=current.Parent
  end
  return nil
 end
 local function rounded(value)return math.floor(value+.5)end
 local function metrics(node)
  local supplied=adapter.GetMetrics and adapter.GetMetrics(node)or {};local result={}
  local box=boxOf(node);local s=styleOf(node)or {};local view=viewport();local root=pageScroll(node)
  local exists=not hidden(node)and(box~=nil or #clientRects(node,true)>0)
  local width,height=if box then size(box)else 0,0
  if box then width,height=size(box)end
  local bt,br,bb,bl=Borders.sizes(s)
  local sx,sy=0,0;if box then sx,sy=scrollPosition(box)end
  result.clientWidth=if root then view.ClientWidth or view.Width or 0 elseif not exists or s.Display=='inline'then 0 else math.max(0,width-bl-br-(box and box.ScrollY or 0))
  result.clientHeight=if root then view.ClientHeight or view.Height or 0 elseif not exists or s.Display=='inline'then 0 else math.max(0,height-bt-bb-(box and box.ScrollX or 0))
  result.clientLeft=if exists and s.Display~='inline'then bl+(box and box.ScrollLeadingX or 0)else 0;result.clientTop=if exists and s.Display~='inline'then bt+(box and box.ScrollLeadingY or 0)else 0
  result.scrollLeft=if root then view.ScrollX or 0 elseif exists then sx else 0;result.scrollTop=if root then view.ScrollY or 0 elseif exists then sy else 0
  result.scrollWidth=if root then math.max(view.ScrollWidth or 0,result.clientWidth)elseif exists then math.max(result.clientWidth,(box and(box.ScrollRight or box.UnclippedRight)or width)-bl-br)else 0
  result.scrollHeight=if root then math.max(view.ScrollHeight or 0,result.clientHeight)elseif exists then math.max(result.clientHeight,(box and(box.ScrollBottom or box.UnclippedBottom)or height)-bt-bb)else 0
  result.offsetParent=offsetParent(node)
  local fragments=clientRects(node,true)
  local raw=union(fragments);result.offsetWidth=raw.Width;result.offsetHeight=raw.Height
  local x,y=project(worldMatrix(node,false,false),0,0)
  if not box then local first=fragments[1];if first then x,y=first.X,first.Y end end
  if result.offsetParent then
   local parent=result.offsetParent;local ps=styleOf(parent)or {}
   -- Chromium's static body offset origin is the initial containing block,
   -- including when a child's margin has collapsed through the body.
   if parent.Name~='body'or ps.Position and ps.Position~='static'then
    local px,py=project(worldMatrix(parent,false,false),0,0);local pbt,_,_,pbl=Borders.sizes(ps)
    if parent.Name=='body'then pbt,pbl=0,0 end
    x-=px+pbl;y-=py+pbt
   end
  end
  result.offsetLeft=if exists and node.Name~='body'then x else 0;result.offsetTop=if exists and node.Name~='body'then y else 0
  for key,value in supplied do result[key]=value end
  for key,value in result do if type(value)=='number'and key~='scrollLeft'and key~='scrollTop'then result[key]=rounded(value)end end
  return result
 end
 local function computed(node,pseudo)
  api:Flush()
  if adapter.GetComputedProperties then local result=adapter.GetComputedProperties(node,pseudo);if result~=nil then return result end end
  -- CSSOM requires participation in the flat tree, not a rendered box. Hidden
  -- connected elements still have computed values; unslotted/detached ones do not.
  local current,depth=node,0
  while current and current.Kind~='Document'do
   depth+=1;if depth>256 then fail('RangeError','Geometry ancestor budget exceeded')end
   current=ShadowTree.FlatParent(current)
  end
  if not current then return {Names={},Values={}}end
  if pseudo~=''then
   local normalized=pseudo:lower()
   local name=normalized:match('^::([%a%-]+)$')
   if not name then
    local legacy=normalized:match('^:([%a%-]+)$')
    if legacy=='before'or legacy=='after'then name=legacy end
   end
   if normalized:match('^::picker%(%s*select%s*%)$')then name='picker(select)'end
   if not name or not({before=true,after=true,marker=true,placeholder=true,backdrop=true,selection=true,['picker-icon']=true,checkmark=true,['picker(select)']=true})[name]then return {Names={},Values={}}end
   local t=tree();local box=if name=='picker(select)'and t and t.PickerBox then t:PickerBox(node)else nil
   local style=if box then box.Style else t and t.PseudoStyle and t:PseudoStyle(node,name)
   return Computed.read(style,box,viewport())
  end
  local t=tree();local style=styleOf(node)or(t and t.ComputedElementStyle and t:ComputedElementStyle(node))
  return Computed.read(style,if hidden(node)then nil else boxOf(node),viewport())
 end
 local function cssProperty(key)
  if key=='cssFloat'then return 'float'end
  return if key:sub(1,2)=='--'then key else(key:gsub('%u',function(c)return '-'..c:lower()end))
 end
 local function styleState(value)return brand(styles,value,'CSSStyleDeclaration')end
 local function cssValue(state,name)
  if name:sub(1,2)~='--'then name=name:lower()end
  local data=computed(state.Node,state.Pseudo);return data.Values[name]or ''
 end
 method(styleProto,'getPropertyValue',1,function(args,value)required(args,1,'getPropertyValue');return cssValue(styleState(value),text(args[1]))end)
 method(styleProto,'getPropertyPriority',1,function(args,value)required(args,1,'getPropertyPriority');styleState(value);text(args[1]);return ''end)
 method(styleProto,'item',1,function(args,value)required(args,1,'CSSStyleDeclaration.item');local state=styleState(value);local i=uint(args[1]);return computed(state.Node,state.Pseudo).Names[i+1]or ''end)
 for _,name in {'setProperty','removeProperty'}do method(styleProto,name,if name=='setProperty'then 2 else 1,function(_,value)styleState(value);fail('NoModificationAllowedError','Computed style is read-only')end)end
 accessor(styleProto,'length',function(value)local state=styleState(value);return #computed(state.Node,state.Pseudo).Names end)
 accessor(styleProto,'parentRule',function(value)styleState(value);return N end)
 accessor(styleProto,'cssText',function(value)styleState(value);return ''end,function(value)styleState(value);fail('NoModificationAllowedError','Computed style is read-only')end)
 local function computedWrapper(node,pseudo)
  if adapter.StyleDeclarations then
   -- Inline, rule and computed styles share one realm interface and native
   -- receiver brand. The provider reads current renderer data on demand.
   local value=adapter.StyleDeclarations:NewComputed(function()check();return computed(node,pseudo)end)
   local state={Node=node,Pseudo=pseudo};value.GeometryState=state;styles[value]=state
   return value
  end
  local state={Node=node,Pseudo=pseudo};local value={Kind='computed-style',Prototype=styleProto,GeometryState=state};styles[value]=state
  local extra={}
  value.Get=function(key)
   check();if extra[key]~=nil then return extra[key]end;if type(key)~='string'then return U end
   if vm.Has(styleProto,key)then return vm.Get(styleProto,key,value)end
   local data=computed(node,pseudo);local at=tonumber(key)
   if at and at>=0 and at==math.floor(at)and tostring(at)==key then return data.Names[at+1]or U end
   local property=cssProperty(key);return data.Values[property]or(if Properties[property]then ''else U)
  end
  value.Set=function(key,item,strict)
   if type(key)=='string'and(key=='cssText'or Properties[cssProperty(key)]or computed(node,pseudo).Values[cssProperty(key)]~=nil)then fail('NoModificationAllowedError','Computed style is read-only')end
   if key=='length'or key=='parentRule'or type(key)=='string'and key:match('^%d+$')then if strict then fail('TypeError','Read-only style property')end;return end
   extra[key]=item
  end
  value.Keys=function()local names=computed(node,pseudo).Names;local keys={};for i=1,#names do keys[i]=tostring(i-1)end;for key in extra do table.insert(keys,key)end;return keys end
  value.GetOwnPropertyDescriptor=function(key)
   if extra[key]~=nil then return {Value=extra[key],Writable=true,Enumerable=true,Configurable=true}end
   local i=tonumber(key);if i and i>=0 and i==math.floor(i)and tostring(i)==key then local name=computed(node,pseudo).Names[i+1];if name then return {Value=name,Writable=false,Enumerable=true,Configurable=true}end end
   return nil
  end
  return value
 end
 local function dictionary(value,name)
  if value==U or value==N then return nil end;if not object(value)then fail('TypeError',name..' requires a dictionary')end;return value
 end
 local function enum(value,default,allowed,name)
  local result=if value==U then default else text(value);if not allowed[result]then fail('TypeError','Invalid '..name..': '..result)end;return result
 end
 local BEHAVIOR={auto=true,instant=true,smooth=true}
 local function scrollOptions(args,currentX,currentY,relative)
  local x,y,behavior=currentX,currentY,'auto'
  if #args<=1 then
   local options=dictionary(arg(args,1),'scroll');local b=if options then vm.Get(options,'behavior')else U
   behavior=enum(b,'auto',BEHAVIOR,'ScrollBehavior')
   local left=if options then vm.Get(options,'left')else U;local top=if options then vm.Get(options,'top')else U
   x=if left==U then(if relative then 0 else currentX)else finite(left);y=if top==U then(if relative then 0 else currentY)else finite(top)
  else x,y=finite(args[1]),finite(args[2])end
  if relative then x+=currentX;y+=currentY end;return x,y,behavior
 end
 local function scroll(node,x,y,behavior,relative)
  local data=if node then metrics(node)else nil;local view=viewport();local root=node==nil or pageScroll(node)
  local maxX=math.max(0,if root then(view.ScrollWidth or view.Width or 0)-(view.ClientWidth or view.Width or 0)else data.scrollWidth-data.clientWidth)
  local maxY=math.max(0,if root then(view.ScrollHeight or view.Height or 0)-(view.ClientHeight or view.Height or 0)else data.scrollHeight-data.clientHeight)
  local s=if node then styleOf(node)or {}else {};if node and not root and(hidden(node)or not boxOf(node))then return end
  -- Negative RTL origins are supplied explicitly by the native adapter.
  local minX=if data then data.MinScrollLeft or 0 else view.MinScrollX or 0
  x,y=math.clamp(x,minX,if minX<0 then 0 else maxX),math.clamp(y,0,maxY)
  if not adapter.Scroll then if maxX>0 or maxY>0 then fail('NotSupportedError','Native scrolling adapter is unavailable')end;return end
  return adapter.Scroll(if root then nil else node,x,y,if behavior=='auto'then s.ScrollBehavior or behavior else behavior,relative)
 end
 local function promiseOperation(action)
  local ok,result=pcall(action)
  if not adapter.CreatePromise then
   if not ok then error(result,0)end
   return if result==nil then U else result
  end
  local promise,resolve,reject=adapter.CreatePromise()
  if ok then resolve({if result==nil then U else result})else reject({VM.exceptionValue(result)})end
  return promise
 end
 local function scrollCall(node,args,relative)
  api:Flush();local data=if node then metrics(node)else viewport();local x,y=if node then data.scrollLeft else data.ScrollX or 0,if node then data.scrollTop else data.ScrollY or 0
  local nx,ny,behavior=scrollOptions(args,x,y,relative);return scroll(node,nx,ny,behavior,relative)
 end
 local ALIGN={start=true,center=true,['end']=true,nearest=true}
 local function align(start,finish,portStart,portFinish,mode)
  if mode=='start'then return start-portStart elseif mode=='end'then return finish-portFinish elseif mode=='center'then return (start+finish-portStart-portFinish)/2 end
  local small=finish-start<=portFinish-portStart
  if start<portStart and finish>portFinish or start>=portStart and finish<=portFinish then return 0 end
  if start<portStart and small or finish>portFinish and not small then return start-portStart end
  return finish-portFinish
 end
 local function sideValue(values,i,basis)return if not values then 0 elseif type(values[i])=='number'then values[i]else Length.resolve(values[i],basis)end
 local function intoView(node,args,selectionRect)
  local first=arg(args,1);local opts={Behavior='auto',Block='start',Inline='nearest',Container='all'}
  if type(first)=='boolean'then opts.Block=if first then 'start'else 'end'
  elseif first~=U then
   local d=dictionary(first,'scrollIntoView')
   for _,entry in {{'behavior','Behavior','auto',BEHAVIOR},{'block','Block','start',ALIGN},{'container','Container','all',{all=true,nearest=true}},{'inline','Inline','nearest',ALIGN}}do
    opts[entry[2]]=enum(if d then vm.Get(d,entry[1])else U,entry[3],entry[4],entry[1])
   end
  end
  api:Flush();if hidden(node)or(not selectionRect and #clientRects(node,false)==0)then return U end
  if adapter.ScrollIntoView and not selectionRect then return adapter.ScrollIntoView(node,opts)end
  local containers={};local current=node.Parent
  while current and current.Kind~='Document'do local box=boxOf(current);if box and box.ScrollGui and not pageScroll(current)then table.insert(containers,current)end;current=current.Parent or(if current.Kind=='ShadowRoot'then current.Host else nil)end
  table.insert(containers,false)
  local completions={}
  for _,container in containers do
   vm.Step();local r=if selectionRect then selectionRect()else bounding(clientRects(node,false));local port,info,s
   if not r then break end
   if container then info=metrics(container);local outer=bounding(clientRects(container,false));port={X=outer.X+info.clientLeft,Y=outer.Y+info.clientTop,Width=info.clientWidth,Height=info.clientHeight};s=styleOf(container)or {}
   else info=viewport();port={X=0,Y=0,Width=info.ClientWidth or info.Width or 0,Height=info.ClientHeight or info.Height or 0};s={}end
   local targetStyle=styleOf(node)or {};local margin=targetStyle.ScrollMargin;local padding=s.ScrollPadding
   local left=r.X-sideValue(margin,4,r.Width);local right=r.X+r.Width+sideValue(margin,2,r.Width)
   local top=r.Y-sideValue(margin,1,r.Height);local bottom=r.Y+r.Height+sideValue(margin,3,r.Height)
   local psx=port.X+sideValue(padding,4,port.Width);local pex=port.X+port.Width-sideValue(padding,2,port.Width)
   local psy=port.Y+sideValue(padding,1,port.Height);local pey=port.Y+port.Height-sideValue(padding,3,port.Height)
   local vertical=s.WritingMode=='vertical-rl'or s.WritingMode=='vertical-lr'
   local block,inline=opts.Block,opts.Inline
   if (not vertical and s.Direction=='rtl')or(vertical and s.WritingMode=='vertical-rl')then
    if vertical then block=if block=='start'then 'end'elseif block=='end'then 'start'else block
    else inline=if inline=='start'then 'end'elseif inline=='end'then 'start'else inline end
   end
   local dx=align(left,right,psx,pex,if vertical then block else inline);local dy=align(top,bottom,psy,pey,if vertical then inline else block)
   if adapter.ProjectScrollDelta then dx,dy=adapter.ProjectScrollDelta(if container then container else nil,dx,dy)end
   local completion=scroll(if container then container else nil,(if container then info.scrollLeft else info.ScrollX or 0)+dx,(if container then info.scrollTop else info.ScrollY or 0)+dy,opts.Behavior)
   if completion~=nil and completion~=U then table.insert(completions,completion)end
   if opts.Container=='nearest'then break end
  end
  if #completions>0 and adapter.CreatePromise and adapter.Await then
   local promise,resolve,reject=adapter.CreatePromise();local left=#completions
   for _,completion in completions do adapter.Await(completion,function()if not api.Alive then return end;left-=1;if left==0 then resolve({U})end end,function(reason)if api.Alive then reject({reason})end end)end
   return promise
  end
  return U
 end
 function api:ScrollSelectionRect(node,selectionRect)
  check();return intoView(node,{vm.Object({behavior='instant',block='nearest',inline='nearest'})},selectionRect)
 end
 local METRICS={clientWidth=true,clientHeight=true,clientLeft=true,clientTop=true,offsetWidth=true,offsetHeight=true,offsetLeft=true,offsetTop=true,offsetParent=true,scrollWidth=true,scrollHeight=true,scrollLeft=true,scrollTop=true}
 function api.ElementGet(node,key)
  check();if not node or node.Kind~='Element'then return nil end
  if METRICS[key]then api:Flush();local data=metrics(node);return if key=='offsetParent'then wrap(data[key])else data[key]end
  if key=='getBoundingClientRect'then return function()api:Flush();return fromData(bounding(clientRects(node,false)),true)end end
  if key=='getClientRects'then return function()api:Flush();return rectList(clientRects(node,false))end end
  if key=='scroll'or key=='scrollTo'or key=='scrollBy'then return function(args)return promiseOperation(function()return scrollCall(node,args,key=='scrollBy')end)end end
  if key=='scrollIntoView'then return function(args)return promiseOperation(function()return intoView(node,args)end)end end
  return nil
 end
 function api.ElementSet(node,key,value,strict)
  check();if not node or node.Kind~='Element'or not METRICS[key]then return false end
  if key=='scrollLeft'or key=='scrollTop'then api:Flush();local data=metrics(node);local numberValue=finite(value);scroll(node,if key=='scrollLeft'then numberValue else data.scrollLeft,if key=='scrollTop'then numberValue else data.scrollTop,'auto')
  elseif strict then fail('TypeError','Read-only geometry property: '..key)end
  return true
 end
 local function environment()
  local view=viewport();local env=table.clone(view.Environment or {});env.Width,env.Height=view.Width or 0,view.Height or 0;return env
 end
 local function mediaQuery(source)
  if #source>4096 then fail('RangeError','Media query budget exceeded')end
  local compiled=Media.compile(source)
  if not compiled or #compiled>128 then fail('RangeError','Media query branch budget exceeded')end
  return compiled,Media.serialize(compiled)
 end
 local function matching(state)return Media.matches(state.Query,environment())end
 queryProto=vm.Object({},if globals.EventTarget then vm.Get(globals.EventTarget,'prototype')else vm.Prototypes.Object)
 mediaEventProto=vm.Object({},if globals.Event then vm.Get(globals.Event,'prototype')else vm.Prototypes.Object)
 accessor(queryProto,'media',function(value)return brand(queries,value,'MediaQueryList.media').Media end)
 accessor(queryProto,'matches',function(value)return matching(brand(queries,value,'MediaQueryList.matches'))end)
 accessor(queryProto,'onchange',function(value)brand(queries,value,'MediaQueryList.onchange');return value.Get('onchange')end,
  function(value,callback)brand(queries,value,'MediaQueryList.onchange');value.Set('onchange',callback)end)
 accessor(mediaEventProto,'media',function(value)return brand(mediaEvents,value,'MediaQueryListEvent.media').Media end)
 accessor(mediaEventProto,'matches',function(value)return brand(mediaEvents,value,'MediaQueryListEvent.matches').Matches end)
 for _,entry in {{'addListener','addEventListener'},{'removeListener','removeEventListener'}}do
  method(queryProto,entry[1],1,function(args,value)required(args,1,entry[1]);brand(queries,value,'MediaQueryList.'..entry[1]);if not eventHost then fail('NotSupportedError','Media query events require EventTarget host')end
   return vm:Call(eventHost:TargetMethods(value,entry[2]),{'change',args[1]},value)end)
 end
 local function newMediaEvent(kind,init)
  if not eventHost then fail('NotSupportedError','MediaQueryListEvent requires Event host')end
  local d=dictionary(init,'MediaQueryListEvent');local fields={}
  for _,name in {'bubbles','cancelable','composed'}do fields[name]=d and VM.truth(vm.Get(d,name))or false end
  local matches=if d then vm.Get(d,'matches')else U;local media=if d then vm.Get(d,'media')else U
  local value=eventHost:NewEvent(kind,fields,'Event');vm.SetPrototype(value,mediaEventProto)
  local state={Matches=VM.truth(matches),Media=if media==U then ''else text(media)};value.GeometryMediaEvent=state;mediaEvents[value]=state;return value
 end
 constructor('MediaQueryList',0,queryProto,function()fail('TypeError','Illegal MediaQueryList constructor')end)
 constructor('DOMRectList',0,listProto,function()fail('TypeError','Illegal DOMRectList constructor')end)
 if not adapter.StyleDeclarations then constructor('CSSStyleDeclaration',0,styleProto,function()fail('TypeError','Illegal CSSStyleDeclaration constructor')end)end
 constructor('MediaQueryListEvent',1,mediaEventProto,function(args)required(args,1,'MediaQueryListEvent');return newMediaEvent(text(args[1]),arg(args,2))end)
 local match=native('matchMedia',1,function(args)
  required(args,1,'matchMedia');local query,media=mediaQuery(text(args[1]));local state={Query=query,Media=media,Last=false}
  state.Last=matching(state);local value=vm.Object({},queryProto);value.GeometryState=state;queries[value]=state
  if queryCount>=4096 then local live={};for i=1,queryCount do if queryOrder[i]then table.insert(live,queryOrder[i])end end;queryOrder=setmetatable(live,{__mode='v'});queryCount=#live end
  if queryCount>=4096 then fail('RangeError','MediaQueryList budget exceeded')end;queryCount+=1;queryOrder[queryCount]=value
  if eventHost then eventHost:WrapTarget(value,{Handlers=true,HandlerNames={onchange=true}})end
  return value
 end)
 global('matchMedia',match)
 global('getComputedStyle',native('getComputedStyle',1,function(args)
  required(args,1,'getComputedStyle');local node=element(args[1]);local pseudo=arg(args,2);pseudo=if pseudo==U or pseudo==N then ''else text(pseudo)
  if pseudo==':before'or pseudo==':after'or pseudo==':first-letter'or pseudo==':first-line'then pseudo=':'..pseudo end
  api:Flush();return computedWrapper(node,pseudo)
 end))
 local windowMethods={}
 for _,name in {'scroll','scrollTo','scrollBy'}do windowMethods[name]=native(name,0,function(args)return promiseOperation(function()return scrollCall(nil,args,name=='scrollBy')end)end);global(name,windowMethods[name])end
 local WINDOW={innerWidth='Width',innerHeight='Height',scrollX='ScrollX',scrollY='ScrollY',pageXOffset='ScrollX',pageYOffset='ScrollY'}
 function api.WindowGet(key)
  check();if key=='devicePixelRatio'then local view=viewport();return view.DevicePixelRatio or(view.MediaFeatures and view.MediaFeatures.Resolution)or 1 end;if windowMethods[key]then return windowMethods[key]end;if WINDOW[key]then api:Flush();return viewport()[WINDOW[key]]or 0 end;return nil
 end
 function api.WindowSet(key,_value,strict)if not WINDOW[key]then return false end;if strict then fail('TypeError','Read-only viewport property: '..key)end;return true end
 function api:ViewportChanged()
  check();local changed={}
  for i=1,queryCount do local value=queryOrder[i];local state=value and queries[value];if state then local now=matching(state);if now~=state.Last then state.Last=now;table.insert(changed,{Target=value,State=state,Matches=now})end end end
  if #changed==0 or not eventHost then return end
  local dispatch=function()
   if not api.Alive then return end
   for _,entry in changed do if not api.Alive then return end;local init=vm.Object({matches=entry.Matches,media=entry.State.Media});eventHost:Dispatch(entry.Target,newMediaEvent('change',init),true)end
  end
  if adapter.QueueTask then adapter.QueueTask(dispatch)else dispatch()end
 end
 function api:Rect(x,y,width,height,readonly)return rect(x,y,width,height,not readonly)end
 function api:RectList(raw)check();return rectList(raw)end
 function api:Describe(value)
  check();local r=rects[value];if r then return {Kind=if r.Mutable then 'DOMRect'else 'DOMRectReadOnly',Data={x=r.x,y=r.y,width=r.width,height=r.height},ByteLength=32}end
  return geometryMath:Describe(value)
 end
 function api:Restore(record)
  check();local r=record.Data;if record.Kind=='DOMRect'or record.Kind=='DOMRectReadOnly'then return rect(r.x,r.y,r.width,r.height,record.Kind=='DOMRect')end
  return geometryMath:Restore(record)
 end
 function api:ClientRects(node)api:Flush();return clientRects(node,false)end
 function api:Metrics(node)api:Flush();return metrics(node)end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  if geometryMath then geometryMath:Destroy()end
  for _,map in {rects,lists,styles,queries,mediaEvents,queryOrder}do table.clear(map)end;table.clear(adapter)
 end
 for _,entry in {{readonlyProto,'DOMRectReadOnly'},{rectProto,'DOMRect'},{listProto,'DOMRectList'},{styleProto,'CSSStyleDeclaration'},{queryProto,'MediaQueryList'},{mediaEventProto,'MediaQueryListEvent'}}do
  if vm.SymbolToStringTag then define(entry[1],vm.SymbolToStringTag,{value=entry[2],configurable=true})end
 end
 geometryMath=GeometryMath.install(vm,globals,{Binary=adapter.Binary,Events=eventHost,Rect=function(x,y,w,h,readonly)return api:Rect(x,y,w,h,readonly)end})
 return api
end
return Geometry
