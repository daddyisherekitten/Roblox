--!strict
return function(Parser,Runtime,Events,fixture)
	for _,case in fixture.cases do
		local output,diagnostics={},{};local events=Events.new(error)
		local runtime=Runtime.new(Parser.parseDocument('<!doctype html><body></body>'),{Events=events,MaxSteps=300000,
			Console=function(_,value)table.insert(output,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
		local ok,message=runtime:Run('function record(v){console.log(String(v));}'..case.source)
		assert(ok,tostring(message));assert(#diagnostics==0,table.concat(diagnostics,' / '))
		assert(#output==#case.expected,case.name..': '..table.concat(output,' | '))
		for i,value in output do assert(value==case.expected[i],case.name..' ['..i..']: '..value..' ~= '..case.expected[i])end
		runtime:Destroy();events:Destroy()
	end
	local events=Events.new(error);local runtime=Runtime.new(Parser.parseDocument('<!doctype html><div id="tile"></div>'),{Events=events,MaxSteps=300000})
	local ok,message=runtime:Run([=[
function check(v,m){if(!v)throw new Error(m);}
const tile=document.getElementById('tile'),move=new CSSTranslate(CSS.px(10),CSS.px(20));
const transform=new CSSTransformValue([move,new CSSScale(2,3)]);
tile.attributeStyleMap.set('transform',transform);
check(tile.style.transform==='translate(10px, 20px) scale(2, 3)','Typed transform commits the real declaration');
const reread=tile.attributeStyleMap.get('transform');
check(reread instanceof CSSTransformValue && reread[0] instanceof CSSTranslate && reread[1] instanceof CSSScale,'Live transform reification');
move.x.value=30;check(transform.toMatrix().e===30 && tile.style.transform.includes('10px'),'Children stay live; a declaration is a serialized snapshot');
tile.attributeStyleMap.set('transform',transform);check(tile.style.transform.includes('30px'),'Explicit recommit shares the normal mutation path');
let errorCount=0;try{move.x=CSS.s(1);}catch(e){errorCount++;}check(move.x.value===30,'Invalid member writes are atomic');
try{transform[5]=move;}catch(e){check(e.name==='RangeError','Index range error');errorCount++;}
transform[2]=new CSSRotate(CSS.deg(90));check(transform.length===3 && [...transform.keys()].join(',')==='0,1,2','Append at length and live iterators');
check(transform instanceof CSSStyleValue && move instanceof CSSTransformComponent && !(move instanceof CSSStyleValue),'Correct interface inheritance');
check(Object.getPrototypeOf(CSSMathSum)===CSSMathValue && Object.getPrototypeOf(CSSTranslate)===CSSTransformComponent && typeof CSSUnitValue.parse==='function','Interface constructor inheritance');
check(Reflect.deleteProperty(transform,'0')===false && Reflect.preventExtensions(transform)===false,'Platform collection invariants');
check(CSSStyleValue.parse('transform','translate(0) rotate(0) scale(50%)').toString()==='translate(0px, 0px) rotate(0deg) scale(0.5, 0.5)','Zero unit defaults and scale percentages');
const p=new CSSPerspective(CSS.px(500));check(p.toMatrix().m34===-0.002 && !p.toMatrix().is2D,'Perspective carries its normative 3D dimension flag');
const t3=new CSSTranslate(CSS.px(0),CSS.px(0),CSS.px(0));check(!t3.toMatrix().is2D,'A zero Z value still represents an explicitly 3D component');
t3.is2D=true;t3.z=CSS.em(2);check(t3.toMatrix().is2D && t3.toMatrix().m43===0,'Ignored Z needs no contextual conversion');
const matrix=new CSSMatrixComponent(new DOMMatrix([1,2,3,4,5,6]));const held=matrix.matrix;matrix.matrix=held;check(matrix.matrix===held,'Matrix setter retains the mutable object');
const getter=Object.getOwnPropertyDescriptor(CSSUnitValue.prototype,'value').get;
try{getter.call(new CSSKeywordValue('auto'));}catch(e){check(e.name==='TypeError','Unit getter brand');errorCount++;}
check(errorCount===3,'Expected typed transform/brand failures');
const savedMatrix=DOMMatrix,savedTranslate=CSSTranslate;
const saved11=Object.getOwnPropertyDescriptor(DOMMatrixReadOnly.prototype,'m11');
Object.defineProperty(DOMMatrixReadOnly.prototype,'m11',{get(){return 999;},configurable:true});
DOMMatrix=function(){throw new Error('Author constructor called');};
CSSTranslate=function(){throw new Error('Author constructor called');};
check(matrix.toMatrix().a===1,'Matrix conversion reads native slots through intrinsic getters');
check(CSSStyleValue.parse('transform','translate(2px)').toMatrix().e===2,'Parsing uses intrinsic constructors');
DOMMatrix=savedMatrix;CSSTranslate=savedTranslate;Object.defineProperty(DOMMatrixReadOnly.prototype,'m11',saved11);
]=]);assert(ok,tostring(message));runtime:Destroy();events:Destroy()
	print('Typed transforms/numeric parse: '..#fixture.cases..' native fixtures, retained children, matrices, dimensions, indexed mutation, atomic live maps, reification and cleanup passed')
end
