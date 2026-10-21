--!strict
return function(Parser,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local output,diagnostics={},{}
		local runtime=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),{Events=Events.new(error),MaxSteps=200000,
			Console=function(_,value)table.insert(output,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
		local ok,message=runtime:Run('function record(v){console.log(String(v));}'..case.source)
		assert(ok,tostring(message));assert(#diagnostics==0,table.concat(diagnostics,' / '))
		assert(#output==#case.expected,case.name..': '..table.concat(output,' | '))
		for index,value in output do assert(value==case.expected[index],case.name..' ['..index..']: '..value..' ~= '..case.expected[index])end
		runtime:Destroy()
	end
	local diagnostics={};local events=Events.new(error)
	local runtime=Runtime.new(Parser.parseDocument('<!doctype html><div id="tile"></div>'),{Events=events,MaxSteps=200000,Diagnostic=function(value)table.insert(diagnostics,value)end})
	local ok,message=runtime:Run([=[
function check(v,m){if(!v)throw new Error(m);}
const tile=document.getElementById('tile');
const width=new CSSMathSum(CSS.px(24),CSS.percent(10));
tile.attributeStyleMap.set('width',width);
check(tile.style.width==='calc(24px + 10%)','Math writes share the declaration/cascade path');
let errors=0;try{tile.attributeStyleMap.set('width',new CSSMathProduct(CSS.px(1),CSS.px(2)));}catch(e){errors++;}
check(errors===1 && tile.style.width==='calc(24px + 10%)','Invalid dimensional writes are atomic');
check(width instanceof CSSMathValue && width instanceof CSSNumericValue && width instanceof CSSStyleValue,'Math inheritance');
check(width.values instanceof CSSNumericArray && width.values[0].value===24,'Readonly numeric array indices/brand');
let readonly=0;try{width.values[0]=CSS.px(99);}catch(e){readonly++;}
check(width.values[0].value===24,'Readonly math members preserve source identity');
check(Reflect.set(width.values,'2',CSS.px(1))===false && width.values.length===2,'A readonly numeric array has no indexed setter');
check(Reflect.defineProperty(width.values,'0',{value:CSS.px(1)})===false && Reflect.deleteProperty(width.values,'0')===false,'Getter-only indexed define/delete invariants');
check(Reflect.preventExtensions(width.values)===false,'Indexed platform objects remain extensible');
width.values.note='kept';check(Object.keys(width.values).join(',')==='0,1,note' && width.values[0].value===24,'Numeric indices and ordinary expandos');
const child=CSS.px(4),parent=new CSSMathSum(child,CSS.px(8));child.value=7;
check(parent.to('px').value===15,'Child value mutation is live');
check(String(parent.toSum())==='calc(15px)' && parent.toSum('cm').values[0].unit==='cm','Sum conversion');
try{width.to('px');}catch(e){errors++;}
check(errors===2,'No invented percentage basis');
const hinted=new CSSMathSum(CSS.px(2),CSS.percent(5));
const product=new CSSMathProduct(hinted,CSS.percent(10));
check(product.type().length===2 && !product.type().percent && product.type().percentHint==='length','Product propagates percent hints before combining dimensions');
let hintError=false;try{new CSSMathSum(hinted,new CSSMathSum(CSS.s(1),CSS.percent(2)));}catch(e){hintError=e.name==='TypeError';}
check(hintError,'Conflicting percent hints cannot be added');
hintError=false;try{new CSSMathProduct(hinted,new CSSMathSum(CSS.s(1),CSS.percent(2)));}catch(e){hintError=e.name==='TypeError';}
check(hintError,'Conflicting percent hints cannot be multiplied');
check(CSS.px(1).equals(CSS.px(1.00000000000001))===false,'Equality must not use a loose numerical tolerance');
const fallback=new CSSUnparsedValue(['12px']);const ref=new CSSVariableReferenceValue('--x',fallback);
const tokens=new CSSUnparsedValue(['calc(',ref,' + 3px)']);
check(tokens instanceof CSSUnparsedValue && tokens instanceof CSSStyleValue,'Unparsed inheritance');
check(tokens.length===3 && tokens[1]===ref && [...tokens].length===3,'Token indices and iteration');
check(String(tokens)==='calc(var(--x,12px) + 3px)','Variable fallback serialization');
tokens[3]=' ';check(tokens.length===4 && [...tokens.keys()].join(',')==='0,1,2,3','Append at length');
tokens.note='kept';check(Object.keys(tokens).join(',')==='0,1,2,3,note','Ordered expando and segment keys');
check(Reflect.set(tokens,'length',9)===false && tokens.length===4,'Inherited readonly length');
check(Reflect.deleteProperty(tokens,'0')===false && Reflect.deleteProperty(tokens,'note')===true,'No indexed deleter');
check(Reflect.defineProperty(tokens,'1',{value:ref})===true && tokens[1]===ref,'Indexed descriptor setter');
const saved=tokens[0];check(Reflect.defineProperty(tokens,'0',{value:saved,writable:false})===true && Object.getOwnPropertyDescriptor(tokens,'0').writable===true && Reflect.preventExtensions(tokens)===false,'Indexed setter ignores ordinary descriptor flags');
const base=Object.getPrototypeOf(tokens);check(Object.setPrototypeOf(tokens,base)===tokens,'Prototype preservation');
check(String(new CSSUnparsedValue(['\ud800','\ud83d\ude00']))==='\ufffd\ud83d\ude00','USVString surrogate conversion');
try{tokens[6]='?';}catch(e){check(e.name==='RangeError','Index error');errors++;}
try{ref.variable='bad';}catch(e){check(e.name==='TypeError','Variable error');errors++;}
tile.attributeStyleMap.set('--width',tokens);check(tile.attributeStyleMap.get('--width') instanceof CSSUnparsedValue,'Live custom map reification');
const parsed=CSSStyleValue.parse('--nested','calc(var(--x, var(--y, 2px)) + 1px)');
check(parsed.length===3 && parsed[1] instanceof CSSVariableReferenceValue && parsed[1].fallback[1].variable==='--y','Nested raw references');
check(String(parsed)==='calc(var(--x, var(--y, 2px)) + 1px)','Nested reification roundtrip');
const quoted=CSSStyleValue.parse('--literal','"var(--ignored)" /*var(--ignored)*/ var(--live)');
check(quoted.length===2 && quoted[1].variable==='--live','Quoted/comment var strings stay literal');
check(CSSStyleValue.parse('width','VAR(--x)') instanceof CSSUnparsedValue,'Case insensitive var function');
const cyclic=new CSSUnparsedValue(['']);cyclic[0]=new CSSVariableReferenceValue('--cycle',cyclic);
try{String(cyclic);}catch(e){check(e.name==='TypeError','Cycle error');errors++;}
check(errors===5,'Expected grammar/typing/cycle failures');
]=])
	assert(ok,tostring(message));assert(#diagnostics==0,table.concat(diagnostics,' / '))
	runtime:Destroy();events:Destroy()
	print('Typed math/tokens: '..#fixture.cases..' native Chromium fixtures, brands, dimensions, live children/maps, atomic writes, conversions, indexed arrays, nested variables and bounded cycles passed')
end
