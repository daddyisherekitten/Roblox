--!strict
-- UAX9 L1/L2 is a projection of each actual wrapped line. Logical owners and
-- source ranges are never reordered, so copying still follows DOM order.
local Bidi=require(script.Parent.Bidi)
local WhiteSpace=require(script.Parent.WhiteSpace)
local Work=require(script.Parent.Parent.WorkContext)
local Class=require(script.Parent.BidiClass)
local Paint={}
function Paint.text(item: any,text: string?): string
 local value=text or item.Text or ''
 local forced=item.NativeBidiForced
 if text and item.BidiDirection=='rtl'and not forced then
  -- A prefix or independently painted glyph may have no strong character
  -- although its owner does. Preserve the owner's resolved paragraph parity.
  forced=true;for _,code in utf8.codes(value)do local kind=Class.get(code);if kind=='R'or kind=='AL'then forced=false;break end end
 end
 if not forced or value==''then return value end
 -- Each retained label is one resolved directional run. Force that resolved
 -- parity, rather than asking an isolated label to guess paragraph context.
 return utf8.char(if item.BidiDirection=='rtl'then 0x202e else 0x202d)..value..utf8.char(0x202c)
end
function Paint.glyphX(item: any,glyph: any): number
 return if item.BidiDirection=='rtl'then item.Width-glyph.X-glyph.Width else glyph.X
end
function Paint.order(displayed: any)
 local lines={};local order={}
 for _,item in displayed do
  if item.Kind=='Break'or not item.LineIndex or not item.BidiParagraph then continue end
  if not lines[item.LineIndex]then lines[item.LineIndex]={};table.insert(order,item.LineIndex)end
  table.insert(lines[item.LineIndex],item)
 end
 for _,number in order do
  Work.checkpoint();local items=lines[number];local paragraph=items[1].BidiParagraph
  local first,last=math.huge,0
  for _,item in items do
   if item.BidiFirst then first=math.min(first,item.BidiFirst);last=math.max(last,item.BidiLast)end
   if item.BidiGap then first=math.min(first,item.BidiGap)end
  end
  if first==math.huge then continue end
  local line=Bidi.line(paragraph,first,last);local atoms={};local previous
  local start=items[1].X-(items[1].FragmentPaintLeft or 0)
  local hanging=0
  if paragraph.ParagraphLevel==1 then
   for index=#items,1,-1 do local item=items[index]
    if item.Kind~='Space'or not WhiteSpace.hanging(item.Style)then break end
    hanging+=item.Width
   end
   start-=hanging
  end
  for index,item in items do
   local level=if item.BidiFirst then line.Levels[item.BidiFirst]else nil
   item.BidiDirection=if (level or item.BidiLevel or 0)%2==1 then 'rtl'else 'ltr'
   local rank,finish=math.huge,0
   for _,position in item.BidiPositions or {}do local visual=line.Inverse[position.Index]
    if visual then rank=math.min(rank,visual);finish=math.max(finish,visual)end
   end
   if rank==math.huge then rank=if previous then previous.Rank+.01 else 0 end
   local left,right=item.FragmentPaintLeft or 0,item.FragmentPaintRight or 0
   local gap=if previous then item.X-left-previous.LogicalRight else 0
   item.BidiGapRect=nil
   if gap~=0 then
    local gapRank=item.BidiGap and line.Inverse[item.BidiGap]
    if not gapRank then gapRank=if item.BidiDirection=='rtl'then finish+.5 else rank-.5 end
    table.insert(atoms,{Rank=gapRank,Width=gap,Gap=item,Order=index*2-1})
   end
   local atom={Rank=rank,Width=left+item.Width+right,Item=item,Left=left,Right=right,Order=index*2,LogicalRight=item.X+item.Width+right}
   table.insert(atoms,atom);previous=atom
  end
  table.sort(atoms,function(a,b)return if a.Rank~=b.Rank then a.Rank<b.Rank else a.Order<b.Order end)
  -- Inline borders belong to each visual fragment's outer edges, not to the
  -- source endpoint word when that word is visually inside an LTR/RTL group.
  -- Keep the total reserved advance; distribute its two physical edges after
  -- ordering, so an asymmetric border never becomes an interior word gap.
  local group
  local function finishFragment()
   if not group then return end
   group.First.Left,group.Last.Right=group.Left,group.Right
   group.First.Width+=group.Left;group.Last.Width+=group.Right;group=nil
  end
  for index,atom in atoms do
   if index%64==0 then Work.checkpoint()end
   local owner=if atom.Item then atom.Item.Fragment elseif atom.Gap.SpaceBefore then atom.Gap.SpaceStyle and atom.Gap.SpaceStyle.InlineFragment else atom.Gap.Fragment
   if group and group.Owner~=owner then finishFragment()end
   if atom.Item and owner then
    if not group then group={Owner=owner,First=atom,Last=atom,Left=0,Right=0}end
    local left,right=atom.Left,atom.Right
    if owner.Style.Direction=='rtl'then left,right=right,left end
    group.Left+=left;group.Right+=right;group.Last=atom
    atom.Left,atom.Right,atom.Width=0,0,atom.Item.Width
   end
  end
  finishFragment()
  local x=start
  for _,atom in atoms do
   if atom.Item then
    local item=atom.Item;local left,right=atom.Left,atom.Right
    local edgeDirection=if item.Fragment then 'ltr'else item.BidiDirection
    if edgeDirection=='rtl'then left,right=right,left end
    item.FragmentPaintLeft,item.FragmentPaintRight=left,right
    item.X=x+left
   else atom.Gap.BidiGapRect={X=x,Width=atom.Width}end
   x+=atom.Width
  end
 end
end
function Paint.visual(items: any): any
 local active=false;for _,item in items do if item.BidiParagraph then active=true;break end end
 if not active then return items end
 local result=table.clone(items)
 table.sort(result,function(a,b)
  local al,bl=a.LineIndex or math.huge,b.LineIndex or math.huge
  if al~=bl then return al<bl end
  return (a.X or 0)<(b.X or 0)
 end)
 return result
end
return Paint
