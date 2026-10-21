--!strict
-- Page-owned lazy media/image continuations. Only pending targets are measured after
-- existing geometry notifications; no author observer or permanent frame scan.
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Matrix=require(script.Parent.Parent.CSS.Matrix4)
local Transform=require(script.Parent.Parent.CSS.Transform2D)
local Length=require(script.Parent.Parent.CSS.LengthExpression)
local Positioned=require(script.Parent.Parent.Layout.PositionedLayout)
local Work=require(script.Parent.Parent.WorkContext)
local LazyMedia={}
function LazyMedia.new(page,tree,options)
 options=options or{}
 local tasks=options.Task or task
 local margin=options.Margin or 0
 assert(type(margin)=='number'and margin>=0 and margin<math.huge,'LazyMediaMargin must be a finite non-negative pixel distance')
 local api={Alive=true,Count=0};local pending={};local queued=false;local ready=false;local running=false;local dirty=false
 local function living()return api.Alive and page~=nil and page.Alive end
 local function parent(node)return ShadowTree.FlatParent(node)or(if node.Kind=='ShadowRoot'then node.Host else node.Parent)end
 local function box(node)
  local found=tree.NodeBoxes[node]
  if not found then local item=tree.MediaByNode and tree.MediaByNode[node];found=item and item.GeometryBox end
  return found
 end
 -- Overflow clips follow containing blocks. Out-of-flow boxes escape the
 -- ordinary overflow ancestors between themselves and their actual block.
 local function clipParent(node)
  local item=box(node);local style=tree.NodeStyles[node]or(item and item.Style)or{}
  local position=style.Position
  if position=='fixed'then
   local owner=item and item.FixedContainingBox;if not owner then return nil end
   local ancestor=parent(node)
   while ancestor do Work.checkpoint();if box(ancestor)==owner then return ancestor end;ancestor=parent(ancestor)end
   return nil
  elseif position=='absolute'then
   local ancestor=parent(node)
   while ancestor do
    Work.checkpoint()
    local candidate=box(ancestor);local s=tree.NodeStyles[ancestor]or(candidate and candidate.Style)or{}
    if candidate and(s.Position and s.Position~='static'or Positioned.establishesFixedContainingBlock(s,candidate))then return ancestor end
    ancestor=parent(ancestor)
   end
   return nil
  end
  return parent(node)
 end
 local function size(value)return value.OuterWidth or value.Width or 0,value.OuterHeight or value.Height or 0 end
 local function rect(node,view)
  local chain,seen,visited={},{},{};local current=node
  while current do
   Work.checkpoint()
   if visited[current]then return nil end;visited[current]=true
   local item=box(current);local style=tree.NodeStyles[current]or(item and item.Style)
   if style and(style.Hidden or style.Display=='none')then return nil end
   if item and not seen[item]then seen[item]=true;table.insert(chain,item)end
   current=parent(current)
  end
  if #chain==0 then return nil end
  local clips={};local clip=clipParent(node);while clip do Work.checkpoint();local entry=box(clip);if entry then clips[entry]=true end;clip=clipParent(clip)end
  local width,height=size(chain[1]);local matrix=Matrix.identity();local stop=#chain;local fixed=false
  for index,item in chain do if item.Style and item.Style.Position=='fixed'and not item.FixedContainingBox then stop=index;fixed=true;break end end
  for index=stop,1,-1 do
   Work.checkpoint()
   local item=chain[index];local x,y=item.PaintX or item.LayoutX or 0,item.PaintY or item.LayoutY or 0
   if fixed and index==stop then x,y=item.FixedViewportX or x,item.FixedViewportY or y end
   matrix=Matrix.multiply(matrix,Matrix.translate(x,y))
   local style=item.Style or{};local w,h=size(item);local ref=Transform.layoutReference(style,w,h)
   local ox,oy=ref.W/2,ref.H/2;if style.TransformOrigin then ox,oy=Transform.origin(style.TransformOrigin,ref.W,ref.H)end
   local transform=Transform.matrix(item.TransformOverride or Transform.operations(style),ref.W,ref.H)
   matrix=Matrix.multiply(matrix,Matrix.around(transform,ref.X+ox,ref.Y+oy,if style.TransformOrigin and style.TransformOrigin.Z then Length.resolve(style.TransformOrigin.Z,0)else 0))
   if index>1 and clips[item]then
    local position=item.ScrollGui and item.ScrollGui.CanvasPosition
    matrix=Matrix.multiply(matrix,Matrix.translate(-(if position then position.X else item.ScrollLeft or 0),-(if position then position.Y else item.ScrollTop or 0)))
   end
  end
  if not fixed then matrix=Matrix.multiply(Matrix.translate(-(view.ScrollX or 0),-(view.ScrollY or 0)),matrix)end
  local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
  for _,point in{{0,0},{width,0},{width,height},{0,height}}do
   local value=Matrix.point(matrix,point[1],point[2]);if value.W==0 then return nil end
   local x,y=value.X/value.W,value.Y/value.W
   left,top,right,bottom=math.min(left,x),math.min(top,y),math.max(right,x),math.max(bottom,y)
  end
  return {Left=left,Top=top,Right=right,Bottom=bottom,FixedBox=if fixed then chain[stop]else nil}
 end
 local function touches(target,clip,x,y)
  if x then target.Left=math.max(target.Left,clip.Left);target.Right=math.min(target.Right,clip.Right)end
  if y then target.Top=math.max(target.Top,clip.Top);target.Bottom=math.min(target.Bottom,clip.Bottom)end
  return target.Right>=target.Left and target.Bottom>=target.Top
 end
 local function intersects(node)
  if not ready or not ShadowTree.Connected(node,page.Document)then return false end
  local view=page:GeometryViewport();local target=rect(node,view);if not target then return false end
  local ancestor=clipParent(node)
  while ancestor and ancestor.Kind~='Document'and(not target.FixedBox or box(node)~=target.FixedBox)do
   Work.checkpoint()
   local value=box(ancestor);local style=tree.NodeStyles[ancestor]or(value and value.Style)or{}
   local x,y=style.OverflowX or style.Overflow or'visible',style.OverflowY or style.Overflow or'visible'
   if x~='visible'or y~='visible'or style.Contain and style.Contain.Paint then
    local clip=rect(ancestor,view);if not clip then return false end
    clip.Left-=margin;clip.Top-=margin;clip.Right+=margin;clip.Bottom+=margin
    if not touches(target,clip,x~='visible'or style.Contain and style.Contain.Paint,y~='visible'or style.Contain and style.Contain.Paint)then return false end
   end
   if value==target.FixedBox then break end
   ancestor=clipParent(ancestor)
  end
  return touches(target,{Left=-margin,Top=-margin,Right=(view.ClientWidth or view.Width)+margin,Bottom=(view.ClientHeight or view.Height)+margin},true,true)
 end
 function api:WillDefer(node)
  return living()and options.ScriptingEnabled~=false and(node.Attributes.loading or''):lower()=='lazy'
 end
 local function take(node,kind)
  local record=pending[node];local entry=record and record[kind]
  if not entry then return nil end
  record[kind]=nil;api.Count-=1
  if next(record)==nil then pending[node]=nil end
  local callback=entry.Callback;entry.Callback=nil;return callback
 end
 function api:Resume(node,kind)
  if not living()then return false end
  -- Take every slot before callbacks: a resumed fetch may install a new slot.
  local media=if kind==nil or kind=='Media'then take(node,'Media')else nil
  local poster=if kind==nil or kind=='Poster'then take(node,'Poster')else nil
  local image=if kind==nil or kind=='Image'then take(node,'Image')else nil
  local failed,value=false,nil
  if media then local ok,result=pcall(media);if not ok then failed,value=true,result end end
  if poster and living()then local ok,result=pcall(poster);if not ok and not failed then failed,value=true,result end end
  if image and living()then local ok,result=pcall(image);if not ok and not failed then failed,value=true,result end end
  if failed then error(value,0)end
  return media~=nil or poster~=nil or image~=nil
 end
 function api:Check(layoutReady)
  if not living()then return end
  if layoutReady then ready=true end
  if self.Count==0 then return end
  if queued then if running then dirty=true end;return end
  queued=true
  local ok,message=pcall(tasks.defer,function()
   if not living()then queued=false;return end
   running=true
   local work=Work.new(1,{Task=tasks,Clock=options.Clock,Alive=living})
   -- A later cancellation must not replace an earlier callback failure.
   local failed,value=false,nil
   local result=table.pack(pcall(work.Run,work,function()
    local targets={};for node in pending do Work.checkpoint();table.insert(targets,node)end
    for _,node in targets do
     Work.checkpoint();if not living()then break end
     if pending[node]and(not self:WillDefer(node)or intersects(node))then
      local success,answer=pcall(self.Resume,self,node)
      if not success and not failed then failed,value=true,answer end
      if not living()then break end
     end
    end
    if failed then error(value,0)end
   end))
   work:Finish();running=false;queued=false
   local again=dirty;dirty=false
   local followup=table.pack(pcall(function()if again and living()then self:Check()end end))
   if failed then error(value,0)end
   if not result[1]and not(Work.isCancelled(result[2])and not living())then error(result[2],0)end
   if not followup[1]then error(followup[2],0)end
  end)
  if not ok then queued=false;error(message,0)end
 end
 function api:Defer(node,kind,callback)
  if not self:WillDefer(node)then return nil end
  take(node,kind)
  local entry={Callback=callback};local record=pending[node]or{};pending[node]=record;record[kind]=entry;self.Count+=1
  local checked,message=pcall(self.Check,self)
  if not checked then if pending[node]and pending[node][kind]==entry then take(node,kind)end;error(message,0)end
  return function()local current=pending[node];if current and current[kind]==entry then take(node,kind)end end
 end
 function api:AttributeChanged(node)if living()and not self:WillDefer(node)then self:Resume(node)end end
 function api:Destroy()
  if not self.Alive then return end;self.Alive=false
  for node,record in pending do for _,entry in record do entry.Callback=nil end;pending[node]=nil end
  self.Count=0;page=nil;tree=nil;table.clear(options)
 end
 return api
end
return LazyMedia
