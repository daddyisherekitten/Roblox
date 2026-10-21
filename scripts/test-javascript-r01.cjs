// Deterministic ECMAScript core and binary64 radix references. Native Node is
// uncontextified here so its global object's descriptors match ordinary globals.
const fs=require('node:fs');
const path=require('node:path');
const cp=require('node:child_process');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const radixFile=path.join(root,'tests/fixtures/javascript-r01-radix.json');
const referenceFile=path.join(root,'tests/fixtures/javascript-r01-reference.json');
const edge=[0,-0,NaN,Infinity,-Infinity,Number.MIN_VALUE,-Number.MIN_VALUE,Number.MAX_VALUE,-Number.MAX_VALUE,
  2**-1022,2**-52,2**53-1,2**53,2**53+2,1e-300,1e-100,1e20,1e100,0.1,0.2,0.3,0.5,0.9,1/3,2/3,
  0.9999999999999999,1.0000000000000002,123.456789,-31.75];
let seed=0x6e624eb7;
function next(){seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return seed>>>0;}
for(let i=0;i<32;i++){
 const bytes=Buffer.alloc(8);bytes.writeUInt32LE(next(),0);bytes.writeUInt32LE(next(),4);
 const value=bytes.readDoubleLE();if(Number.isFinite(value))edge.push(value);
}
const fixtures=edge.map((value,index)=>{
 const sourceValue=Object.is(value,-0)?'-0':String(value);
 const radices=Array.from({length:35},(_,i)=>i+2);
 return {name:`binary64 radix corpus ${index}: ${sourceValue}`,source:`const n=${sourceValue};for(const r of [${radices.join(',')}])record(n.toString(r));`,expected:radices.map(r=>value.toString(r))};
});
if(process.argv.includes('--update-reference')){
 fs.writeFileSync(radixFile,JSON.stringify(fixtures,null,2)+'\n');
 fs.writeFileSync(referenceFile,JSON.stringify({schema:'javascript-r01-reference/v1',recorded:'2026-10-04',node:process.version,v8:process.versions.v8,
  radixCases:fixtures.length*35,globalContext:'vm.constants.DONT_CONTEXTIFY',seed:'0x6e624eb7',
  standards:['https://tc39.es/ecma262/multipage/ecmascript-language-functions-and-classes.html','https://tc39.es/ecma262/multipage/ecmascript-language-scripts-and-modules.html','https://tc39.es/ecma262/multipage/numbers-and-dates.html'],
  deviations:['Node vm reports SyntaxError for a restricted existing global function declaration; ECMA-262 specifies TypeError.',
   'Chromium 154 / Node 24 V8 reads generic TypedArray input length or iterator values before newTarget.prototype; current ECMA-262 allocates the object before examining object input. The engine follows that confirmed browser profile.']},null,2)+'\n');
}else assert.deepEqual(JSON.parse(fs.readFileSync(radixFile,'utf8')),fixtures,'Native radix results changed; inspect the recorded reference before updating it.');
for(const file of ['javascript-r01-core.json','javascript-r01-radix.json']){
 const result=cp.spawnSync(process.execPath,[path.join(root,'scripts/test-javascript-language.cjs'),`--fixtures=${file}`,'--global-object'],{stdio:'inherit'});
 if(result.error)throw result.error;if(result.status)process.exit(result.status);
}
console.log(`R01: core object/environment cases and ${fixtures.length*35} native binary64 radix comparisons passed.`);
