const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),zlib=require('node:zlib'),crypto=require('node:crypto'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),args={};
for(let index=2;index<process.argv.length;index+=2){assert.ok(process.argv[index].startsWith('--')&&process.argv[index+1],'Expected --option value');args[process.argv[index].slice(2)]=process.argv[index+1];}
const directory=path.resolve(args.assets||path.join(root,'src/HTMLEngine/Websites/Assets'));
const manifestPath=path.resolve(args.manifest||path.join(root,'build/wiki1-port-20261019/image-pack.json'));
const manifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
const output=path.resolve(args.output||path.dirname(manifestPath));fs.mkdirSync(output,{recursive:true});
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
let tiles=0;
const uniqueTiles=new Set();
for(const image of manifest.records){
 const source=Buffer.alloc(image.width*image.height*4);
 for(const tile of image.tiles){
  const module=fs.readFileSync(path.join(directory,'Pixels',tile.name+'.luau'),'utf8');
  const chunks=[...module.matchAll(/^\s*"([A-Za-z0-9+/=]*)",$/gm)].map(x=>x[1]);
  assert.ok(chunks.length);assert.ok(chunks.every(x=>x.length<=60000));
  const decoded=zlib.zstdDecompressSync(Buffer.from(chunks.join(''),'base64'));
  assert.equal(decoded.length,tile.width*tile.height*4);
  assert.ok(tile.width<=1024&&tile.height<=1024);
  assert.equal(hash(decoded),tile.sha256);
  for(let row=0;row<tile.coreH;row++)decoded.copy(source,((tile.y+row)*image.width+tile.x)*4,((tile.y-tile.top+row)*tile.width+tile.x-tile.left)*4,((tile.y-tile.top+row)*tile.width+tile.x-tile.left+tile.coreW)*4);
  tiles++;
  uniqueTiles.add(tile.name);
 }
 assert.equal(hash(source),image.rgbaSHA256,'Tiled image reconstructs the exact original decoded samples');
}
assert.equal(tiles,manifest.tiles);
if(manifest.uniqueTiles!==undefined)assert.equal(uniqueTiles.size,manifest.uniqueTiles);
const pngArgs=[path.join(__dirname,'verify-wttg2-pngs.py'),'--manifest',manifestPath];
if(args.archive)pngArgs.push('--archive',path.resolve(args.archive),'--registry',path.resolve(args.registry));
else pngArgs.push('--browser-root',path.resolve(args['browser-root']||path.join(root,'examples/websites')));
const pngProof=JSON.parse(cp.execFileSync(args.python||'C:/Python310/python.exe',pngArgs,{encoding:'utf8',windowsHide:true,maxBuffer:4*1024*1024}));
fs.writeFileSync(path.join(output,'independent-png-proof.json'),JSON.stringify(pngProof,null,2)+'\n');
const decoder=fs.readFileSync(path.join(directory,'PixelDecoder.luau'),'utf8');
const harness=`local Decoder=(function()\n${decoder}\nend)()\n
local calls={}
local service={Base64Decode=function(_,v)table.insert(calls,'base64');assert(buffer.tostring(v)=='AA==');return buffer.fromstring('compressed')end,
GetDecompressedBufferSize=function(_,v,a)table.insert(calls,'size');assert(buffer.tostring(v)=='compressed' and a=='zstd');return 16 end,
DecompressBuffer=function(_,v,a)table.insert(calls,'decode');assert(a=='zstd');return buffer.create(16)end}
local packed={Width=2,Height=2,Bytes=16,Data={'AA=='}}
assert(buffer.len(Decoder.decode(packed,service,'zstd'))==16)
assert(table.concat(calls,',')=='base64,size,decode')
local function rejects(value,expected)
local ok,err=pcall(Decoder.decode,value,service,'zstd');assert(not ok and tostring(err):find(expected,1,true),tostring(err))end
rejects({Width=1025,Height=1,Bytes=4100,Data={'AA=='}},'width')
rejects({Width=2,Height=2,Bytes=15,Data={'AA=='}},'byte length')
rejects({Width=2,Height=2,Bytes=16,Data={string.rep('A',60001)}},'chunk')
service.GetDecompressedBufferSize=function()return 17 end
rejects(packed,'decompressed size mismatch')
service.GetDecompressedBufferSize=function()return 16 end
service.DecompressBuffer=function()return buffer.create(12)end
rejects(packed,'output size mismatch')
print('PixelDecoder validates actual dimensions, byte budgets and decompressor output')\n`;
const target=path.join(output,'test-pixel-decoder.luau');fs.writeFileSync(target,harness);
cp.execFileSync(path.join(root,'build/tools/luau/luau.exe'),[target],{stdio:'inherit'});
const catalogSource=fs.readFileSync(path.join(directory,'ImageCatalog.luau'),'utf8');
const catalogBody=catalogSource.replace('local Manifest = require(script.Parent.ImageManifest)','local Manifest = fixtureManifest').replace('local Decoder = require(script.Parent.PixelDecoder)','local Decoder = fixtureDecoder');
assert.notEqual(catalogBody,catalogSource,'ImageCatalog dependency fixture was applied');
const catalogHarness=`local decoded, requires = 0, 0
local function image(path)
 return {Path=path,Width=2,Height=2,Tiles={{Name='tile',X=0,Y=0,Width=2,Height=2,Left=0,Top=0,PixelWidth=2,PixelHeight=2}}}
end
local fixtureManifest={image('/a/photo.png'),image('/b/photo.png'),image('/shared.png'),image('/a/deep/item.png')}
local fixtureDecoder={decode=function(packed) decoded+=1; assert(packed.Width==2); return buffer.create(16) end}
local script={Parent={Pixels={tile='tile'}}}
local function require(name) requires+=1; assert(name=='tile'); return {Width=2,Height=2} end
local Catalog=(function()\n${catalogBody}\nend)()
local sources=Catalog.forPage('http://localhost:8000/a/deep/index.html')
assert(sources['/a/photo.png'] and sources['../photo.png']==sources['/a/photo.png'])
assert(sources['item.png']==sources['/a/deep/item.png'])
assert(sources['../../shared.png']==sources['/shared.png'])
assert(sources['http://localhost:8000/a/photo.png']==sources['/a/photo.png'])
assert(not sources['/b/photo.png'],'Another site cannot collide with its photo basename')
assert(decoded==0 and requires==0,'Catalog construction must not load or decompress pixel modules')
local pixel=sources['../photo.png'].ResolveImage('pixels/tile')
assert(pixel.Width==2 and buffer.len(pixel.Pixels)==16 and decoded==1 and requires==1)
assert(sources['item.png'].ResolveImage('pixels/tile')==pixel and decoded==1,'Identical packed tiles share a live decoded resource')
assert(sources['item.png'].ResolveImage('untrusted/tile')==nil and decoded==1)
local shared=Catalog.forPage('http://localhost:8000/a/deep/index.html',{'http://localhost:8000/b/photo.png?version=1'})
assert(shared['/b/photo.png'] and shared['../../b/photo.png']==shared['/b/photo.png'])
assert(not shared['/a/photo.png'] and not shared['/shared.png'],'Explicit dependency closure stays private')
assert(next(Catalog.forPage('http://localhost:8000/a/index.html',{}))==nil)
print('ImageCatalog scopes resources to each document, resolves nested/shared aliases, and lazily reuses pixel tiles')
`;
const catalogTarget=path.join(output,'test-image-catalog.luau');fs.writeFileSync(catalogTarget,catalogHarness);
cp.execFileSync(path.join(root,'build/tools/luau/luau.exe'),[catalogTarget],{stdio:'inherit'});
const result={images:manifest.images,tiles,uniqueTiles:uniqueTiles.size,independentPNGCount:pngProof.independentPNGCount,allTilesReconstructed:true,catalogScopedAndLazy:true,nativeEncodingServiceObserved:false};
fs.writeFileSync(path.join(output,'image-validation.json'),JSON.stringify(result,null,2)+'\n');
console.log(`${manifest.images} original images / ${tiles} tiles reconstructed losslessly; ${pngProof.independentPNGCount} PNGs independently verified; native EncodingService execution remains a Studio check.`);
