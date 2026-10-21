const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),{openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
(async()=>{let mountedHTML='',browser;const server=http.createServer((_,response)=>{response.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});response.end(mountedHTML);});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));try{browser=await openBrowser(path.join(root,'build'));
 const html='<!doctype html><html><head></head><body></body></html>';
 const definitions=fs.readFileSync(path.join(root,'tests/fixtures/url-record-cases.js'),'utf8');
 await browser.load(html);const cases=await browser.evaluate(definitions+'\nurlRecordCases');const records=[];
 for(const record of cases){
  if(record.html){mountedHTML=record.html;const url='http://127.0.0.1:'+server.address().port+'/url-reference/index.html';await browser.send('Page.navigate',{url});for(let attempt=0;;attempt++){if(await browser.evaluate(`location.href===${JSON.stringify(url)}&&document.readyState==='complete'`))break;if(attempt>=200)throw new Error('Mounted reference did not load');await new Promise(resolve=>setTimeout(resolve,10));}}
  else await browser.load(html);
  const expected=await browser.evaluate(record.source);const values=JSON.parse(expected);const documentURL=await browser.evaluate('location.href');const parse=record.input===undefined?undefined:{input:record.input.toWellFormed(),base:record.base,ok:values[0]!=='TypeError',href:values[0],hostname:values[1]};
  let standardExpected,standardDeltas;
  if(record.name==='DOM href/src/base mutation'){
   // HTML's frozen-base algorithm step 3 requires the document fallback URL
   // on parse failure. Preserve Chromium's differing result as raw evidence.
   standardDeltas=[{index:11,native:values[11],standard:documentURL,reference:'https://html.spec.whatwg.org/multipage/semantics.html#set-the-frozen-base-url'}];values[11]=documentURL;standardExpected=JSON.stringify(values);
  }
  records.push({...record,...(parse?{parse}:{}),...(standardExpected?{standardExpected,standardDeltas}:{}),documentURL,expected});
 }
 fs.writeFileSync(path.join(root,'tests/fixtures/url-record-browser.json'),JSON.stringify({html,records,userAgent:await browser.evaluate('navigator.userAgent'),references:['https://url.spec.whatwg.org/#concept-opaque-host-parser','https://url.spec.whatwg.org/#forbidden-host-code-point','https://url.spec.whatwg.org/#c0-control-percent-encode-set','https://url.spec.whatwg.org/commit-snapshots/fde3f74f063341a28d437216f75735b8b40128f5/#concept-host-parser','https://url.spec.whatwg.org/commit-snapshots/fde3f74f063341a28d437216f75735b8b40128f5/#host-state']},null,2)+'\n');
 console.log(records.length+' native opaque-host URL/DOM/setter records');
 }finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}})().catch(error=>{console.error(error);process.exitCode=1;});
