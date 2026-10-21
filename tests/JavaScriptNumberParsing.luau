--!strict
return function(Numbers: any,fixtures: any)
 for _,fixture in fixtures do local n=Numbers.parse(fixture.source);local actual=if n==0 and 1/n<0 then '-0'else Numbers.string(n);assert(actual==fixture.expected,fixture.name..': '..actual..' versus '..fixture.expected)end
end
