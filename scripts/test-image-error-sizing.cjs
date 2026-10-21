// Browser-authored geometry reference for broken images. Run --serve to inspect.
const fs = require('node:fs'), path = require('node:path'), http = require('node:http');
const root = path.resolve(__dirname, '..');
const cases = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/image-error-sizing.json'), 'utf8'));
if (!process.argv.includes('--serve')) {
  const result = require('node:child_process').spawnSync(process.execPath, [path.join(root, 'scripts/run-html-tests.cjs'), 'ImageErrorSizing'], {stdio:'inherit'});
  process.exitCode = result.status ?? 1;
} else {
  const server = http.createServer((req, res) => {
    if (req.url !== '/') { res.writeHead(404); res.end(); return; }
    const html = `<!doctype html><meta charset="utf-8"><title>Broken image sizing reference</title>
<style>body{font:16px/20px Arial;margin:0}.host{width:400px;margin:0;padding:0}img{background:#edf1e6}</style>
<h1>Broken image sizing reference</h1><pre id="result">Loading</pre><div id="cases"></div><script>
const cases=${JSON.stringify(cases).replaceAll('<','\\u003c')};
(async()=>{const records=[];for(const c of cases){
 const host=document.createElement('div');host.className='host';
 host.innerHTML='<img '+c.attributes+' style="'+c.style+'" '+(c.alt===undefined?'':'alt="'+c.alt+'"')+'>';
 const img=host.firstElementChild;document.getElementById('cases').append(host);
 await new Promise(resolve=>{img.onload=img.onerror=resolve;img.src='missing.png';});
 const r=img.getBoundingClientRect(),s=getComputedStyle(img);
 records.push({name:c.name,width:r.width,height:r.height,display:s.display,ratio:s.aspectRatio,naturalWidth:img.naturalWidth,naturalHeight:img.naturalHeight,complete:img.complete});
}document.getElementById('result').textContent=JSON.stringify(records);})();
</script>`;
    res.writeHead(200, {'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'}); res.end(html);
  });
  server.listen(0, '127.0.0.1', () => console.log('Image error sizing reference: http://127.0.0.1:'+server.address().port+'/'));
}
