--!strict
-- Publication of generated text shares retained boxes with ordinary DOM work.
return function(Parser,Node,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout)
 local factory={};local made={}
 function factory.create(class,parent,props)
  local gui=table.clone(props);gui.ClassName=class;gui.Parent=parent
  function gui:Destroy()assert(not self.Destroyed,'A generated resource is disposed once');self.Destroyed=true;self.Parent=nil end
  table.insert(made,gui);return gui
 end
 factory.modifier=factory.create
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local renderer=loadRenderTree(factory);local layout=loadBlockLayout(overrides)
 local css=[=[body{counter-reset:step} .row{counter-increment:step}.row::before{content:counter(step) ":" attr(data-label) " ";color:#123456}.row::after{content:" end"}.row.alt::before{content:"Changed " attr(data-label);color:red}.row.off::before{content:none}.row.block::after{content:"Block";display:block;width:80px;height:20px;background:blue}.row.hide{display:none}.tasks{list-style:decimal}.tasks li::marker{content:counter(list-item) ") "}.tasks.alt li::marker{content:"OK "}.tasks.none li::marker{content:none}]=]
 local doc=Parser.parseDocument('<html><head><style id="sheet">'..css..'</style></head><body><input id="note" value="kept"><p id="one" class="row" data-label="Alpha">One</p><p id="two" class="row" data-label="Beta">Two</p><ol class="tasks" id="tasks" start="3"><li id="task">Task</li><li id="task2">Next</li></ol><p id="outside">Outside</p></body></html>')
 local tree=renderer.build(doc,{AbsoluteSize=Vector2.new(400,600)},error)
 local function arrange(items)Dirty.begin(tree,items);layout.arrange(tree,400,0,0,function()return true end);Dirty.finish(tree,true)end
 arrange()
 local function find(id)local node=Node.findById(doc,id);assert(node,id);return node end
 local function mutate(node,change)local needed,items=tree:ApplyDOMChanges({[node]=change});if needed then arrange(items)end end
 local function attr(id,key,value)local node=find(id);node.Attributes[key]=value;mutate(node,{Attributes={[key]=true}})end
 local function text(id)
  local result={};local target=find(id)
  for _,item in tree.TextItems do if item.Style and(item.Style.Node==target or item.Style.HitNode==target)then table.insert(result,item.Text or'')end end
  return table.concat(result,' ')
 end
 local one=tree.NodeBoxes[find('one')];local two=tree.NodeBoxes[find('two')];local outside=tree.NodeBoxes[find('outside')];local input
 for _,control in tree.Controls do if control.Node==find('note')then input=control;break end end
 assert(input);local nativeInput=input.Item.Gui;input.Value='local';nativeInput.Text='local';nativeInput.CursorPosition=3
 local function stable()
  assert(tree.NodeBoxes[find('one')]==one and tree.NodeBoxes[find('two')]==two and tree.NodeBoxes[find('outside')]==outside,'Generated publication retains its host and unrelated boxes')
  assert(input.Item.Gui==nativeInput and not nativeInput.Destroyed and nativeInput.Text=='local'and nativeInput.CursorPosition==3,'Generated publication preserves local input value/selection')
 end
 assert(text('one'):find('1:Alpha',1,true)and text('two'):find('2:Beta',1,true),text('one')..' / '..text('two'))
 attr('one','data-label','Revised');assert(text('one'):find('1:Revised',1,true)and not text('one'):find('Alpha',1,true));stable()
 attr('one','class','row alt');assert(text('one'):find('Changed',1,true)and text('one'):find('Revised',1,true));stable()
 attr('one','class','row off');assert(not text('one'):find('Revised',1,true),'Removing a generated pseudo removes its retained text');stable()
 attr('one','class','row block');local block
 for _,child in one.Children do if child.Node and child.Node.GeneratedPseudo=='after'then block=child end end
 assert(block and block.OuterWidth==80 and block.OuterHeight==20,'A block pseudo participates in ordinary box layout');stable()
 attr('one','class','row hide');assert(text('two'):find('1:Beta',1,true),'Hidden counters do not advance following siblings')
 attr('one','class','row');assert(text('two'):find('2:Beta',1,true));stable()
 local task=tree.NodeBoxes[find('task')];local task2=tree.NodeBoxes[find('task2')]
 assert(task.Marker.CustomText=='3) 'and task2.Marker.CustomText=='4) ','Implicit list-item counters honor ordered-list start')
 local marker=task.Marker.Gui
 attr('tasks','class','tasks alt');assert(task.Marker.CustomText=='OK 'and task.Marker.Gui==marker,'Marker changes retain compatible native surfaces')
 attr('tasks','class','tasks none');assert(task.Marker==nil or task.Marker.CustomText==nil or task.Marker.CustomText=='','content:none must remove the custom marker')
 attr('tasks','class','tasks');assert(task.Marker and task.Marker.CustomText=='3) ')
 local sheet=find('sheet');sheet.Children[1].Text=css:gsub('" end"','" changed"');mutate(sheet,{Text=true,Stylesheet=true})
 assert(text('one'):find('changed',1,true),'Stylesheet mutation updates existing pseudo output');stable()
 local body=find('one').Parent;local inserted=Parser.parseDocument('<p class="row" data-label="New">Inserted</p>')
 local new
 if not new then local pending={inserted};while #pending>0 do local n=table.remove(pending);if n.Name=='p'then new=n;break end;for _,c in n.Children do table.insert(pending,c)end end end
 assert(new);new.Parent=body;table.insert(body.Children,table.find(body.Children,find('two')),new);mutate(body,{Children=true})
 assert(text('two'):find('3:Beta',1,true),'Insertion recalculates counter output in following siblings');stable()
 table.remove(body.Children,table.find(body.Children,new));new.Parent=nil;mutate(body,{Children=true})
 assert(text('two'):find('2:Beta',1,true),'Removal restores the following counter');stable()
 -- An inline counter edit may alter following generated strings, even though
 -- the following pseudo's own cascade is retained by the local style scope.
 attr('one','style','counter-increment:step 3')
 assert(text('one'):find('3:Revised',1,true)and text('two'):find('4:Beta',1,true),'Scoped pseudo style reuse still updates following counter values: '..text('one')..' / '..text('two'));stable()
 attr('one','style','counter-increment:step 1')
 assert(text('two'):find('2:Beta',1,true),'Counter rollback preserves global flat-tree order');stable()
 attr('one','style','--suffix:"variable";color:blue')
 sheet.Children[1].Text=css..'.row::after{content:var(--suffix,"fallback");color:inherit}'
 mutate(sheet,{Text=true,Stylesheet=true})
 assert(text('one'):find('variable',1,true)and text('two'):find('fallback',1,true),'Recompiled pseudo variables retain independent inherited values')
 attr('one','style','--suffix:"local";color:red')
 assert(text('one'):find('local',1,true)and text('two'):find('fallback',1,true),'Local custom properties update generated strings without changing unrelated pseudos');stable()
 local ordinaryDoc=Parser.parseDocument('<style>body{counter-reset:step}li{counter-increment:step}a:hover{color:red}</style><body><a id="nav" href="#">Navigation</a><ol><li id="default-marker">Ordinary marker</li><li>Following marker</li></ol></body>')
 local ordinaryTree=renderer.build(ordinaryDoc,{AbsoluteSize=Vector2.new(400,600)},error)
 layout.arrange(ordinaryTree,400,0,0,function()return true end)
 local ordinaryItem=ordinaryTree.NodeBoxes[Node.findById(ordinaryDoc,'default-marker')]
 local ordinaryGui,markerGui,count=ordinaryItem.Gui,ordinaryItem.Marker.Gui,#made
 local _,needsLayout=ordinaryTree:SetCSSState('hover',Node.findById(ordinaryDoc,'nav'))
 assert(not needsLayout and #made==count and ordinaryItem.Gui==ordinaryGui and ordinaryItem.Marker.Gui==markerGui and not ordinaryGui.Destroyed,'First paint-only hover must not rebuild unrelated default markers with host counter operations')
 ordinaryTree:SetMediaEnvironment(560,600)
 assert(next(ordinaryTree:GeneratedChanges(true))==nil,'Viewport metadata alone must not invalidate generated marker output or local text-layout eligibility')
 local interactionDoc=Parser.parseDocument('<html><head><style>li::before{content:"Before "}li::after{content:"After";display:block}li::first-letter{color:red}</style></head><body><ul><li id="interaction-item"><a id="interaction-link" onclick="void 0">Link text</a></li></ul></body></html>')
 local interactionTree=renderer.build(interactionDoc,{AbsoluteSize=Vector2.new(400,600)},error)
 layout.arrange(interactionTree,400,0,0,function()return true end)
 local html=Node.findElement(interactionDoc,function(element)return element.Name=='html'end)
 local interactionItem=interactionTree.NodeBoxes[Node.findById(interactionDoc,'interaction-item')]
 local retained={};for gui,style in interactionTree.HitStyles do retained[gui]=style end
 local interactionMarker=interactionItem.Marker.Gui;local markerStyle=interactionItem.Marker.Style
 local beforeInteraction=#made
 for index,value in {'cursor:pointer;user-select:none;pointer-events:none','cursor:default;user-select:text;pointer-events:auto','cursor:pointer;user-select:none;pointer-events:none'}do
  local viewportWidth,viewportHeight=400+index*40,600+index*20
  interactionTree:SetMediaEnvironment(viewportWidth,viewportHeight)
  html.Attributes.style=value
  local requiresLayout=interactionTree:ApplyDOMChanges({[html]={Attributes={style=true}}})
  assert(not requiresLayout and #made==beforeInteraction,'Inherited interaction-only styles must not rebuild list links or generated text')
  assert(interactionItem.Marker.Gui==interactionMarker and interactionItem.Marker.Style==markerStyle,'Interaction-only publication must retain the existing marker and computed style')
  local expected=if value:find('none',1,true)then 'none'else 'auto'
  local expectedCursor=if expected=='none'then 'pointer'else 'default'
  assert(markerStyle.PointerEvents==expected,'Retained marker interaction styles must stay current')
  assert(markerStyle.Cursor==expectedCursor,'Retained marker cursor must stay current')
  assert(markerStyle.ViewportWidth==viewportWidth and markerStyle.ViewportHeight==viewportHeight,'Retained marker viewport metadata must advance beside interaction changes')
  for gui,style in retained do
   assert(not gui.Destroyed and interactionTree.HitStyles[gui]==style,'Inherited cursor changes must preserve every generated hit surface')
   if style.Node then
    assert(style.PointerEvents==expected,'Retained generated hit styles must receive the new interaction values: '..tostring(style.Node.Name)..'/'..tostring(style.PseudoElement)..' '..tostring(style.PointerEvents)..' expected '..expected)
    assert(style.Cursor==expectedCursor,'Retained generated hit styles must receive the new cursor')
    assert(style.ViewportWidth==viewportWidth and style.ViewportHeight==viewportHeight,'Retained generated hit styles must receive simultaneous viewport metadata')
   end
  end
 end
 print('Generated content: attr/class/visibility/stylesheet/structure updates, sibling/list counters, block pseudos, dynamic markers and retained controls passed')
end
