--!strict
return function(Parser,fixtures)
 for _,fixture in fixtures do
  local matrix,is2D=Parser.parse(fixture.source)
  if fixture.error then assert(matrix==nil,'Unexpected acceptance: '..fixture.source)
  else
   assert(matrix,'Unexpected rejection: '..fixture.source)
   assert(is2D==fixture.is2D,'Incorrect dimension flag: '..fixture.source)
   for i,expected in fixture.values do assert(math.abs(matrix[i]-expected)<=1e-10*math.max(1,math.abs(expected)),'Incorrect entry '..i..': '..fixture.source..' ('..tostring(matrix[i])..' instead of '..expected..')')end
  end
 end
 assert(Parser.parse('translate('..string.rep('calc(',80)..'1px'..string.rep(')',80)..')')==nil,'Deep math must fail predictably')
 assert(Parser.parse(string.rep('scale(1)',4100))==nil,'Long lists must fail predictably')
 print('GeometryTransformParser: '..#fixtures..' syntax/math/units/matrix cases and resource bounds passed')
end
