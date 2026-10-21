--!strict
-- Dynamic source uses the same bounded parser/interpreter and never Luau code.
local Syntax=require(script.Parent.Syntax)
local DynamicCode={}
function DynamicCode.install(vm: any,globals: any,options: any): any
 local VM=vm.Model;local U=VM.Undefined;local api={Alive=true}
 local function fail(message)VM.throw(VM.error('SyntaxError',tostring(message)))end
 local function parse(source,settings)
  local ok,ast=pcall(Syntax.parse,source,settings);if not ok then fail(ast)end;return ast
 end
 local function define(target,key,value,writable,configurable)
  vm.DefineProperty(target,key,vm.Object({value=value,writable=writable,enumerable=false,configurable=configurable},VM.Null))
 end
 function api:Eval(source,scope)
  assert(self.Alive,'Dynamic JavaScript disposed')
  if type(source)~='string'then return source end
  return options.Eval(source,scope)
 end
 local eval={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,
  Call=function(args)return api:Eval(if args[1]==nil then U else args[1])end}
 define(eval,'length',1,false,true);define(eval,'name','eval',false,true);api.EvalFunction=eval
 globals.eval=eval;vm.Global.Bindings.eval={Value=eval}
 local function oneFunction(source)
  local ast=parse(source)
  if #ast.Items~=1 or ast.Items[1].Kind~='function-declaration'then fail('Invalid dynamic function source')end
  return ast.Items[1].Value
 end
 for _,kind in {'Function','AsyncFunction','GeneratorFunction','AsyncGeneratorFunction'}do
  local async=kind=='AsyncFunction'or kind=='AsyncGeneratorFunction'
  local generator=kind=='GeneratorFunction'or kind=='AsyncGeneratorFunction'
  local prefix=(if async then 'async 'else '')..'function'..(if generator then '*'else '')..' anonymous('
  local proto=vm.Prototypes[kind]
  if not proto then proto=vm.Object({},vm.Prototypes.Function);vm.Prototypes[kind]=proto end
  local constructor
  local function create(args,newTarget)
   assert(api.Alive,'Dynamic JavaScript disposed')
   local parameters={};for i=1,#args-1 do table.insert(parameters,VM.string(vm.ToPrimitive(args[i],'string')))end
   local body=if #args==0 then ''else VM.string(vm.ToPrimitive(args[#args],'string'))
   local params=table.concat(parameters,',')
   -- Separate parses reject delimiter/comment injection across the two
   -- source components before the combined function is interpreted.
   oneFunction(prefix..params..'\n){}')
   oneFunction(prefix..'\n){\n'..body..'\n}')
   local source=prefix..params..'\n) {\n'..body..'\n}'
   local ast=oneFunction(source);ast.SourceText=source
   local value=options.Evaluate(ast,vm.Global)
   local targetProto=vm.Get(newTarget or constructor,'prototype')
   value.Prototype=if vm.ObjectModel.IsObject(targetProto)then targetProto else proto
   return value
  end
  constructor={Kind='native-function',Values={},Prototype=if kind=='Function'then vm.Prototypes.Function else globals.Function,
   Call=function(args)return create(args)end,Construct=create}
  define(constructor,'length',1,false,true);define(constructor,'name',kind,false,true);define(constructor,'prototype',proto,false,false)
  define(proto,'constructor',constructor,kind=='Function',true)
  if kind~='Function'and vm.SymbolToStringTag then define(proto,vm.SymbolToStringTag,kind,false,true)end
  if kind=='Function'then globals.Function=constructor;vm.Global.Bindings.Function={Value=constructor}end
 end
 local tostringFunction={Kind='native-function',Values={},Prototype=vm.Prototypes.Function,Call=function(_,receiver)
  if not VM.callable(receiver)then VM.throw(VM.error('TypeError','Function.toString receiver is not callable'))end
  return if type(receiver)=='table'and receiver.SourceText then receiver.SourceText else 'function () { [native code] }'
 end}
 define(tostringFunction,'length',0,false,true);define(tostringFunction,'name','toString',false,true)
 define(vm.Prototypes.Function,'toString',tostringFunction,true,true)
 function api:Destroy()self.Alive=false;table.clear(options)end
 return api
end
return DynamicCode
