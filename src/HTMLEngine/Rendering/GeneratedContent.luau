--!strict
-- Re-evaluate generated content in flat-tree order. This updates counter state
-- without measuring boxes; only owners whose generated output/style changed
-- are subsequently refreshed by the renderer.
local Counters=require(script.Parent.Parent.CSS.Counters)
local ShadowTree=require(script.Parent.Parent.DOM.ShadowTree)
local Generated={}
local interactionFields=table.freeze({Cursor=true,PointerEvents=true,UserSelect=true})
Generated.InteractionFields=interactionFields
function Generated.markerStyle(style)
 local marker=table.clone(style);marker.PseudoElement='marker';marker.ListItem=false
 -- A default marker inherits its text styling, not its originating element's
 -- counter operations. Initial rendering and later recascades share this
 -- record shape so a paint-only change cannot fabricate a marker change.
 marker.CounterReset={};marker.CounterIncrement={};marker.CounterSet={};return marker
end
local function same(a,b)
 if a==b then return true end;if type(a)~='table'or type(b)~='table'then return false end
 for k,v in a do if k~='Node'and k~='HitNode'and not same(v,b[k])then return false end end
 for k in b do if k~='Node'and k~='HitNode'and a[k]==nil then return false end end;return true
end
function Generated.update(document,previous,resolve,pseudo,fields,registry,affected)
 local records,changed,interactions={},{},{};local computed={};local state=Counters.new(registry);local quoteDepth=0
 local function pseudoStyle(node,style,name)
  -- Counter/quote order still uses the complete flat tree. The cascade of
  -- an unrelated pseudo is unchanged, including a previously absent pseudo.
  if affected and not affected[node]then
   local record=previous[node]and previous[node][name];return record and record.Style
  end
  return pseudo(node,style,name)
 end
 state.PseudoFor=pseudoStyle
 local function lookahead(node)
  if not node or node.Kind=='Document'then return nil end
  if computed[node]then return computed[node]end
  local inherited=lookahead(ShadowTree.FlatParent(node))
  if node.Kind~='Element'then return inherited end
  local style=resolve(node,inherited);computed[node]=style;return style
 end
 -- Cache only this generated-content pass. Future siblings inherit through
 -- their actual flat-tree parents, including unvisited ancestors and slots.
 state.StyleFor=lookahead
 local function generated(node,name,style)
  local p=pseudoStyle(node,style,name)
  if name=='marker'and style.ListItem then
   if not p then p=Generated.markerStyle(style)end
  elseif not p or p.Hidden or #(p.GeneratedContent or{})==0 then return end
  if not p or p.Hidden then return end
  state.Registry=p.CounterStyles or registry
  Counters.enter(state,p);local parts={}
  for _,part in p.GeneratedContent do
   if part.Kind=='text'then table.insert(parts,part.Value)
   elseif part.Kind=='attr'then table.insert(parts,node.Attributes[part.Name]or'')
   elseif part.Kind=='counter'or part.Kind=='counters'then table.insert(parts,Counters.render(state,part))
   elseif part.Kind=='quote'then
    if part.Value=='close-quote'or part.Value=='no-close-quote'then quoteDepth=math.max(0,quoteDepth-1)end
    if part.Value=='open-quote'or part.Value=='close-quote'then local pairs=p.Quotes or{{'“','”'}};local pair=pairs[math.min(#pairs,quoteDepth+1)];if pair then table.insert(parts,pair[if part.Value=='close-quote'then 2 else 1])end end
    if part.Value=='open-quote'or part.Value=='no-open-quote'then quoteDepth+=1 end
   end
  end
  local number=if name=='marker'then Counters.value(state,'list-item')else nil
  if name=='marker'and #(p.GeneratedContent or{})==0 and p.GeneratedContent.Mode~='none'then number=Counters.markerNumber(state,node,style)or number end
  records[node]=records[node]or{};records[node][name]={Style=p,Text=table.concat(parts),Number=number};Counters.leave(state)
 end
 local function visit(node,inherited)
  if node.Kind=='Element'then
   if node.Name=='style'or node.Name=='link'or node.Name=='script'or node.Name=='head'or node.Name=='template'then return end
   local style=resolve(node,inherited);if not style or style.Hidden or style.Display=='none'then return end;computed[node]=style
   style.Node=node;Counters.enter(state,style);if style.ListItem then generated(node,'marker',style)end
   if node.Name=='option'then generated(node,'checkmark',style)end;generated(node,'before',style)
   local initial=pseudoStyle(node,style,'first-letter');if initial then records[node]=records[node]or{};records[node]['first-letter']={Style=initial,Text=''}end
   for _,child in ShadowTree.FlatChildren(node)do visit(child,style)end
   generated(node,'after',style);if node.Name=='select'then generated(node,'picker-icon',style)end;Counters.leave(state)
  else for _,child in ShadowTree.FlatChildren(node)do visit(child,inherited)end end
 end
 visit(document,nil)
 local function compare(node)
  local old,new=previous[node]or{},records[node]or{}
  for _,name in {'before','after','marker','first-letter','picker-icon','checkmark'}do
   local a,b=old[name],new[name]
   if (a==nil)~=(b==nil)or a and b and(a.Text~=b.Text or a.Number~=b.Number)then changed[node]=true;break end
   if a and b and a.Style~=b.Style then
    local interaction=false
    for field in fields do
     -- Viewport metadata alone is not generated-box geometry. Real vw/vh
     -- changes are reflected in their resolved size/spacing/font fields.
     if field~='ViewportWidth'and field~='ViewportHeight'and not same(a.Style[field],b.Style[field])then
      if interactionFields[field]then interaction=true else changed[node]=true;break end
     end
    end
    if interaction and not changed[node]then
     -- Inline generated runs and markers retain this computed-style identity.
     -- Cursor/selection/hit testing changes cannot invalidate their glyphs,
     -- counters or geometry. Cloned block/first-letter styles are synchronized
     -- by the renderer through the interaction publication below.
     for field in interactionFields do a.Style[field]=b.Style[field]end
     a.Style.ViewportWidth,a.Style.ViewportHeight=b.Style.ViewportWidth,b.Style.ViewportHeight
     b.Style=a.Style
     local updates=interactions[node]or{};interactions[node]=updates;updates[name]=a.Style
    end
   end
  end
 end
 for node in previous do compare(node)end;for node in records do if not previous[node]then compare(node)end end
 return records,changed,interactions
end
return Generated
