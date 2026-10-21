--!strict
return function(VM: any,BigInt: any,fixtures: any)
 for _,fixture in fixtures do
  local vm=VM.new({},{MaxSteps=1000000});local api=BigInt.install(vm,{})
  local ok,result=pcall(function()
   if fixture.op=='parse'then return api:Parse(fixture.left)
   elseif fixture.op=='number'then return BigInt.Number(api:Parse(fixture.left))
   elseif fixture.op=='fromNumber'then return api:FromNumber(fixture.number)
   elseif fixture.op=='compareNumber'then return BigInt.CompareNumber(api:Parse(fixture.left),fixture.number)
   elseif fixture.op=='negate'or fixture.op=='not'then return api:Unary(if fixture.op=='negate'then '-'else '~',api:Parse(fixture.left))end
   return api:Binary(fixture.op,api:Parse(fixture.left),api:Parse(fixture.right))
  end)
  if fixture.error then assert(not ok and vm.Get(VM.exceptionValue(result),'name')==fixture.error,fixture.name..': expected '..fixture.error)
  else assert(ok,fixture.name..': '..tostring(result));local actual=if BigInt.is(result)then BigInt.String(result,fixture.radix or 10)else tostring(result);assert(actual==fixture.expected,fixture.name..': '..actual..' versus '..fixture.expected)end
  api:Destroy();vm:Destroy()
 end
 local vm=VM.new({},{MaxSteps=1000000});local api=BigInt.install(vm,{});local huge='0x1'..string.rep('0',1024)
 local ok,err=pcall(function()return api:Parse(huge)end);assert(not ok and vm.Get(VM.exceptionValue(err),'name')=='RangeError')
 assert(BigInt.String(api:Binary('>>',api:Parse('-3'),api:Parse('999999999999999999999')))== '-1')
 api:Destroy();vm:Destroy()
end
