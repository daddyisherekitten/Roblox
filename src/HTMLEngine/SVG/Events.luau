--!strict
local Events={}
local function preventDefault(e) e.DefaultPrevented=true end
local function stopPropagation(e) e.PropagationStopped=true end
local function stopImmediate(e) e.ImmediateStopped=true;e.PropagationStopped=true end
function Events.new(report: any): any
 local kinds,alive={},true; local bus={}
 local function disconnect(item)
  if not item.Alive then return end
  item.Alive=false
  local bucket=item.Bucket;local index=table.find(bucket,item)
  if index then table.remove(bucket,index) end
  local kind=kinds[item.Kind]
  if kind then
   kind.Count-=1
   if #bucket==0 then kind.Nodes[item.Node or bus]=nil end
   if kind.Count==0 then kinds[item.Kind]=nil end
  end
  item.Node=nil;item.Fn=nil
 end
 function bus:On(node: any,kind: string,fn: any,options: any?): any
  assert(alive and type(fn)=='function','Live event bus and callback required')
  local group=kinds[kind]
  if not group then group={Count=0,Nodes={}};kinds[kind]=group end
  local bucket=group.Nodes[node or bus]
  if not bucket then bucket={};group.Nodes[node or bus]=bucket end
  local item={Node=node,Kind=kind,Fn=fn,Bucket=bucket,Capture=options==true or (type(options)=='table' and options.Capture==true),Once=type(options)=='table' and options.Once==true,Alive=true}
  table.insert(bucket,item);group.Count+=1
  return {
   Disconnect=function() disconnect(item) end
  }
 end
 function bus:Emit(target: any,kind: string,data: any?,bubbles: boolean?): any
  local e={Type=kind,Target=target,Data=data or {},DefaultPrevented=false,PropagationStopped=false,ImmediateStopped=false,Phase=0,Path={},PreventDefault=preventDefault,StopPropagation=stopPropagation,StopImmediatePropagation=stopImmediate}
  local group=kinds[kind]
  if not group or not alive then return e end
  if target==nil then return e end
  local path={};local n=target;while n do table.insert(path,n);n=n.Parent end
  e.Path=path
  -- Only listeners on this event's path are relevant. Snapshot all of them
  -- before dispatch so listeners added by a callback wait for the next event.
  local snapshot={}
  for _,node in path do local bucket=group.Nodes[node];if bucket then snapshot[node]=table.clone(bucket) end end
  local function invoke(node: any,capture: boolean,phase: number)
   e.CurrentTarget=node;e.Phase=phase
   local bucket=snapshot[node];if not bucket then return end
   for _,v in bucket do
     if not alive or e.ImmediateStopped then break end
    if v.Alive and v.Capture==capture then
      local fn=v.Fn;if v.Once then disconnect(v) end
      local ok,err=pcall(fn,e);if not ok then report(tostring(err)) end
    end
   end
  end
  for i=#path,2,-1 do invoke(path[i],true,1);if e.PropagationStopped then break end end
  if alive and not e.PropagationStopped and target then
   invoke(target,true,2);if not e.ImmediateStopped then invoke(target,false,2) end
   if bubbles~=false and not e.PropagationStopped then for i=2,#path do invoke(path[i],false,3);if e.PropagationStopped then break end end end
  end
  e.CurrentTarget=nil;e.Phase=0;return e
 end
 function bus:Has(kind: string): boolean
  return alive and kinds[kind]~=nil
 end
 function bus:Destroy()
  if not alive then return end;alive=false
  for _,kind in kinds do for _,bucket in kind.Nodes do
   for _,item in bucket do item.Alive=false;item.Fn=nil;item.Node=nil end
   table.clear(bucket)
  end end
  table.clear(kinds)
 end
 return bus
end
return Events
