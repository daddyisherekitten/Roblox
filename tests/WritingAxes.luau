--!strict
return function(Style: any,Axes: any,Scroll: any,reference: any)
 local fixtureElement=require('DOM/Node').element
 local function near(a,b,message)assert(math.abs(a-b)<.04,message..': '..a..' vs '..b)end
 local records=table.clone(reference.logical);for _,record in reference.inherited or{}do table.insert(records,record)end
 for _,record in records do
  local parent=if record.parentCSS then Style.resolve(fixtureElement('div',{style=record.parentCSS}),{FontSize=16},error)else {FontSize=16}
  local style=Style.resolve(fixtureElement('div',{style=record.css}),parent,error)
  local key=record.writingMode..'/'..record.direction..(if record.parentMode then '/inherit '..record.parentMode..'/'..record.parentDirection else '')
  for family,field in {margin='Margin',padding='Padding',border='BorderSides',inset='Inset', ['scroll-padding']='ScrollPadding',['scroll-margin']='ScrollMargin'}do
   for index,expected in record.values[family]do
    local value=if field=='Inset'then style[({'Insettop','Insetright','Insetbottom','Insetleft'})[index]]elseif field=='BorderSides'then style.BorderSides[index].Width else style[field][index]
    assert(value~=nil,'Missing resolved logical longhand '..key..'/'..family..'/'..index)
    near(if type(value)=='number'then value else value.Value,expected,'Native logical '..key..'/'..family..'/'..index)
   end
  end
  for index,expected in record.values.radius do near(style.BorderRadii[index].X.Value,expected,'Native logical corner '..key..'/'..index)end
 end
 for _,record in reference.scroll do
  local style={WritingMode=record.writingMode,Direction=record.direction,TextOrientation=record.orientation,ScrollSnapType={Axis='both'},ScrollPadding={4,6,8,10}}
  local child={Style={ScrollSnapAlign={Inline=record.align,Block=record.align},ScrollMargin={3,5,7,9}},LayoutX=240,LayoutY=200,OuterWidth=40,OuterHeight=30}
  local gui={CanvasPosition=Vector2.new(0,0),CanvasSize=UDim2.fromOffset(600,500)}
  local box={Style=style,ScrollGui=gui,OuterWidth=record.width,OuterHeight=record.height,Children={child}}
  local position,x,y=Scroll.snapTargets(box);assert(x==child and y==child)
  near(position.X,record.x,'Native scroll inline/block X '..record.writingMode..'/'..record.direction..'/'..record.align)
  near(position.Y,record.y,'Native scroll inline/block Y '..record.writingMode..'/'..record.direction..'/'..record.align)
  for _,axis in {'inline','block'}do
   style.ScrollSnapType.Axis=axis;local nextPosition,tx,ty=Scroll.snapTargets(box)
   local horizontal=if axis=='inline'then not Axes.vertical(style)else Axes.vertical(style)
   assert((tx~=nil)==horizontal and(ty~=nil)~=horizontal,'Logical scroll-snap axis follows writing mode')
   near(if horizontal then nextPosition.X else nextPosition.Y,if horizontal then record.x else record.y,'Native retained snap axis')
   assert(child.LayoutX==240 and child.LayoutY==200 and gui.CanvasPosition.X==0 and gui.CanvasPosition.Y==0,'Target projection must not mutate source layout or scroll position')
  end
 end
 local differences=0;for _,record in reference.inherited or{}do if record.difference then differences+=1 end end
 print('Writing axes: '..#reference.logical..' native mappings, '..#(reference.inherited or{})..' normative inheritance projections ('..differences..' raw Chrome differences), '..#reference.scroll..' native scroll alignments passed')
end
