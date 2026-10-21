--!strict
-- Native CSSOM queries over actual retained inline layout, including source
-- spans after word merging. Font zero isolates geometry from OS font metrics.
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,ScriptGeometry,fixture)
 local allocations,measurements=0,0
 local factory={}
 function factory.create(class,parent,properties)
  allocations+=1;local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent
  function gui:Destroy()self.Destroyed=true;self.Parent=nil end
  return gui
 end
 function factory.measure(text,_,size)measurements+=1;return Vector2.new(#text*size*.5,size)end
 local renderer=loadRenderTree(factory)
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=factory.measure}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local layout=loadBlockLayout(overrides)
 local checks=0
 for _,case in fixture.cases do
  local document=Parser.parseDocument(case.html);local target=Node.findById(document,'target')
  local root={AbsoluteSize=Vector2.new(800,600)}
  local tree=renderer.build(document,root,error,nil,nil,nil,function()return 'rbxassetid://1'end,case.css)
  tree.ViewportHeight=600;tree:SetMediaEnvironment(800,600)
  Dirty.begin(tree);layout.arrange(tree,800,0,0,function()return true end);Dirty.finish(tree,true)
  local page={Alive=true,Document=document,Root=root}
  function page:GeometryViewport()return {Width=800,Height=600,ClientWidth=800,ClientHeight=600,ScrollX=0,ScrollY=0}end
  function page:HasPendingLayout()return false end
  function page:FlushScriptLayout()error('Clean geometry query unexpectedly requests layout')end
  local events=Events.new(error);local output={}
  local realm=Runtime.new(document,{Events=events,Schedule=function()end,Diagnostic=error,
   Console=function(_,value)table.insert(output,value)end,
   CreateGeometryAdapter=function(runtime)return ScriptGeometry.new(page,tree,runtime)end})
  local scriptText=[=[
(()=>{
const e=document.getElementById('target');
for(const r of e.getClientRects())console.log('R',r.x,r.y,r.width,r.height);
const r=e.getBoundingClientRect();console.log('B',r.x,r.y,r.width,r.height);
console.log('O',e.offsetLeft,e.offsetTop,e.offsetWidth,e.offsetHeight,e.offsetParent?.id||e.offsetParent?.localName||null);
console.log('C',e.clientLeft,e.clientTop,e.clientWidth,e.clientHeight,e.scrollWidth,e.scrollHeight);
})();
]=]
  local before=allocations
  local function query()
   table.clear(output);realm:Run(scriptText);assert(#realm.Diagnostics==0,case.name..' query diagnostics')
   assert(#output==#case.rects+3,case.name..' rectangle count '..tostring(#output-3)..' ~= '..#case.rects)
   local function compare(line,expected,label)
    local parts={};for token in line:gmatch('%S+')do table.insert(parts,token)end
    for i,value in expected do
     if type(value)=='number'then local actual=tonumber(parts[i+1]);assert(actual and math.abs(actual-value)<.01,case.name..' '..label..' axis '..i..': '..tostring(actual)..' ~= '..value)
     else assert(parts[i+1]==tostring(value),case.name..' '..label..' offset parent '..tostring(parts[i+1])..' ~= '..tostring(value))end
    end
    checks+=1
   end
   for i,expected in case.rects do compare(output[i],expected,'client rect '..i)end
   compare(output[#output-2],case.boundingSpec or case.bounding,'bounding');compare(output[#output-1],case.offset,'offset');compare(output[#output],case.client,'client')
   if #case.rects==0 then assert(output[#output-1]:match('null$'),'No layout box has a null offsetParent')end
   assert(allocations==before,case.name..' geometry creates no GUI objects')
  end
  query();local warm=measurements;query()
  assert(measurements==warm,case.name..' repeated geometry reuses prefix widths')
  realm:Destroy();events:Destroy();page.Alive=false
 end
 print('Inline geometry: '..#fixture.cases..' native box/offset sequences, '..checks..' repeated CSSOM queries; no layout or GUI allocation passed')
end
