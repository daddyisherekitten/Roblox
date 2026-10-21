--!strict
return function(Parser,Style,Floats,Flow,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local fixtureElement=require('DOM/Node').element
 local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or .0001),tostring(a)..' differs from '..tostring(b)) end
 local function resolved(css) return Style.resolve(fixtureElement('div',{style=css}),{Font='Arial',FontSize=14,Color=Color3.new()},error) end
 local function geometry(side,shape,margin)
  local style=resolved('width:120px;height:120px;margin:0 10px 6px 0;shape-outside:'..shape..';shape-margin:'..margin)
  local flow={Floats={},X=0,Y=0}
  Floats.add(flow,{Style=style,LayoutMargin=style.Margin,OuterWidth=120,OuterHeight=120},side,if side=='left' then 0 else 270,0,130,126,400)
  return flow
 end
 local circle=geometry('left','circle(50%)','10px')
 local top=Floats.bounds(circle,0,0,400,21.7)
 local middle=Floats.bounds(circle,0,43.4,400,21.7)
 local bottom=Floats.bounds(circle,0,108.5,400,21.7)
 near(top,126.390625,.15);near(middle,130);near(bottom,123.40625,.15)
 near(Floats.bounds(circle,0,126,400,21.7),0)
 assert(top<middle and bottom<middle,'Each complete line band must follow the circle contour, then regain the full width')
 local rightCircle=geometry('right','circle(50%)','10px')
 local left,right=Floats.bounds(rightCircle,0,43.4,400,21.7)
 near(left,0);near(right,270)
 local both={Floats={circle.Floats[1],rightCircle.Floats[1]}}
 left,right=Floats.bounds(both,0,43.4,400,21.7);near(left,130);near(right,270)
 near(Floats.clear(both,30,'both'),126)
 local ellipse=geometry('left','ellipse(40% 30%)','10px')
 local l=Floats.bounds(ellipse,0,0,400,20)
 assert(l>65 and l<120,'Elliptical shape-margin must expand the contour rather than reserving a rectangle')
 local none=geometry('left','none','0')
 near(Floats.bounds(none,0,0,400,21.7),130)
 local function create(class,parent,props)
  local object={ClassName=class,Parent=parent,Position={0,0},Size={0,0},Visible=true,BackgroundTransparency=1}
  for key,value in props or {} do object[key]=value end
  function object:Destroy()self.Destroyed=true end
  return object
 end
 local measure={measure=function(text,_,size)return {X=reference.words[text] or #text*7,Y=size} end}
 local overrides={['Layout/TextMeasure']=measure,['Layout/FontProfiles']={face=function(font)return font end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local renderer=loadRenderTree({create=create})
 local html='<style>*{box-sizing:border-box}#story{font-family:Arial;font-size:14px;line-height:21.7px;display:flow-root}#shape{display:grid;float:left;width:120px;height:120px;margin:0 10px 6px 0;shape-outside:circle(50%);shape-margin:10px}p{margin:0}#clear{clear:both}</style><div id="story"><span id="shape">SHAPE</span><p id="text">'..reference.text..'</p><p id="clear">Clear</p></div>'
 local tree=renderer.build(Parser.parse(html),{},error)
 local ids={};for node,box in tree.NodeBoxes do if node.Attributes and node.Attributes.id then ids[node.Attributes.id]=box end end
 local function arrange(width)layout.arrange(tree,width,0,0,function()return true end)end
 arrange(reference.width)
 local paragraph=ids.text;local run=paragraph.Children[1]
 assert(paragraph.LayoutX==0 and paragraph.OuterWidth==reference.width,'A float narrows inline lines, not the paragraph box')
 local lines={}
 for _,word in run.DisplayItems or run.Items do if word.Kind~='Break' and word.LineIndex then
  local line=lines[word.LineIndex]
  if not line then line={Text='',X=word.X,Y=word.LineTop};lines[word.LineIndex]=line end
  if word.SpaceBefore and #line.Text>0 then line.Text..=' ' end
  line.Text..=word.Text
 end end
 assert(#lines==#reference.lines,'Browser and engine must produce the same number of lines with identical text measurements')
 for index,line in lines do
  local expected=reference.lines[index]
  assert(line.Text==expected.text:match('^%s*(.-)%s*$'),'Browser line '..index..' differs: '..line.Text)
  near(line.X,expected.x,.15)
  near(line.Y,expected.y-reference.lines[1].y,.1)
 end
 local first=run.Items[1];arrange(250)
 assert(run.Items[1]==first,'Resize reuses existing text objects')
 local reachedFullWidth=false
 for _,word in run.Items do if word.LineTop and word.LineTop>=126 and word.LineLeft==0 then reachedFullWidth=true end end
 assert(reachedFullWidth,'A narrower paragraph must regain its complete width below the float')
 assert(ids.clear.LayoutY>=126 and ids.clear.LayoutY>=ids.text.OuterHeight,'Clear starts below the float and the preceding paragraph')
 -- Inherited exclusions must reach text through ordinary nested block boxes,
 -- while a new formatting context reserves the rectangular float margin box.
 local nestedHTML=html:gsub('<p id="text">','<div style="padding:3px 5px"><p id="text">'):gsub('</p><p id="clear">','</p></div><p id="clear">')
 local nested=renderer.build(Parser.parse(nestedHTML),{},error)
 layout.arrange(nested,reference.width,0,0,function()return true end)
 local nestedP;for node,box in nested.NodeBoxes do if node.Attributes and node.Attributes.id=='text' then nestedP=box end end
 local nestedWord=nestedP.Children[1].Items[1]
 local expected=Floats.bounds(circle,5,3,reference.width-10,21.7)
 near(nestedWord.X,expected,.0001)
 local inlineFloat=renderer.build(Parser.parse((html:gsub('display:grid;float:left','float:left'))),{},error)
 layout.arrange(inlineFloat,reference.width,0,0,function()return true end)
 local inlineShape;for node,box in inlineFloat.NodeBoxes do if node.Attributes and node.Attributes.id=='shape' then inlineShape=box end end
 assert(inlineShape.Style.Display=='block' and inlineShape.OuterWidth==120 and inlineShape.OuterHeight==120,'A floated span must accept box sizes and become a block')
 local percent=geometry('left','circle(50%)','2.5%')
 near(Floats.bounds(percent,0,43.4,400,21.7),130)
 -- A tall inline atom widens the exclusion band before any wrap decision.
 local tall={{Kind='Word',Text='A',Width=15,SpaceWidth=4,SpaceBefore=false,WrapBefore=true,Ascent=10,Descent=4,Baseline=10},
  {Kind='Image',Width=20,Height=65,SpaceWidth=4,SpaceBefore=true,WrapBefore=true,Ascent=65,Descent=0,Baseline=65}}
 Flow.arrange(tall,400,{Ascent=10,Descent=4},'left',0,nil,nil,Floats.lines(circle,400))
 near(tall[1].LineLeft,130);near(tall[2].LineLeft,130)
 -- Float geometry must retain the containing block's percentage basis after
 -- its preferred width has been measured, including margins and padding.
 local function sizedFloat(css,tag)
  local sample=renderer.build(Parser.parse('<style>*{box-sizing:border-box}#host{display:flow-root;width:100%}#sized{float:right;'..css..'}</style><div id="host">'..(tag or '<div id="sized"></div>')..'</div>'),{},error,nil,nil,nil,function()return 'rbxassetid://11'end)
  local sized;for node,box in sample.NodeBoxes do if node.Attributes and node.Attributes.id=='sized' then sized=box end end
  assert(sized,'The float fixture must own a render box')
  return sample,sized
 end
 local percentage,percentageBox=sizedFloat('width:68%;margin-right:1%;padding:10px;border:2px solid;height:90px')
 layout.arrange(percentage,400,0,0,function()return true end)
 near(percentageBox.OuterWidth,272);near(percentageBox.ContentWidth,248)
 near(percentageBox.LayoutMargin[2],4);near(percentageBox.LayoutX,124)
 layout.arrange(percentage,800,0,0,function()return true end)
 near(percentageBox.OuterWidth,544);near(percentageBox.ContentWidth,520)
 near(percentageBox.LayoutMargin[2],8);near(percentageBox.LayoutX,248)
 local automatic,automaticBox=sizedFloat('min-width:40%;margin-right:2%;padding:5%;height:50px')
 layout.arrange(automatic,400,0,0,function()return true end)
 near(automaticBox.OuterWidth,160);near(automaticBox.ContentWidth,120)
 near(automaticBox.Style.Padding[4],20);near(automaticBox.LayoutMargin[2],8);near(automaticBox.LayoutX,232)
 local replaced,replacedBox=sizedFloat('width:50%;height:30px;margin-right:2%', '<img id="sized" src="missing-float-test.png" alt="">')
 layout.arrange(replaced,400,0,0,function()return true end)
 near(replacedBox.OuterWidth,200);near(replacedBox.LayoutMargin[2],8);near(replacedBox.LayoutX,192)
 print('Float shapes: measured HTML lines, full-height bands, left/right/opposite floats, circle/ellipse margin geometry, nested blocks, resize, tall inline items and clear passed')
end
