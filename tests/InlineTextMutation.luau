--!strict
return function(Parser,Style,loadRenderTree,loadWordLayout,loadBlockLayout)
 local Node=require('DOM/Node');local allocations=0
 local function create(class,parent,props)
  allocations+=1;local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent
  if gui.Visible==nil then gui.Visible=true end;function gui:Destroy()self.Destroyed=true end;return gui
 end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)local n=0;for _ in utf8.graphemes(text)do n+=1 end;return {X=n*5,Y=size}end}}
 local wordLayout=loadWordLayout(overrides);overrides['Layout/WordLayout']=wordLayout;local layout=loadBlockLayout(overrides)
 local cases={
  {'line-break','normal','anywhere','AB<span id="middle">CDEFGH</span>IJ','middle'},
  {'text-autospace','normal','no-autospace','漢<span id="middle">ABC</span>字','copy'},
  {'hanging-punctuation','none','first','&quot;ABCDE&quot;','copy'},
  {'hanging-punctuation','none','last','AB<span id="middle">CD!</span>','middle'},
 }
 local function build(record,changed)
  local html=record[4];local target=record[5]
  if changed and target=='middle'then html=html:gsub('id="middle"','id="middle" style="'..record[1]..':'..record[3]..'"')end
  local css='#'..target..'.changed,#'..target..':hover{'..record[1]..':'..record[3]..'!important}'
  local source='<style>'..css..'</style><div id="copy" style="font-family:Roboto;font-size:20px;line-height:20px;'..record[1]..':'..(if changed and target=='copy'then record[3]else record[2])..'">'..html..'</div><input id="kept" value="kept"><div id="following">Unrelated</div>'
  local document=Parser.parse(source);return renderer.build(document,{},error),assert(Node.findById(document,'copy')),assert(Node.findById(document,target)),assert(Node.findById(document,'following'))
 end
 local function snapshot(tree,copy,width)
  layout.arrange(tree,width,0,0,function()return true end)
  local box=assert(tree.NodeBoxes[copy]);local words=box.Children[1]
  local display={};local source={}
  for _,item in words.Items do if item.Kind=='Word'then table.insert(source,item.Text)end end
  for _,item in words.DisplayItems or words.Items do if item.Kind=='Word'then
   table.insert(display,item.Text..'@'..tostring(item.X)..','..tostring(item.Y)..':'..tostring(item.Width)..':'..tostring(item.Height))
  end end
  return tostring(#words.Items)..':'..table.concat(display,'|')..':'..tostring(box.OuterHeight),words,table.concat(source)
 end
 local comparisons=0
 for _,record in cases do
  local reference,referenceCopy=build(record,true)
  for _,route in {'style','class','hover'}do
   local tree,copy,target,following=build(record,false)
   local initial,_,source=snapshot(tree,copy,30)
   local copyBox,followingBox=tree.NodeBoxes[copy],tree.NodeBoxes[following]
   local copyGui,followingGui=copyBox.Gui,followingBox.Gui;local control=tree.Controls[1];local controlGui=control.Item.Gui
   local originalStyle=target.Attributes.style
   for _=1,2 do
    if route=='hover'then local changed,needed=tree:SetCSSState('hover',target);assert(changed and needed)
    else target.Attributes[route]=if route=='style'then (originalStyle or'')..';'..record[1]..':'..record[3]else 'changed';local needed=tree:ApplyDOMChanges({[target]={Attributes={[route]=true}}});assert(needed,record[1]..' '..route..' must request layout')end
    for _,width in {20,30,65}do
     local actual,_,text=snapshot(tree,copy,width);local expected=snapshot(reference,referenceCopy,width)
     assert(actual==expected,record[1]..' '..route..' @'..width..': '..actual..' / '..expected);comparisons+=1
     assert(text==source,'Inline retokenization preserves every source character')
     assert(tree.NodeBoxes[copy]==copyBox and copyBox.Gui==copyGui and not copyGui.Destroyed)
     assert(tree.NodeBoxes[following]==followingBox and followingBox.Gui==followingGui and not followingGui.Destroyed)
     assert(tree.Controls[1]==control and control.Item.Gui==controlGui and not controlGui.Destroyed,'Inline text changes retain unrelated control identity')
    end
    if route=='hover'then local changed,needed=tree:SetCSSState('hover',nil);assert(changed and needed)
    else target.Attributes[route]=if route=='style'then originalStyle else nil;local needed=tree:ApplyDOMChanges({[target]={Attributes={[route]=true}}});assert(needed,record[1]..' '..route..' reversal must request layout')end
    assert(snapshot(tree,copy,30)==initial,'Removing a source rule restores the original token boundaries and geometry')
   end
  end
 end
 -- Uniform line-break changes need new wrapping, but its tokenizer input and
 -- source style boundaries stay equal: preserve the original native label.
 local tree,copy=build({'line-break','normal','anywhere','ABCDEFGHIJ','copy'},false)
 local _,words=snapshot(tree,copy,20);local word=words.Items[1];local gui=word.Gui
 copy.Attributes.style=copy.Attributes.style..';line-break:anywhere';assert((tree:ApplyDOMChanges({[copy]={Attributes={style=true}}})))
 snapshot(tree,copy,20);assert(words.Items[1]==word and word.Gui==gui and not gui.Destroyed and tree.NodeBoxes[copy].OuterHeight==60)
 local count=allocations;assert(not tree:ApplyDOMChanges({[copy]={Attributes={style=true}}}));snapshot(tree,copy,20)
 assert(allocations==count,'An unchanged source rule neither retokenizes nor recreates fragments')
 assert(comparisons==72)
 print('Inline text mutation: 72 fresh-DOM token/position/width/height comparisons, live style/class/hover reversal, source preservation, controls and uniform-label reuse passed')
end
