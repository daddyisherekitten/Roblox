// Real published page modules and shared script sources; native pixels are a seam.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
function websiteTable(catalog,names){
 const selected=catalog.Modules.filter(page=>!names||names.includes(page.name));
 if(names)assert.equal(selected.length,names.length);
 const assets=fs.readFileSync(path.join(root,'src/HTMLEngine/Websites/Assets/HostScripts.luau'),'utf8');
 const pages=selected.map(page=>{
  const folder=path.join(root,'src/HTMLEngine/Websites',page.name),read=child=>fs.readFileSync(path.join(folder,child+'.luau'),'utf8');
  const factory='(function()\nlocal script={HTML="HTML",CSS="CSS",Parent={Assets={ImageCatalog="ImageCatalog",HostScripts="HostScripts"}}}\nlocal function require(token)\nif token=="HostScripts"then return sharedScripts elseif token=="ImageCatalog"then return{forPage=function()return{}end}elseif token=="HTML"then return(function()\n'+read('HTML')+'\nend)()elseif token=="CSS"then return(function()\n'+read('CSS')+'\nend)()else error("Unexpected original website dependency "..tostring(token))end\nend\n'+read('init')+'\nend)()';
  return'{Route='+JSON.stringify(page.sourcePath)+',Name='+JSON.stringify(page.name)+',Website='+factory+'}';
 });
 return'(function()\nlocal sharedScripts=(function()\n'+assets+'\nend)()\nreturn{'+pages.join(',')+'}\nend)()';
}
module.exports={websiteTable};
