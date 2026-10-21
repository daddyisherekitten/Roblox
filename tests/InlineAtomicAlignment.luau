--!strict
-- Browser geometry uses neutral boxes. The imported document keeps its real
-- structure and styles; external rasters are empty SVGs of the same dimensions.
return function(Parser,DOM,loadRenderTree,loadWordLayout,loadBlockLayout,reference,pageHTML,pageCSS,pageImages)
 local function near(actual,expected,label,tolerance)
  assert(type(actual)=='number'and math.abs(actual-expected)<(tolerance or .12),label..': '..tostring(actual)..' differs from '..tostring(expected))
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
  return {X=(if text==' 'then reference.textMetrics.spaceWidth else #text*8)*size/16,Y=size}
 end
 local renderer=loadRenderTree({create=create,measure=measure})
 local metrics={
  resolve=function(style)
   local size=style.FontSize
   return {TextSize=size,Baseline=size*reference.textMetrics.baseline/16,Top=0,
    XHeight=size*(reference.textMetrics.baseline-reference.textMetrics.xHeight)/16,Bottom=size,Calibrated=true}
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
 local function arrange(tree,width)layout.arrange(tree,width,0,0,function()return true end)end
 for _,test in reference.cases do
  local document=Parser.parse('<!doctype html><html><head><style>'..reference.baseCSS..(test.css or'')..'</style></head><body><div id="container">'..test.body..'</div></body></html>')
  local tree=renderer.build(document,{},error,function(font)return font end)
  arrange(tree,test.width)
  local container=assert(tree.NodeBoxes[DOM.findById(document,'container')])
  near(container.OuterHeight,test.geometry.container.height,test.name..' container height')
  local retained={}
  for index,expected in test.geometry.columns do
   local box=assert(tree.NodeBoxes[DOM.findById(document,'column'..index)])
   retained[index]=box.Gui
   local label=test.name..' @'..test.width..' column '..index
   near(box.LayoutX,expected.x,label..' x')
   near(box.LayoutY,expected.y,label..' y')
   near(box.OuterWidth,expected.width,label..' width')
   near(box.OuterHeight,expected.height,label..' height')
  end
  local before=allocations
  arrange(tree,test.width+41);arrange(tree,test.width)
  for index,expected in test.geometry.columns do
   local box=tree.NodeBoxes[DOM.findById(document,'column'..index)]
   assert(box.Gui==retained[index],'Resizing retains each atomic inline GUI')
   near(box.LayoutY,expected.y,test.name..' restored column y')
  end
  assert(allocations==before,'Resizing must not allocate replacement atomic inline GUIs')
 end
 local svgs={}
 for name,image in pageImages do
  svgs[name]=Parser.parse('<svg width="'..image.Width..'" height="'..image.Height..'" viewBox="0 0 '..image.Width..' '..image.Height..'"></svg>').Children[1]
 end
 local function svgFor(source)return svgs[source:match('([^/]+)$')]end
 local document=Parser.parse(pageHTML)
 local pageDiagnostics={}
 local page=renderer.build(document,{},function(message)pageDiagnostics[message]=true end,function(font)return font end,nil,nil,nil,pageCSS,nil,nil,nil,nil,nil,'http://localhost:8000/mutilation/index.html',nil,nil,nil,nil,svgFor)
 local container=assert(DOM.findById(document,'container'))
 local columns={}
 for _,node in container.Children do
  if node.Attributes and node.Attributes.class=='w33'then table.insert(columns,assert(page.NodeBoxes[node]))end
 end
 assert(#columns==3,'The actual imported document retains its three original inline-block columns')
 local retained={columns[1].Gui,columns[2].Gui,columns[3].Gui}
 for _,width in {800,1100,1600,800}do
  arrange(page,width)
  local lines={}
  for _,run in page.NodeBoxes[container].Children do
   for _,item in run.Items or{}do if item.InlineBox then lines[item.LineIndex]=true end end
  end
  local lineCount=0
  for _ in lines do lineCount+=1 end
  assert(lineCount==(if width==800 then 2 else 1),'The actual imported columns wrap only at the narrow reference width')
  local centre=columns[1].LayoutY+columns[1].OuterHeight/2
  for index,column in columns do
   if width>800 or index<3 then
    near(column.LayoutY+column.OuterHeight/2,centre,'Actual page columns on the same line share the same vertical centre')
   else
    assert(column.LayoutY>=columns[1].LayoutY+columns[1].OuterHeight-.01,'A narrow imported row wraps its last column to the next line')
   end
   near(column.OuterWidth,page.NodeBoxes[container].ContentWidth*.33,'Actual percentage column width')
   assert(column.Gui==retained[index],'The actual imported columns retain their GUI across resize')
  end
  -- Each of the last two columns owns two image rows. Clear blocks must keep
  -- those floats inside their row and prevent one row from crossing another.
  for columnIndex=2,3 do
   local column=columns[columnIndex]
   local rows={}
   for _,node in column.Node.Children do
    if node.Attributes and node.Attributes.class=='mb'then table.insert(rows,assert(page.NodeBoxes[node]))end
   end
   assert(#rows==2,'The imported image column keeps both original rows')
   for _,row in rows do
    local clear
    local floatBottom=0
    for _,child in row.Children do
     if child.Kind=='Words'then continue end
     if child.Style.Float~='none'then floatBottom=math.max(floatBottom,child.LayoutY+child.OuterHeight)end
     if child.Style.Clear=='both'then clear=child end
    end
    assert(clear and clear.LayoutY>=floatBottom-.01,'Clearance follows both image floats')
    assert(row.OuterHeight>=floatBottom-.01,'A cleared row contains the full height of its image floats')
   end
   assert(rows[2].LayoutY>=rows[1].LayoutY+rows[1].OuterHeight-.01,'Imported image rows cannot overlap')
  end
 end
 local knownWarnings={['Unsupported style: font-size: 100%']=true,
  ['Unsupported style on inline element: margin: 0']=true,['Unsupported style on inline element: padding: 0']=true,
  ['Unsupported style on inline element: border: 0']=true}
 for message in pageDiagnostics do assert(knownWarnings[message],'Unexpected imported-page diagnostic: '..message)end
 print('Atomic inline alignment: '..#reference.cases..' native geometries, all vertical-align modes, float clearance, resize reuse and actual imported columns passed')
end
