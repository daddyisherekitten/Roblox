// Regression readers may use retired sources; the runtime catalog never does.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const archive = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/retired-nightweb-pages-20261019.json'), 'utf8'));
const sites = archive.sites;
for (const [folder,site] of Object.entries(sites)) for (const kind of ['files','modules']) {
 for (const [file,value] of Object.entries(site[kind])) {
  const bytes = Buffer.from(value,site.encodings[kind][file]);
  assert.equal(bytes.length,site.byteLengths[kind][file],`Changed retired input length ${folder}/${kind}/${file}`);
  assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),site.sha256[kind][file],`Changed retired input ${folder}/${kind}/${file}`);
 }
}
function readArchived(folder,kind,file) {
 const site=sites[folder];
 assert.ok(site && Object.hasOwn(site[kind],file),`Missing retired input ${folder}/${kind}/${file}`);
 assert.equal(site.encodings[kind][file],'utf8',`Requested text from binary retired input ${folder}/${kind}/${file}`);
 return site[kind][file];
}
function readWebsiteFile(folder,file) {
 const active=path.join(root,'examples/websites',folder,file);
 return fs.existsSync(active)?fs.readFileSync(active,'utf8'):readArchived(folder,'files',file);
}
function readWebsiteModule(module,file) {
 const active=path.join(root,'src/HTMLEngine/Websites',module,file);
 if (fs.existsSync(active)) return fs.readFileSync(active,'utf8');
 const found=Object.entries(sites).find(([,site])=>site.module===module);
 assert.ok(found,`Missing retired module ${module}/${file}`);
 return readArchived(found[0],'modules',file);
}
module.exports={readWebsiteFile,readWebsiteModule,retiredNightwebPages:sites};
