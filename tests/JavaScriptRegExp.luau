--!strict
return function(VM,RegExp,Lexer,fixtures)
 for _,fixture in fixtures do
  local values={};local globals={record=function(args)table.insert(values,VM.string(args[1]));return VM.Undefined end}
  local vm=VM.new(globals,{MaxSteps=1000000});vm.Model=VM;local regex=vm.RegExp or RegExp.install(vm,globals)
  local ok,message=pcall(function()vm:Run(fixture.source)end)
  assert(ok,fixture.name..": "..VM.string(VM.exceptionValue(message)))
  assert(#values==#fixture.expected,fixture.name..": "..table.concat(values," | "))
  for i,value in fixture.expected do assert(values[i]==value,fixture.name..": "..table.concat(values," | "))end
  regex:Destroy();vm:Destroy()
 end
 do
  local values={};local globals={record=function(args)table.insert(values,VM.string(args[1]))end};local vm=VM.new(globals,{MaxSteps=1000000});vm.Model=VM
  local regex=RegExp.install(vm,globals,{MaxBacktrackingSteps=500})
  vm:Run("try{new RegExp('(a+)+$').test('aaaaaaaaaaaaaaaaaaaaaaaa!');}catch(e){record(e.name);}record(new RegExp('a+').test('aaaa'));")
  assert(values[1]=="RangeError"and values[2]=="true","Pathological backtracking is bounded without corrupting later matching")
  local retained=regex:Create("a","");regex:Destroy();local ok=pcall(function()vm:Call(vm.Get(retained,"test"),{"a"},retained)end);assert(not ok,"Retained RegExp wrappers cannot execute after disposal");vm:Destroy()
 end
 do
  local cases={
   {"if (ready) /a[\\/]b/gi.test(text);",1,0},
   {"while (ready) /x/.test(text);",1,0},
   {"const x=f() / 2 / 3;",0,2},
   {"const x=({a:1}) / 2;",0,1},
   {"function f(){} /x/.test(text);",1,0},
   {"const f=function(){} / 2;",0,1},
   {"const f=()=>{}; /x/.test(text);",1,0},
   {"const f=(()=>{}) / 2;",0,1},
   {"class A{} /x/.test(text);const x=class {} / 2;",1,1},
   {"class A { #function=8; #class(){ /method/.test('method');return this.#function / 2;} static { /static/.test('static'); } } /after/.test('after');const x=class{m(){return /inside/;}} / 2;",4,2},
   {"const a={function:4,class(){return /method/;}};a.function / 2;",1,1},
   {"const t=`${/a/.test(x)} ${4 / 2}`;",1,1},
   {"const q={return:4};q.return / 2;",0,1},
   {"for (const x of /r/g){}",1,0},
  }
  for _,case in cases do local regular,division=0,0;for _,token in Lexer.scan(case[1])do if token.Kind=="regexp"then regular+=1 elseif token.Value=="/"then division+=1 end end;assert(regular==case[2]and division==case[3],"RegExp lexical goal: "..case[1])end
  for _,source in {"const r=/x\ny/;","const r=/[abc/;","const x=1.5n;","const x=1e2n;","const x=01n;"}do local ok=pcall(Lexer.scan,source);assert(not ok,"Lexical error was not rejected: "..source)end
  local tokens=Lexer.scan("0n 1_234n 0xffn 0b101n 0o77n");assert(tokens[1].Kind=="bigint"and tokens[1].Value=="0"and tokens[2].Value=="1_234"and tokens[3].Value=="0xff"and tokens[4].Value=="0b101"and tokens[5].Value=="0o77","BigInt tokens preserve exact integer text")
 end
 print("JavaScript RegExp: "..#fixtures.." shared traces, lexical goals, BigInt token text, bounded backtracking and disposal passed")
end
