--!strict
local Events=require(script.Parent.Events)
local HitTest=require(script.Parent.HitTest)
local Queries=require(script.Parent.Queries)
local Style=require(script.Parent.Style)
local Session={}
local function same(a: any,b: any): boolean
 if a==b then return true end
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 for k,v in a do if k=='SourceNode' then if v~=b[k] then return false end elseif not same(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end;return true
end
local function signature(items: any): any
 local result={}
 for _,s in items do
  local v={};for _,key in {'Geometry','Transform','Clip','Hidden','PointerEvents','StrokeWidth','DashArray','DashOffset','LineCap','LineJoin','MiterLimit','NonScalingStroke','FillRule','SourceId','SourceNode'} do v[key]=s[key] end
  v.Filled=s.Fill~=nil;v.Stroked=s.Stroke~=nil
  v.Pixels=s.ImageBox and s.Fill and s.Fill.Pixels
  if s.Children then v.Children=signature(s.Children) end
  if s.ClipPath then v.ClipPath=signature(s.ClipPath.RenderTree or s.ClipPath.Shapes) end
  table.insert(result,v)
 end
 return result
end
local function ancestor(node: any,fn: any): any while node do if fn(node) then return node end;node=node.Parent end;return nil end
function Session.new(document: any,build: any,options: any?): any
 options=options or {}
 local self={Document=document,States={},Alive=true,Dirty=true,Scale=1,Stats={Builds=0,HitBuilds=0,Mutations=0},Pointers={},Capture={},Log={}}
 local stateRules=Style.collect(document,function() end,options.CSS)
 function self:InvalidateStyles() stateRules=nil;self.Dirty=true end
 local function stateChanges(name: string,value: any): boolean
  if self.States[name]==value then return false end
  if not stateRules then stateRules=Style.collect(document,function() end,options.CSS) end
  local after=table.clone(self.States);after[name]=value
  return Style.stateChanges(document,stateRules,name,self.States,after)
 end
 local bus=Events.new(options.Report or warn);self.Events=bus
 function self:On(node,kind,fn,opts) return bus:On(node,kind,fn,opts) end
 function self:Node(id) return self.Document.Ids[id] end
 function self:Flush(): boolean
  if not self.Alive then return false end
  if self.Animation then
   local animation=self.Animation
   local sample={Animation=animation,Time=self.Time or 0,TransitionTime=animation.TransitionTime,Version=animation.Version,Mutations=self.Stats.Mutations,Hover=self.States.hover,Active=self.States.active,Focus=self.States.focus}
   local previous=self.LastSample
   local changed=not previous or animation.Version==nil
   if not changed then for key,value in sample do if previous[key]~=value then changed=true;break end end end
   if not changed then for key in previous do if sample[key]==nil then changed=true;break end end end
   if changed then
    local animated=animation:Sample(sample.Time,self.States);self.LastSample=sample
    if not same(self.Animated or {},animated) then self.Animated=animated;self.Dirty=true end
   end
  end
  if not self.Dirty then
   if self.Scene and self.HitScale~=self.Scale then self.Snapshot=HitTest.prepare(self.Scene,self.Scale);self.HitScale=self.Scale;self.Stats.HitBuilds+=1 end
   return false
  end
  local scene=build(self.Document,self.States,self.Animated);local key=signature(scene.RenderTree or scene.Shapes)
  if not self.HitKey or not same(key,self.HitKey) or self.HitScale~=self.Scale then
   self.Snapshot=HitTest.prepare(scene,self.Scale);self.HitKey=key;self.HitScale=self.Scale;self.Stats.HitBuilds+=1
  end
  self.Scene=scene;self.Dirty=false;self.Stats.Builds+=1;return true
 end
 function self:SetTime(time)
  assert(time>=0 and time<math.huge,'Finite nonnegative time required');self.Time=time
 end
 function self:SetAttribute(node,key,value)
  assert(self.Alive and node and node.Kind=='Element','Live SVG element required')
  if value~=nil then value=tostring(value) end
  if node.Attributes[key]==value then return end
  if key=='id' then
   assert(not value or not self.Document.Ids[value] or self.Document.Ids[value]==node,'Duplicate SVG id')
   if node.Attributes.id then self.Document.Ids[node.Attributes.id]=nil end;if value then self.Document.Ids[value]=node end
  end
  node.Attributes[key]=value;self.Dirty=true;self.Stats.Mutations+=1
  if node.Name=='style' and (key=='media' or key=='type') then stateRules=nil end
  if (key=='begin' or key=='end') and self.Animation and self.Animation.InvalidateEvents then self.Animation:InvalidateEvents() end
 end
 function self:Dispatch(node,kind,data,bubbles)
  if not self.Alive then return nil end
  if self.Animation and node then self.Animation:Event(node,kind,self.Time or 0) end
  local e=bus:Emit(node,kind,data,bubbles)
  if kind~='pointermove' then table.insert(self.Log,kind..':'..(node and node.Attributes and node.Attributes.id or '—'));if #self.Log>8 then table.remove(self.Log,1) end end
  return e
 end
 function self:Focus(node)
  if not self.Alive or self.States.focus==node then return end
  local old=self.States.focus;local visual=stateChanges('focus',node);self.States.focus=node;self.Dirty=self.Dirty or visual
  if old then self:Dispatch(old,'blur',{RelatedTarget=node},false);self:Dispatch(old,'focusout',{RelatedTarget=node}) end
  if node then self:Dispatch(node,'focus',{RelatedTarget=old},false);self:Dispatch(node,'focusin',{RelatedTarget=old}) end
 end
 function self:Focusable()
  local result={};local order=0
  local function walk(n)
   if n.Kind~='Element' then return end;order+=1
   local entry=self.Scene.Nodes[n];local a=n.Attributes;local tab=tonumber(a.tabindex)
   if entry and entry.Visible and ((tab and tab>=0) or (tab==nil and n.Name=='a' and a.href)) then table.insert(result,{Node=n,Tab=tab or 0,Order=order}) end
   for _,c in n.Children do walk(c) end
  end
  walk(document.Root);table.sort(result,function(a,b) local x,y=if a.Tab>0 then a.Tab else math.huge,if b.Tab>0 then b.Tab else math.huge;return if x==y then a.Order<b.Order else x<y end)
  return result
 end
 function self:SetPointerCapture(id,node)
  assert(self.Pointers[id] and self.Pointers[id].Down,'Pointer is not pressed')
  if self.Capture[id]==node then return end
  self:ReleasePointerCapture(id);self.Capture[id]=node;self:Dispatch(node,'gotpointercapture',{PointerId=id})
 end
 function self:ReleasePointerCapture(id)
  local node=self.Capture[id];self.Capture[id]=nil;if node then self:Dispatch(node,'lostpointercapture',{PointerId=id}) end
 end
 function self:Activate(node,data)
  local e=self:Dispatch(node,'click',data);if not e or e.DefaultPrevented then return end
  local link=ancestor(node,function(n) return n.Name=='a' and n.Attributes.href end)
  if link then self.Link=link.Attributes.href;if options.Navigate then options.Navigate(self.Link,link) end end
 end
function self:Pointer(kind,x,y,id,pointerType)
  if not self.Alive then return end
  id=id or 1;pointerType=pointerType or 'mouse'
  -- Captured motion targets a stable source node; rebuilding geometry here is redundant.
  if not self.Capture[id] then
   if self.Dirty or not self.Scene or self.HitScale~=self.Scale then self:Flush() end
  end
  local shape=if self.Capture[id] then nil else HitTest.query(self.Snapshot,x,y);local hit=shape and shape.SourceNode
  local p=self.Pointers[id] or {};self.Pointers[id]=p
  local target=self.Capture[id] or hit;local data: any
  local hasMoveListener=kind=='move' and (bus:Has('pointermove') or (self.Animation and self.Animation.HasEvent and self.Animation:HasEvent('pointermove')))
  local hoverChanged=false
  local dirty=false
  if kind~='cancel' and p.Hover~=target then
   local old=p.Hover;local visual=stateChanges('hover',target);p.Hover=target;self.States.hover=target
   hoverChanged=true
   dirty=dirty or visual
   local common=ancestor(old,function(n) return ancestor(target,function(v) return v==n end)~=nil end)
   if old then self:Dispatch(old,'pointerout',{RelatedTarget=target,PointerId=id}) end
   local n=old;while n and n~=common do self:Dispatch(n,'pointerleave',{RelatedTarget=target,PointerId=id},false);n=n.Parent end
   if target then self:Dispatch(target,'pointerover',{RelatedTarget=old,PointerId=id}) end
   local entered={};n=target;while n and n~=common do table.insert(entered,n);n=n.Parent end
   for i=#entered,1,-1 do self:Dispatch(entered[i],'pointerenter',{RelatedTarget=old,PointerId=id},false) end
  end
  if kind=='down' then
   data={X=x,Y=y,PointerId=id,PointerType=pointerType,Buttons=1}
   if p.Down~=hit then
    local visual=stateChanges('active',hit);p.Down=hit;self.States.active=hit;dirty=dirty or visual
   end
   local e=self:Dispatch(target,'pointerdown',data)
   if not e or not e.DefaultPrevented then self:Focus(ancestor(hit,function(n) return n.Attributes and (n.Attributes.tabindex~=nil or (n.Name=='a' and n.Attributes.href)) end)) end
   if pointerType=='touch' and hit and not self.Capture[id] then self:SetPointerCapture(id,hit) end
  elseif kind=='up' then
   data={X=x,Y=y,PointerId=id,PointerType=pointerType,Buttons=1}
   local down=p.Down;p.Down=nil;if self.States.active~=nil then local visual=stateChanges('active',nil);self.States.active=nil;dirty=dirty or visual end
   data.Buttons=0;self:Dispatch(target,'pointerup',data)
   if down and target then
    local clickTarget=if self.Capture[id] then target else ancestor(down,function(n) return ancestor(target,function(v) return v==n end)~=nil end)
    if clickTarget then self:Activate(clickTarget,data) end
   end
   self:ReleasePointerCapture(id)
   if pointerType=='touch' then
    if self.States.hover~=nil then dirty=stateChanges('hover',nil) or dirty end
    p.Hover=nil;self.States.hover=nil;self.Pointers[id]=nil
   end
  elseif kind=='cancel' then
   data={X=x,Y=y,PointerId=id,PointerType=pointerType,Buttons=if p.Down then 1 else 0}
   self:Dispatch(self.Capture[id] or p.Down,'pointercancel',data);p.Down=nil;self:ReleasePointerCapture(id)
   if self.States.active~=nil then dirty=dirty or stateChanges('active',nil) end
   if self.States.hover~=nil then dirty=dirty or stateChanges('hover',nil) end
   self.States.active=nil;self.States.hover=nil
   self.Pointers[id]=nil
  elseif kind=='move' and (hasMoveListener or hoverChanged) then
   data={X=x,Y=y,PointerId=id,PointerType=pointerType,Buttons=if p.Down then 1 else 0}
   self:Dispatch(target,'pointermove',data)
  end
  self.Dirty = self.Dirty or dirty
end
 function self:Key(key,shift)
  if not self.Alive then return end;self:Flush()
  local e=self:Dispatch(self.States.focus,'keydown',{Key=key,ShiftKey=shift==true})
  if e and e.DefaultPrevented then return end
  if key=='Tab' then
   local list=self:Focusable();if #list==0 then return end
   local index=if shift then 1 else 0;for i,v in list do if v.Node==self.States.focus then index=i;break end end
   self:Focus(list[(index-1+(if shift then -1 else 1))%#list+1].Node)
  elseif key=='Enter' and self.States.focus and self.States.focus.Name=='a' then self:Activate(self.States.focus,{Key=key}) end
 end
 function self:KeyUp(key,shift)
  if self.Alive then self:Dispatch(self.States.focus,'keyup',{Key=key,ShiftKey=shift==true}) end
 end
 function self:Cursor()
  local node=self.States.hover;local entry=node and self.Scene.Nodes[node];local value=entry and entry.Node.Attributes.cursor
  if value and value~='auto' then return value end
  return if ancestor(node,function(n) return n.Name=='a' and n.Attributes.href end) then 'pointer' else 'default'
 end
 function self:GetBBox(node) self:Flush();return Queries.box(self.Scene,node) end
 function self:GetCTM(node) self:Flush();return Queries.matrix(self.Scene,node,{SX=self.Scale,SY=self.Scale,TX=0,TY=0}) end
 function self:GetScreenCTM(node) self:Flush();return Queries.matrix(self.Scene,node,options.Screen and options.Screen()) end
 function self:GetTotalLength(node) self:Flush();return Queries.length(self.Scene,node) end
 function self:GetPointAtLength(node,distance) self:Flush();return Queries.point(self.Scene,node,distance) end
 function self:Metadata(node)
  local function text(n) local s=n.Text or '';for _,c in n.Children or {} do s..=text(c) end;return s end
  local a=node.Attributes;local label,description=a['aria-label'],nil
  for _,c in node.Children do if c.Name=='title' and not label then label=text(c) elseif c.Name=='desc' then description=text(c) end end
  return {Role=a.role,Label=label,Description=description,TabIndex=tonumber(a.tabindex)}
 end
 function self:Destroy()
  if not self.Alive then return end
  self.Alive=false;if self.Script then self.Script:Destroy() end;bus:Destroy();table.clear(self.Pointers);table.clear(self.Capture);table.clear(self.States);self.Snapshot=nil;self.Scene=nil;self.HitKey=nil;self.LastSample=nil;self.Animated=nil
 end
 self:Flush();return self
end
return Session
