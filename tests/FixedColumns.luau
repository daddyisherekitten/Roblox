--!strict
-- Native browser word positions for the real CSS catalog column probes.
return function(Parser,loadRenderTree,loadWordLayout,loadBlockLayout,references)
 local function near(a,b,tolerance)assert(math.abs(a-b)<(tolerance or .15),tostring(a)..' differs from '..tostring(b))end
 local function create(class,parent,props)
  local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent
  function gui:Destroy()self.Destroyed=true end
  return gui
 end
 local renderer=loadRenderTree({create=create,modifier=create})
 local css='<style>.property-probe{display:block;box-sizing:border-box;width:140px;max-width:100%;min-height:34px;padding:7px;border:2px solid #80a6d4;background:#d4e4f6;color:#173d68;font:14px/1.4 Arial;overflow-wrap:anywhere}</style>'
 for _,reference in references do
  local widths={}
  local expected={}
  for _,word in reference.words do
   widths[word.text]=math.max(widths[word.text] or 0,word.width)
   if word.text~=' ' then table.insert(expected,word) end
  end
  local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=widths[text] or #text*6,Y=size}end}}
  overrides['Layout/WordLayout']=loadWordLayout(overrides)
  local layout=loadBlockLayout(overrides)
  local tree=renderer.build(Parser.parse(css..reference.html),{},function()end)
  local box=tree.Children[1]
  local gap=tonumber(string.match(reference.gap,'[%d.]+'))
  local columnWidth=(122-gap)/2
  local usedCount=1
  for _,word in expected do usedCount=math.max(usedCount,math.floor((word.x-9+.01)/(columnWidth+gap))+1) end
  local wrapped=reference.property=='column-height' or reference.property=='column-wrap'
  for _,width in {300,180,300} do
   layout.arrange(tree,width,0,0,function()return true end)
   near(box.OuterWidth,reference.outerWidth);near(box.OuterHeight,reference.outerHeight)
   local run=box.Children[1];local words=run.DisplayItems or run.Items
   assert(#words==#expected,reference.property..' must preserve all words')
   local firstY=words[1].Gui.Position[2]
   for index,word in words do
    local native=expected[index]
    assert(word.Text==native.text,reference.property..': text order differs')
    assert(math.abs(word.Gui.Position[1]-native.x)<.15,reference.property..': '..word.Text..' x '..word.Gui.Position[1]..' differs from '..native.x)
    near(word.Gui.Position[2]-firstY,native.y-expected[1].y)
    if not wrapped then assert(word.LineTop+word.LineHeight<=66+.01,'Column lines must fit the 57px content height, starting after 9px of border/padding') end
   end
   assert(box.ColumnLayout.Count==2 and (wrapped or box.ColumnLayout.UsedCount==usedCount),'Overflow column count must match the native browser')
   near(box.UnclippedRight,math.max(140,9+usedCount*columnWidth+(usedCount-1)*gap))
   for _,segment in box.ColumnLayout.Segments do
    if not wrapped then assert(segment.Count==usedCount);near(segment.Height,57) end
   end
   if box.Style.ColumnRuleStyle~='none' then
    assert(#box.ColumnRules==usedCount-1,'Rules must separate overflow columns as well')
    for _,rule in box.ColumnRules do near(rule.Size[2],57) end
   end
  end
 end
 -- Automatic-height balancing still grows normally; a max-height also caps
 -- the fragment area and contributes horizontal overflow to the canvas.
 local words='One two three four five six seven eight nine ten. Eleven twelve thirteen fourteen.'
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return{X=#text*6,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 for _,style in {'height:57px','max-height:57px','height:90px;max-height:57px','height:57px;column-fill:auto'} do
  local tree=renderer.build(Parser.parse('<div style="columns:2;column-gap:8px;font:12px/1.4 Arial;'..style..'">'..words..'</div>'),{},function()end)
  layout.arrange(tree,122,0,0,function()return true end)
  local box=tree.Children[1]
  assert(box.ColumnLayout.UsedCount>2 and box.OuterHeight<=57,'Both definite height and max-height constrain overflow fragments')
 end
 print('Fixed columns: native HTML word positions for '..#references..' catalog probes, 57px fragment height, overflow columns, rules, horizontal extents, resize, max-height and auto fill passed')
end
