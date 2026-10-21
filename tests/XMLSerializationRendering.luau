--!strict
return function(Parser,Node,Runtime,Events,Dirty,loadRenderTree,loadWordLayout,loadBlockLayout,Markup)
 local made={};local factory={}
 function factory.create(class,parent,properties)
  local gui=table.clone(properties);gui.ClassName=class;gui.Parent=parent;gui.Visible=true
  function gui:Destroy()assert(not self.Destroyed,'Resource disposed once');self.Destroyed=true;self.Parent=nil end
  table.insert(made,gui);return gui
 end
 factory.modifier=factory.create
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=(utf8.len(text)or 0)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides);local renderer=loadRenderTree(factory);local layout=loadBlockLayout(overrides)
 local document=Parser.parseDocument('<!doctype html><style>body{margin:0}p{border:1px solid red}input{width:100px}</style><body><p id="panel">A &amp; B <span>unchanged</span></p><input id="edit" value="author"><svg id="shape" width="10" height="10"><rect width="10" height="10"/></svg></body>')
 local tree=renderer.build(document,{AbsoluteSize=Vector2.new(400,500)},function()end)
 Dirty.begin(tree);layout.arrange(tree,400,0,0,function()return true end);Dirty.finish(tree,true)
 local panel=Node.findById(document,'panel');local shape=Node.findById(document,'shape');local panelBox=tree.NodeBoxes[panel];local shapeBox=tree.NodeBoxes[shape]
 local items=table.clone(tree.TextItems);local controls=table.clone(tree.Controls);local count=#made;local nativeInput=controls[1].Item.Gui
 nativeInput.Text='typed';nativeInput.CursorPosition=3;nativeInput.SelectionStart=1
 local changes=0;local events=Events.new(error);local realm=Runtime.new(document,{URL='https://example.test/serialized-renderer',Events=events,ControlAdapter={},Schedule=function()end,Mutation=function()changes+=1 end})
 local html=Markup.serialize(panel)
 assert(realm:Run([=[
 const node=document.getElementById('panel'),child=node.firstChild,attr=node.getAttributeNode('id');
 const output=new XMLSerializer().serializeToString(node);
 if(output!=='<p xmlns="http://www.w3.org/1999/xhtml" id="panel">A &amp; B <span>unchanged</span></p>'||node.firstChild!==child||node.getAttributeNode('id')!==attr)throw new Error('Rendered source identity');
 const svg=document.getElementById('shape');const encoded=new XMLSerializer().serializeToString(svg);
 if(encoded.indexOf('xmlns="http://www.w3.org/2000/svg"')<0||svg.firstChild.localName!=='rect')throw new Error('Rendered SVG namespace');
 ]=]),table.concat(realm.Diagnostics,'\n'))
 assert(Markup.serialize(panel)==html and tree.NodeBoxes[panel]==panelBox and tree.NodeBoxes[shape]==shapeBox and #made==count and changes==0 and next(realm.Pending)==nil,'Serializing retained trees creates/reconciles no surfaces or pending DOM refresh')
 for index,item in items do assert(tree.TextItems[index]==item and not item.Gui.Destroyed,'Text owners retained')end
 assert(tree.Controls[1]==controls[1]and nativeInput==controls[1].Item.Gui and not nativeInput.Destroyed and nativeInput.Text=='typed'and nativeInput.CursorPosition==3 and nativeInput.SelectionStart==1,'Native input value/selection retained')
 realm:Destroy();events:Destroy();for _,gui in made do if not gui.Destroyed then gui:Destroy()end end
 local weak=setmetatable({},{__mode='k'})
 local function discarded()
  local ev=Events.new(error);local runtime=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),{Events=ev,Schedule=function()end})
  assert(runtime:Run('window.serializer=new XMLSerializer();window.node=document.createElement("span");serializer.serializeToString(node);'))
  weak[runtime]=true;weak[runtime.VM]=true;weak[runtime.Window.Get('serializer')]=true;weak[runtime.Window.Get('node')]=true
  runtime:Destroy();ev:Destroy()
 end
 discarded()
 for batch=1,2048 do if next(weak)==nil then break end;local garbage=table.create(2048);for index=1,2048 do garbage[index]={batch,index}end end
 assert(next(weak)==nil,'XMLSerializer brands do not retain discarded pages/instances/nodes')
 print('H05 XML serialization renderer: boxes/SVG/text/native input value+selection unchanged, no author mutation/GUI creation, discarded serializer/page collected')
end
