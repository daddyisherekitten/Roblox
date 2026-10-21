--!strict
return function(Parser,Node,Runtime,Events,fixture)
 local Stylesheet=require('CSS/Stylesheet');local Style=require('CSS/InlineStyle')
 local checks=0
 for _,case in fixture.cases do
  local document=Parser.parseDocument(case.doctype..'<html><head></head><body><div id="target"></div></body></html>')
  local records,diagnostics={},{};local events=Events.new(error)
  local runtime=Runtime.new(document,{Events=events,Console=function(_,value)table.insert(records,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
  local ok,message=runtime:Run('var e=document.getElementById("target");var sheet=document.createElement("style");document.head.append(sheet);')
  assert(ok,tostring(message))
  for _,probe in case.values do
   local property,value=string.format('%q',probe.property),string.format('%q',probe.value)
   local source='e.style.cssText="";e.style.setProperty('..property..','..value..');sheet.textContent="div{"+'..property..'+":"+'..value..'+"}";console.log(e.style.getPropertyValue('..property..')+"|"+sheet.sheet.cssRules[0].style.getPropertyValue('..property..')+"|"+CSS.supports('..property..','..value..'));'
   ok,message=runtime:Run(source);assert(ok,case.mode..' '..probe.property..':'..probe.value..' '..tostring(message))
   local expected=(probe.standardInline or probe.inline)..'|'..probe.rule..'|'..tostring(probe.supports)
   assert(records[#records]==expected,case.mode..' '..probe.property..':'..probe.value..' '..records[#records]..' ~= '..expected)
   local rules=Stylesheet.collect(document,error,'@supports ('..probe.property..':'..probe.value..'){#target{--native-probe:yes}}')
   local matched=Stylesheet.match(rules,Node.findById(document,'target'));local supported=false
   for _,entry in matched.Normal do if entry.Custom=='--native-probe'then supported=true end end
   assert(supported==probe.atSupports,case.mode..' @supports '..probe.property..':'..probe.value)
   checks+=1
  end
  assert(#diagnostics==0,'Quirks values: unexpected runtime diagnostics');runtime:Destroy();events:Destroy()
 end
 local document=Parser.parseDocument('<style>#target{--v:20;width:var(--v);--c:abc;color:var(--c)}</style><div id="target"></div>')
 local node=Node.findById(document,'target');local rules=Stylesheet.collect(document,error)
 local style=Style.resolve(node,{FontSize=16},error,false,Stylesheet.match(rules,node))
 assert(style.Width.Value==20 and not style.Width.Percent and style.Color==Color3.fromRGB(170,187,204),'Quirky grammar survives variable substitution in its original parsing mode')
 local runtime=Runtime.new(document,{Diagnostic=error,Console=function(_,value)assert(value==fixture.extra.keyframeWidth..'|'..fixture.extra.keyframeColor..'|'..fixture.extra.adoptedWidth..'|'..fixture.extra.adoptedNewHeight)end})
 local ok,message=runtime:Run('var s=document.createElement("style");s.textContent="@keyframes t{to{width:30;color:abc}}";document.head.append(s);var k=s.sheet.cssRules[0].cssRules[0].style;var e=document.getElementById("target");e.style.width="20";var other=new DOMParser().parseFromString("<!doctype html><body></body>","text/html");other.adoptNode(e);e.style.height="20";console.log(k.width+"|"+k.color+"|"+e.style.width+"|"+e.style.height);')
 assert(ok,tostring(message));runtime:Destroy()
 print('Quirks values: '..checks..' native declaration/CSSOM/supports probes and substituted values passed')
end
