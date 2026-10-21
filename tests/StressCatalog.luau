--!strict
-- The real parser, renderer and layout run on every smaller stress category.
return function(pages, Parser, loadRenderTree, loadWordLayout, loadBlockLayout)
 local started=os.clock()
 local totalProbes,totalNodes,totalGui=0,0,0
 local moduleCount=0
 local overrides={['Layout/FontProfiles']={face=function(face)return face end},['Layout/TextMeasure']={measure=function(text,_,size)return {X=utf8.len(text)*size*.5,Y=size}end}}
 overrides['Layout/WordLayout']=loadWordLayout(overrides)
 local layout=loadBlockLayout(overrides)
 for _,page in pages do
  moduleCount+=1
  local document=Parser.parse(page.html)
  assert(document.NodeCount<20000,"Stress category exceeds parser node budget: "..page.name)
  assert(#document.Diagnostics==0,document.Diagnostics[1])
  totalNodes+=document.NodeCount
  local count=0
  local renderer=loadRenderTree({create=function(class,_,props)
   count+=1
   local gui=table.clone(props)
   if class=="Frame" then
    local function check(key)
     assert(key~="TextColor3" and key~="TextTransparency",key.." is not a valid member of Frame "..(props.Name or ""))
    end
    setmetatable(gui,{__index=function(_,key)check(key);return nil end,__newindex=function(target,key,value)check(key);rawset(target,key,value)end})
   end
   return gui
  end})
  local diagnostics={}
  local seen={}
  local function report(message)
   if not seen[message] then seen[message]=true;table.insert(diagnostics,message)end
  end
  local tree=renderer.build(document,{AbsoluteSize={X=1280,Y=800}},report,nil,nil,nil,function()return "rbxassetid://1" end,nil,nil,nil,nil,nil,{["styles.css"]=page.css})
  if page.name=="html-css-stress-html" then
   for _,message in diagnostics do
    for _,feature in {":user-invalid",":checked",":has(",":placeholder-shown","@supports","prefers-reduced-motion","color-scheme: light","Unsupported style on inline element"} do
     assert(not message:find(feature,1,true),"Resolved stress CSS still reports "..feature..": "..message)
    end
   end
  end
  if page.name=="html-css-stress-forms" then
   for _,message in diagnostics do
    assert(not message:find("select multiple/size > 1",1,true)
     and not message:find("custom-select",1,true)
     and not message:find("scroll-marker",1,true),"Form page still reports an unsupported selector or list select: "..message)
   end
  end
  local probes=0
  local pending={document}
  while #pending>0 do
   local node=table.remove(pending)
   if node.Attributes and node.Attributes["data-property"] then probes+=1 end
   for _,child in node.Children or {} do table.insert(pending,child)end
   if node.Content then table.insert(pending,node.Content)end
   if node.InternalShadowRoot then table.insert(pending,node.InternalShadowRoot)end
  end
  totalProbes+=probes
  local heights={}
  for _,width in {1280,800,390,1280} do
   local height=layout.arrange(tree,width,0,0,function()return true end)
   assert(height==height and height>0 and height<1000000,"Finite layout required: "..page.name)
   table.insert(heights,height)
  end
  assert(math.abs(heights[1]-heights[4])<.01,"Resize accumulated offsets: "..page.name)
  if page.name=="html-css-stress-css-ui" then
   local accent
   for _,control in tree.Controls do
    if control.Node.Attributes["aria-label"]=="Accent probe" then accent=control.Item;break end
   end
   assert(accent and accent.BoxWidth==130 and accent.BoxHeight==36
    and accent.BoxGui.Size[1]==36 and accent.BoxGui.Size[2]==36
    and accent.BoxGui.Position[1]==47 and accent.Ticks[1].BackgroundColor3==Color3.new(0,0,0),
    "The real accent-color card must center its dark-mark square inside the 130px input")
  end
  local allocations=count
  layout.arrange(tree,1280,0,0,function()return true end)
  assert(count==allocations,"Repeated layout allocated GUIs: "..page.name)
  -- Exercise the shared navigation on every real stress category, not only one page.
  for _,link in tree.Links do
   local parent=link.Parent
   if parent and parent.Attributes and (parent.Attributes.class=='section-nav' or parent.Attributes.class=='hero-top') then
    for _,state in {'hover','focus','focus-visible','active'}do
     local before=count
     local _,reflow=tree:SetCSSState(state,link)
     assert(not reflow,'Navigation '..state..' caused full layout: '..page.name)
     _,reflow=tree:SetCSSState(state,nil)
     assert(not reflow,'Leaving navigation '..state..' caused full layout: '..page.name)
     if state=='hover' then assert(count==before,'Navigation hover allocated new visuals: '..page.name)end
    end
   end
  end
  allocations=count -- Focus rings may be created once and retained for later repaint.
  if page.name=="html-css-stress-forms" then
   local field,range,color,multiple,disabled,fieldsetDisabled
   for _,control in tree.Controls do
    local id=control.Node.Attributes.id
    if id=="f-text" then field=control
    elseif id=="f-range" then range=control
    elseif id=="f-color" then color=control
    elseif id=="f-multi" then multiple=control
    elseif id=="f-disabled" then disabled=control
    elseif control.Node.Attributes.value=="disabled über fieldset" then fieldsetDisabled=control end
   end
   assert(range and range.Item.BoxGui.BackgroundTransparency==1,
    "Native range appearance must not paint a rectangular input background")
   assert(color and color.Type=="color" and color.Value=="#087f72" and color.Item.ColorSwatch
    and color.Item.ColorSwatch.BackgroundColor3==Color3.fromRGB(8,127,114)
    and color.Item.BoxWidth==50 and color.Item.BoxHeight==27 and not color.Item.Editor,
    "Color input must render the HTML-sized color swatch instead of hex text")
   assert(multiple and multiple.Item.SelectListRows[1].Gui.BackgroundColor3==Color3.fromRGB(206,206,206)
    and multiple.Item.SelectListRows[1].Label.TextColor3==Color3.fromRGB(16,16,16),
    "Unfocused selected list options use the browser's gray inactive selection")
   assert(disabled and fieldsetDisabled and disabled.Disabled and fieldsetDisabled.Disabled
    and disabled.Item.BoxGui.BackgroundColor3==Color3.new(1,1,1)
    and fieldsetDisabled.Item.BoxGui.BackgroundColor3==Color3.new(1,1,1),
    -- Native HTML: the authored input background is white; :disabled changes opacity.
    "Direct and fieldset-inherited disabled inputs preserve the HTML's authored white background: "
     ..tostring(disabled and disabled.Disabled).."/"..tostring(fieldsetDisabled and fieldsetDisabled.Disabled)
     .."/"..tostring(fieldsetDisabled and fieldsetDisabled.Item.BoxGui.BackgroundColor3[1]*255)
     .."/"..tostring(fieldsetDisabled and fieldsetDisabled.Item.BoxGui.BackgroundColor3[2]*255)
     .."/"..tostring(fieldsetDisabled and fieldsetDisabled.Item.BoxGui.BackgroundColor3[3]*255)
     .."/"..tostring(fieldsetDisabled and fieldsetDisabled.Item.Style.ControlBackgroundSpecified))
   assert(field and field.Item.Style~=tree.NodeStyles[field.Node],"The real form input uses a derived flex-item style")
   assert(tree:SetCSSState("focus-visible",field.Node))
   layout.arrange(tree,1280,0,0,function()return true end)
   assert(field.Item.ControlOutline and field.Item.ControlOutline.Style.BorderColor==Color3.fromRGB(180,68,9)
    and field.Item.ControlOutline.Gui.Position[1]==-7 and field.Item.ControlOutline.Gui.Size[1]==field.Item.BoxWidth+14,
    "The real form CSS must draw its orange focus ring outside the input")
   assert(tree:SetCSSState("focus-visible",nil))
   layout.arrange(tree,1280,0,0,function()return true end)
   assert((not field.Item.ControlOutline or field.Item.ControlOutline.Gui.Visible==false),"The form focus ring disappears on blur")
  end
  if page.name=="html-css-stress-html" then
   assert(tree:SetMediaEnvironment(800,800))
   assert(tree:SetMediaEnvironment(1280,800))
   assert(count==allocations,"Dynamic repaint allocated GUIs")
  end
  totalGui+=count
 end
 assert(moduleCount>10,"Expected independent stress categories")
 assert(totalProbes==1017,"All 1017 CSS property probes must survive across category pages")
 print(string.format("Stress categories: %d pages, %d source nodes, %d properties, %d mock GUIs; %.1f ms",moduleCount,totalNodes,totalProbes,totalGui,(os.clock()-started)*1000))
end
