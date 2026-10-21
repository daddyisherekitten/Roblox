--!strict
return function(Parser,Style,loadRenderTree,loadWordLayout,loadBlockLayout,reference)
 local element=require('DOM/Node').element
 local function resolve(css,parent)
  return Style.resolve(element('span',{style=css}),parent or {Font='Roboto',FontSize=20,Color=Color3.new()},error,true)
 end
 assert(resolve('word-break:break-word').WordBreak=='break-word')
 assert(resolve('word-break:BREAK-WORD').WordBreak=='break-word')
 assert(resolve('',resolve('word-break:break-word')).WordBreak=='break-word')
 assert(resolve('word-break:initial',resolve('word-break:break-word')).WordBreak=='normal')
 assert(resolve('word-break:unset',resolve('word-break:break-word')).WordBreak=='break-word')
 assert(resolve('word-break:inherit',resolve('word-break:break-word')).WordBreak=='break-word')
 assert(resolve('word-break:normal!important;word-break:break-word').WordBreak=='normal')
 assert(resolve('--breaking:break-word;word-break:var(--breaking)').WordBreak=='break-word')
 for _,value in {'break-word normal','break-word break-word','anywhere','"break-word"'}do
  local errors=0
  local computed=Style.resolve(element('div',{style='word-break:break-word;word-break:'..value}),{},function()errors+=1 end)
  assert(computed.WordBreak=='break-word'and errors==1,'Invalid grammar preserves the prior declaration')
 end
 local allocations,measurements=0,0
 local function create(class,parent,props)
  allocations+=1;local gui=table.clone(props);gui.ClassName,gui.Parent=class,parent
  if gui.Visible==nil then gui.Visible=true end
  function gui:Destroy()self.Destroyed=true end
  return gui
 end
 local renderer=loadRenderTree({create=create,modifier=create})
 local overrides={['Layout/FontProfiles']={face=function(font)return font end},['Layout/TextMeasure']={measure=function(text,_,size)
  measurements+=1;local count=0;for _ in utf8.graphemes(text)do count+=1 end;return {X=count*5,Y=size}
 end}}
 local wordLayout=loadWordLayout(overrides);overrides['Layout/WordLayout']=wordLayout
 local layout=loadBlockLayout(overrides)
 local function build(html,css)
  local tree=renderer.build(Parser.parse('<div style="font-family:Roboto;font-size:20px;line-height:20px;'..(css or'')..'">'..html..'</div>'),{},error)
  return tree,tree.Children[1]
 end
 local function lines(box)
  local result={}
  for _,run in box.Children do if run.Kind=='Words'then
   for _,item in run.DisplayItems or run.Items do if item.Kind=='Word'and item.Text~=''then
    local index=item.LineIndex or 1;result[index]=(result[index]or'')..item.Text:gsub(' ','')
   end end
  end end
  local compact={};for index=1,#result do if result[index]then table.insert(compact,result[index])end end
  return compact
 end
 local function sameLines(actual,expected,label)
  assert(table.concat(actual,'|')==table.concat(expected,'|'),label..': '..table.concat(actual,'|')..' != '..table.concat(expected,'|'))
 end
 assert(reference.supports and #reference.records==135)
 for _,record in reference.records do
  local tree,box=build(record.html,'word-break:'..record.wordBreak..';overflow-wrap:'..record.overflowWrap)
  layout.arrange(tree,record.columns*5,0,0,function()return true end)
  sameLines(lines(box),record.lines,record.wordBreak..'/'..record.overflowWrap..'/'..record.html..'/'..record.columns)
  assert(box.Style.WordBreak==record.computedWordBreak and box.Style.OverflowWrap==record.computedOverflowWrap,'The compatibility value changes used wrapping, not either computed keyword')
  local minimum=layout.naturalWidth(box,1000,function()return true end,true,true)/5
  local maximum=layout.naturalWidth(box,1000,function()return true end,false,true)/5
  assert(math.abs(minimum-record.minimum)<.02 and math.abs(maximum-record.maximum)<.02,'Native intrinsic width parity '..record.wordBreak..'/'..record.overflowWrap..': '..minimum..'/'..maximum..' != '..record.minimum..'/'..record.maximum)
 end
 for _,mode in {'nowrap','pre'}do
  local tree,box=build('ABCDEFGHIJ','word-break:break-word;white-space:'..mode)
  layout.arrange(tree,20,0,0,function()return true end)
  assert(box.OuterHeight==20 and box.Children[1].Items[1].Gui.Visible and not box.Children[1].DisplayItems,'No-wrap modes suppress compatibility emergency breaks')
 end
 for _,text in {'Äp','👩‍💻p'}do
  local tree,box=build(text,'word-break:break-word')
  layout.arrange(tree,5,0,0,function()return true end)
  local display=box.Children[1].DisplayItems
  assert(#display==2 and display[1].Text==text:sub(1,-2)and display[2].Text=='p','Compatibility wrapping preserves complete grapheme clusters')
 end
 do
  local tree,box=build('ABCDE','word-break:break-word;letter-spacing:2px;text-decoration:underline;text-shadow:1px 1px')
  layout.arrange(tree,20,0,0,function()return true end)
  local run=box.Children[1];assert(run.DisplayItems[1].Text=='ABC'and run.DisplayItems[1].Width==19)
  for _,item in run.DisplayItems do assert(item.DecorationFrames[1].Visible and item.ShadowLabels[1].Gui.Visible and item.Glyphs)end
  local first=run.Items[1];local gui=first.Gui
  local count,calls=allocations,measurements
  layout.arrange(tree,100,0,0,function()return true end);layout.arrange(tree,20,0,0,function()return true end)
  assert(run.Items[1]==first and first.Gui==gui and allocations==count and measurements==calls,'Width changes retain source word/glyph and fragment allocations')
 end
 do
  local source='<style>#mutable{width:20px;font-family:Roboto;font-size:20px;line-height:20px}#mutable.breaking{word-break:break-all}#mutable.compat{word-break:break-word;overflow-wrap:normal}#mutable.anywhere{overflow-wrap:anywhere}#mutable:hover{word-break:break-word}</style><div id="mutable">ABCDEFGHIJ</div><input id="untouched" value="kept"><p>Unrelated text</p>'
  local tree=renderer.build(Parser.parse(source),{},error)
  layout.arrange(tree,100,0,0,function()return true end)
  local box=tree.Children[1];local word=box.Children[1].Items[1];local wordGui,boxGui=word.Gui,box.Gui
  local input=tree.Controls[1];local inputGui=input.Item.Gui;local unrelated=tree.Children[#tree.Children].Gui
  for _,mode in {'breaking','','compat','','anywhere','','compat'}do
   box.Node.Attributes.class=mode
   local needed=tree:ApplyDOMChanges({[box.Node]={Attributes={class=true}}})
   assert(needed,'Word-break/overflow-wrap class mutation requests actual layout')
   layout.arrange(tree,100,0,0,function()return true end)
   assert(box.OuterHeight==(if mode==''then 20 else 60))
   assert(box.Gui==boxGui and box.Children[1].Items[1]==word and word.Gui==wordGui and input.Item.Gui==inputGui and tree.Children[#tree.Children].Gui==unrelated,'Uniform wrapping changes preserve source word, box and unrelated control/GUI identity')
  end
  box.Node.Attributes.class='';tree:ApplyDOMChanges({[box.Node]={Attributes={class=true}}});layout.arrange(tree,100,0,0,function()return true end)
  local changed,needed=tree:SetCSSState('hover',box.Node);assert(changed and needed)
  layout.arrange(tree,100,0,0,function()return true end);assert(box.OuterHeight==60)
  changed,needed=tree:SetCSSState('hover',nil);assert(changed and needed)
  layout.arrange(tree,100,0,0,function()return true end);assert(box.OuterHeight==20 and word.Gui==wordGui)
 end
 do
  local tree,box=build('AB<span id="split">CDEFGH</span>IJ','width:20px;overflow-wrap:normal')
  layout.arrange(tree,100,0,0,function()return true end)
  local span;for node in tree.NodeStyles do if node.Attributes and node.Attributes.id=='split'then span=node end end
  assert(span and #box.Children[1].Items==1,'Equal source styles initially merge one lexical word')
  span.Attributes.style='word-break:break-word'
  assert(tree:ApplyDOMChanges({[span]={Attributes={style=true}}}))
  layout.arrange(tree,100,0,0,function()return true end)
  assert(#box.Children[1].Items==3 and box.Children[1].Items[2].Style.WordBreak=='break-word','A changed inline source splits only its affected lexical owner')
  local text={};for _,item in box.Children[1].DisplayItems or box.Children[1].Items do table.insert(text,item.Text or'')end
  assert(table.concat(text)=='ABCDEFGHIJ','Dynamic inline repartition loses no source text')
  span.Attributes.style='';tree:ApplyDOMChanges({[span]={Attributes={style=true}}});layout.arrange(tree,100,0,0,function()return true end)
  assert(#box.Children[1].Items==1 and box.Children[1].Items[1].Text=='ABCDEFGHIJ','Removing an inline wrapping override merges the original lexical group')
 end
 print('Word-break: 135 Chromium line/intrinsic/computed cases, grammar/inheritance/cascade, graphemes, paint, retained resize, live class/state changes and inline source regroup passed')
end
