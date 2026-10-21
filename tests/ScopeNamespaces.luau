--!strict
return function(Parser,Node,Runtime,Events,Stylesheet,fixture,edges)
 local function quoted(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)return if c=='"'or c=='\\'then '\\'..c else string.format('\\u%04x',string.byte(c))end)..'"'end
 local document=Parser.parseDocument(fixture.html);local events=Events.new(error);local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
 assert(runtime:Run('(()=>{'..fixture.setup..'})()'))
 local equivalents={};local cases=table.clone(fixture.cases);for _,case in edges.cases do equivalents[case.normativeFor]=case;table.insert(cases,case)end
 local comparisons,projections=0,0
 for _,case in cases do
  local rules=Stylesheet.collect(document,error,case.css)
  assert(runtime:Run('(()=>{const sheet=new CSSStyleSheet();sheet.replaceSync('..quoted(case.css)..');const last=sheet.cssRules[sheet.cssRules.length-1];globalThis.scopeProbeResult=JSON.stringify([sheet.cssRules.length,last.constructor.name]);})()'))
  assert(runtime.Window.Get('scopeProbeResult')=='['..case.expected.count..',"'..case.expected.type..'"]',case.name..': actual scope rule tree')
  local counterpart=equivalents[case.name];local expected=if counterpart then counterpart.expected.colors else case.expected.colors
  for recordIndex,record in expected do
   if counterpart and record[2]~=case.expected.colors[recordIndex][2]then projections+=1 end
   local selected=Stylesheet.rawMatch(rules,Node.findById(document,record[1]));local actual=selected.Normal[#selected.Normal].Value;local wanted=record[2]:gsub(' ','')
   assert(actual==wanted,case.name..' '..record[1]..': '..actual..' != '..wanted);comparisons+=1
  end
 end
 assert(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,' | '));runtime:Destroy();events:Destroy()
 assert(comparisons==6672 and projections==20,'Exact270raw+8nativecontrols and20 named inherited frozen namespace deltas')
 print('Scope root/relative namespace probe: '..#cases..' raw CSSOM/style contexts /'..comparisons..' subjects passed')
end
