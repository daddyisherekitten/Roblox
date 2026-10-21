--!strict
-- Renderer-independent geometry fixtures. Coordinates mirror the native HTML
-- fixture; the adapter supplies existing box data and counts actual dirty syncs.
return function(VM: any,Geometry: any,HostEvents: any,fixtures: any,Transform: any,Length: any,Promises: any)
 local function runFixture(fixture)
  local values={};local globals={record=function(args)table.insert(values,VM.string(args[1]))end}
  local vm=VM.new(globals,{MaxSteps=100000});local tasks,microtasks={},{}
  local promises=Promises.new({Enqueue=function(fn)table.insert(microtasks,fn)end,
   Call=function(fn,args,receiver)return vm:Call(fn,args,receiver)end,Get=function(value,key,receiver)return vm.Get(value,key,receiver)end,
   Object=vm.Object,Array=vm.Array,Iterator=vm.Iterator,Construct=function(fn,args)return vm:Construct(fn,args)end})
  promises:Attach(vm);globals.Promise=promises.Constructor;vm.Global.Bindings.Promise={Value=globals.Promise}
  local events=HostEvents.install(vm,globals,{Clock=function()return 0 end})
  local document={Kind='Document',Children={}}
  local function node(name,parent,id)local n={Kind='Element',Name=name,Parent=parent,Attributes={id=id},Children={}};table.insert(parent.Children,n);return n end
  local root=node('html',document,'root');local body=node('body',root,'body');local scroller=node('div',body,'scroller');local child=node('div',scroller,'child');local fixed=node('div',body,'fixed');local invisible=node('div',body,'invisible');local inline=node('span',body,'inline')
  local nodes={root=root,body=body,scroller=scroller,child=child,fixed=fixed,invisible=invisible,inline=inline}
  local t={NodeBoxes={},NodeStyles={}}
  local function box(n,x,y,w,h,extra)
   local s={Display='block',Position='static',Padding={0,0,0,0},Margin={0,0,0,0},Opacity=1,BoxSizing='content-box',FontSize=16,Font='Arial',Color={R=0,G=0,B=0},LineHeight={Kind='normal'},Visibility='visible'}
   for k,v in extra or {}do s[k]=v end
   local b={Node=n,Style=s,LayoutX=x,LayoutY=y,PaintX=x,PaintY=y,OuterWidth=w,OuterHeight=h,ContentWidth=w,ContentHeight=h,UnclippedRight=w,UnclippedBottom=h,Children={}}
   t.NodeStyles[n],t.NodeBoxes[n]=s,b;return b
  end
  box(root,0,0,800,1600);box(body,0,0,800,1600)
  local container=box(scroller,10,20,114,94,{Position='absolute',Padding={5,5,5,5},BorderSizes={2,2,2,2},BorderStyle='solid',OverflowX='auto',OverflowY='auto',ScrollbarWidth='none'})
  container.ContentWidth,container.ContentHeight=100,80;container.ScrollRight,container.ScrollBottom=209,170;container.ScrollGui={CanvasPosition={X=0,Y=0}}
  local target=box(child,7,8,200,160,{Position='absolute'});local floating=box(fixed,200,40,20,30,{Position='fixed'});floating.FixedViewportX,floating.FixedViewportY=200,40
  box(invisible,0,0,10,10,{Hidden=true,Display='none'});t.NodeStyles[inline]={Display='inline',Position='static'}
  local view={Width=640,Height=480,ClientWidth=640,ClientHeight=480,ScrollWidth=800,ScrollHeight=1600,ScrollX=0,ScrollY=0,Environment={Pointer='fine',Hover=true}}
  local pending,flushCount=false,0;local wrappers={};local rawStyles={};local api
  local function wrap(n)
   if wrappers[n]then return wrappers[n]end
   local raw={};rawStyles[n]=raw
   local inlineStyle={Get=function(key)return raw[key]or ''end,Set=function(key,value)
    raw[key]=VM.string(value);pending=true
   end}
   local value={DOMNode=n,Get=function(key)
    if key=='style'then return inlineStyle elseif key=='id'then return n.Attributes.id end
    local result=api.ElementGet(n,key);return if result==nil then VM.Undefined else result
   end,Set=function(key,item,strict)
    if api.ElementSet(n,key,item,strict)then return end
   end}
   wrappers[n]=value;return value
  end
  local function flush()
   assert(pending,'An unchanged layout must not be flushed');pending=false;flushCount+=1
   for n,raw in rawStyles do local b=t.NodeBoxes[n];local s=t.NodeStyles[n]
    if b then
     for _,entry in {{'width','OuterWidth','ContentWidth'},{'height','OuterHeight','ContentHeight'}}do local val=raw[entry[1]];if val then local dimension=tonumber(val:match('^([%d%.]+)px$'));if dimension then b[entry[2]],b[entry[3]]=dimension,dimension end end end
     if raw.transform then s.Transform=Transform.parse(raw.transform,Length.parse)or {}end
     if raw.transformOrigin then s.TransformOrigin=Transform.parseOrigin(raw.transformOrigin,Length.parse)end
     if raw.display then s.Display=raw.display;s.Hidden=raw.display=='none'end
    end
   end
  end
  api=Geometry.install(vm,globals,{GetTree=function()return t end,GetViewport=function()return view end,
   HasPending=function()return pending end,Flush=flush,Wrap=wrap,Unwrap=function(value)return if type(value)=='table'and wrappers[value.DOMNode]==value then value.DOMNode else nil end,
   GetClientRects=function(n)if n==inline then return {{X=10,Y=100,Width=20,Height=10},{X=10,Y=110,Width=30,Height=10}}end;return nil end,
   GetUntransformedClientRects=function(n)if n==inline then return {{X=10,Y=100,Width=20,Height=10},{X=10,Y=110,Width=30,Height=10}}end;return nil end,
   Scroll=function(n,x,y,_behavior)if n then t.NodeBoxes[n].ScrollGui.CanvasPosition={X=x,Y=y}else view.ScrollX,view.ScrollY=x,y end end,
   Events=events,QueueTask=function(fn)table.insert(tasks,fn)end,
   CreatePromise=function()return promises:CreateCapability()end,Await=function(value,fulfilled,rejected)promises:Await(value,fulfilled,rejected)end})
  globals.document=vm.Object({getElementById=function(args)return nodes[VM.string(args[1])]and wrap(nodes[VM.string(args[1])])or VM.Null end,body=wrap(body),documentElement=wrap(root)})
  vm.Global.Bindings.document={Value=globals.document}
  for _,name in {'innerWidth','innerHeight','scrollX','scrollY','pageXOffset','pageYOffset'}do
   vm.Global.Bindings[name]={Value=api.WindowGet(name)}
  end
  globals.resizeViewport=function(args)view.Width,view.Height=args[1],args[2];view.ClientWidth,view.ClientHeight=args[1],args[2];api:ViewportChanged()end
  globals.pumpEvents=function()local jobs=tasks;tasks={};for _,fn in jobs do fn()end end
  globals.flushCount=function()return flushCount end
  for _,name in {'resizeViewport','pumpEvents','flushCount'}do vm.Global.Bindings[name]={Value=globals[name]}end
  local ok,message=pcall(function()vm:Run(fixture.source);local turns=0;while #microtasks>0 do turns+=1;assert(turns<=1024,'Geometry microtask budget');local jobs=microtasks;microtasks={};for _,fn in jobs do fn()end end end)
  assert(ok,fixture.name..': '..tostring(message))
  assert(#values==#fixture.expected,fixture.name..': record count '..#values..' versus '..#fixture.expected)
  for i,want in fixture.expected do assert(values[i]==want,fixture.name..' record '..i..': '..tostring(values[i])..' versus '..want)end
  -- Multiple clean reads use cached renderer state; one dirty batch is synced once.
  local before=flushCount;api.ElementGet(child,'offsetWidth');api.ElementGet(child,'clientHeight');assert(flushCount==before,'Clean geometry reads must not flush')
  wrap(child).Get('style').Set('width','77px');local measured=api.ElementGet(child,'offsetWidth');assert(measured==77 and flushCount==before+1,'Geometry reads synchronously flush one dirty batch')
  api.ElementGet(child,'offsetWidth');assert(flushCount==before+1,'Repeated reads reuse layout')
  api:Destroy();events:Destroy();promises:Destroy();vm:Destroy();local alive=pcall(function()api.ElementGet(child,'clientWidth')end);assert(not alive,'Disposed geometry rejects reads')
 end
 for _,fixture in fixtures do runFixture(fixture)end
end
