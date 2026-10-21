// Independent ordinary Chromium capture. No feature flags or user browser.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),crypto=require('node:crypto');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/video-lazy-reference');
const pin={commit:'ba3400bb4f3d86477a5c8cfc07ff91fc0caaf21c',sha256:'49641dedf6fd316141e44a8f0596fab586e455c7cb5946c54b5e19df88ea0a4f'};
const frozen=fs.readFileSync(path.join(root,'build/media-reflection-reference/html-target-source'));
if(crypto.createHash('sha256').update(frozen).digest('hex')!==pin.sha256)throw Error('Frozen media source changed');
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j6ioAAAAASUVORK5CYII=','base64');
const wav=Buffer.alloc(32044);wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVE',8);wav.write('fmt ',12);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(8000,24);wav.writeUInt32LE(16000,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(wav.length-44,40);
const requests=[],documents=new Map();
const server=http.createServer((req,res)=>{
 if(documents.has(req.url)){res.writeHead(200,{'Content-Type':'text/html','Cache-Control':'no-store'});res.end(documents.get(req.url));return;}
 requests.push({url:req.url,range:req.headers.range||null});
 const image=req.url.includes('.png'),data=image?png:wav;
 res.writeHead(200,{'Content-Type':image?'image/png':'audio/wav','Content-Length':data.length,'Cache-Control':'no-store'});res.end(data);
});
const wait=()=>new Promise(resolve=>setTimeout(resolve,200));
const cases=[['default',null],['eager','eager'],['invalid','unknown'],['lazy offscreen','lazy'],['lazy mixed case','LaZy'],['lazy whitespace invalid',' lazy '],['lazy visible','lazy','visible'],['lazy eager mutation','lazy','eager'],['lazy play','lazy','play'],['lazy load','lazy','load'],['lazy scroll','lazy','scroll'],['lazy poster replacement','lazy','poster'],['lazy scripting disabled','lazy','disabled']];
(async()=>{
 fs.mkdirSync(folder,{recursive:true});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const base='http://127.0.0.1:'+server.address().port;const browser=await openBrowser(folder);
 const result={captured:new Date().toISOString(),target:pin,browser:await browser.send('Browser.getVersion'),profile:'Ordinary browser, same-origin local HTTP page and PCM WAV in VIDEO (metadata/audio only), real PNG poster and HTTP requests; no video frame/decoder or fixed UA-distance claim.',cases:[]};
 try{
  result.loadingSupported=await browser.evaluate("'loading'in HTMLMediaElement.prototype");
  for(let index=0;index<cases.length;index++){
   const [name,loading,action]=cases[index],prefix='/case'+index;
   const html='<!doctype html><style>body{margin:0}video{display:block;width:200px;height:100px;margin-top:'+(action==='visible'?0:100000)+'px}</style><video id=m muted preload=auto '+(loading===null?'':'loading="'+loading+'"')+' src="'+base+prefix+'/one.wav" poster="'+base+prefix+'/one.png"></video>';
   const start=requests.length;documents.set(prefix+'/index.html',html);
   await browser.send('Emulation.setScriptExecutionDisabled',{value:action==='disabled'});
   await browser.send('Page.navigate',{url:base+prefix+'/index.html'});await wait();
   const snapshot=()=>browser.evaluate("({loading:m.loading,attribute:m.getAttribute('loading'),ready:m.readyState,network:m.networkState,current:m.currentSrc,error:m.error?.code||null,rectTop:m.getBoundingClientRect().top,complete:document.readyState,outcome:window.playOutcome||null})");
   const row={name,html,before:await snapshot(),initialRequests:requests.slice(start)};
   if(action&&action!=='visible'&&action!=='disabled'){
    await browser.evaluate(action==='eager'?"m.loading='eager'":action==='play'?"m.play().then(()=>window.playOutcome='fulfilled',e=>window.playOutcome=e.name);undefined":action==='load'?"m.load()":action==='poster'?"m.poster='"+base+prefix+"/two.png';window.scrollTo(0,100000)":"window.scrollTo(0,100000)");
    await wait();row.after=await snapshot();row.allRequests=requests.slice(start);
   }
   result.cases.push(row);console.log(name+': '+JSON.stringify({before:row.before,initial:row.initialRequests.map(v=>v.url),after:row.after,all:row.allRequests?.map(v=>v.url)}));
  }
  fs.writeFileSync(path.join(root,'tests/fixtures/video-lazy-browser.json'),JSON.stringify(result,null,2)+'\n');
  fs.writeFileSync(path.join(folder,'native.json'),JSON.stringify(result,null,2)+'\n');
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;server.close();});
