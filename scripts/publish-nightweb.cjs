'use strict';
// Publish authored browser files as independent HTML-engine website modules.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),browserRoot=path.join(root,'examples/websites'),modulesRoot=path.join(root,'src/HTMLEngine/Websites');
const dataPath=path.join(root,'scripts/data/nightweb-sites.json'),catalogPath=path.join(root,'scripts/data/nightweb-catalog.json');
const origin='http://localhost:8000',hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const quote=value=>'"'+String(value).replace(/["\\\x00-\x1f\x7f]/g,c=>c==='"'||c==='\\'?'\\'+c:'\\'+c.charCodeAt(0).toString().padStart(3,'0'))+'"';
function literal(text){let equals='==';while(text.includes(']'+equals+']'))equals+='=';return '['+equals+'[\n'+text+']'+equals+']';}
function inside(base,relative){const target=path.resolve(base,relative);assert(target.startsWith(base+path.sep),'Path escaped '+base);return target;}
function files(base){return fs.readdirSync(base,{withFileTypes:true}).flatMap(item=>item.isDirectory()?files(path.join(base,item.name)):[path.join(base,item.name)]);}
function validate(pages){
 assert(Array.isArray(pages)&&pages.length===25,'Expected 15 original sites, the directory and nine subpages');
 assert.equal(pages.filter(p=>p.home&&p.module!=='Nachtverzeichnis').length,15);
 assert.equal(new Set(pages.map(p=>p.route)).size,pages.length);assert.equal(new Set(pages.map(p=>p.module)).size,pages.length);
 for(const page of pages){assert(/^\/[a-z0-9-]+\/[a-z0-9-]+\.html$/.test(page.route),page.route);assert(/^[A-Za-z][A-Za-z0-9_]*$/.test(page.module),page.module);assert(page.title&&page.description);}
}
function preservePrevious(){
 const directory=path.join(root,'build/retired-original-sites-20261019');fs.mkdirSync(directory,{recursive:true});
 const archive=path.join(directory,'previous-sites.zip');
 if(!fs.existsSync(archive)){
  const python=String.raw`from pathlib import Path
import sys, zipfile, hashlib, json
r=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve()
assert out.is_relative_to(r/'build')
items=list((r/'examples/websites').rglob('*'))+list((r/'src/HTMLEngine/Websites').rglob('*'))
items += [r/'default.project.json',r/'htmlpage.project.json',r/'scripts/data/wttg2-catalog.json']
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,6) as z:
 for f in sorted(set(items)):
  if f.is_file(): z.write(f,f.relative_to(r).as_posix())
with zipfile.ZipFile(out) as z: assert z.testzip() is None
print(json.dumps({'archive':str(out),'files':len([p for p in items if p.is_file()]),'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}))`;
  const result=cp.execFileSync(process.env.PYTHON_BIN||'python',['-c',python,root,archive],{encoding:'utf8',windowsHide:true});fs.writeFileSync(path.join(directory,'backup.json'),result);
 }
 const fixture=path.join(root,'tests/fixtures/retired-wiki-hover-20261019.json');
 if(!fs.existsSync(fixture)){
  const sources={};for(const name of ['init','HTML','CSS']){const source=fs.readFileSync(path.join(modulesRoot,'DeepWiki',name+'.luau'),'utf8');sources[name]={source,sha256:hash(source)};}
  fs.writeFileSync(fixture,JSON.stringify({date:'2026-10-19',scope:'Non-served original Wiki hover regression; ImageCatalog acquisition is stubbed by the test.',sources},null,2)+'\n');
 }
}
function installDrafts(){
 const drafts=path.join(root,'examples/site-drafts'),groups=['directory','collection-a','collection-b','collection-c'];
 const pages=groups.flatMap(group=>JSON.parse(fs.readFileSync(inside(drafts,group+'/manifest.json'),'utf8')));validate(pages);
 const routes=new Set(pages.map(p=>p.route));
 // Check complete inputs and every local reference before replacing served files.
 for(const group of groups){
  const base=inside(drafts,group);
  for(const page of pages.filter(p=>fs.existsSync(inside(base,p.route.slice(1))))){
   const source=fs.readFileSync(inside(base,page.route.slice(1)),'utf8');assert(/<!doctype\s+html>/i.test(source),page.route);
   for(const match of source.matchAll(/(?:href|src)\s*=\s*["']([^"']+)["']/gi)){
    if(match[1].startsWith('#'))continue;const url=new URL(match[1],origin+page.route);assert.equal(url.origin,origin,'External dependency '+url.href);
    if(url.pathname.endsWith('.html'))assert(routes.has(url.pathname),'Unknown route '+url.pathname);
    else assert(fs.existsSync(inside(base,decodeURI(url.pathname).slice(1))),'Missing local asset '+url.pathname);
   }
  }
 }
 for(const page of pages)assert(groups.some(group=>fs.existsSync(inside(drafts,group+page.route))),'Missing source '+page.route);
 preservePrevious();
 // Resolved targets are direct children of these two explicitly named roots.
 for(const base of [browserRoot,modulesRoot])for(const item of fs.readdirSync(base)){
  if(base===modulesRoot&&item==='init.luau')continue;
  const target=inside(base,item);assert.equal(path.dirname(target),base);fs.rmSync(target,{recursive:true,force:true});
 }
 for(const group of groups){
  const base=inside(drafts,group);
  for(const item of fs.readdirSync(base,{withFileTypes:true}))if(item.isDirectory()){
   const from=inside(base,item.name),to=inside(browserRoot,item.name);assert(!fs.existsSync(to));fs.renameSync(from,to);
  }
 }
 fs.writeFileSync(dataPath,JSON.stringify({entry:'/verzeichnis/index.html',pages},null,2)+'\n');
 // All authored sources now live in examples/websites; discard duplicate manifests.
 assert(drafts===path.join(root,'examples','site-drafts'));fs.rmSync(drafts,{recursive:true});
}
function publish(){
 const config=JSON.parse(fs.readFileSync(dataPath,'utf8')),pages=config.pages;validate(pages);
 const modules=[];
 for(const page of pages){
  const sourcePath=inside(browserRoot,page.route.slice(1)),folder=path.dirname(sourcePath),directory=path.posix.dirname(page.route);
  const html=fs.readFileSync(sourcePath,'utf8').replace(/\r\n/g,'\n'),css=fs.readFileSync(path.join(folder,'styles.css'),'utf8').replace(/\r\n/g,'\n');
  const scripts=[...html.matchAll(/<script\b[^>]*\bsrc=["']([^"']+)["']/gi)].map(m=>m[1]);assert(scripts.length<=1,'Keep page scripts small and independent');
  const scriptPath=scripts[0],script=scriptPath?fs.readFileSync(inside(folder,scriptPath),'utf8').replace(/\r\n/g,'\n'):null;
  const svgs=files(folder).filter(f=>f.endsWith('.svg'));
  const lines=['--!strict','-- Generated by scripts/publish-nightweb.cjs; edit browser-native sources.', 'return {','\tName = '+quote(page.title)+',','\tURL = '+quote(origin+page.route)+',','\tPath = '+quote(page.route)+',','\tCatalogHidden = '+String(!page.home)+',','\tHTML = require(script.HTML),','\tStylesheets = { ["styles.css"] = require(script.CSS), ['+quote(origin+directory+'/styles.css')+'] = require(script.CSS) },','\tOptions = { DefaultFont = "Arial",'];
  if(svgs.length){lines.push('\t\tSVGs = {');for(const svg of svgs){const relative=path.relative(folder,svg).replaceAll('\\','/'),source=fs.readFileSync(svg,'utf8');for(const key of [relative,directory+'/'+relative,origin+directory+'/'+relative])lines.push('\t\t\t['+quote(key)+'] = '+literal(source)+',');}lines.push('\t\t},');}
  if(script!==null){lines.push('\t\tJavaScriptServices = { ScriptSources = { ['+quote(origin+directory+'/'+scriptPath)+'] = require(script.JavaScript) } },');}
  lines.push('\t},','}','');
  const sources={'init.luau':lines.join('\n'),'HTML.luau':'--!strict\nreturn '+literal(html)+'\n','CSS.luau':'--!strict\nreturn '+literal(css)+'\n'};
  if(script!==null)sources['JavaScript.luau']='--!strict\nreturn '+literal(script)+'\n';
  const target=inside(modulesRoot,page.module);fs.mkdirSync(target,{recursive:true});
  const moduleFiles=[];for(const[name,text]of Object.entries(sources)){const file=inside(target,name);fs.writeFileSync(file,text);moduleFiles.push({path:path.relative(root,file).replaceAll('\\','/'),sha256:hash(text),byteLength:Buffer.byteLength(text)});}
  modules.push({name:page.module,url:origin+page.route,sourcePath:page.route,title:page.title,description:page.description,CatalogHidden:!page.home,interaction:page.interaction||null,files:moduleFiles});
 }
 const browserFiles=files(browserRoot).map(file=>{const bytes=fs.readFileSync(file);return{target:path.relative(root,file).replaceAll('\\','/'),sha256:hash(bytes),byteLength:bytes.length};});
 const catalog={date:'2026-10-19',publisher:'scripts/publish-nightweb.cjs',entry:config.entry,origin,counts:{sites:15,htmlRoutes:pages.length,subpages:pages.filter(p=>!p.home).length},Modules:modules,files:browserFiles};
 fs.writeFileSync(catalogPath,JSON.stringify(catalog,null,2)+'\n');return catalog;
}
if(require.main===module){if(process.argv.includes('--backup')){preservePrevious();console.log('Previous served pages preserved outside the runtime catalog.');}else{if(process.argv.includes('--install-drafts'))installDrafts();const result=publish();console.log(JSON.stringify({sites:result.counts.sites,routes:result.Modules.length,files:result.files.length,entry:result.entry}));}}
module.exports={publish};
