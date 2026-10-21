// Shared source strings, captured in isolated Chromium and replayed unchanged.
const urlRecordCases=[];
function constructorCase(name,input,base){
  const args=JSON.stringify(input)+(base===undefined?'':','+JSON.stringify(base));
  const source=`(()=>{try{const u=new URL(${args});return JSON.stringify([u.href,u.hostname,u.host,u.origin,URL.canParse(${args}),URL.parse(${args}).href]);}catch(e){return JSON.stringify([e.name,URL.canParse(${args}),URL.parse(${args})===null]);}})()`;
  urlRecordCases.push({name,source,input,...(base===undefined?{}:{base})});
}
for(let code=0;code<128;code++)constructorCase('opaque ASCII '+code,'foo://a'+String.fromCharCode(code)+'b/p');
for(const input of ['foo://UPPER.example/a','foo://faß.example/p','foo://例え.テスト/p','foo://a😀b/p','foo://a\ud800b/p','foo://a\udc00b/p','foo://a%2fb/p','foo://a%FFb/p','foo://a%b/p','foo://09/p','foo://0x7f000001/p','foo://[2001:0db8::1]:8080/p','foo://[::ffff:192.0.2.128]/p','foo://a[b/p','foo://a]b/p'])constructorCase('opaque constructor '+input,input);
for(const input of ['foo://UPPER.example','foo://UPPER.example?x=1','foo://UPPER.example#part'])constructorCase('opaque empty path '+input,input);
for(const input of ['../next','//Faß.example:123/p','#片段'])constructorCase('opaque relative '+input,input,'foo://UPPER.example:45/a/b?x=1');
for(const scheme of ['foo','https'])for(const suffix of ['',':',':123',':00080',':443','123','x',']','%31',':65536',':x',':123x']){
  const host='[::1]'+suffix;
  constructorCase('IPv6 suffix '+scheme+' '+JSON.stringify(suffix),scheme+'://'+host+'/p');
  for(const key of ['host','hostname']){
    const source=`(()=>{const u=new URL('${scheme}://OLD.example:8080/p?x=1#part');const p=u.searchParams;let failure='';try{u.${key}=${JSON.stringify(host)};}catch(e){failure=e.name;}return JSON.stringify([failure,u.href,u.hostname,u.host,u.origin,p===u.searchParams,p.toString()]);})()`;
    urlRecordCases.push({name:'IPv6 suffix '+scheme+' '+key+' '+JSON.stringify(suffix),source});
  }
}
for(const key of ['host','hostname'])for(let code=0;code<128;code++){
  const value='a'+String.fromCharCode(code)+'b';
  const source=`(()=>{const u=new URL('foo://OLD.example:8080/p?x=1');const p=u.searchParams;u.${key}=${JSON.stringify(value)};return JSON.stringify([u.href,u.hostname,u.host,u.origin,p===u.searchParams,p.toString()]);})()`;
  urlRecordCases.push({name:key+' ASCII '+code,source});
}
for(const key of ['href','host','hostname'])for(const value of ['Faß.example','a😀b','a%2fb','a[b','a]b','a\u0001b','a\u007fb']){
  const assigned=key==='href'?'foo://'+value+'/new?z=2':value;
  const source=`(()=>{const u=new URL('foo://OLD.example:8080/p?x=1');const p=u.searchParams;let failure='';try{u.${key}=${JSON.stringify(assigned)};}catch(e){failure=e.name;}p.append('ä','a b');return JSON.stringify([failure,u.href,u.hostname,u.host,p===u.searchParams,p.toString()]);})()`;
  urlRecordCases.push({name:key+' Unicode/control '+value,source});
}
urlRecordCases.push({name:'DOM href/src/base mutation',html:'<base id="base" href="foo://UPPER.example/dir/"><a id="a" href="item">Item</a><img id="image" src="cover.png"><form id="form" action="send"></form>',source:`(()=>{const b=document.getElementById('base'),a=document.getElementById('a'),i=document.getElementById('image'),f=document.getElementById('form');const out=[document.baseURI,b.href,a.href,i.src,f.action];b.href='foo://Faß.example/other/';out.push(document.baseURI,a.href,i.src,f.action);a.href='foo://a%2fb/p';i.src='foo://a\u0001b/p';out.push(a.href,i.src);b.href='foo://a[b/p';out.push(document.baseURI);return JSON.stringify(out);})()`});
urlRecordCases.push({name:'navigation/history rejects opaque cross origin',source:`(()=>{let error='';try{history.replaceState({},'','foo://UPPER.example/a');}catch(e){error=e.name;}let locationError='';try{location.href='foo://a[b/p';}catch(e){locationError=e.name;}return JSON.stringify([error,locationError]);})()`});
urlRecordCases.push({name:'URI grammar remains separate',source:`(()=>{const s='a"b\x7fä%/[]{}';return JSON.stringify([encodeURI(s),encodeURIComponent(s),decodeURI('%3B%2F%3F%3A%40%26%3D%2B%24%2C%23'),new URL('foo://a"b/p').hostname]);})()`});
urlRecordCases.push({name:'network constructors share opaque parsing',source:`(()=>{const request=new Request('foo://Faß.example/a?x=1'),response=Response.redirect('foo://a\x7fb/p',302);let failure='';try{new Request('foo://a[b/p');}catch(e){failure=e.name;}return JSON.stringify([request.url,response.headers.get('location'),failure]);})()`});
