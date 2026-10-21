// Native iframe srcdoc parsing/base-URL references; isolated HTTP/browser host.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),file=path.join(root,'tests/fixtures/srcdoc-browser.json');
const cases=[
 ['no doctype','<title>Child</title><p>A &amp; B</p>'],
 ['HTML doctype','<!doctype html><p>Standard</p>'],
 ['non HTML doctype','<!doctype wrong><p>Still standard</p>'],
 ['limited quirks doctype','<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"><p>Standard</p>'],
 ['quirks public doctype','<!DOCTYPE HTML PUBLIC "-//W3O//DTD W3 HTML Strict 3.0//EN//"><p>Standard</p>'],
 ['leading comments and implicit body','<!--Comment-->Plain text'],
 ['relative first base','<base href="../other/"><base href="https://ignored.test/"><p>Relative</p>'],
 ['absolute base','<base href="https://remote.test/folder/"><p>Absolute</p>'],
 ['data base uses fallback','<base href="data:text/plain,example"><p>Fallback</p>'],
 ['javascript base uses fallback','<base href="javascript:example"><p>Fallback</p>'],
 ['invalid base uses fallback','<base href="http://["><p>Fallback</p>'],
 ['canonical special host and default port','<base href="HTTPS://Example.TEST:443/a/../b/?q=a b#c d"><p>Canonical</p>'],
 ['IPv6 base','<base href="http://[2001:db8::1]:8080/a"><p>IPv6</p>'],
 ['IDNA and encoded dots','<base href="https://bücher.example/x/%2e%2e/日本"><p>IDNA</p>'],
 ['invalid base port','<base href="https://example.test:70000/"><p>Fallback</p>'],
 ['invalid escaped host','<base href="https://exa%23mple.test/"><p>Fallback</p>'],
 ['opaque custom base','<base href="custom:hello world"><p>Opaque</p>'],
 ['absolute hostless base','<base href="custom:/folder/../next"><p>Hostless</p>'],
 ['empty first base prevents later base','<base href=""><base href="https://ignored.test/"><p>Empty</p>'],
 ['charset meta cannot change srcdoc Unicode' ,'<meta charset="windows-1252"><p>Häuser 日本</p>'],
];
(async()=>{
 let current=0;
 const server=http.createServer((req,res)=>{if(new URL(req.url,'http://local').pathname!=='/page'||!cases[current]){res.writeHead(404);res.end();return;}res.writeHead(200,{'Content-Type':'text/html;charset=utf-8'});const html=cases[current][1].replaceAll('&','&amp;').replaceAll('"','&quot;');res.end('<!doctype html><base href="/assets/root.html"><iframe id=frame srcdoc="'+html+'"></iframe>');});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const origin='http://127.0.0.1:'+server.address().port,browser=await openBrowser(path.join(root,'build'));
 try{
  const fixtures=[];
  for(current=0;current<cases.length;current++){
   await browser.send('Page.navigate',{url:origin+'/page?case='+current});
   let result;for(let tries=0;tries<200;tries++){await new Promise(resolve=>setTimeout(resolve,10));result=await browser.evaluate("(()=>{const d=document.getElementById('frame')?.contentDocument;if(!d||d.URL!=='about:srcdoc'||d.readyState!=='complete')return null;return [d.URL,d.baseURI,d.compatMode,d.characterSet,d.title,d.body.textContent]})()");if(result)break;}
   assert.ok(result,cases[current][0]);result=result.map(value=>value.replaceAll(origin,'https://docs.test'));
   const fixture={name:cases[current][0],html:cases[current][1],fallbackBaseURL:'https://docs.test/assets/root.html',expected:result};
   if(cases[current][0].startsWith('invalid ')&&result[1]==='about:blank'){
    fixture.standardExpected=[...result];fixture.standardExpected[1]=fixture.fallbackBaseURL;
    fixture.nativeDifference='Chromium freezes about:blank on URL parse failure; current HTML frozen-base algorithm uses the fallback base URL.';
   }
   fixtures.push(fixture);
  }
  if(process.argv.includes('--update'))fs.writeFileSync(file,JSON.stringify(fixtures,null,2)+'\n');else assert.deepEqual(fixtures,JSON.parse(fs.readFileSync(file,'utf8')));
  console.log('Srcdoc: '+fixtures.length+' native mode/URL/base/charset references captured.');
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
