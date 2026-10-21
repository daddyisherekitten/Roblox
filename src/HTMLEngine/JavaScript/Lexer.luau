--!strict
-- Positions and line breaks are retained for restricted productions and ASI.
local Strings=require(script.Parent.Strings)
local Identifier=require(script.Parent.Identifier)
local Lexer={}
local WorkContext=require(script.Parent.Parent.WorkContext)
local OPERATORS={">>>=","===","!==","**=","&&=","||=","??=","<<=",">>=","...","=>","?.","??","**","++","--","+=","-=","*=","/=","%=","<=",">=","==","!=","&&","||","<<",">>",">>>","&=","|=","^="}
table.sort(OPERATORS,function(a,b)return #a>#b end)
local ESCAPES={n="\n",r="\r",t="\t",b="\b",f="\f",v="\v",["0"]="\0"}
function Lexer.scan(source: string): any
 WorkContext.checkpoint()
 assert(#source<=65536,"JavaScript source budget exceeded")
 local tokens,at,newline,nesting={},1,false,0
 local nextCheck=1
 local function check()
  if at>=nextCheck then nextCheck=at+256;WorkContext.checkpoint()end
 end
 -- Lexical goal follows expression/statement boundaries. Closing a control
 -- header permits a RegExp statement; a call, object or function expression
 -- instead permits division. Contexts survive nested template substitutions.
 local expressionAllowed,statementStart=true,true
 local contexts={};local pendingFunction,pendingClass,pendingBody,pendingControl
 local asyncStatement=false
 local controlWords={['if']=true,['while']=true,['for']=true,['with']=true,['switch']=true,['catch']=true}
 local prefixWords={['return']=true,['throw']=true,['case']=true,['delete']=true,['void']=true,['typeof']=true,['new']=true,['in']=true,['instanceof']=true,['yield']=true,['await']=true}
 local function lexical(kind,value,hadLine)
  local previous=tokens[#tokens];local beforeStatement=statementStart
  local context=contexts[#contexts]
  if hadLine and previous and(not context or context.Kind=="block"or context.Kind=="function")and(not expressionAllowed or previous.Value=="return"or previous.Value=="yield")then beforeStatement=true end
  if kind=="literal"or kind=="regexp"or kind=="bigint"or(kind=="symbol"and value=="template-end")then expressionAllowed,statementStart=false,false;return end
  if kind=="word"then
   local memberName=previous and(previous.Value=="."or previous.Value=="?."or previous.Value=="#"or(context and(context.Kind=="object"or context.Kind=="class")and(previous.Value=="{"or previous.Value==","or previous.Value==";"or previous.Value=="}")))
   if memberName then expressionAllowed,statementStart=false,false;return end
   if value=="function"then pendingFunction={Expression=not(beforeStatement or(previous and previous.Value=="async"and asyncStatement)),Depth=#contexts};expressionAllowed=true;statementStart=false
   elseif value=="class"then pendingClass={Expression=not beforeStatement,Depth=#contexts};expressionAllowed=true;statementStart=false
   elseif controlWords[value]and beforeStatement then pendingControl=value;expressionAllowed=true;statementStart=false
   elseif value=="else"or value=="do"or value=="try"or value=="finally"or value=="debugger"or value=="break"or value=="continue"then expressionAllowed,statementStart=true,true
   elseif value=="export"or(value=="default"and previous and previous.Value=="export")then expressionAllowed,statementStart=true,true
   elseif prefixWords[value]then expressionAllowed=true;statementStart=false
   elseif value=="of"and contexts[#contexts]and contexts[#contexts].Control=="for"then expressionAllowed=true;statementStart=false
   else expressionAllowed=false;statementStart=false end
   if value=="async"then asyncStatement=beforeStatement end;return
  end
  if kind~="symbol"then return end
  if value=="("then
   local context={Kind="paren",Control=pendingControl,Function=pendingFunction};pendingControl,pendingFunction=nil,nil
   table.insert(contexts,context);expressionAllowed,statementStart=true,false
  elseif value==")"then
   local context=table.remove(contexts)
   if context and context.Kind=="paren"then pendingBody=context.Function;expressionAllowed=context.Control~=nil;statementStart=expressionAllowed else expressionAllowed,statementStart=false,false end
  elseif value=="{"then
   local context
   if pendingBody then context={Kind="function",Expression=pendingBody.Expression};pendingBody=nil
   elseif pendingClass and pendingClass.Depth==#contexts then context={Kind="class",Expression=pendingClass.Expression};pendingClass=nil
   elseif previous and previous.Value=="=>"then context={Kind="function",Expression=true}
   else
    local returnLine=hadLine and previous and(previous.Value=="return"or previous.Value=="yield")
    context={Kind=if expressionAllowed and not statementStart and not returnLine then "object"else "block"}
   end
   table.insert(contexts,context);expressionAllowed=true;statementStart=context.Kind~="object";pendingControl=nil
  elseif value=="}"then local context=table.remove(contexts);expressionAllowed=not context or(context.Kind~="object"and not context.Expression);statementStart=expressionAllowed
  elseif value=="["then table.insert(contexts,{Kind="bracket"});expressionAllowed,statementStart=true,false
  elseif value=="]"then table.remove(contexts);expressionAllowed,statementStart=false,false
  elseif value==";"then expressionAllowed=true;statementStart=not(contexts[#contexts]and contexts[#contexts].Kind=="paren")
  elseif value==":"then expressionAllowed=true;statementStart=not(contexts[#contexts]and contexts[#contexts].Kind=="object")
  elseif value=="."or value=="?."then expressionAllowed,statementStart=false,false
  elseif value=="++"or value=="--"then if hadLine then expressionAllowed=true end;statementStart=false
  elseif value=="template-start"or value=="template-expression"then expressionAllowed,statementStart=true,false
  elseif value=="template-expression-end"then expressionAllowed,statementStart=false,false
  else expressionAllowed=true;statementStart=false end
  if value~="("and value~="{"then pendingControl=nil end
 end
 local function fail(message,start)error("JavaScript syntax: "..message.." at "..(start or at),0)end
 local function emit(kind,value,start,extra)
  assert(#tokens<16000,"JavaScript token budget exceeded")
  local item={Kind=kind,Value=value,Position=start,End=at,LineBefore=newline}
  if extra then for key,v in extra do item[key]=v end end
  lexical(kind,value,newline)
  table.insert(tokens,item);newline=false
 end
 local function codepoint(code)
  if code>0x10ffff then fail("Invalid Unicode escape")end
  if code<=0xffff then return Strings.fromUnits({code})end
  code-=0x10000;return Strings.fromUnits({0xd800+math.floor(code/1024),0xdc00+code%1024})
 end
 local function escape()
  local start=at;at+=1;local c=source:sub(at,at);at+=1
  if c==""then fail("Unclosed escape",start)end
  if c=="\n"then return ""elseif c=="\r"then if source:sub(at,at)=="\n"then at+=1 end;return ""end
  if c=="u"or c=="x"then
   local digits
   if c=="u"and source:sub(at,at)=="{"then
    local last=source:find("}",at+1,true);if not last then fail("Unclosed Unicode escape",start)end
    digits=source:sub(at+1,last-1);at=last+1
    if #digits==0 or #digits>6 or not digits:match("^%x+$")then fail("Invalid Unicode escape",start)end
   else
    local count=if c=="u"then 4 else 2;digits=source:sub(at,at+count-1);at+=count
    if #digits~=count or not digits:match("^%x+$")then fail("Invalid character escape",start)end
   end
   return codepoint(tonumber(digits,16))
  end
  if c:match("%d")and c~="0"then fail("Legacy octal escape",start)end
  if c=="0"and source:sub(at,at):match("%d")then fail("Invalid zero escape",start)end
  return ESCAPES[c]or c
 end
 local scan,template
 local function rune(position)
  local first=source:byte(position)
  if not first then return nil,0 end
  if first<128 then return first,1 end
  local width=if first<224 then 2 elseif first<240 then 3 else 4
  local ok,code=pcall(utf8.codepoint,source,position)
  if not ok then fail('Invalid UTF-8 source',position)end
  return code,width
 end
 local function line(code)return code==10 or code==13 or code==0x2028 or code==0x2029 end
 local function space(code)return code==9 or code==11 or code==12 or code==32 or code==0xa0 or code==0xfeff or code==0x1680 or(code>=0x2000 and code<=0x200a)or code==0x202f or code==0x205f or code==0x3000 end
 local function regexp()
  local start=at;at+=1;local patternStart=at;local inClass=false;local closed=false
  while at<=#source do
   check()
   local cp,width=rune(at);if line(cp)then fail("Newline in regular expression",start)end
   local c=source:sub(at,at)
   if c=="\\"then at+=1;if at>#source then fail("Unclosed regular expression",start)end;local nextCode,nextWidth=rune(at);if line(nextCode)then fail("Newline in regular expression",start)end;at+=nextWidth
   elseif c=="/"and not inClass then closed=true;break
   else if c=="["then inClass=true elseif c=="]"then inClass=false end;at+=width end
  end
  if not closed then fail("Unclosed regular expression",start)end
  local pattern=source:sub(patternStart,at-1);at+=1;local flagsStart=at
  while at<=#source do check();local cp,width=rune(at);if not Identifier.part(cp)then break end;at+=width end
  if source:sub(at,at)=="\\"then fail("Escaped regular expression flags",at)end
  emit("regexp",{Pattern=pattern,Flags=source:sub(flagsStart,at-1)},start)
 end
 template=function()
  nesting+=1;assert(nesting<=96,"JavaScript syntax depth exceeded")
  local start=at;at+=1;emit("symbol","template-start",start)
  while true do
   local pieceStart=at;local raw,cooked={},{}
   while at<=#source do
    check()
    local c=source:sub(at,at)
    if c==string.char(96)or(c=="$"and source:sub(at+1,at+1)=="{")then break end
    local before=at
    if c=="\\"then table.insert(cooked,escape())
    else
     if c=="\r"then at+=1;if source:sub(at,at)=="\n"then at+=1 end;c="\n"else at+=1 end
     table.insert(cooked,c)
    end
    table.insert(raw,source:sub(before,at-1))
   end
   emit("template",Strings.fromUnits(Strings.units(table.concat(cooked))),pieceStart,{Raw=table.concat(raw)})
   if at>#source then fail("Unclosed template",start)end
   if source:sub(at,at)==string.char(96)then local last=at;at+=1;emit("symbol","template-end",last);break end
   local substitution=at;at+=2;emit("symbol","template-expression",substitution);scan(true)
  end
  nesting-=1
 end
 scan=function(substitution)
  local braces=0
  while at<=#source do
   check()
   local c,start=source:sub(at,at),at;local code,width=rune(at)
   if newline and c=="/"and not expressionAllowed then local previous,before=tokens[#tokens],tokens[#tokens-1];if previous and previous.Kind=="word"and before and(before.Value=="break"or before.Value=="continue")then expressionAllowed,statementStart=true,true end end
   if line(code)or space(code)then if line(code)then newline=true end;at+=width
   elseif source:sub(at,at+1)=="//"then at+=2;while at<=#source do check();local cp,size=rune(at);if line(cp)then break end;at+=size end
   elseif source:sub(at,at+1)=="/*"then
    local last=source:find("*/",at+2,true);if not last then fail("Unclosed comment")end
    local comment=source:sub(at,last+1);if comment:find("[\r\n]")or comment:find(utf8.char(0x2028),1,true)or comment:find(utf8.char(0x2029),1,true)then newline=true end;at=last+2
   elseif c=='"'or c=="'"then
    local quote,parts,escaped=c,{},false;at+=1
    while at<=#source and source:sub(at,at)~=quote do
     check()
     c=source:sub(at,at)
     if c=="\n"or c=="\r"then fail("Newline in string")end
     if c=="\\"then escaped=true;table.insert(parts,escape())else table.insert(parts,c);at+=1 end
    end
    if source:sub(at,at)~=quote then fail("Unclosed string",start)end
    at+=1;emit("literal",Strings.fromUnits(Strings.units(table.concat(parts))),start,{DirectiveEligible=not escaped})
   elseif c==string.char(96)then template()
   elseif c=="/"and expressionAllowed then regexp()
   elseif c:match("%d")or(c=="."and source:sub(at+1,at+1):match("%d"))then
    local tail=source:sub(at);local text,value
    if tail:match("^0[xX]")or tail:match("^0[bB]")or tail:match("^0[oO]")then
     local letter=tail:sub(2,2):lower();local base=if letter=="x"then 16 elseif letter=="b"then 2 else 8
     local pattern=if base==16 then "^0[xX]([%x_]+)"elseif base==2 then "^0[bB]([01_]+)"else "^0[oO]([0-7_]+)"
     local digits=tail:match(pattern);if not digits then fail("Invalid numeric literal")end
     text=tail:sub(1,#digits+2)
     if digits:sub(1,1)=="_"or digits:sub(-1)=="_"or digits:find("__",1,true)then fail("Invalid numeric separator")end
     value=tonumber((digits:gsub("_","")),base)
    else
     text=tail:match("^%d[%d_]*%.?[%d_]*[eE][+-]?%d[%d_]*")or tail:match("^%.[%d_]+[eE][+-]?%d[%d_]*")
      or tail:match("^%d[%d_]*%.?[%d_]*")or tail:match("^%.[%d_]+")
     if not text or text:find("__",1,true)or text:sub(-1)=="_"or text:find("_[%.eE]")or text:find("[%.eE]_")then fail("Invalid numeric literal")end
     value=tonumber((text:gsub("_","")))
    end
    if value==nil then fail("Invalid numeric literal",start)end
    at+=#text
    if source:sub(at,at)=="n"then
     local based=text:sub(1,2):lower()=="0x"or text:sub(1,2):lower()=="0b"or text:sub(1,2):lower()=="0o"
     if not based and(text:find("[%.eE]")or(#text>1 and text:sub(1,1)=="0"))then fail("Invalid BigInt literal",start)end
     at+=1;if source:sub(at,at):match("[%w_$]")then fail("Identifier immediately after BigInt")end
     emit("bigint",text,start);continue
    end
    if source:sub(at,at):match("[%w_$]")then fail("Identifier immediately after number")end
    emit("literal",value,start)
   elseif Identifier.start(code)or c=='\\'then
    local parts,escaped={},false;local first=true
    while at<=#source do
     check()
     local cp,size=rune(at);local text
     if source:sub(at,at)=='\\'then
      if source:sub(at+1,at+1)~='u'then fail('Identifier requires a Unicode escape')end
      text=escape();cp=utf8.codepoint(text);escaped=true
      if not(if first then Identifier.start(cp)else Identifier.part(cp))then fail('Invalid escaped identifier')end
     else
      if not(if first then Identifier.start(cp)else Identifier.part(cp))then break end
      text=source:sub(at,at+size-1);at+=size
     end
     table.insert(parts,text);first=false
    end
    emit('word',table.concat(parts),start,{Escaped=escaped})
   else
    if substitution and c=="}"and braces==0 then at+=1;emit("symbol","template-expression-end",start);return end
    if c=="{"then braces+=1 elseif c=="}"then braces-=1 end
    local op
    for _,candidate in OPERATORS do
     if source:sub(at,at+#candidate-1)==candidate and not(candidate=="?."and source:sub(at+2,at+2):match("%d"))then op=candidate;break end
    end
    op=op or c
    if not("(){}[].,;:+-*/%!?=<>&|^~#"):find(c,1,true)then fail("Unsupported token")end
    at+=#op;emit("symbol",op,start)
   end
  end
  if substitution then fail("Unclosed template substitution")end
 end
 scan(false);emit("end","<end>",at)
 return tokens
end
return Lexer
