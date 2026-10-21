--!strict
-- Outline text: layout in user units, then reuse the SVG path paint/compositing pipeline.
-- Source Sans Pro (OFL) is the bundled font. No Roblox TextLabels or demo-string atlas.
local Length=require(script.Parent.Length)
local Path=require(script.Parent.Path)
local TextFont=require(script.Parent.TextFont)
local TextPath=require(script.Parent.TextPath)
local Text={Font=TextFont,Paths=TextPath}
-- A glyph's outline is shared by every occurrence, size and hover state.
-- Check the source string so externally supplied mutable fonts stay correct.
local glyphPaths=setmetatable({},{__mode='k'})
local function glyphPath(glyph)
 local cached=glyphPaths[glyph]
 if cached and cached.Source==glyph.Path then return cached.Parts end
 local parts=Path.parse(glyph.Path)
 glyphPaths[glyph]={Source=glyph.Path,Parts=parts}
 return parts
end
local function numberList(value: string?,context: any,axis: string,report: any): any
 local result={}
 if not value then return result end
 if value:match('^%s*,') or value:match(',%s*,') or value:match(',%s*$') then report('invalid-text-position-list',value);return result end
 for token in value:gmatch('[^,%s]+') do
  local n=if axis=='angle' then tonumber(token) else Length.resolve(token,context,axis,false)
  if not n or n~=n or math.abs(n)>1e6 then report('invalid-text-position-list',value);return {} end
  if #result>=4096 then report('text-position-limit',value:sub(1,40));break end
  table.insert(result,n)
 end
 return result
end
local function distance(value: string?,context: any): number
 return if not value or value=='normal' or value=='baseline' then 0 else Length.resolve(value,context,'font',false) or 0
end
function Text.kern(font: any,left: number,right: number): number
 for _,rule in font.Kern or {} do
  if rule.Coverage then
   if rule.Coverage[left] then return rule.Pairs[tostring(rule.Class1[left] or 0)..':'..tostring(rule.Class2[right] or 0)] or 0 end
  else local value=rule.Pairs[tostring(left)..':'..tostring(right)];if value then return value end end
 end
 return 0
end
local function baseline(a: any,font: any,size: number,context: any): number
 local key=a['alignment-baseline']
 if not key or key=='auto' or key=='baseline' then key=a['dominant-baseline'] end
 local scale=size/font.Units
 local shift=0
 if key=='middle' then shift=font.XHeight*scale/2
 elseif key=='central' then shift=(font.Ascent+font.Descent)*scale/2
 elseif key=='hanging' then shift=font.Ascent*scale*.8
 elseif key=='text-before-edge' or key=='before-edge' then shift=font.Ascent*scale
 elseif key=='text-after-edge' or key=='after-edge' or key=='ideographic' then shift=font.Descent*scale end
 local bs=a['baseline-shift']
 return shift-(if bs=='super' then size*.6 elseif bs=='sub' then -size*.6 else distance(bs,context))
