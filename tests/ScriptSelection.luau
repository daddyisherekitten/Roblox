--!strict
return function(Parser,DOM,Style,Stylesheet,TextSelection,InlineWords,OverflowWrap,ScriptSelection,TextOverflow,Native)
 local document=Parser.parse('<div id="host"><span id="a">hello  </span><b id="b">world</b><p id="p">A😀B</p><p id="q">ÄB</p></div>')
 local host,a,b,p,q=DOM.findById(document,'host'),DOM.findById(document,'a'),DOM.findById(document,'b'),DOM.findById(document,'p'),DOM.findById(document,'q')
 local ta,tb,tp,tq=a.Children[1],b.Children[1],p.Children[1],q.Children[1]
 local style=Style.resolve(a,{},error,false);style.Node=a
 local words=InlineWords.new(error);words:text(ta.Text,style,ta);words:text(tb.Text,style,tb)
 local items=words:take();assert(#items==2 and items[1].Text=='hello'and items[2].Text=='world')
 assert(items[2].SourceSpans[1].Node==tb and items[2].SourceGap[1].Start==5 and #items[2].SourceGap==2,'Collapsed whitespace preserves source UTF16 offsets')
 local joined=InlineWords.new(error);joined:text('hel',style,ta);joined:text('lo',style,tb)
 local merged=joined:take()[1];assert(#merged.SourceSpans==5 and merged.SourceSpans[4].Node==tb and merged.SourceSpans[4].Start==0,'Merged inline text retains distinct DOM origins')
 local upper=table.clone(style);upper.TextTransform='uppercase'
 local sharp={Kind='Text',Text='ß',Children={}};local transformed=InlineWords.new(error);transformed:text(sharp.Text,upper,sharp)
 local ss=transformed:take()[1];assert(ss.Text=='SS'and #ss.SourceSpans==1 and ss.SourceSpans[1].LastByte==2 and ss.SourceSpans[1].Finish==1)
 local pre=table.clone(style);pre.WhiteSpace,pre.WhiteSpaceCollapse,pre.TextWrapMode='pre-wrap','preserve','wrap';local preNode={Kind='Text',Text='a \t\r\n b',Children={}}
 local preserved=InlineWords.new(error);preserved:text(preNode.Text,pre,preNode);local preItems=preserved:take()
 assert(#preItems==5 and preItems[2].Kind=='Space'and #preItems[2].SourceSpans==3 and preItems[4].SourceSpans[1].Start==5 and not preItems[5].SourceGap,'Dynamic CR is a source space; LF remains a break with unchanged following offsets')
 local parent={}
 local function gui(x,y,width,height,kind)
  local value={Parent=parent,AbsolutePosition=Vector2.new(x,y),AbsoluteSize=Vector2.new(width,height),Size=UDim2.fromOffset(width,height),
   Visible=true,FontFace='mock',TextSize=16,LineHeight=1,ZIndex=1,TextXAlignment='Left',TextYAlignment='Top'}
  function value:IsA(name)return name==(kind or 'TextLabel')end;return value
 end
 local tree={CSSRules={},CSSStates={},TextItems={},TextItemsByGui={},NodeStyles={}}
 for _,node in {host,a,b,p,q}do tree.NodeStyles[node]=Style.resolve(node,{},error,false)end
 local function attach(item,x,y,width)
  item.Gui=gui(x,y,width,20,if item.Kind=='Space'then 'Frame'else nil);item.FontFace='mock';item.TextSize=16;item.SelectionOrder=#tree.TextItems+1
  table.insert(tree.TextItems,item);tree.TextItemsByGui[item.Gui]=item;return item
 end
 local hello,world=attach(items[1],100,50,40),attach(items[2],150,50,40)
 local emojiWords=InlineWords.new(error);emojiWords:text(tp.Text,style,tp);local emoji=attach(emojiWords:take()[1],100,90,24)
 local combinedWords=InlineWords.new(error);combinedWords:text(tq.Text,style,tq);local combined=attach(combinedWords:take()[1],100,130,16)
 local page={Document=document,Root={AbsolutePosition=Vector2.new(10,20)},Alive=true}
 local pending=false
 local runtime={HasPending=function()return pending end,Geometry={ClientRects=function(_,node)return if node==a then {{X=90,Y=30,Width=40,Height=20}}else {}end}}
 local painter=TextSelection.new(tree);local adapter=ScriptSelection.new(page,tree,runtime)
 adapter:Apply(ta,1,ta,3);local overlay=painter.Overlays[hello]
 assert(overlay and overlay.Frame.Position[1]==8 and overlay.Frame.Size[1]==16,'Exact byte boundary does not extend into following grapheme')
 adapter:Apply(ta,3,ta,1);assert(painter.Overlays[hello]==overlay,'Backward ranges retain source overlay identity')
 tree.CSSRules=Stylesheet.collect(document,error,'::selection{background:#123456;color:#abcdef}')
 adapter:AfterPaint();assert(painter.Overlays[hello]==overlay and overlay.Frame.BackgroundColor3==Color3.fromRGB(18,52,86)and overlay.Text.TextColor3==Color3.fromRGB(171,205,239),'Paint-only selection colors update retained overlays')
 local sourcePosition=hello.Gui.AbsolutePosition;adapter:AfterLayout();assert(hello.Gui.AbsolutePosition==sourcePosition,'Selection paint never changes source layout')
 local rects=adapter:RangeRects(ta,1,ta,3);assert(#rects==1 and rects[1].X==98 and rects[1].Y==30 and rects[1].Width==16)
 rects=adapter:RangeRects(ta,2,ta,2);assert(#rects==1 and rects[1].Width==0 and rects[1].X==106,'Collapsed text geometry')
 adapter:Apply(ta,5,ta,7);assert(not painter.Overlays[hello]and painter.Gaps[hello],'Whitespace-only range paints its gap')
 rects=adapter:RangeRects(ta,5,ta,7);assert(#rects==1 and rects[1].Width==10,'Whitespace-only geometry')
 assert(adapter:RenderedText(ta,0,tb,5)=='hello world','Rendered string collapses source whitespace')
 adapter:Apply(host,0,host,1);assert(painter.Overlays[hello]and not painter.Overlays[world],'Element child offsets map to rendered descendants')
 rects=adapter:RangeRects(host,0,host,1);assert(#rects==2,'Fully selected element border and merged text/gap rectangles')
 adapter:Apply(tp,2,tp,3);assert(painter.Overlays[emoji].Frame.Position[1]==8 and painter.Overlays[emoji].Frame.Size[1]==8,'Partial surrogate selects whole displayed glyph')
 assert(adapter:RenderedText(tp,1,tp,2)=='😀'and adapter:RenderedText(tp,2,tp,3)=='','Stringifier includes a supplementary grapheme only when its starting UTF16 unit is selected')
 adapter:Apply(tq,1,tq,2);assert(painter.Overlays[combined].Frame.Size[1]==8,'Combining sequence selected atomically')
 assert(adapter:RenderedText(tq,0,tq,1)=='Ä'and adapter:RenderedText(tq,1,tq,2)=='','Stringifier preserves complete combining sequence at its starting source unit')
 local native
 adapter:SetNativeChange(function(...)native={...};adapter:Apply(...)end)
 painter:Begin({emoji.Gui},Vector2.new(108,95));painter:Move({emoji.Gui},Vector2.new(116,95));painter:Finish()
 assert(native[1]==tp and native[2]==1 and native[3]==tp and native[4]==3,'Native drag reports UTF16 boundaries, not UTF8 or grapheme count')
 adapter:SetNativeChange(function()return false end)
 assert(not painter:Begin({emoji.Gui},Vector2.new(108,95))and not painter.Dragging,'Canceled selectstart stops the native gesture')
 adapter:Apply(tp,1,tp,3)
 emoji.Gui.AbsolutePosition=Vector2.new(200,190);adapter:AfterLayout()
 rects=adapter:RangeRects(tp,1,tp,3);assert(rects[1].X==198 and rects[1].Y==170,'Retained geometry follows resize and scroll absolute positions')
 emoji.Gui.AbsoluteSize=Vector2.new(48,40);adapter:AfterLayout()
 rects=adapter:RangeRects(tp,1,tp,3);assert(rects[1].Width==16 and painter.Overlays[emoji].Frame.Size[1]==8,'UIScale changes screen rectangles without double-scaling overlay coordinates')
 emoji.Gui.AbsoluteRotation=90;rects=adapter:RangeRects(tp,1,tp,3);assert(math.abs(rects[1].Width-40)<1e-6 and math.abs(rects[1].Height-16)<1e-6,'Native 2D rotation affects range bounds')
 pending=true;adapter:Apply(ta,0,ta,5);assert(not painter.Overlays[hello],'Pending DOM/layout work does not paint old fragments')
 pending=false;adapter:AfterLayout();assert(painter.Overlays[hello])
 tree.CSSRules=Stylesheet.collect(document,error,'::highlight(amber){background:#ffcc00;color:black}::highlight(blue){background:blue;color:white}')
 local sourceGui=hello.Gui;local normal=painter.Overlays[hello]
 local first={Name='amber',Ranges={{StartNode=ta,StartOffset=0,EndNode=ta,EndOffset=1},{StartNode=ta,StartOffset=3,EndNode=ta,EndOffset=5}}}
 adapter:PaintHighlights({first});assert(tree.TextSelection==painter and painter.Overlays[hello]==normal and hello.Gui==sourceGui,'Custom paint preserves selection and source identity')
 local highlighted={};for frame,item in tree.TextItemsByGui do if item==hello and frame.Name=='HTMLSelection'and frame~=normal.Frame then table.insert(highlighted,frame)end end
 assert(#highlighted==2,'Disjoint ranges retain separate painted segments')
 for _,frame in highlighted do assert(frame.BackgroundColor3==Color3.fromRGB(255,204,0)and frame.ZIndex<normal.Frame.ZIndex)end
 local second={Name='blue',Ranges={{StartNode=ta,StartOffset=1,EndNode=ta,EndOffset=4}}}
 adapter:PaintHighlights({second,first});for _,frame in highlighted do assert(not frame.Destroyed and frame.ZIndex==5,'Priority changes reorder retained overlays')end
 adapter:PaintHighlights({});for _,frame in highlighted do assert(frame.Destroyed and tree.TextItemsByGui[frame]==nil,'Registry removal disposes custom fragments')end
 a.Children={};ta.Parent=nil;adapter:AfterLayout();assert(not painter.Overlays[hello],'Removed source nodes clear obsolete paint without retaining a cached DOM index')
 adapter:Clear();assert(not next(painter.Overlays)and not next(painter.Gaps))
 adapter:Destroy();assert(painter.Changed==nil and painter.Alive,'Adapter does not destroy the input-owned painter')
 painter:Destroy();assert(tree.TextSelection==nil)
 -- Original conditional hyphens are copied, including when only their hidden
 -- UTF-16 unit is selected. Generated automatic hyphens have no DOM source.
 local shyDocument=Parser.parse('<span id="shy" lang="en">hy&shy;phen&shy;ation</span>')
 local shyHost=DOM.findById(shyDocument,'shy');local shyNode=shyHost.Children[1]
 local shyStyle=Style.resolve(shyHost,{},error,true);shyStyle.Node=shyHost
 local shyFlow=InlineWords.new(error);shyFlow:text(shyNode.Text,shyStyle,shyNode)
 local shyItem=shyFlow:take()[1];shyItem.Gui=gui(0,0,88,20)
 local shyTree={TextItems={shyItem},TextItemsByGui={[shyItem.Gui]=shyItem},NodeStyles={[shyHost]=shyStyle},CSSRules={},CSSStates={}}
 local shyPage={Document=shyDocument,Alive=true,Root={AbsolutePosition=Vector2.new(0,0)}}
 local shyAdapter=ScriptSelection.new(shyPage,shyTree)
 assert(shyAdapter:RenderedText(shyNode,0,shyNode,13)=='hy­phen­ation','Copying preserves original SHY while drawing its unbroken word without visible hyphens')
 assert(shyAdapter:RenderedText(shyNode,2,shyNode,3)=='­','A selected hidden SHY still has a source unit')
 assert(shyAdapter:RenderedText(shyNode,3,shyNode,7)=='phen','Source offsets after SHY remain exact')
 assert(shyAdapter:RenderedText(shyNode,0,shyNode,4)=='hy­p','Partial copying inserts SHY at its original source order')
 local shyRects=shyAdapter:RangeRects(shyNode,2,shyNode,3)
 assert(#shyRects==1 and shyRects[1].Width==0,'An invisible SHY retains its zero-width source geometry')
 assert(shyTree.TextSelection:Point({Item=shyItem,Offset=2}).Offset==2,'Picking the hidden SHY boundary keeps the original source offset')
 shyItem.Gui.Visible=false
 assert(shyAdapter:RenderedText(shyNode,0,shyNode,13)=='hy­phen­ation','Copying uses the original owner when its line-fragment GUIs are visible')
 shyAdapter:Destroy();if shyTree.TextSelection then shyTree.TextSelection:Destroy()end
 -- Wrapped fragments retain original source offsets and do not create spaces.
 local wrapStyle=table.clone(style);wrapStyle.OverflowWrap='anywhere'
 local wrapWords=InlineWords.new(error);local wrapNode={Kind='Text',Text='abcdef',Children={}};wrapWords:text(wrapNode.Text,wrapStyle,wrapNode)
 local word=wrapWords:take()[1];word.TextSize=16;word.FontFace='mock';word.Width=48;word.Height=20
 local split=OverflowWrap.splitter({Items={word},MeasureOnly=true},function(text)return Vector2.new(#text*8,20)end,function()return true end)
 local head,tail=split(word,24,false)
 assert(head.Text=='abc'and tail.Text=='def'and tail.SourceSpans[1].Start==3 and tail.SourceSpans[1].FirstByte==1 and not tail.SourceGap)
 local ellipsisStyle=table.clone(wrapStyle);ellipsisStyle.TextOverflow='ellipsis';ellipsisStyle.OverflowX='hidden'
 word.Style=ellipsisStyle;word.X=0;word.Y=0;word.LineIndex=1;word.LineBaseline=16;word.Gui=gui(0,0,48,20)
 local clipped=TextOverflow.prepare({Items={word},Style=ellipsisStyle,CreateWord=function(item)item.Gui=gui(0,0,item.Width,item.Height)end},
  {word},32,{TextSize=16,Baseline=16},'mock',function(text)return Vector2.new(utf8.len(text)*8,20)end,function()return true end)
 assert(clipped[1].Text=='abc'and clipped[1].SourceSpans[3].Finish==3,'Ellipsis prefix retains only its actual source characters')
 local malformed={Item={Glyphs=table.create(16384,false)},First=0,Last=1}
 local guardTree={TextItems={},TextItemsByGui={}};local guard=TextSelection.new(guardTree)
 local ok=pcall(function()guard:Apply({malformed})end);assert(not ok and not next(guard.Overlays),'GUI budget is preflighted before paint mutation');guard:Destroy()
 -- Selection.toString uses rendered transforms; plain copy retains source case.
 -- Both retain whitespace and block/BR
 -- boundaries, independent from soft line wrapping and source DOM whitespace.
 local textDocument=Parser.parse('<div id="text"><p id="one">alpha   beta</p><p id="two">straße<br>last</p><pre id="pre">a  b\n c</pre></div>')
 local textHost=DOM.findById(textDocument,'text');local one=DOM.findById(textDocument,'one');local two=DOM.findById(textDocument,'two');local preElement=DOM.findById(textDocument,'pre')
 local textTree={CSSRules={},CSSStates={},TextItems={},TextItemsByGui={},NodeStyles={}}
 local function install(node,inherited)
  if node.Kind=='Text'then
   local flow=InlineWords.new(error);flow:text(node.Text,inherited,node)
   for _,item in flow:take()do if item.Kind=='Word'or item.Kind=='Space'then
    item.Gui=gui(#textTree.TextItems*50,0,#item.Text*8,20,if item.Kind=='Space'then 'Frame'else nil);item.FontFace='mock';item.TextSize=16
    table.insert(textTree.TextItems,item);textTree.TextItemsByGui[item.Gui]=item
   end end
  elseif node.Kind=='Element'then
   local s=Style.resolve(node,inherited or {},error,false);s.Node=node
   if node==two then s.TextTransform='uppercase'end
   textTree.NodeStyles[node]=s
   for _,child in node.Children do install(child,s)end
  end
 end
 install(textHost,{})
 local textAdapter=ScriptSelection.new({Document=textDocument,Alive=true,Root={AbsolutePosition=Vector2.new(0,0)}},textTree,nil)
 assert(textAdapter:RenderedText(one,0,one,1)=='alpha beta','Collapsed gaps survive independent word labels')
 assert(textAdapter:RenderedText(two,0,two,3)=='STRASSE\nLAST','Selection.toString follows transformed rendered text and BR boundaries')
 assert(textAdapter:CopyText(two,0,two,3)=='straße\nlast','CSS display transforms must not change plain-text copy preparation')
 assert(textAdapter:RenderedText(preElement,0,preElement,1)=='a  b\n c','Preserved whitespace and line breaks')
 assert(textAdapter:RenderedText(textHost,0,textHost,2)=='alpha beta\n\nSTRASSE\nLAST','Paragraph boundaries use rendered line separators and display case')
 assert(textAdapter:CopyText(textHost,0,textHost,2)=='alpha beta\n\nstraße\nlast','Plain copy preparation keeps paragraph separators and original case')
 assert(textAdapter:CopyText(two.Children[1],4,two.Children[1],5)=='ß'and textAdapter:RenderedText(two.Children[1],4,two.Children[1],5)=='SS','Expanded SS display maps to one copied source character')
 local dotDocument=Parser.parse('<p id="dot-copy" lang="tr" style="text-transform:lowercase">İ</p>')
 local dotElement=DOM.findById(dotDocument,'dot-copy');local dotText=dotElement.Children[1]
 local dotStyle=Style.resolve(dotElement,{},error,false);dotStyle.Node=dotElement
 local dotWords=InlineWords.new(error);dotWords:text(dotText.Text,dotStyle,dotText)
 local dotItem=dotWords:take()[1];dotItem.Gui=gui(0,0,8,20);dotItem.TextSize=16;dotItem.FontFace='mock'
 assert(dotItem.Text=='i'and #dotItem.SourceSpans==1 and #dotItem.SourceHiddenSpans==1,'Turkic DOT ABOVE deletion has an original source boundary')
 local dotTree={CSSRules={},CSSStates={},TextItems={dotItem},TextItemsByGui={[dotItem.Gui]=dotItem},NodeStyles={[dotElement]=dotStyle}}
 local dotAdapter=ScriptSelection.new({Document=dotDocument,Alive=true},dotTree,nil)
 assert(dotAdapter:CopyText(dotText,0,dotText,2)=='İ'and dotAdapter:CopyText(dotText,1,dotText,2)=='̇','Display-deleted combining marks remain in complete and partial plain-text copies')
 assert(dotAdapter:RenderedText(dotText,0,dotText,2)=='i'and dotAdapter:RenderedText(dotText,1,dotText,2)=='','Selection.toString excludes display-deleted combining marks')
 local dotRects=dotAdapter:RangeRects(dotText,1,dotText,2)
 assert(#dotRects==1 and dotRects[1].Width==0 and dotRects[1].X==8,'Deleted source dot selects a caret boundary without a fabricated glyph')
 dotAdapter:Destroy()
 for _,case in {{'uppercase','t-uisce','tUISCE',1,2,'','-'},{'lowercase','tUISCE','t-uisce',1,2,'-u','U'}}do
  local caseDocument=Parser.parse('<p id="irish-copy" lang="ga" style="text-transform:'..case[1]..'">'..case[2]..'</p>')
  local caseElement=DOM.findById(caseDocument,'irish-copy');local caseText=caseElement.Children[1]
  local caseStyle=Style.resolve(caseElement,{},error,false);caseStyle.Node=caseElement
  local caseWords=InlineWords.new(error);caseWords:text(caseText.Text,caseStyle,caseText)
  local caseItem=caseWords:take()[1];caseItem.Gui=gui(0,0,#case[3]*8,20);caseItem.TextSize=16;caseItem.FontFace='mock'
  local caseTree={CSSRules={},CSSStates={},TextItems={caseItem},TextItemsByGui={[caseItem.Gui]=caseItem},NodeStyles={[caseElement]=caseStyle}}
  local caseAdapter=ScriptSelection.new({Document=caseDocument,Alive=true},caseTree,nil)
  assert(caseItem.Text==case[3]and caseAdapter:RenderedText(caseText,0,caseText,#case[2])==case[3]and caseAdapter:CopyText(caseText,0,caseText,#case[2])==case[2],'Irish inserted/deleted hyphens retain complete rendered/source strings')
  assert(caseAdapter:RenderedText(caseText,case[4],caseText,case[5])==case[6]and caseAdapter:CopyText(caseText,case[4],caseText,case[5])==case[7],'Irish partial source selection maps inserted/deleted display hyphens')
  local rect=caseAdapter:RangeRects(caseText,case[4],caseText,case[5])[1]
  assert(rect and rect.X==8 and rect.Width==(if case[1]=='uppercase'then 0 else 16),'Irish deletion has a caret and insertion stays inside its original vowel source range')
  caseAdapter:Destroy()
 end
 local wideDocument=Parser.parse('<pre id="wide-copy" style="text-transform:full-width">ab cd</pre>');local wideElement=DOM.findById(wideDocument,'wide-copy');local wideText=wideElement.Children[1]
 local wideStyle=Style.resolve(wideElement,{},error,false);wideStyle.Node=wideElement
 local wideWords=InlineWords.new(error);wideWords:text(wideText.Text,wideStyle,wideText)
 local wideTree={CSSRules={},CSSStates={},TextItems={},TextItemsByGui={},NodeStyles={[wideElement]=wideStyle}}
 for _,item in wideWords:take()do if item.Kind~='Break'then item.Gui=gui(0,0,16,20);item.TextSize=16;item.FontFace='mock';table.insert(wideTree.TextItems,item)end end
 local wideAdapter=ScriptSelection.new({Document=wideDocument,Alive=true},wideTree,nil)
 assert(wideAdapter:RenderedText(wideText,0,wideText,5)=='ａｂ　ｃｄ'and wideAdapter:RenderedText(wideText,2,wideText,3)=='　','Preserved full-width spaces appear in complete and partial rendered strings')
 assert(wideAdapter:CopyText(wideText,0,wideText,5)=='ab cd'and wideAdapter:CopyText(wideText,2,wideText,3)==' ','Plain copy keeps original width and space characters')
 wideAdapter:Destroy()
 local original=textTree.TextItems[1];original.Gui.Visible=false
 local projection=table.clone(original);projection.WrapOwner=original;projection.Text='al';projection.SourceSpans={original.SourceSpans[1],original.SourceSpans[2]};projection.Gui=gui(0,0,16,20)
 table.insert(textTree.TextItems,projection)
 assert(textAdapter:RenderedText(one,0,one,1)=='alpha beta','Clipped or wrapped paint does not truncate copied source text or double-count projections')
 textAdapter:Destroy();assert(textTree.TextSelection==nil and textTree.SelectionPaintChanged==nil,'Owned painter and hook are released')
 local crlfDocument=DOM.document();local crlfElement=DOM.element('pre',{});local crlfText=DOM.text('A\r\nB')
 DOM.append(crlfDocument,crlfElement);DOM.append(crlfElement,crlfText)
 local crlfStyle=Style.resolve(crlfElement,{},error,false);crlfStyle.WhiteSpace,crlfStyle.WhiteSpaceCollapse,crlfStyle.TextWrapMode='pre-wrap','preserve','wrap';crlfStyle.Node=crlfElement
 local crlfWords=InlineWords.new(error);crlfWords:text(crlfText.Text,crlfStyle,crlfText)
 local crlfTree={CSSRules={},CSSStates={},TextItems={},TextItemsByGui={},NodeStyles={[crlfElement]=crlfStyle}}
 for _,item in crlfWords:take()do if item.Kind~='Break'then item.Gui=gui(0,0,8,20,if item.Kind=='Space'then 'Frame'else nil);table.insert(crlfTree.TextItems,item)end end
 local crlfAdapter=ScriptSelection.new({Document=crlfDocument,Alive=true},crlfTree,nil)
 assert(crlfAdapter:RenderedText(crlfText,0,crlfText,4)=='A\r\nB','Preserved source CR is copied verbatim while its painted advance is a CSS space; LF copies once')
 crlfAdapter:Destroy()
 -- Shadow scopes use their own ordinary-tree text order while paint follows
 -- the retained native fragments, including layout/scroll changes.
 local shadowDocument=DOM.document();local shadowHost=DOM.element('div',{});DOM.append(shadowDocument,shadowHost)
 local root={Kind='ShadowRoot',Host=shadowHost,OwnerDocument=shadowDocument,Children={}}
 shadowHost.InternalShadowRoot=root
 local st=DOM.text('alpha');DOM.append(root,st)
 local light=DOM.text('light');DOM.append(shadowHost,light)
 local shadowStyle=Style.resolve(shadowHost,{},error,false);shadowStyle.Node=shadowHost
 local flow=InlineWords.new(error);flow:text(st.Text,shadowStyle,st)
 local shadowWord=flow:take()[1];shadowWord.Gui=gui(200,200,40,20);shadowWord.FontFace='mock';shadowWord.TextSize=16
 local shadowTree={CSSRules={},CSSStates={},TextItems={shadowWord},TextItemsByGui={[shadowWord.Gui]=shadowWord},NodeStyles={[shadowHost]=shadowStyle}}
 local scrolled=0;local shadowRuntime={Geometry={ScrollSelectionRect=function(_,owner,rect)
  assert(owner==shadowHost);assert(rect().X==216);scrolled+=1
 end}}
 local shadowAdapter=ScriptSelection.new({Document=shadowDocument,Alive=true,Root={AbsolutePosition=Vector2.new(0,0)}},shadowTree,shadowRuntime)
 shadowAdapter:Apply(st,1,st,4)
 assert(shadowTree.TextSelection.Overlays[shadowWord].Frame.Size[1]==24,'Shadow DOM paints real source glyphs')
 assert(shadowAdapter:RenderedText(st,1,st,4)=='lph','Shadow selection copying uses its own scope')
 assert(shadowAdapter:RenderedText(shadowHost,0,shadowHost,1)=='','Light-tree copying does not include shadow text')
 shadowAdapter:ScrollFocus(st,2);assert(scrolled==1,'Caret scroll uses current native position and shadow host')
 shadowWord.Gui.AbsolutePosition=Vector2.new(120,90)
 local shadowRects=shadowAdapter:RangeRects(st,1,st,4)
 assert(shadowRects[1].X==128 and shadowRects[1].Y==90,'Shadow glyph geometry follows resize and scroll')
 -- Visual movement uses native line coordinates and preserves horizontal goal.
 local second=DOM.text('abcdef');DOM.append(root,second)
 local secondFlow=InlineWords.new(error);secondFlow:text(second.Text,shadowStyle,second)
 local secondWord=secondFlow:take()[1];secondWord.Gui=gui(120,120,48,20);secondWord.FontFace='mock';secondWord.TextSize=16
 table.insert(shadowTree.TextItems,secondWord);shadowTree.TextItemsByGui[secondWord.Gui]=secondWord
 local moved,offset=shadowAdapter:MoveVisual(st,2,true,'line');assert(moved==second and offset==2,'Move down retains visual caret column')
 moved,offset=shadowAdapter:MoveVisual(second,2,false,'line');assert(moved==st and offset==2,'Move up retains visual caret column')
 moved,offset=shadowAdapter:MoveVisual(st,2,true,'lineboundary');assert(moved==st and offset==5,'Line boundary uses displayed line')
 -- Native labels shape an unmixed RTL word; selection coordinates must follow
 -- that visual run while DOM offsets remain in logical UTF-16 order.
 local rtlText=DOM.text('אבגד');DOM.append(root,rtlText)
 local rtlStyle=table.clone(shadowStyle);rtlStyle.Direction='rtl'
 shadowTree.NodeStyles[shadowHost]=rtlStyle
 local rtlFlow=InlineWords.new(error);rtlFlow:text(rtlText.Text,rtlStyle,rtlText)
 local rtlWord=rtlFlow:take()[1];rtlWord.Gui=gui(300,300,32,20);rtlWord.FontFace='mock';rtlWord.TextSize=16
 table.insert(shadowTree.TextItems,rtlWord);shadowTree.TextItemsByGui[rtlWord.Gui]=rtlWord
 shadowAdapter:Apply(rtlText,0,rtlText,1)
 local rtlOverlay=shadowTree.TextSelection.Overlays[rtlWord]
 assert(rtlOverlay.Frame.Position[1]==24 and rtlOverlay.Frame.Size[1]==8,'RTL first logical glyph paints at the right of its native run')
 local rtlRect=shadowAdapter:RangeRects(rtlText,1,rtlText,1)[1]
 assert(rtlRect.X==324 and rtlRect.Width==0,'RTL caret follows native shaped coordinates')
 moved,offset=shadowAdapter:MoveVisual(rtlText,1,true,'lineboundary')
 assert(moved==rtlText and offset==4,'RTL logical line end maps to the left visual boundary')
 moved,offset=shadowAdapter:MoveVisual(rtlText,1,false,'lineboundary')
 assert(moved==rtlText and offset==0,'RTL logical line start maps to the right visual boundary')
 shadowAdapter:Destroy()
 local supported={};for _,value in Native and Native.supports or {}do if value.supported then supported[value.collapse..':'..value.wrap]=true end end
 local comparisons=0
 local function copy(html,collapse,wrap)
  local document=Parser.parse('<div id="copy" style="white-space-collapse:'..collapse..';text-wrap-mode:'..wrap..'">'..html..'</div>')
  local host=assert(DOM.findById(document,'copy'));local flow=InlineWords.new(error)
  local textTree={CSSRules={},CSSStates={},TextItems={},TextItemsByGui={},NodeStyles={}}
  local function visit(node,parentStyle)
   if node.Kind=='Text'then flow:text(node.Text,parentStyle,node)
   elseif node.Kind=='Element'then
    local computed=Style.resolve(node,parentStyle or {},error,node.Name~='div');computed.Node=node;textTree.NodeStyles[node]=computed
    if node.Name=='br'then flow:lineBreak(computed)else for _,child in node.Children do visit(child,computed)end end
   end
  end
  visit(host)
  for _,item in flow:take()do if item.Kind~='Break'then
   item.Gui=gui(0,0,math.max(1,#item.Text)*8,20,if item.Kind=='Space'then 'Frame'else nil);item.SelectionOrder=#textTree.TextItems+1
   table.insert(textTree.TextItems,item);textTree.TextItemsByGui[item.Gui]=item
  end end
  local adapter=ScriptSelection.new({Document=document,Alive=true},textTree,nil)
  local result=adapter:RenderedText(host,0,host,#host.Children);adapter:Destroy();return result
 end
 for _,record in Native and Native.records or {}do
  if not supported[record.collapse..':'..record.wrap]then continue end
  assert(copy(record.html,record.collapse,record.wrap)==record.copied,'Native whitespace copy: '..record.collapse..'/'..record.wrap..'/'..record.name..'/'..record.columns)
  comparisons+=1
 end
 if Native then assert(comparisons==312);print('Selection native whitespace reference: '..comparisons..' supported source-copy cases passed, including CR/FF')end
 assert(copy(' AA\tBB\n CC ','preserve-spaces','nowrap')==' AA BB  CC ','Converted preserve-spaces whitespace copies once without invented newlines')
 assert(copy(' AA\tBB\n CC ','discard','wrap')=='AABBCC','Discarded whitespace does not reappear through special source newline copying')
 assert(copy(' AA\tBB\n CC ','preserve-breaks','nowrap')=='AA BB\nCC','Preserved breaks copy correctly with nowrap')
 print('Script selection: source mapping, whitespace, graphemes, DOM boundaries, native drag, paint identity, geometry and lifecycle passed')
end
