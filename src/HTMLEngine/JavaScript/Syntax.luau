--!strict
-- Bounded ECMAScript AST grammar shared by HTML, SVG and Canvas.
local Lexer=require(script.Parent.Lexer)
local Validation=require(script.Parent.SyntaxValidation)
local RegExpSyntax=require(script.Parent.RegExpSyntax)
local Syntax={}
local WorkContext=require(script.Parent.Parent.WorkContext)
local PRECEDENCE={["??"]=1,["||"]=1,["&&"]=2,["|"]=3,["^"]=4,["&"]=5,["=="]=6,["!="]=6,["==="]=6,["!=="]=6,
 ["<"]=7,[">"]=7,["<="]=7,[">="]=7,["in"]=7,["instanceof"]=7,["<<"]=8,[">>"]=8,[">>>"]=8,["+"]=9,["-"]=9,["*"]=10,["/"]=10,["%"]=10,["**"]=11}
local ASSIGN={["="]=true,["+="]=true,["-="]=true,["*="]=true,["/="]=true,["%="]=true,["**="]=true,["<<="]=true,[">>="]=true,[">>>="]=true,["&="]=true,["|="]=true,["^="]=true,["&&="]=true,["||="]=true,["??="]=true}
local RESERVED={["break"]=true,["case"]=true,["catch"]=true,["class"]=true,["const"]=true,["continue"]=true,["debugger"]=true,["default"]=true,["delete"]=true,
 ["do"]=true,["else"]=true,["enum"]=true,["export"]=true,["extends"]=true,["false"]=true,["finally"]=true,["for"]=true,["function"]=true,["if"]=true,["import"]=true,
 ["in"]=true,["instanceof"]=true,["new"]=true,["null"]=true,["return"]=true,["super"]=true,["switch"]=true,["this"]=true,["throw"]=true,["true"]=true,["try"]=true,["typeof"]=true,["var"]=true,["void"]=true,["while"]=true,["with"]=true}
