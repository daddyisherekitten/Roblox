// Rebuild the reviewed complete game collection into staging by default.
// The input archive is opened read-only; no game code is executed or patched.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),cp=require('node:child_process'),crypto=require('node:crypto');
const {publish}=require('./wttg2-site-publisher.cjs');
const {pack}=require('./pack-wttg2-images.cjs');
const root=path.resolve(__dirname,'..');
function registryOf(archivePath){
 const fd=fs.openSync(archivePath,'r');let at=0;
 function read(length){assert.ok(Number.isSafeInteger(length)&&length>=0&&length<=1024*1024);const value=Buffer.alloc(length);assert.equal(fs.readSync(fd,value,0,length,at),length);at+=length;return value;}
 function string(){let length=0;for(let shift=0;shift<35;shift+=7){const byte=read(1)[0];length+=(byte&127)*2**shift;if(!(byte&128))return read(length).toString('utf8');}throw Error('Invalid archive string');}
 try{
  assert.equal(string(),'zfbRes_v1');const count=read(4).readInt32LE();assert.ok(count>0&&count<=100000);
  const registry=Array.from({length:count},()=>({Path:string(),Offset:Number(read(8).readBigInt64LE()),Length:read(4).readInt32LE()}));
  const size=fs.fstatSync(fd).size;let end=at;
  for(const entry of [...registry].sort((a,b)=>a.Offset-b.Offset)){
   assert.ok(entry.Path.startsWith('/')&&!entry.Path.includes('\\')&&!entry.Path.split('/').includes('..'));
   assert.ok(Number.isSafeInteger(entry.Offset)&&entry.Offset===end&&entry.Length>=0&&entry.Offset+entry.Length<=size);end+=entry.Length;
  }
  assert.equal(end,size);assert.equal(new Set(registry.map(x=>x.Path)).size,count);
  const hash=crypto.createHash('sha256'),chunk=Buffer.alloc(1024*1024);
  for(let offset=0;offset<size;){const n=fs.readSync(fd,chunk,0,Math.min(chunk.length,size-offset),offset);assert.ok(n>0);hash.update(chunk.subarray(0,n));offset+=n;}
  const sha256=hash.digest('hex');
  assert.equal(sha256,'73a2f9896ca9c058b81e46cdda33ceae9338437a2e889b9e943da2485ff3ab3e','Selection metadata belongs to a different game build; review before importing');
  return {Registry:registry,SourceSHA256:sha256,SourceLength:size};
 }finally{fs.closeSync(fd);}
}
function run(gameDirectory,options={}){
 const archivePath=path.join(path.resolve(gameDirectory),'WTTG2_Data/Resources/browser_assets');
 const selectedPath=path.resolve(options.selectedPath||path.join(root,'scripts/data/wttg2-full-selection.json'));
 const selected=JSON.parse(fs.readFileSync(selectedPath,'utf8')),full=Array.isArray(selected.documents);
 if(full)assert.equal(selected.resourcePolicy.status,'reviewed','Full collection content review must be complete');
 const registry=registryOf(archivePath),build=path.resolve(options.outputRoot||path.join(root,full?'build/wttg2-full-20261019/rebuild':'build/wiki1-port-20261019/rebuild'));fs.mkdirSync(build,{recursive:true});
 const registryPath=path.join(build,'import-registry.json'),decoded=path.join(build,'decoded'),sourcePathsPath=path.join(build,'selected-image-paths.json');
 fs.writeFileSync(registryPath,JSON.stringify(registry,null,2)+'\n');
 const decodeArgs=['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'decode-wttg2-images.ps1'),'-ArchivePath',archivePath,'-RegistryPath',registryPath,'-OutputDirectory',decoded];
 if(full){fs.writeFileSync(sourcePathsPath,JSON.stringify(selected.resourcePolicy.allowedImagePaths,null,2)+'\n');decodeArgs.push('-SourcePathsPath',sourcePathsPath);}else decodeArgs.push('-SelectedPath',selectedPath);
 cp.execFileSync('powershell',decodeArgs,{stdio:'inherit',windowsHide:true});
 const modulesRoot=path.join(build,'stage-modules'),browserRoot=path.join(build,'stage-websites');
 const pixels=pack(decoded,path.join(modulesRoot,'Assets'),{proofPath:path.join(build,'image-pack.json')});
 const pages=publish({workspace:root,registry:registry.Registry,archivePath,selectedPath,browserRoot,modulesRoot,buildRoot:build,catalogPath:path.join(build,'staged-catalog.json')});
 const result={realSites:pages.realCount,htmlRoutes:pages.htmlCount,images:pixels.images,sourceReadOnly:true,outputRoot:build,catalogPath:path.join(build,'staged-catalog.json')};
 console.log(JSON.stringify(result));return result;
}
if(require.main===module){assert.ok(process.argv[2],'Usage: node scripts/import-wttg2-wiki.cjs "C:/.../Welcome to the Game II" [--output PATH] [--selected PATH]');const args={};for(let i=3;i<process.argv.length;i+=2){assert.ok(process.argv[i].startsWith('--')&&process.argv[i+1]);args[process.argv[i].slice(2)]=process.argv[i+1];}run(process.argv[2],{outputRoot:args.output,selectedPath:args.selected});}
module.exports={registryOf,run};
