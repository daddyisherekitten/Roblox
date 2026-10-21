--!strict
return function(Parser,Node,Runtime,Events,Stylesheet,fixture)
 local function quoted(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)return if c=='"'or c=='\\'then '\\'..c else string.format('\\u%04x',string.byte(c))end)..'"'end
 local document=Parser.parseDocument(fixture.html);local events=Events.new(error)
 local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end});local colors=0
 for _,case in fixture.cases do
  local rules=Stylesheet.collect(document,function(x)if case.expected.count>0 then error(x)end end,case.source)
  assert(runtime:Run('(()=>{const s=new CSSStyleSheet();s.replaceSync('..quoted(case.source)..');globalThis.scopeTopCount=s.cssRules.length;})()'))
  assert(runtime.Window.Get('scopeTopCount')==case.expected.count,case.source..': CSSOM count')
  for _,record in case.expected.colors do
   local matched=Stylesheet.rawMatch(rules,Node.findById(document,record[1]));local declarations=if #matched.Important>0 then matched.Important else matched.Normal
   assert(declarations[#declarations].Value:gsub(' ','')==record[2]:gsub(' ',''),case.source..' '..record[1]);colors+=1
  end
 end
 assert(colors==88 and #fixture.cases==8,'Exact independently captured top-level controls')
 assert(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,' | '));runtime:Destroy();events:Destroy()
 print('Scope top references: 8 native CSSOM/style grammar cases /88 subjects passed')
end
