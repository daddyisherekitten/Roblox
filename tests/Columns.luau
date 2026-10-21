--!strict
return function(Parser,Style,Columns,loadRenderTree,loadWordLayout,loadBlockLayout,reference,Dirty,BorderBox)
 local fixtureElement=require('DOM/Node').element
 local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or .0001),tostring(a)..' differs from '..tostring(b)) end
 local function create(class,parent,props)
  local object={ClassName=class,Parent=parent,Position={0,0},Size={0,0},Visible=true}
  for key,value in props or {} do object[key]=value end
  function object:Destroy() self.Destroyed=true end
  return object
 end
 local widths={}
 for _,child in reference.children do for text,width in child.words do widths[text]=width end end
 local measure={measure=function(text,_,size)return {X=widths[text] or (utf8.len(text) or 0)*6,Y=size}end}
 local overrides={['Layout/TextMeasure']=measure,['Layout/FontProfiles']={face=function(font)return font end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local factory={create=create,modifier=create}
 local renderer=loadRenderTree(factory)
 local source='<style>*{box-sizing:border-box}#columns{font-family:Arial;font-size:13px;line-height:1.5;columns:2 145px;column-gap:22px;column-rule:1px solid #a8c4d9;column-fill:balance;orphans:2;widows:2}p{margin:0 0 14px;line-height:1.55}h4{font-size:13px;line-height:1.5;margin:8px 0;column-span:all;padding:7px;background:#e9f3fa}</style><div id="columns">'
 for _,child in reference.children do source..='<'..child.tag..'>'..child.text..'</'..child.tag..'>' end
 source..='</div>'
 local tree=renderer.build(Parser.parse(source),{},error)
 local box=tree.Children[1]
 local function arrange(width) layout.arrange(tree,width,0,0,function()return true end) end
 arrange(reference.width)
 assert(box.ColumnLayout.Count==1,'Below the 312px threshold the widget must use one column')
 near(box.OuterHeight,reference.height,.25)
 for index,child in box.Children do
  near(child.OuterWidth,reference.children[index].width,.1)
  near(child.LayoutY,reference.children[index].top,.25)
  near(child.OuterHeight,reference.children[index].height,.15)
 end
 local firstWord=box.Children[1].Children[1].Items[1]
 local heading=box.Children[2]
 local gridAutoFlow=box.Style.GridAutoFlow
 for _,width in {480,320,311.5,700,250,480,480} do
  arrange(width)
  local count=if width>=312 then 2 else 1
  local columnWidth=(width-22*(count-1))/count
  assert(box.ColumnLayout.Count==count and not box.ColumnMode,'Columns never use implicit Grid tracks')
  near(box.ColumnLayout.Width,columnWidth)
  near(heading.OuterWidth,width)
  assert(firstWord==box.Children[1].Children[1].Items[1],'Resize must reuse word objects')
  assert(box.Style.GridAutoFlow==gridAutoFlow,'Columns must not mutate grid auto-flow')
  local before,after={},{}
  for _,fragment in box.ColumnLayout.Fragments do
   assert(fragment.Column<=count,'Balancing must fit the requested number of columns')
   near(fragment.Width,columnWidth)
   assert(fragment.X>=0 and fragment.X+fragment.Width<=width+.001,'Fragments must fit the column bounds')
   local region=if fragment.Box==box.Children[1] then before else after
   local bottom=region[fragment.Column] or 0
   assert(fragment.Y>=bottom-.001,'Successive lines in one column cannot overlap')
   region[fragment.Column]=fragment.Y+fragment.Height
  end
  local seen={}
  for _,child in box.Children do
   if child==heading then continue end
   local run=child.Children[1]
   local counts={}
   for _,word in run.DisplayItems or run.Items do
    if word.Kind=='Break' then continue end
    assert(word.ColumnIndex>=1 and word.ColumnIndex<=count)
    near(word.Gui.Position[1],word.X)
    near(word.Gui.Position[2],word.Y)
    assert(word.LineLeft>=0 and word.LineRight<=width+.001)
    counts[word.ColumnIndex]=counts[word.ColumnIndex] or {}
    counts[word.ColumnIndex][word.LineIndex]=true
    seen[word]=true
   end
   if next(counts) and counts[2] then
    for _,indices in counts do local n=0;for _ in indices do n+=1 end;assert(n>=2,'Orphans/widows must keep at least two paragraph lines on each side') end
   end
  end
  assert(seen[firstWord],'Fragmentation cannot lose text')
  for _,rule in box.ColumnRules do if count==1 then assert(not rule.Visible,'Resize hides old column rules') end end
 end
 local function resolved(css) return Style.resolve(fixtureElement('div',{style=css}),{Font='Arial',FontSize=13,Color=Color3.new()},error) end
 local s=resolved('columns:3 100px;column-gap:10px')
 assert(Columns.geometry(s,320)==3 and Columns.geometry(s,209)==1)
 assert(not Columns.is(resolved('display:grid;columns:2')) and not Columns.is(resolved('display:flex;columns:2')))
 local atomic=renderer.build(Parser.parse('<div style="columns:2;column-gap:10px;direction:rtl"><div style="height:20px"></div><div style="height:20px"></div><div style="height:20px"></div><div style="height:20px"></div></div>'),{},error)
 layout.arrange(atomic,110,0,0,function()return true end)
 assert(atomic.Children[1].Children[1].LayoutX==60 and atomic.Children[1].Children[3].LayoutX==0,'RTL orders whole block fragments from the right')
 local plain=renderer.build(Parser.parse('<div style="columns:2;column-gap:10px;line-height:20px;padding:5px">'..reference.children[1].text..'</div>'),{},error)
 layout.arrange(plain,310,0,0,function()return true end)
 local plainBox,foundSecond=plain.Children[1],false
 local plainRun=plainBox.Children[1]
 for _,word in plainRun.Items do
  if word.ColumnIndex==2 then
   assert(word.Gui.Position[1]>=160,'Anonymous text must paint in the second column without a block GUI origin')
   foundSecond=true
  end
 end
 assert(foundSecond,'Long anonymous text must fragment across columns')
 local function dirtyUpdate(items)
  Dirty.begin(tree,items);arrange(480);Dirty.finish(tree,true)
 end
 dirtyUpdate()
 local positions={}
 for _,child in box.Children do for _,run in child.Children do for _,word in run.Items or {} do positions[word]={word.X,word.Y,word.LineTop,word.ColumnIndex} end end end
 for _=1,3 do
  dirtyUpdate({[firstWord]=true})
  for word,saved in positions do near(word.X,saved[1]);near(word.Y,saved[2]);near(word.LineTop,saved[3]);assert(word.ColumnIndex==saved[4],'Partial updates must not accumulate fragment offsets') end
 end
 box.Style.ColumnRuleStyle,box.Style.ColumnRuleWidth='dotted',3
 arrange(480)
 local pool=box.ColumnRulePatterns[1]
 assert(box.ColumnRules[1].BackgroundTransparency==1 and #pool.Parts>1,'A dotted column rule needs gaps between visible marks')
 local borderStyle=resolved('border-left:3px dotted #369')
 local border=BorderBox.create(borderStyle,create('Frame',nil,{}),factory)
 BorderBox.arrange(border,borderStyle,3,box.ColumnLayout.Segments[1].Height)
 local borderPool=border.Pools[2]
 assert(#pool.Parts==#borderPool.Parts,'Borders and column rules share the same dot count')
 for index=1,#pool.Parts do
  local dot,edge=pool[index],borderPool[index]
  near(dot.Position[1],edge.Position[1]);near(dot.Position[2],edge.Position[2])
  near(dot.Size[1],edge.Size[1]);near(dot.Size[2],edge.Size[2])
  assert(pool.Corners[index].CornerRadius.Scale==.5,'Column-rule dots must use the border renderer\'s circular UICorner')
 end
 local retained=pool[1]
 box.Style.ColumnRuleStyle='dashed';box.Style.ColumnRuleColor=Color3.new(1,0,0);box.Style.ColumnRuleColorAlpha=.5
 arrange(480)
 assert(pool[1]==retained and pool.Corners[1].CornerRadius.Scale==0,'Changing style reuses marks and removes dotted rounding')
 near(pool[1].BackgroundTransparency,.5);assert(pool[1].BackgroundColor3==Color3.new(1,0,0))
 box.Style.ColumnRuleStyle='double';arrange(480)
 assert(#pool.Parts==2 and pool[1].Size[1]==1 and pool[2].Position[1]==2,'Double column rules use the border renderer\'s separated bands')
 box.Style.ColumnRuleStyle='solid';arrange(480)
 assert(#pool.Parts==1 and pool[1].Visible and not pool[2].Visible,'Solid rules hide old pattern segments')
 box.Style.ColumnRuleStyle='none';arrange(480);assert(not box.ColumnRules[1].Visible)
 local dynamic=renderer.build(Parser.parse('<style>#cols{columns:2;column-rule:3px solid blue}#cols:hover{column-rule-style:dotted}</style><div id="cols">One two three four five six seven eight nine ten eleven twelve.</div>'),{},error)
 local dynamicBox=dynamic.Children[1]
 dynamic:SetCSSState('hover',dynamicBox.Node)
 layout.arrange(dynamic,180,0,0,function()return true end)
 assert(dynamicBox.Style.ColumnRuleStyle=='dotted' and #dynamicBox.ColumnRulePatterns[1].Parts>1,'Live CSS state changes update column rules')
 print('Columns: native HTML at narrow width, repeated resize, full-width spanners, line fragmentation, bounds, orphan/widow protection, rules, RTL and Grid isolation passed')
end
