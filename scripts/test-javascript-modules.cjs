// Native source-text modules and the HTML engine execute the same module graphs.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
if(!vm.SourceTextModule){const result=cp.spawnSync(process.execPath,['--experimental-vm-modules',__filename,...process.argv.slice(2)],{stdio:'inherit'});process.exit(result.status??1)}
(async()=>{
 const fixtures=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/javascript-modules.json'),'utf8'));
 for(const fixture of fixtures){
  const output=[],cache=new Map();
  const context=vm.createContext({console:{log:(...args)=>output.push(args.map(String).join(' '))},setTimeout,clearTimeout,queueMicrotask,URL});
  const resolve=(specifier,base)=>new URL(specifier,base).href;
  const load=href=>{
   if(cache.has(href))return cache.get(href);
   if(!(href in fixture.sources))throw new TypeError('Missing module source '+href);
   const module=new vm.SourceTextModule(fixture.sources[href],{context,identifier:href,
    initializeImportMeta:meta=>{meta.url=href;meta.resolve=specifier=>resolve(specifier,href)},
    importModuleDynamically:async(specifier,referrer)=>{const target=load(resolve(specifier,referrer.identifier));if(target.status==='unlinked')await target.link(linker);if(target.status==='linked')await target.evaluate();return target},
   });cache.set(href,module);return module;
  };
  const linker=(specifier,referrer)=>load(resolve(specifier,referrer.identifier));
  try{const main=load('https://modules.test/main.js');await main.link(linker);await main.evaluate()}catch(error){output.push('error:'+error.name)}
  assert.deepEqual(output,fixture.expected,'Native module: '+fixture.name);
 }
 console.log('Native source-text modules: '+fixtures.length+' shared graphs passed.');
 if(!process.argv.includes('--native-only')){const result=cp.spawnSync(process.execPath,[path.join(root,'scripts/run-html-tests.cjs'),'JavaScriptModules'],{stdio:'inherit'});process.exitCode=result.status??1}
})().catch(error=>{console.error(error);process.exitCode=1});