end
function Text.expand(root: any,context: any,diagnostic: any?,resolveFont: any?): (any,any)
 local seen={};local problems={}
 local function report(code: string,value: any)
  local key=code..':'..tostring(value)
  if not seen[key] and #problems<32 then seen[key]=true;table.insert(problems,{Code=code,Value=value});if diagnostic then diagnostic(code,value) end end
 end
 local records,recordsByNode,raw={},{},{}
 local function fontFor(a: any): any
  local font=if resolveFont then resolveFont(a['font-family'],a['font-weight'],a['font-style']) else nil
  if font then return font end
  local family=(a['font-family'] or 'Source Sans Pro'):lower():gsub('["\']','')
  local available=false
  for candidate in family:gmatch('[^,]+') do
   candidate=candidate:match('^%s*(.-)%s*$') :: string
   if candidate=='source sans pro' or candidate=='sans-serif' then available=true;break end
  end
  if not available then report('svg-font-fallback',a['font-family']) end
  local bold=a['font-weight']=='bold' or (tonumber(a['font-weight']) or 400)>=600
  local italic=a['font-style']=='italic' or a['font-style']=='oblique'
  return if bold and italic then TextFont.Faces.BoldIt elseif bold then TextFont.Faces.Bold elseif italic then TextFont.Faces.It else TextFont
 end
 local walk
 walk=function(node: any,ancestors: any,depth: number,preserve: boolean)
  if depth>64 then report('text-depth-limit',64);return end
  if node.Kind~='Element' or node.Attributes.display=='none' then return end
  local a=node.Attributes;local ctx=table.clone(context)
  ctx.FontSize=Length.resolve(a['font-size'] or '16',context,'font',true) or 16
  local record={Node=node,Index=0,Context=ctx,Font=fontFor(a),Depth=depth,Positions={},First=math.huge,Last=0}
  local parentRecord=ancestors[#ancestors]
  record.Path=if node.Name=='textPath' then TextPath.resolve(context.Document,node,ctx,report) or false else parentRecord and parentRecord.Path
  for _,key in {'x','y','dx','dy','rotate'} do record.Positions[key]=numberList(if node.Name=='textPath' then nil else a[key],ctx,if key=='rotate' then 'angle' elseif key=='x' or key=='dx' then 'x' else 'y',report) end
  table.insert(records,record)
  if not recordsByNode[node]then recordsByNode[node]=record end
  local chain=table.clone(ancestors);table.insert(chain,record)
  local space=a['xml:space']
  preserve=if space=='preserve' then true elseif space=='default' then false else preserve
  local ws=a['white-space'] or 'normal';preserve=preserve or ws=='pre' or ws=='pre-wrap' or ws=='break-spaces'
  if a['unicode-bidi'] and a['unicode-bidi']~='normal' and a['unicode-bidi']~='bidi-override' then report('text-bidi-mode-unimplemented',a['unicode-bidi']) end
  for _,child in node.Children do
   if child.Kind=='Text' then
    for _,cp in utf8.codes(child.Text) do
     if #raw>=16384 then report('text-character-limit',4096);return end
     local whitespace=cp==32 or cp==9 or cp==10 or cp==13
     local newline=(preserve or ws=='pre-line') and (cp==10 or cp==13)
     table.insert(raw,{CP=if newline then 10 elseif whitespace then 32 else cp,White=whitespace,Preserve=preserve or newline,Break=newline,Owner=record,Chain=chain})
    end
   elseif child.Name=='tspan' or child.Name=='textPath' then walk(child,chain,depth+1,preserve)
   else report('unsupported-text-child',child.Name) end
  end
 end
 walk(root,{},0,false)
 local chars={};local lastVisible=0
 for j=#raw,1,-1 do if not raw[j].White or raw[j].Preserve then lastVisible=j;break end end
 for i,c in raw do
  if c.White and not c.Preserve then
   if #chars==0 or chars[#chars].White then continue end
   if i>lastVisible then continue end
  end
  if #chars>=4096 then report('text-character-limit',4096);break end
  local pos={}
  for _,r in c.Chain do
   r.Index+=1
   for key,list in r.Positions do
    local v=if key=='rotate' and #list>0 then list[math.min(r.Index,#list)] else list[r.Index]
    if v~=nil then pos[key]=v end
   end
  end
  c.Position=pos;table.insert(chars,c)
 end
 local glyphs,chunks={},{}
 local x,y=0,0;local chunk=nil;local previous=nil;local i=1;local activePath=nil;local lineX,lineY=0,0
 while i<=#chars do
  local c=chars[i];local r=c.Owner;local a=r.Node.Attributes;local font=r.Font;local p=c.Position
  local size=r.Context.FontSize;local scale=size/font.Units
  local vertical=a['writing-mode']=='vertical-rl' or a['writing-mode']=='vertical-lr'
  if c.Break then
   if r.Path~=nil or vertical then report('text-line-break-mode-unimplemented','textPath/vertical')
   else
    local lh=a['line-height'] or 'normal'
    local step=if lh=='normal' then (font.Ascent-font.Descent)*scale elseif tonumber(lh) then tonumber(lh)*size else Length.resolve(lh,r.Context,'font',true) or size*1.2
    lineY+=step;x,y=lineX,lineY;chunk=nil;previous=nil
   end
   i+=1;continue
  end
  if r.Path~=activePath then
   if activePath then x,y=TextPath.point(activePath,activePath.Length,true);x=x or 0;y=y or 0 end
   activePath=r.Path;chunk=nil;previous=nil
   if activePath~=nil then x,y=0,0 end
  end
  if r.Path~=nil and vertical then report('vertical-text-path-unimplemented','writing-mode') end
  if r.Path~=nil then p=table.clone(p);p.y=nil end
  if not chunk or p.x~=nil or p.y~=nil then
   x=p.x or x;y=p.y or y
   if #glyphs==0 or p.x~=nil then lineX=x end
   if #glyphs==0 or p.y~=nil then lineY=y end
   chunk={First=#glyphs+1,Last=#glyphs,X=x,Y=y,Vertical=vertical,Anchor=a['text-anchor'] or 'start',RTL=a.direction=='rtl',Override=a['unicode-bidi']=='bidi-override',Advance=0}
   table.insert(chunks,chunk);previous=nil
  elseif vertical~=chunk.Vertical then report('text-mixed-writing-mode-unimplemented',a['writing-mode']) end
  x+=p.dx or 0;y+=p.dy or 0
  local cp=c.CP;local consumed=1
  local function compatible(nextIndex: number): boolean
   local nextChar=chars[nextIndex]
   if not nextChar or nextChar.Owner~=r then return false end
   local q=nextChar.Position
   return q.x==nil and q.y==nil and q.dx==nil and q.dy==nil and q.rotate==nil and p.rotate==nil
  end
  if compatible(i+1) then
   local composed=font.Compose[tostring(cp)..':'..tostring(chars[i+1].CP)]
   if composed then cp=composed;consumed=2 end
  end
  local id=font.Cmap[cp]
  if not id then report('svg-missing-glyph',cp);id=0 end
  if cp>=0x590 and cp<=0x8ff then report('text-complex-shaping-required',cp) end
  if cp>=0x300 and cp<=0x36f then report('text-mark-positioning-unimplemented',cp) end
  if consumed==1 and a['font-variant-ligatures']~='none' and a['font-variant-ligatures']~='no-common-ligatures' and distance(a['letter-spacing'],r.Context)==0 and p.rotate==nil then
   for _,lig in font.Ligatures or {} do
    if lig.Sequence[1]~=id then continue end
    local matches=true
    for j=2,#lig.Sequence do if not compatible(i+j-1) or font.Cmap[chars[i+j-1].CP]~=lig.Sequence[j] then matches=false;break end end
    if matches then id=lig.Glyph;consumed=#lig.Sequence;break end
   end
  end
  local glyph=font.Glyphs[id] or font.Glyphs[0]
  if previous and previous.Owner==r and p.dx==nil and p.dy==nil and a['font-kerning']~='none' then
   local kern=Text.kern(font,previous.Id,id)*scale
   if vertical then y+=kern else x+=kern end
  end
  local advance=(if vertical and a['text-orientation']=='upright' then size else glyph.Advance*scale)+distance(a['letter-spacing'],r.Context)+(if cp==32 then distance(a['word-spacing'],r.Context) else 0)
  local entry={Id=id,Glyph=glyph,Owner=r,CP=cp,X=x,Y=y,Scale=scale,Stretch=1,Advance=advance,Rotation=p.rotate or 0,Vertical=vertical,Shift=baseline(a,font,size,r.Context),Chunk=chunk,Consumed=consumed}
  entry.Path=r.Path
  table.insert(glyphs,entry);chunk.Last=#glyphs
  for _,ancestor in c.Chain do ancestor.First=math.min(ancestor.First,#glyphs);ancestor.Last=#glyphs end
  if vertical then y+=advance else x+=advance end
  chunk.Advance=if vertical then y-chunk.Y else x-chunk.X
  previous=entry;i+=consumed
 end
 -- Inner textLength ranges first. Adjust subsequent positions without changing stroke widths.
 for index=#records,1,-1 do
  local r=records[index];local a=r.Node.Attributes
  if a.textLength and r.Last>=r.First then
   local wanted=Length.resolve(a.textLength,r.Context,'x',true)
   local first,last=glyphs[r.First],glyphs[r.Last]
   if not wanted or wanted>1e6 then report('invalid-text-length',a.textLength)
   elseif first.Chunk~=last.Chunk then report('text-length-multiple-chunks-unimplemented',a.textLength)
   else
    local axis=if first.Vertical then 'Y' else 'X';local start=first[axis];local width=last[axis]+last.Advance-start
    local mode=a.lengthAdjust or 'spacing'
    if mode~='spacing' and mode~='spacingAndGlyphs' then report('invalid-length-adjust',mode);mode='spacing' end
    if width>0 and (mode=='spacingAndGlyphs' or r.Last>r.First) then
     local delta=wanted-width;local factor=wanted/width
     for j=r.First,r.Last do
      local g=glyphs[j]
      if mode=='spacingAndGlyphs' then g[axis]=start+(g[axis]-start)*factor;g.Stretch*=factor;g.Advance*=factor
      else g[axis]+=(j-r.First)*delta/(r.Last-r.First) end
     end
     for j=r.Last+1,first.Chunk.Last do glyphs[j][axis]+=delta end
     first.Chunk.Advance+=delta
    end
   end
  end
 end
 for _,part in chunks do
  local offset=if part.Anchor=='middle' then -part.Advance/2 elseif (part.Anchor=='end' and not part.RTL) or (part.Anchor=='start' and part.RTL) then -part.Advance else 0
  local axis=if part.Vertical then 'Y' else 'X';local start=if part.Vertical then part.Y else part.X
  for j=part.First,part.Last do
   local g=glyphs[j]
   if part.Override and part.RTL then g[axis]=start+part.Advance-(g[axis]-start)-g.Advance end
   g[axis]+=offset
  end
 end
 local groups={}
 for _,r in records do
  local node=table.clone(r.Node);node.Name='g';node.Children={};node.Attributes=table.clone(node.Attributes)
  for _,key in {'x','y','dx','dy','rotate','textLength','lengthAdjust'} do node.Attributes[key]=nil end
  groups[r]=node
 end
 -- Preserve text/tspan paint order by collecting paths in original character order below.
 local emitted={}
 for _,g in glyphs do
  local placement=nil
  if g.Path~=nil then
   if not g.Path or g.Vertical then continue end
   placement=TextPath.place(g.Path,g)
   if not placement then continue end
  end
  local r=g.Owner;local owner=groups[r]
  local ancestor=r.Node.Parent
  local branch=owner
  while ancestor and ancestor~=root.Parent do
   local parentRecord=recordsByNode[ancestor]
   if not parentRecord then break end
   if not emitted[branch] then table.insert(groups[parentRecord].Children,branch);emitted[branch]=true end
   branch=groups[parentRecord];ancestor=ancestor.Parent
  end
  local angle=math.rad(g.Rotation+(if g.Vertical and r.Node.Attributes['text-orientation']~='upright' then 90 else 0))+(if placement then placement.Angle else 0)
  local cosine,sine=math.cos(angle),math.sin(angle)
  local function point(p: any): (string,any)
   local xx=p[1]*g.Scale*g.Stretch;local yy=-p[2]*g.Scale
   local shift=g.Shift
   local ox,oy=g.X,g.Y+shift
   if placement then ox,oy=placement.X,placement.Y end
   if g.Vertical then
    if r.Node.Attributes['text-orientation']=='upright' then ox-=g.Glyph.Advance*g.Scale/2;oy+=r.Font.Ascent*g.Scale
    else ox-=(r.Font.Ascent+r.Font.Descent)*g.Scale/2 end
   end
   -- Keep the historical six-decimal outline precision for identical coverage,
   -- and retain those coordinates instead of tokenizing this generated d again.
   local px=string.format('%.6f',ox+xx*cosine-yy*sine)
   local py=string.format('%.6f',oy+xx*sine+yy*cosine)
   return px..' '..py,{tonumber(px),tonumber(py)}
  end
  local parts=glyphPath(g.Glyph);local commands={};local outlines={}
  for _,part in parts do
   local startText,startPoint=point(part.Points[1])
   local outline={Points={startPoint},Curves={},Closed=part.Closed};table.insert(outlines,outline)
   table.insert(commands,'M'..startText)
   for j=2,#part.Points do
    local endText,endPoint=point(part.Points[j]);outline.Points[j]=endPoint
    local curve=part.Curves[j]
    if curve then
     local controlText,control=point(curve.Control1)
     local mapped={Kind=curve.Kind,Control1=control};outline.Curves[j]=mapped
     if curve.Control2 then local text,value=point(curve.Control2);controlText..=' '..text;mapped.Control2=value end
     table.insert(commands,curve.Kind..controlText..' '..endText)
    else table.insert(commands,'L'..endText) end
   end
   if part.Closed then table.insert(commands,'Z') end
  end
  local attributes=table.clone(r.Node.Attributes)
  for _,key in {'id','x','y','dx','dy','rotate','textLength','lengthAdjust','transform','transform-origin','transform-box','style','filter','clip-path','mask-image','mix-blend-mode','isolation'} do attributes[key]=nil end
  attributes.opacity='1';attributes.d=table.concat(commands,' ')
  for _,key in {'marker-start','marker-mid','marker-end'} do attributes[key]='none' end
  table.insert(owner.Children,{Kind='Element',Name='path',NamespaceURI=root.NamespaceURI,Attributes=attributes,OutlineSubpaths=outlines,Children={},Parent=owner,Scope=r.Node.Scope,Source=r.Node.Source,EventSource=r.Node.EventSource,Computed=r.Node.Computed,TextRoot=groups[records[1]]})
 end
 local result=groups[records[1]] or {Kind='Element',Name='g',NamespaceURI=root.NamespaceURI,Attributes={},Children={}}
 return result,{Glyphs=glyphs,Chunks=chunks,Diagnostics=problems}
end
return Text