function Syntax.parse(source: string,options: any?): any
 local tokens=Lexer.scan(source);local index,depth,blockLevel=1,0,0
 local module=options and options.Module==true
 local context={Function=false,Await=module,Module=module,Private=options and options.PrivateNames,
  NewTarget=options and options.NewTarget,SuperProperty=options and options.SuperProperty,SuperCall=options and options.SuperCall,Loop=0,Switch=0,Labels={}}
 local allowIn=true
 local expression,assignment,statement,block,pattern,primary,classExpression
 local function fail(message)error("JavaScript syntax: "..message.." at "..tokens[index].Position,0)end
 local function peek(value)return tokens[index].Kind~='literal'and tokens[index].Kind~='template'and not tokens[index].Escaped and tokens[index].Value==value end
 local function take(value)if peek(value)then index+=1;return true end;return false end
 local function need(value)if not take(value)then fail("Expected "..value)end end
 local function enter()WorkContext.checkpoint();depth+=1;assert(depth<=96,"JavaScript syntax depth exceeded")end
 local function identifier(binding)
  local token=tokens[index]
  if token.Kind~="word"then fail("Identifier expected")end
  if binding and(RESERVED[token.Value]or((context.Await or context.Module)and token.Value=="await")or(context.Generator and token.Value=="yield"))then fail("Invalid binding "..token.Value)end
  index+=1;return token.Value
 end
 local function semi()
  if take(";")or peek("}")or peek("<end>")or tokens[index].LineBefore then return end
  fail("Expected semicolon")
 end
 local function names(p,out)
  if p.Kind=="identifier"then table.insert(out,p.Name)
  elseif p.Kind=="array-pattern"then for _,entry in p.Items do if entry.Kind~="hole"then names(entry.Pattern or entry,out)end end
  elseif p.Kind=="object-pattern"then for _,entry in p.Properties do names(entry.Pattern,out)end
  elseif p.Pattern then names(p.Pattern,out)end
 end
 pattern=function(defaults)
  enter();local p
  if take("[")then
   local items={}
   while not peek("]")do
    if take(",")then table.insert(items,{Kind="hole"});continue end
    local rest=take("...");local entry=pattern(not rest)
    table.insert(items,if rest then {Kind="rest",Pattern=entry}else entry)
    if rest then if peek(",")then fail("Rest element must be last")end;break end
    if not take(",")then break end
   end
   need("]");p={Kind="array-pattern",Items=items}
  elseif take("{")then
   local properties={}
   while not peek("}")do
    if take("...")then
     table.insert(properties,{Rest=true,Pattern={Kind="identifier",Name=identifier(true)}})
     if peek(",")then fail("Rest property must be last")end;break
    end
    local computed,key,value=false,nil,nil
    if take("[")then computed=true;key=expression();need("]")
    else local t=tokens[index];if t.Kind~="word"and t.Kind~="literal"then fail("Property name expected")end;index+=1;key=t.Value end
    if take(":")then value=pattern(true)
    else
     if computed or type(key)~="string"or RESERVED[key]then fail("Invalid shorthand binding")end
     value={Kind="identifier",Name=key}
     if take("=")then value={Kind="default-pattern",Pattern=value,Value=assignment()}end
    end
    table.insert(properties,{Key=key,Computed=computed,Pattern=value})
    if not take(",")then break end
   end
   need("}");p={Kind="object-pattern",Properties=properties}
  else p={Kind="identifier",Name=identifier(true)}end
  if defaults and take("=")then p={Kind="default-pattern",Pattern=p,Value=assignment()}end
  depth-=1;return p
 end
 local function parameters()
  need("(");local params={}
  while not peek(")")do
   local rest=take("...");local p=pattern(not rest)
   table.insert(params,if rest then {Kind="rest",Pattern=p}else p)
   if rest then if peek(",")then fail("Rest parameter must be last")end;break end
   if not take(",")then break end
  end
  need(")");return params
 end
 local function functionBody(params,isAsync,name,arrow,generator,methodContext)
  local previous=context
  context={Function=true,Module=previous.Module,NewTarget=if arrow then previous.NewTarget==true else true,Await=isAsync==true,Generator=generator==true,Private=previous.Private,
   SuperProperty=if arrow then previous.SuperProperty else methodContext and methodContext.SuperProperty,
   SuperCall=if arrow then previous.SuperCall else methodContext and methodContext.SuperCall,Loop=0,Switch=0,Labels={}}
  local bound={};for _,p in params do names(p,bound)end
  local seen={}
  for _,nameValue in bound do
   if context.Await and nameValue=="await"then fail("Invalid async parameter")end
   if seen[nameValue]and(arrow or isAsync)then fail("Duplicate function parameter")end;seen[nameValue]=true
  end
  local body
  if peek("{")then body=block()else
   if not arrow then fail("Function body expected")end
   body={Kind="block",Items={{Kind="return",Value=assignment()}}}
  end
  context=previous
  return {Kind="function",Params=params,Body=body,Async=isAsync==true,Generator=generator==true,Name=name,Arrow=arrow==true}
 end
 local function func(isAsync,name,generator,methodContext,sourceStart)
  sourceStart=sourceStart or tokens[index].Position
  local previousAwait=context.Await;context.Await=false
  local params=parameters();context.Await=previousAwait
  local value=functionBody(params,isAsync,name,false,generator,methodContext)
  value.SourceText=source:sub(sourceStart,tokens[index-1].End-1);return value
 end
 local function arrowStart()
  local offset,isAsync=0,false
  if peek("async")and not tokens[index+1].LineBefore then offset=1;isAsync=true end
  local first=tokens[index+offset]
  if first.Kind=="word"and tokens[index+offset+1].Value=="=>"then return isAsync,offset,"single"end
  if first.Kind~='literal'and first.Value=="("then
   local level=0
   for i=index+offset,#tokens do
    if tokens[i].Value=="("then level+=1 elseif tokens[i].Value==")"then
     level-=1;if level==0 then
      if tokens[i+1].Value=="=>"then return isAsync,offset,"multiple"end;break
     end
    end
   end
  end
  return nil
 end
 local function args()
  need("(");local values={}
  while not peek(")")do
   local spread=take("...");local value=assignment()
   table.insert(values,if spread then {Kind="spread",Value=value}else value)
   if not take(",")then break end
  end
  need(")");return values
 end
 local function template(tag)
  need("template-start");local parts,raw={},{}
  while true do
   local t=tokens[index];if t.Kind~="template"then fail("Template chunk expected")end;index+=1
   table.insert(parts,{Kind="literal",Value=t.Value});table.insert(raw,t.Raw)
   if take("template-end")then break end
   need("template-expression");table.insert(parts,expression());need("template-expression-end")
  end
  return {Kind="template",Parts=parts,Raw=raw,Tag=tag}
 end
 local function privateName()
  local mark=tokens[index];need('#')
  if not context.Private or tokens[index].Position~=mark.End then fail('Invalid private identifier')end
  return identifier(false)
 end
 classExpression=function(required)
  local sourceStart=tokens[index].Position;need('class');local previous=context
  local name=if peek('extends')or peek('{')then nil else identifier(true)
  if required and not name then fail('Class declaration needs a name')end
  local heritage=if take('extends')then primary()else nil
  need('{');context={Function=false,Module=previous.Module,Await=false,Private=true,SuperProperty=true,NewTarget=true,Loop=0,Switch=0,Labels={}}
  local elements,privates,constructor={},{},false
  while not peek('}')do
   if take(';')then continue end
   local static=false
   if peek('static')and tokens[index+1].Value~='('and tokens[index+1].Value~='='and tokens[index+1].Value~=';'and tokens[index+1].Value~='}'then index+=1;static=true end
   if static and peek('{')then table.insert(elements,{Kind='static-block',Body=block()});continue end
   local elementStart=tokens[index].Position
   local async,accessor,generator=false,nil,false
   if peek('async')and not tokens[index+1].LineBefore and tokens[index+1].Value~='('and tokens[index+1].Value~='='and tokens[index+1].Value~=';'and tokens[index+1].Value~='}'then index+=1;async=true end
   if(peek('get')or peek('set'))and tokens[index+1].Value~='('and tokens[index+1].Value~='='and tokens[index+1].Value~=';'and tokens[index+1].Value~='}'then accessor=tokens[index].Value;index+=1 end
   generator=take('*')
   local computed,key,private=false,nil,false
   if take('[')then computed=true;key=expression();need(']')
   elseif peek('#')then private=true;key=privateName()
   else local token=tokens[index];if token.Kind~='word'and token.Kind~='literal'then fail('Class element name expected')end;key=token.Value;index+=1 end
   if not computed and(private and key=='constructor'or static and not private and key=='prototype')then fail('Forbidden class element name')end
   local isConstructor=not static and not private and not computed and key=='constructor'
   local element={Key=key,Computed=computed,Private=private,Static=static}
   if peek('(')then
    if isConstructor then if constructor or accessor or async or generator then fail('Invalid class constructor')end;constructor=true end
    element.Kind='method';element.Constructor=isConstructor;element.Accessor=accessor
    element.Value=func(async,nil,generator,{SuperProperty=true,SuperCall=isConstructor and heritage~=nil},elementStart);element.Value.Method=true;element.Value.Strict=true
    if accessor and(#element.Value.Params~=(if accessor=='get'then 0 else 1)or(generator or async)or(accessor=='set'and element.Value.Params[1].Kind=='rest'))then fail('Invalid class accessor')end
   else
    if accessor or async or generator or isConstructor then fail('Invalid class field')end
    element.Kind='field';element.Value=if take('=')then assignment()else nil;semi()
   end
   if private then
    local prior=privates[key]
    if prior and(not accessor or not prior.Accessor or prior.Accessor==accessor or prior.Static~=static or prior.Pair)then fail('Duplicate private name')end
    if prior then prior.Pair=true else privates[key]=element end
   end
   table.insert(elements,element)
  end
  need('}');context=previous
  return {Kind='class',Name=name,Heritage=heritage,Elements=elements,PrivateNames=privates,SourceText=source:sub(sourceStart,tokens[index-1].End-1)}
 end
 primary=function()
  enter();local t=tokens[index];local n
  if t.Kind=="literal"then index+=1;n={Kind="literal",Value=t.Value,DirectiveEligible=t.DirectiveEligible}
  elseif t.Kind=="regexp"then
   RegExpSyntax.compile(t.Value.Pattern,t.Value.Flags,function()end,function(message)fail(message)end)
   index+=1;n={Kind="regexp",Pattern=t.Value.Pattern,Flags=t.Value.Flags}
  elseif t.Kind=="bigint"then index+=1;n={Kind="bigint",Value=t.Value}
  elseif take("true")then n={Kind="literal",Value=true}
  elseif take("false")then n={Kind="literal",Value=false}
  elseif take("null")then n={Kind="null"}
  elseif peek('class')then n=classExpression(false)
  elseif take('super')then
   if not context.SuperProperty and not context.SuperCall then fail('super outside method')end
   if peek('(')and not context.SuperCall then fail('super call outside derived constructor')end
   if not peek('(')and not peek('.')and not peek('[')then fail('Invalid super reference')end
   n={Kind='super'}
  elseif peek('#')then n={Kind='private-name',Name=privateName()}
  elseif take("import")then
   if take(".")then need("meta");if not context.Module then fail("import.meta outside module")end;n={Kind="import-meta"}
   else
    local values=args();if #values<1 or #values>2 or values[1].Kind=="spread"or(values[2]and values[2].Kind=="spread")then fail("Invalid dynamic import arguments")end
    n={Kind="dynamic-import",Value=values[1],Options=values[2]}
   end
  elseif peek("template-start")then n=template()
  elseif peek("async")and tokens[index+1].Value=="function"and not tokens[index+1].LineBefore then
   index+=2;local generator=take('*');local name=if peek("(")then nil else identifier(true);n=func(true,name,generator,nil,t.Position)
  elseif take("function")then local generator=take('*');local name=if peek("(")then nil else identifier(true);n=func(false,name,generator,nil,t.Position)
  elseif take("new")then
   local target
   if take(".")then need("target");if not context.NewTarget then fail("new.target outside ordinary function")end;n={Kind="new-target"}
   else
    if take("(")then target=expression();need(")")
    else target={Kind="identifier",Name=identifier(false)}end
    while peek(".")or peek("[")do
     if take(".")then target={Kind="member",Object=target,Key={Kind="literal",Value=identifier(false)}}
     else need("[");local key=expression();need("]");target={Kind="member",Object=target,Key=key}end
    end
    n={Kind="new",Target=target,Args=if peek("(")then args()else {}}
   end
  elseif take("(")then local value=expression();need(")");n={Kind="group",Value=value}
  elseif take("[")then
   local items={}
   while not peek("]")do
    if take(",")then table.insert(items,{Kind="hole"});continue end
    local spread=take("...");local value=assignment();table.insert(items,if spread then {Kind="spread",Value=value}else value)
    if not take(",")then break end
   end
   need("]");n={Kind="array",Items=items}
  elseif take("{")then
   local props={}
   while not peek("}")do
    if take("...")then table.insert(props,{Spread=true,Value=assignment()})
    else
     local methodStart=tokens[index].Position
     local isAsync,accessor,generator=false,nil,false
     if peek("async")and not tokens[index+1].LineBefore and tokens[index+1].Value~=":"and tokens[index+1].Value~=","and tokens[index+1].Value~="}"and tokens[index+1].Value~="("then index+=1;isAsync=true end
     if(peek("get")or peek("set"))and tokens[index+1].Value~=":"and tokens[index+1].Value~=","and tokens[index+1].Value~="}"and tokens[index+1].Value~="("then accessor=tokens[index].Value;index+=1 end
     generator=take("*")
     local computed,key=false,nil
     if take("[")then computed=true;key=expression();need("]")
     else local keyToken=tokens[index];if keyToken.Kind~="word"and keyToken.Kind~="literal"then fail("Property name expected")end;key=keyToken.Value;index+=1 end
     local value,method,cover,shorthand
     if peek("(")then value=func(isAsync,nil,generator,{SuperProperty=true},methodStart);value.Method=true;method=true
      if accessor and(#value.Params~=(if accessor=="get"then 0 else 1)or generator or isAsync or(accessor=="set"and value.Params[1].Kind=="rest"))then fail("Invalid accessor parameters")end
     elseif take(":")then if accessor or isAsync or generator then fail("Method expected")end;value=assignment()
     else
      if accessor or isAsync or generator or computed or type(key)~="string"or RESERVED[key]then fail("Invalid shorthand property")end
      value={Kind="identifier",Name=key}
      shorthand=true
      if take('=')then value={Kind='assign',Target=value,Op='=',Value=assignment()};cover=true end
     end
     table.insert(props,{Key=key,Computed=computed,Value=value,Method=method,Accessor=accessor,Cover=cover,Shorthand=shorthand})
    end
    if not take(",")then break end
   end
   need("}");n={Kind="object",Properties=props}
  else
   if RESERVED[t.Value]and t.Value~="this"then fail("Unexpected "..tostring(t.Value))end
   n={Kind="identifier",Name=identifier(false)}
  end
  local chain,optional=0,false
  while true do
   chain+=1;assert(chain<=96,"JavaScript expression chain budget exceeded")
   if take(".")then
    local private=peek('#');if private and n.Kind=='super'then fail('Private super reference')end
    n={Kind="member",Object=n,Private=private,Key={Kind="literal",Value=if private then privateName()else identifier(false)}}
   elseif take("?.")then
    optional=true
    if peek("(")then n={Kind="call",Target=n,Args=args(),Optional=true}
    elseif take("[")then local key=expression();need("]");n={Kind="member",Object=n,Key=key,Optional=true}
    else local private=peek('#');n={Kind="member",Object=n,Private=private,Key={Kind="literal",Value=if private then privateName()else identifier(false)},Optional=true}end
   elseif take("[")then local key=expression();need("]");n={Kind="member",Object=n,Key=key}
   elseif peek("(")then n={Kind="call",Target=n,Args=args()}
   elseif peek("template-start")then if optional then fail("Optional chain cannot be a template tag")end;n=template(n)
   else break end
  end
  if optional then n={Kind="chain",Value=n}end
  if n.Kind=='private-name'and not peek('in')then fail('Private name requires in operator')end
  depth-=1;return n
 end
 local function unary()
  local t=tokens[index]
  if take("++")or take("--")then
   local target=unary();if target.Kind~="identifier"and target.Kind~="member"then fail("Invalid update target")end
   return {Kind="update",Target=target,Delta=if t.Value=="++"then 1 else -1,Prefix=true}
  elseif take("!")or take("~")or take("+")or take("-")or take("typeof")or take("void")or take("delete")then return {Kind="unary",Op=t.Value,Value=unary()}
  elseif peek("await")and context.Await then index+=1;return {Kind="await",Value=unary()}end
  local n=primary()
  if not tokens[index].LineBefore and(peek("++")or peek("--"))then
   if n.Kind~="identifier"and n.Kind~="member"then fail("Invalid update target")end
   local delta=if take("++")then 1 else -1;if delta==-1 then need("--")end
   n={Kind="update",Target=n,Delta=delta}
  end
  return n
 end
 local function binary(min)
  enter();local left=unary()
  while true do
   local op=tokens[index].Value;local p=if tokens[index].Kind=='literal'then nil else PRECEDENCE[op]
   if not p or p<min or(op=="in"and not allowIn)then break end
   if op=="**"and left.Kind=="unary"then fail("Unary expression before exponentiation requires parentheses")end
   index+=1;local right=binary(if op=="**"then p else p+1)
   if op=="??"and((left.Kind=="binary"and(left.Op=="||"or left.Op=="&&"))or(right.Kind=="binary"and(right.Op=="||"or right.Op=="&&")))then fail("Mixing nullish and logical operators requires parentheses")end
   if(op=="||"or op=="&&")and((left.Kind=="binary"and left.Op=="??")or(right.Kind=="binary"and right.Op=="??"))then fail("Mixing logical and nullish operators requires parentheses")end
   left={Kind="binary",Op=op,Left=left,Right=right}
  end
  depth-=1;return left
 end
 local function assignmentPattern(node)
  if node.Kind=='identifier'or node.Kind=='member'then return node end
  if node.Kind=='group'then return assignmentPattern(node.Value)end
  if node.Kind=='assign'and node.Op=='='then return {Kind='default-pattern',Pattern=assignmentPattern(node.Target),Value=node.Value}end
  if node.Kind=='array'then
   local items={};for i,item in node.Items do
    if item.Kind=='hole'then table.insert(items,item)
    elseif item.Kind=='spread'then if i~=#node.Items then fail('Rest assignment must be last')end;table.insert(items,{Kind='rest',Pattern=assignmentPattern(item.Value)})
    else table.insert(items,assignmentPattern(item))end
   end;return {Kind='array-pattern',Items=items}
  elseif node.Kind=='object'then
   local properties={};for i,property in node.Properties do
    if property.Method or property.Accessor then fail('Method is not an assignment target')end
    if property.Spread then if i~=#node.Properties then fail('Rest assignment must be last')end;table.insert(properties,{Rest=true,Pattern=assignmentPattern(property.Value)})
    else table.insert(properties,{Key=property.Key,Computed=property.Computed,Pattern=assignmentPattern(property.Value)})end
   end;return {Kind='object-pattern',Properties=properties}
  end
  fail('Invalid destructuring assignment target')
 end
 assignment=function()
  enter()
  if peek('yield')and context.Generator then
   index+=1;local delegate=not tokens[index].LineBefore and take('*')
   local value=if not delegate and(tokens[index].LineBefore or peek(';')or peek('}')or peek(')')or peek(']')or peek(',')or peek('<end>'))then nil else assignment()
   depth-=1;return {Kind='yield',Value=value,Delegate=delegate}
  end
  local isAsync,offset,form=arrowStart()
  local n
  if form then
   local sourceStart=tokens[index].Position
   index+=offset
   local previousAwait=context.Await;context.Await=false
   local params=if form=="multiple"then parameters()else {{Kind="identifier",Name=identifier(true)}}
   context.Await=previousAwait
   if tokens[index].LineBefore then fail("Newline before arrow")end;need("=>");n=functionBody(params,isAsync,nil,true)
   n.SourceText=source:sub(sourceStart,tokens[index-1].End-1)
  else
   n=binary(1)
   if take("?")then local yes=assignment();need(":");n={Kind="conditional",Test=n,Yes=yes,No=assignment()}end
   local op=tokens[index].Value
   if tokens[index].Kind~='literal'and ASSIGN[op]then
    if n.Kind=='group'then n=n.Value end
    if n.Kind~="identifier"and n.Kind~="member"and not(op=="="and(n.Kind=="array"or n.Kind=="object"))then fail("Invalid assignment target")end
    if n.Kind=='array'or n.Kind=='object'then n=assignmentPattern(n)end
    index+=1;n={Kind="assign",Target=n,Op=op,Value=assignment()}
   end
  end
  depth-=1;return n
 end
 expression=function()
  local n=assignment()
  if take(",")then local items={n};repeat table.insert(items,assignment())until not take(",");return {Kind="sequence",Items=items}end
  return n
 end
 local function usingStart()
  return(peek('using')and tokens[index+1].Kind=='word'and not tokens[index+1].LineBefore)or(peek('await')and tokens[index+1].Value=='using'and not tokens[index+1].LineBefore)
 end
 local function declaration(inFor)
  local mode=tokens[index].Value;index+=1;local entries={}
  if mode=='await'then need('using');if not context.Await then fail('await using outside async context')end;mode='await-using'end
  local using=mode=='using'or mode=='await-using'
  if using and not inFor and blockLevel==0 and not module then fail('using declaration requires a block or module')end
  if using and not inFor and context.UsingCaseLevel==blockLevel then fail('using in a switch case requires a block')end
  repeat
   local p=if using then {Kind='identifier',Name=identifier(true)}else pattern(false);local value=if take("=")then assignment()else nil
   if not value and(mode=="const"or using)and not peek("in")and not peek("of")then fail("Declaration needs initializer")end
   local bound={};names(p,bound)
   table.insert(entries,{Name=if p.Kind=="identifier"then p.Name else nil,Pattern=p,Names=bound,Value=value})
  until not take(",")
  return {Kind="declare",Mode=mode,Entries=entries}
 end
 block=function()
  enter();need("{");blockLevel+=1;local items={}
  while not peek("}")do if peek("<end>")then fail("Unclosed block")end;table.insert(items,statement())end
  need("}");blockLevel-=1;depth-=1;return {Kind="block",Items=items}
 end
 local function loopBody()
  context.Loop+=1;local body=statement(true);context.Loop-=1;return body
 end
 statement=function(single)
  enter();local n;local sourceStart=tokens[index].Position
  if single and(peek('let')or peek('const')or peek('class')or usingStart())then fail('Lexical declaration requires a block')end
  if peek("{")then n=block()
  elseif take(";")then n={Kind="empty"}
  elseif peek("let")or peek("const")or peek("var")or usingStart()then n=declaration();semi()
  elseif peek('class')then local value=classExpression(true);n={Kind='class-declaration',Name=value.Name,Value=value}
  elseif peek("async")and tokens[index+1].Value=="function"and not tokens[index+1].LineBefore then index+=2;local generator=take('*');local name=identifier(true);n={Kind="function-declaration",Name=name,Value=func(true,name,generator,nil,sourceStart)}
  elseif take("function")then local generator=take('*');local name=identifier(true);n={Kind="function-declaration",Name=name,Value=func(false,name,generator,nil,sourceStart)}
  elseif take("if")then need("(");local test=expression();need(")");local yes=statement(true);n={Kind="if",Test=test,Yes=yes,No=if take("else")then statement(true)else nil}
  elseif take("while")then need("(");local test=expression();need(")");n={Kind="while",Test=test,Body=loopBody()}
  elseif take("do")then local body=loopBody();need("while");need("(");local test=expression();need(")");n={Kind="do",Test=test,Body=body}
  elseif take("for")then
   local isAwait=take("await");if isAwait and not context.Await then fail("for await outside async function")end
   need("(");local init
   if not peek(";")then
    local previous=allowIn;allowIn=false
    init=if peek("let")or peek("const")or peek("var")or usingStart()then declaration(true)else {Kind="expression",Value=expression()}
    allowIn=previous
   end
   if peek("in")or peek("of")then
    local mode=tokens[index].Value;index+=1
    if not init then fail("Loop binding expected")end
    if isAwait and mode~='of'then fail('for await requires of')end
    if init.Kind=="declare"and(#init.Entries~=1 or init.Entries[1].Value)then fail("Invalid iteration declaration")end
    if init.Kind=='expression'then init.Value=assignmentPattern(init.Value);if init.Value.Kind=='default-pattern'then fail('Invalid iteration assignment')end end
    if init.Kind=='declare'and(init.Mode=='using'or init.Mode=='await-using')and(mode=='in'or init.Entries[1].Name=='of')then fail('Invalid using loop binding')end
    local value=if mode=='of'then assignment()else expression();need(")");n={Kind="for-each",Init=init,Value=value,Mode=mode,Await=isAwait,Body=loopBody()}
   else
    if isAwait then fail("for await requires of")end
    need(";");local test=if peek(";")then nil else expression();need(";");local update=if peek(")")then nil else expression();need(")")
    n={Kind="for",Init=init,Test=test,Update=update,Body=loopBody()}
   end
  elseif take("switch")then
   need("(");local test=expression();need(")");need("{");local cases,hasDefault={},false;context.Switch+=1;blockLevel+=1
   local previousCaseLevel=context.UsingCaseLevel;context.UsingCaseLevel=blockLevel
   while not peek("}")do
    local testValue
    if take("case")then testValue=expression()
    elseif take("default")then if hasDefault then fail("Duplicate default")end;hasDefault=true
    else fail("case or default expected")end
    need(":");local items={}
    while not peek("case")and not peek("default")and not peek("}")do table.insert(items,statement())end
    table.insert(cases,{Test=testValue,Items=items})
   end
   need("}");context.Switch-=1;blockLevel-=1;context.UsingCaseLevel=previousCaseLevel;n={Kind="switch",Test=test,Cases=cases}
  elseif take("try")then
   local body=block();local handler,parameter,finalizer
   if take("catch")then if take("(")then parameter=pattern(false);need(")")end;handler=block()end
   if take("finally")then finalizer=block()end
   if not handler and not finalizer then fail("try requires catch or finally")end
   n={Kind="try",Body=body,Handler=handler,Parameter=parameter,Finalizer=finalizer}
  elseif take("return")then
   if not context.Function then fail("return outside function")end
   n={Kind="return",Value=if tokens[index].LineBefore or peek(";")or peek("}")or peek("<end>")then nil else expression()};semi()
  elseif take("throw")then
   if tokens[index].LineBefore then fail("Newline after throw")end;n={Kind="throw",Value=expression()};semi()
  elseif peek("break")or peek("continue")then
   local kind=tokens[index].Value;index+=1;local label
   if not tokens[index].LineBefore and tokens[index].Kind=="word"then label=identifier(true)end
   if label then
    if not context.Labels[label]then fail("Unknown label "..label)end
    if kind=="continue"and context.Labels[label]~="loop"then fail("continue requires loop label")end
   elseif kind=="break"and context.Loop==0 and context.Switch==0 then fail("break outside loop/switch")
   elseif kind=="continue"and context.Loop==0 then fail("continue outside loop")end
   n={Kind=kind,Label=label};semi()
  elseif take("debugger")then n={Kind="empty"};semi()
  elseif tokens[index].Kind=="word"and tokens[index+1].Value==":"then
   local label=identifier(true);need(":");if context.Labels[label]then fail("Duplicate label")end
   context.Labels[label]=if peek("for")or peek("while")or peek("do")then "loop"else "block"
   local body=statement(true);context.Labels[label]=nil
   if body.Kind=="for"or body.Kind=="while"or body.Kind=="do"or body.Kind=="for-each"then body.Label=label end
   n={Kind="label",Name=label,Body=body}
  else n={Kind="expression",Value=expression()};semi()end
  if n.Kind=='function-declaration'then n.Value.Declaration=true;n.Single=single==true end
  depth-=1;return n
 end
 local items,imports,exports,requests={},{},{},{}
 local function stringLiteral()
  local t=tokens[index];if t.Kind~="literal"or type(t.Value)~="string"then fail("Module specifier/name must be a string")end;index+=1;return t.Value
 end
 local function exportName()
  return if tokens[index].Kind=="literal"then stringLiteral()else identifier(false)
 end
 local function request(specifier)
  local attributes={}
  if take("with")then
   need("{")
   while not peek("}")do
    local key=exportName();need(":");local value=stringLiteral()
    if attributes[key]then fail("Duplicate import attribute")end;attributes[key]=value
    if not take(",")then break end
   end
   need("}")
  end
  local record={Specifier=specifier,Attributes=attributes};table.insert(requests,record);return record
 end
 local function addExport(name,localName,from,importName,star)
  if name then for _,entry in exports do if entry.Name==name then fail("Duplicate export "..name)end end end
  table.insert(exports,{Name=name,Local=localName,From=from,Import=importName,Star=star})
 end
 while not peek("<end>")do
  if module and peek("import")and tokens[index+1].Value~="("and tokens[index+1].Value~="."then
   index+=1;local entries={};local from
   if tokens[index].Kind=="literal"then from=request(stringLiteral())
   else
    if not peek("*")and not peek("{")then table.insert(entries,{Local=identifier(true),Import="default"});if not take(",")then need("from");from=request(stringLiteral())end end
    if not from then
     if take("*")then need("as");table.insert(entries,{Local=identifier(true),Namespace=true})
     else
      need("{")
      while not peek("}")do
       local wasString=tokens[index].Kind=="literal";local name=exportName();local localName
       if take("as")then localName=identifier(true)else
        if wasString or RESERVED[name]or name=="await"then fail("Import binding needs alias")end;localName=name
       end
       table.insert(entries,{Local=localName,Import=name});if not take(",")then break end
      end
      need("}")
     end
     need("from");from=request(stringLiteral())
    end
   end
   for _,entry in entries do entry.From=from;table.insert(imports,entry)end;semi()
  elseif module and take("export")then
   if take("*")then
    local name=if take("as")then exportName()else nil;need("from");local from=request(stringLiteral())
    addExport(name,nil,from,nil,true);semi()
   elseif take("{")then
    local entries={}
    while not peek("}")do
     local name=exportName();table.insert(entries,{Local=name,Name=if take("as")then exportName()else name});if not take(",")then break end
    end
    need("}");local from=if take("from")then request(stringLiteral())else nil
    for _,entry in entries do addExport(entry.Name,if from then nil else entry.Local,from,if from then entry.Local else nil)end;semi()
   elseif take("default")then
    local isAsync=peek("async")and tokens[index+1].Value=="function"and not tokens[index+1].LineBefore
    if peek('class')then
     local value=classExpression(false);local name=value.Name or '*default*'
     if not value.Name then value.InferredName='default'end
     if value.Name then table.insert(items,{Kind='class-declaration',Name=name,Value=value})
     else table.insert(items,{Kind='declare',Mode='const',Entries={{Name=name,Pattern={Kind='identifier',Name=name},Names={name},Value=value}}})end
     addExport('default',name)
    elseif peek("function")or isAsync then
     local sourceStart=tokens[index].Position
     index+=if isAsync then 2 else 1
     local generator=take('*');local name=if peek("(")then "*default*"else identifier(true)
     local value=func(isAsync,if name=='*default*'then 'default'else name,generator,nil,sourceStart);value.Declaration=true
     table.insert(items,{Kind="function-declaration",Name=name,Value=value});addExport("default",name)
    else
     local value=assignment();local name="*default*"
     table.insert(items,{Kind="declare",Mode="const",Entries={{Name=name,Pattern={Kind="identifier",Name=name},Names={name},Value=value}}})
     addExport("default",name);semi()
    end
   else
    if not(peek('class')or peek("var")or peek("let")or peek("const")or peek("function")or(peek("async")and tokens[index+1].Value=="function"))then fail("Export declaration expected")end
    local item=statement();table.insert(items,item)
    if item.Kind=="declare"then for _,entry in item.Entries do for _,name in entry.Names do addExport(name,name)end end
    elseif item.Kind=="function-declaration"or item.Kind=='class-declaration'then addExport(item.Name,item.Name)end
   end
  else table.insert(items,statement())end
 end
 local ast={Kind='program',Items=items,Module=module,Imports=imports,Exports=exports,Requests=requests};Validation.check(ast,options);return ast
end
function Syntax.parseModule(source: string): any return Syntax.parse(source,{Module=true})end
return Syntax
