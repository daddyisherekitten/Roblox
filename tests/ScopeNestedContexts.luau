--!strict
return function(Parser,Node,Runtime,Events,Stylesheet,nested,contexts)
 local function quoted(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)return if c=='"'or c=='\\'then '\\'..c else string.format('\\u%04x',string.byte(c))end)..'"'end
 local function json(value)
  if value==nil then return 'null'elseif type(value)=='string'then return quoted(value)end
  local parts={};for _,entry in value do table.insert(parts,json(entry))end;return '['..table.concat(parts,',')..']'
 end
 local document=Parser.parseDocument(nested.html);local events=Events.new(error)
 local runtime=Runtime.new(document,{Events=events,ControlAdapter={},Schedule=function()end})
 local function tree(records,starts)
  local result={};for _,r in records do local row={r.family,r.selector or false,tree(r.rules or {},starts)}
   if starts then row={r.family,r.selector or false,r.start or false,r['end']or false,tree(r.rules or {},starts)}end
   table.insert(result,row)
  end;return result
 end
 local function encode(value)
  if value==false then return 'null'elseif type(value)=='string'then return quoted(value)end
  local parts={};for _,v in value do table.insert(parts,encode(v))end;return '['..table.concat(parts,',')..']'
 end
 local function cssTree(source,starts)
  local fields=if starts then 'r.constructor.name,r.selectorText??null,r.start??null,r.end??null,'else'r.constructor.name,r.selectorText??null,'
  assert(runtime:Run('(()=>{const sheet=new CSSStyleSheet();sheet.replaceSync('..quoted(source)..');function record(r){return ['..fields..'r.cssRules?Array.from(r.cssRules,record):[]];}globalThis.scopeTree=JSON.stringify(Array.from(sheet.cssRules,record));globalThis.scopeRoundTrip=Array.from(sheet.cssRules,r=>r.cssText).join("\\n");})()'))
  return runtime.Window.Get('scopeTree'),runtime.Window.Get('scopeRoundTrip')
 end
 local colors=0
 for _,case in nested.cases do
  local diagnostics={};local rules=Stylesheet.collect(document,function(x)table.insert(diagnostics,x)end,case.source)
  assert(#diagnostics==0,table.concat(diagnostics,' | '))
  local actual,serialized=cssTree(case.source,true)
  assert(actual==encode(tree(case.expected.tree,true)),case.name..': CSSOM tree '..actual)
  for _,source in {case.source,serialized}do
   rules=Stylesheet.collect(document,error,source)
   for _,record in case.expected.colors do
    local selected=Stylesheet.rawMatch(rules,Node.findById(document,record[1]));local actual=selected.Normal[#selected.Normal].Value
    assert(actual:gsub(' ','')==record[2]:gsub(' ',''),case.name..' '..record[1]..': '..actual..' != '..record[2]);colors+=1
   end
  end
 end
 for _,case in contexts.cases do
  local actual=cssTree(case.source,false)
  assert(actual==encode(tree(case.expected,false)),case.name..': CSSOM tree '..actual)
 end
 for _,case in contexts.mutations do
  local selector=quoted(case.selector)
  assert(runtime:Run('(()=>{const sheet=new CSSStyleSheet();sheet.replaceSync("@scope (.root){p{color:red}}");const scope=sheet.cssRules[0];scope.cssRules[0].selectorText='..selector..';globalThis.setSelector=scope.cssRules[0].selectorText;scope.insertRule('..selector..'+"{color:blue}",0);globalThis.insertSelectors=JSON.stringify(Array.from(scope.cssRules,r=>[r.constructor.name,r.selectorText]));})()'))
  assert(runtime.Window.Get('setSelector')==case.expected.set.selector,case.name..': selector setter')
  local expected={};for _,r in case.expected.rules do table.insert(expected,{r[1],r[2]})end
  assert(runtime.Window.Get('insertSelectors')==json(expected),case.name..': insertRule')
 end
 assert(#runtime.Diagnostics==0,table.concat(runtime.Diagnostics,' | '));runtime:Destroy();events:Destroy()
 assert(colors==216 and #contexts.cases==36 and #contexts.mutations==6,'Exact independent native contexts')
 print('Scope nested contexts: 12 CSSOM/collect/serialized trees, 216 colors, 36 parse contexts and 6 setter/insertion pairs passed')
end
