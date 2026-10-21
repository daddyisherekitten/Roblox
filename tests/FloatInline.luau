--!strict
-- Native font bounds are the seam; DOM construction and all flow/layout code
-- are the production implementations. No original game image is decoded.
return function(Parser,DOM,loadRenderTree,loadWordLayout,loadBlockLayout,reference,bombHTML,bombCSS,bombImages)
 local function near(actual,expected,label,tolerance)
  assert(type(actual)=='number'and math.abs(actual-expected)<(tolerance or .15),label..': '..tostring(actual)..' differs from '..tostring(expected))
 end
 local allocations=0
 local function create(class,parent,props)
  allocations+=1
  local object={ClassName=class,Parent=parent,Position={0,0},Size={0,0},Visible=true,BackgroundTransparency=1}
  for key,value in props or{}do object[key]=value end
  function object:Destroy()self.Destroyed=true end
  return object
 end
 local function measure(text,_,size)
  return {X=(reference.textMetrics.widths[text]or #text*11)*size/20,Y=size}
 end
 local renderer=loadRenderTree({create=create,measure=measure})
 local metrics={
  resolve=function(style)
   local size=style.FontSize
   return {TextSize=size,Baseline=size*reference.textMetrics.baseline/20,Top=0,XHeight=size*.3,Bottom=size,Calibrated=true}
  end,
  extents=function(style,font,measuredHeight)
   local line=style.LineHeight;local height=math.max(font.TextSize,measuredHeight or 0)
   if line and line.Kind=='px'then height=line.Value elseif line and line.Kind=='number'then height=style.FontSize*line.Value end
   local leading=(height-font.TextSize)/2
   return {Ascent=font.Baseline+leading,Descent=font.TextSize-font.Baseline+leading}
  end,
 }
 local overrides={['Layout/TextMeasure']={measure=measure},['Layout/FontProfiles']={face=function(font)return font end},['Layout/FontMetrics']=metrics}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local function ids(tree)
  local out={}
  for node,box in tree.NodeBoxes do if node.Attributes and node.Attributes.id then out[node.Attributes.id]=box end end
  return out
 end
 local function arrange(tree,width)
  layout.arrange(tree,width,0,0,function()return true end)
 end
 local anchors=0
 local function checkAnchors(tree)
  local stack={tree}
  while #stack>0 do
   local box=table.remove(stack)
   if box.Kind=='Words'then
    for _,item in box.Items do if item.Kind=='Float'then
     anchors+=1
     assert(item.Gui==nil and item.Width==nil and item.Height==nil,'A float anchor has no inline GUI or measured word geometry')
     assert(item.BidiParagraph==nil and item.BidiPositions==nil,'A float anchor is absent from bidi paragraph resolution')
    end end
    for _,item in box.DisplayItems or{}do assert(item.Kind~='Float','Float anchors cannot enter retained text paint arrays')end
   end
   for _,child in box.Children or{}do table.insert(stack,child)end
  end
 end
 for _,test in reference.cases do
  local document=Parser.parse('<!doctype html><html><head><style>'..reference.baseCSS..(test.css or'')..'</style></head><body><div id="container">'..test.body..'</div></body></html>')
  local tree=renderer.build(document,{},error,function(font)return font end)
  arrange(tree,test.width)
  local boxes=ids(tree)
  for name,expected in test.geometry do
   if name=='text'then continue end
   local box=assert(boxes[name],test.name..' missing '..name)
   local label=test.name..' @'..test.width..' #'..name
   near(box.LayoutX,expected.x,label..' x')
   near(box.LayoutY,expected.y,label..' y')
   near(box.OuterWidth,expected.width,label..' width')
   near(box.OuterHeight,expected.height,label..' height')
  end
  if test.geometry.text then
   local lines={}
   for _,run in boxes.container.Children do if run.Kind=='Words'then
    for _,item in run.DisplayItems or run.Items do if item.Kind=='Word'then
     local line=lines[item.LineIndex]
     if not line then line={X=item.X,Right=item.X+item.Width,Top=item.LineTop};lines[item.LineIndex]=line
     else line.X=math.min(line.X,item.X);line.Right=math.max(line.Right,item.X+item.Width)end
    end end
   end end
   local native=test.geometry.text.lineBoxes
   assert(#lines==#native,test.name..' native text line count')
   for index,line in lines do
    near(line.X,native[index].x,test.name..' line x',.6)
    near(line.Top,native[index].y-native[1].y,test.name..' line top')
    near(line.Right-line.X,native[index].width,test.name..' line width',.6)
   end
  end
  local gui=boxes.float.Gui;local before=allocations
  arrange(tree,test.width+41);arrange(tree,test.width)
  assert(boxes.float.Gui==gui and allocations==before,'A float resize reuses all existing GUI owners')
  near(boxes.float.LayoutY,test.geometry.float.y,test.name..' resized float y')
  checkAnchors(tree)
 end
 assert(anchors>=18,'The generic suite must exercise mixed inline/float anchors rather than only standalone floats')
 local directional=renderer.build(Parser.parse('<!doctype html><html><head><style>'..reference.baseCSS..'#container{direction:rtl}</style></head><body><div id="container"><span>א</span><div id="float" class="floater"></div><span>B</span></div></body></html>'),{},error,function(font)return font end)
 arrange(directional,600)
 local resolvedBidi=false
 for _,run in ids(directional).container.Children do if run.Kind=='Words'then
  for _,item in run.Items do if item.Kind=='Word'and item.BidiParagraph then resolvedBidi=true end end
 end end
 assert(resolvedBidi,'A mixed RTL paragraph must exercise the actual bidi resolver around the float anchor')
 checkAnchors(directional)
 -- Keep actual imported HTML and CSS. Each external raster is represented by
 -- an empty SVG with the same manifest dimensions at the resource boundary.
 local svgs={}
 for name,image in bombImages do
  svgs[name]=Parser.parse('<svg width="'..image.Width..'" height="'..image.Height..'" viewBox="0 0 '..image.Width..' '..image.Height..'"></svg>').Children[1]
 end
 local function svgFor(source)
  local name=source:match('([^/]+)$')
  return svgs[name]
 end
 local document=Parser.parse(bombHTML)
 local pageDiagnostics={}
 local bomb=renderer.build(document,{},function(message)pageDiagnostics[message]=true end,function(font)return font end,nil,nil,nil,bombCSS,nil,nil,nil,nil,nil,'http://localhost:8000/thebombmaker/index.html',nil,nil,nil,nil,svgFor)
 local boxes=ids(bomb)
 local gui=boxes.right.Gui
 for _,width in {800,1100,800}do
  arrange(bomb,width)
  near(boxes.right.LayoutY,boxes.left.LayoutY,'Imported page columns share their top')
  near(boxes.right.OuterWidth,boxes.container.ContentWidth*.68,'Imported page percentage float width')
  near(boxes.right.LayoutMargin[2],boxes.container.ContentWidth*.01,'Imported page percentage float margin')
  near(boxes.right.LayoutX,boxes.container.ContentWidth*.31,'Imported page right float x')
  assert(boxes.right.Gui==gui,'Imported page resize retains the same text-card GUI')
 end
 checkAnchors(bomb)
 local knownWarnings={['Unsupported style: font-size: 100%']=true,['Unsupported style: font-size: large']=true,
  ['Unsupported style on inline element: margin: 0']=true,['Unsupported style on inline element: padding: 0']=true,['Unsupported style on inline element: border: 0']=true}
 for message in pageDiagnostics do assert(knownWarnings[message],'Unexpected imported-page diagnostic: '..message)end
 print('Float inline: '..#reference.cases..' native geometry cases, preserved anchors, float clear/fit/side, text wrapping, resize reuse and original page columns passed')
end
