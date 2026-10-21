--!strict
return function(Parser,Style,Balance,loadRenderTree,loadWordLayout,loadBlockLayout)
 local fixtureElement=require('DOM/Node').element
 local function resolve(css,parent,warn)return Style.resolve(fixtureElement('div',{style=css}),parent or {},warn or error)end
 local function near(a,b)assert(math.abs(a-b)<.01,tostring(a)..' differs from '..tostring(b))end
 for _,css in {'flex-wrap:balance','flex-wrap:wrap balance','flex-wrap:balance wrap-reverse','flex-flow:column wrap balance'} do
  local s=resolve(css);assert(s.FlexBalance and s.FlexWrap~='nowrap')
 end
 assert(not resolve('flex-wrap:balance;flex-flow:row').FlexBalance)
 local parent=resolve('flex-flow:column wrap-reverse balance;flex-line-count:3')
 assert(resolve('flex-flow:inherit;flex-line-count:inherit',parent).FlexBalance)
 assert(resolve('',parent).FlexLineCount==1 and not resolve('',parent).FlexBalance)
 for _,css in {'flex-wrap:nowrap balance','flex-wrap:balance balance','flex-wrap:wrap wrap-reverse','flex-line-count:0','flex-line-count:2.5'} do
  local warnings=0;resolve(css,nil,function()warnings+=1 end);assert(warnings==1)
 end
 -- Compare the optimized partitioner with an exhaustive oracle, including
 -- the earliest-line tie rule; this does not mirror its divide-and-conquer DP.
 local function oracle(sizes,limit,gap,count)
  local best,bestCuts=math.huge,nil
  local function search(first,k,score,cuts)
   if k==0 then
    if first>#sizes and score<best-1e-7 then best,bestCuts=score,table.clone(cuts) end
    return
   end
   for finish=#sizes-k+1,first,-1 do
    local used=gap*(finish-first);for i=first,finish do used+=sizes[i] end
    if used<=limit+1e-7 or finish==first then
     table.insert(cuts,finish);search(finish+1,k-1,score+(limit-used)^2,cuts);table.remove(cuts)
    end
   end
  end
  search(1,count,0,{})
  return bestCuts
 end
 for seed=1,120 do
  local sizes,items={},{}
  local n=3+seed%6;local limit=45+seed%60;local gap=seed%4
  for i=1,n do local size=(seed*i*13)%50+1;sizes[i]=size;items[i]={Base=size,Extra=0,Min=0,Max=math.huge} end
  local lines=Balance.collect(items,limit,gap,1+seed%n,function()return true end)
  local expected=oracle(sizes,limit,gap,#lines);local endIndex=0
  for index,line in lines do endIndex+=#line.Items;assert(endIndex==expected[index],'Balanced partition differs from exhaustive optimum') end
 end
 local renderer=loadRenderTree({create=function(_,_,props)return table.clone(props)end})
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 local content=string.rep('<div style="width:40px;height:20px;flex-shrink:0">X</div>',5)
 local function build(css,width)
  local tree=renderer.build(Parser.parse('<div style="display:flex;gap:10px;align-content:start;'..css..'">'..content..'</div>'),{},error)
  layout.arrange(tree,width,0,0,function()return true end);return tree,tree.Children[1]
 end
 local tree,box=build('flex-wrap:balance;flex-line-count:2',300)
 assert(box.FlexLineCount==2);near(box.Children[3].LayoutX,100);near(box.Children[4].LayoutY,30)
 for _,width in {100,300,100,300} do layout.arrange(tree,width,0,0,function()return true end);assert(box.FlexLineCount==(if width==100 then 3 else 2)) end
 local _,plain=build('flex-wrap:wrap;flex-line-count:4',300);assert(plain.FlexLineCount==1,'Count alone must not force unbalanced wrapping')
 local _,nowrap=build('flex-wrap:nowrap;flex-line-count:4',100);assert(nowrap.FlexLineCount==1)
 local _,reversed=build('flex-wrap:wrap-reverse balance;flex-line-count:2',300);near(reversed.Children[1].LayoutY,30);near(reversed.Children[4].LayoutY,0)
 local _,column=build('flex-flow:column balance;flex-line-count:2',300);assert(column.FlexLineCount==2);near(column.OuterHeight,80)
 local _,excess=build('flex-wrap:balance;flex-line-count:20',300);assert(excess.FlexLineCount==5)
 local items={};for i=1,2000 do items[i]={Base=20,Extra=0,Min=0,Max=math.huge} end
 local lines=Balance.collect(items,600,0,1,function()return true end)
 assert(#lines==67,'Large balanced lists preserve all items without a quadratic per-line scan')
 print('Flex balance: exhaustive partition oracle, minimum count, clamp, wrap/nowrap, reverse, columns, resize, CSS cascade and 2000 items passed')
end
