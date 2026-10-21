const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
let retired;
function retiredAuthored(){
 if(retired)return retired;
 retired=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/retired-authored-darknet-20261019.json'),'utf8'));
 const hash=source=>require('node:crypto').createHash('sha256').update(source).digest('hex');
 for(const[file,expected]of Object.entries(retired.hashes)){
  const source=file.startsWith('examples/websites/')?retired.browserFiles[file.slice('examples/websites/'.length)]:(()=>{const parts=file.split('/');return retired.modules[parts[3]][path.basename(parts[4],'.luau')];})();
  assert.equal(hash(source),expected,'Retired authored source '+file);
 }
 return retired;
}
function factorySource(name,snapshot){
 assert(/^[A-Za-z][A-Za-z0-9_]*$/.test(name));
 const folder=path.join(root,'src/HTMLEngine/Websites',name);
 const read=child=>snapshot?snapshot[name][child]:fs.readFileSync(path.join(folder,child+'.luau'),'utf8');
 const children=['HTML','CSS','JavaScript'].filter(child=>snapshot?Object.hasOwn(snapshot[name],child):fs.existsSync(path.join(folder,child+'.luau')));
 return '(function()\nlocal script={'+children.map(child=>child+'="'+child+'"').join(',')+'}\nlocal function require(token)\n'+children.map((child,i)=>(i?'elseif':'if')+' token=="'+child+'"then return(function()\n'+read(child)+'\nend)()\n').join('')+'else error("Unexpected website dependency "..tostring(token))end\nend\n'+read('init')+'\nend)()';
}
function websiteTable(catalog,snapshot){return '{'+catalog.Modules.map(page=>'{Route='+JSON.stringify(page.sourcePath)+',Name='+JSON.stringify(page.name)+',Website='+factorySource(page.name,snapshot)+',Probe='+JSON.stringify(page.interaction?.probe||'')+'}').join(',')+'}';}
module.exports={factorySource,websiteTable,retiredAuthored};
