--!strict
return function(Parser,Runtime,Events,fixtures)
 local failures={}
 for _,fixture in fixtures do
  local output,diagnostics={},{}
  local runtime=Runtime.new(Parser.parseDocument('<!doctype html><html><body></body></html>'),{
   Events=Events.new(error),URL='https://example.test/r04',
   Console=function(_,s)table.insert(output,s)end,Diagnostic=function(s)table.insert(diagnostics,s)end})
  runtime:Run('function record(value){console.log(String(value));}\n'..fixture.source)
  if #diagnostics>0 or #output~=#fixture.expected then
   table.insert(failures,fixture.name..': '..table.concat(diagnostics,' / ')..' output='..table.concat(output,' / '))
  else for i,value in output do if value~=fixture.expected[i]then
   table.insert(failures,fixture.name..' ['..i..'] '..value..' ~= '..fixture.expected[i])
  end end end
  runtime:Destroy()
 end
 for _,message in failures do print('R04 mismatch: '..message)end
 assert(#failures==0,'R04 shadow selection failures: '..#failures)
 print('R04 Selection: '..#fixtures..' Chromium 154 reference cases passed')
end
