const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const root = path.resolve(__dirname, '..');
const cases = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/top-layer-positioning.json'), 'utf8'));
if (!process.argv.includes('--serve')) {
  const result = require('node:child_process').spawnSync(process.execPath, [path.join(root, 'scripts/run-html-tests.cjs'), 'TopLayerPositioning'], {stdio:'inherit'});
  process.exitCode = result.status ?? 1;
} else {
  const server = http.createServer((req,res) => {
    const html = `<!doctype html><meta charset="utf-8"><title>Top-layer positioning reference</title><h1>Top-layer positioning reference</h1><pre id="result">Running</pre><script>
const cases=${JSON.stringify(cases).replaceAll('<','\\u003c')};
(async()=>{const results=[];for(const size of [[500,400],[320,220]]){for(const c of cases){
const frame=document.createElement('iframe');frame.style.cssText='border:0;width:'+size[0]+'px;height:'+size[1]+'px';document.body.append(frame);
const d=frame.contentDocument;d.open();d.write('<!doctype html><style>html,body{margin:0;padding:0}body{height:1800px}#target{'+(c.base||'width:120px;height:80px;padding:0;border:0;background:#ed963b;box-sizing:border-box')+'}</style><div id="host" style="'+(c.host||'')+'"><'+c.tag+' id="target" '+(c.popover?'popover="'+c.popover+'"':'')+' style="'+(c.style||'')+'"></'+c.tag+'></div>');d.close();
const t=d.getElementById('target');if(c.action)t[c.action]();
for(const scroll of [0,120]){frame.contentWindow.scrollTo(0,scroll);await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
const s=frame.contentWindow.getComputedStyle(t),r=t.getBoundingClientRect();const p=d.elementFromPoint(r.x+r.width/2,r.y+r.height/2);
results.push({name:c.name,width:size[0],viewportWidth:d.documentElement.clientWidth,height:size[1],viewportHeight:d.documentElement.clientHeight,scroll:frame.contentWindow.scrollY,position:s.position,rect:{x:r.x,y:r.y,width:r.width,height:r.height},hit:p===t,overflow:s.overflow,padding:[s.paddingTop,s.paddingRight,s.paddingBottom,s.paddingLeft].map(parseFloat)});}
if(c.action==='showModal')t.close();if(c.action==='showPopover')t.hidePopover();frame.remove();}}
document.getElementById('result').textContent=JSON.stringify(results);document.title='Top-layer positioning: '+results.length+' browser measurements';})().catch(e=>document.getElementById('result').textContent='ERROR '+e.stack);
</script>`;
    res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(html);
  });
  server.listen(0,'127.0.0.1',()=>console.log('Top-layer positioning reference: http://127.0.0.1:'+server.address().port+'/'));
}
