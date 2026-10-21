// Shared source fixtures executed in native Node/ICU and the engine VM.
const fs=require('fs'),path=require('path'),vm=require('vm');
const fixtures=[];
function add(name,source,options={}){const values=[];const previous=process.env.TZ;process.env.TZ=options.DefaultTimeZone||'UTC';try{vm.runInNewContext(source,{record:value=>values.push(String(value)),Intl,Date,URL,URLSearchParams,TextEncoder,Uint8Array},{timeout:30000});}finally{if(previous===undefined)delete process.env.TZ;else process.env.TZ=previous;}fixtures.push({name,source,options,expected:values});}
add('normalize conversion, Unicode, astral and lone surrogates',String.raw`
for(const s of ['a\u0308','\u212b','\ufb03','\uff21','\u1e9b\u0323','\u1100\u1161\u11a8','\ud800e\u0301\udc00','\ud834\udd1e\u0301','x\u0315\u0300\u05ae'])for(const form of ['NFC','NFD','NFKC','NFKD'])record(JSON.stringify(s.normalize(form)));
record(String.prototype.normalize.call({toString(){return 'e\u0301'}}));record('e\u0301'.normalize(undefined));
const boxed=new String('wrong');boxed.toString=function(){return 'A\u0308'};record(boxed.normalize());record(String.prototype.normalize.call(123));
for(const f of [null,'nfc','',{},Symbol()])try{record('x'.normalize(f))}catch(e){record(e.name)}
try{String.prototype.normalize.call(null)}catch(e){record(e.name)}
record(String.prototype.normalize.length);record(Object.prototype.toString.call(new String('x')));
`);
add('URL Unicode and IP hosts',String.raw`
for(const source of ['https://BÜCHER.de:443/a b?x=ä#ö','http://faß.de/','https://例え.テスト/','http://\uff26\uff2f\uff2f\u3002com/','https://☃.net/','https://xn--bcher-kva.de/','http://127.1/','http://0x7f000001/','http://0177.0.0.1/','http://2130706433/','http://1.2.65535/','http://256.1/','http://1.2.3.256/','http://09/','http://[2001:0db8:0:0:1:0:0:1]:80/','http://[::ffff:192.0.2.128]/','http://[1::2::3]/','http://[::gg]/','http://[::1%25eth0]/','http://a\u200cb.de/','http://\u0301abc.de/','http://אa.com/','http://xn--/','http://xn--abc-/','http:////Example.COM/a','foo://UPPER.example/a','blob:https://bücher.de/a','file://localhost/a'])try{const u=new URL(source);record(JSON.stringify([u.href,u.hostname,u.host,u.origin]))}catch(e){record(e.name)}
for(const source of ['../c?x=1','#片段','//bücher.de:443/a','http:next','\\\\example.net\\x'])try{record(new URL(source,'http://example.test/a/b').href)}catch(e){record(e.name)}
try{new URL('http://[192.0.2.1::]/')}catch(e){record(e.name)}
const u=new URL('https://example.test:444/a?x=1');const p=u.searchParams;u.hostname='bücher.de';record(u.href);u.host='[2001:db8::1]:443';record(u.href);u.host='[bad]';record(u.href);u.searchParams.append('ä','a b');record(u.href);u.href='http://127.1/?z=2';record(p===u.searchParams);record(p.toString());record(URL.canParse('http://256.1'));record(URL.parse('http://[x]')===null);
`);
for(const locale of ['de-DE','en-US','en-GB']){
add('DateTimeFormat daily '+locale,`
const t=Date.UTC(2026,9,5,13,4,5,123);
for(const options of [{},{year:'numeric',month:'long',day:'numeric'},{weekday:'long',year:'numeric',month:'long',day:'numeric'},{year:'2-digit',month:'2-digit',day:'2-digit'},{year:'numeric',month:'short'},{weekday:'short'},{hour:'numeric',minute:'numeric'},{hour:'2-digit',minute:'2-digit',second:'2-digit',fractionalSecondDigits:3},{year:'numeric',month:'long',day:'numeric',hour:'numeric',minute:'numeric'},{hour:'numeric',minute:'numeric',timeZoneName:'long'},{hour:'numeric',minute:'numeric',timeZoneName:'shortOffset'}]){
const f=new Intl.DateTimeFormat('${locale}',{...options,timeZone:'Europe/Berlin'});record(f.format(t));record(JSON.stringify(f.formatToParts(t)));record(JSON.stringify(f.resolvedOptions()));record(f.format===f.format);
}
for(const dateStyle of ['full','long','medium','short'])for(const timeStyle of ['full','long','medium','short'])for(const hourCycle of ['h11','h12','h23','h24']){const f=new Intl.DateTimeFormat('${locale}',{dateStyle,timeStyle,hourCycle,timeZone:'Europe/Berlin'});record(f.format(t));record(JSON.stringify(f.formatToParts(t)));}
const d=new Date(t);record(d.toLocaleDateString('${locale}',{timeZone:'UTC'}));record(d.toLocaleTimeString('${locale}',{timeZone:'UTC'}));record(d.toLocaleString('${locale}',{timeZone:'UTC'}));
`);
}
add('DateTimeFormat brands, negotiation and errors',String.raw`
record(JSON.stringify(Intl.DateTimeFormat.supportedLocalesOf(['de-DE','en-GB','en-US'])));
record(new Intl.DateTimeFormat('en-US-u-ca-gregory-nu-latn',{timeZone:'uTc'}).resolvedOptions().locale);
record(new Intl.DateTimeFormat('de-DE',{timeZone:'+0530',hour:'numeric',minute:'numeric',timeZoneName:'shortOffset'}).format(0));
for(const options of [{timeZone:'Made/Up'},{fractionalSecondDigits:0},{hourCycle:'oops'},{dateStyle:'full',year:'numeric'},{dateStyle:'foo'}])try{new Intl.DateTimeFormat('de-DE',options)}catch(e){record(e.name)}
const f=new Intl.DateTimeFormat('de-DE',{timeZone:'UTC'});try{f.format(NaN)}catch(e){record(e.name)}
try{Intl.DateTimeFormat.prototype.formatToParts.call({})}catch(e){record(e.name)}
try{Object.getOwnPropertyDescriptor(Intl.DateTimeFormat.prototype,'format').get.call({})}catch(e){record(e.name)}
try{new Date(0).toLocaleDateString('en',{timeStyle:'short'})}catch(e){record(e.name)}
try{new Date(0).toLocaleTimeString('en',{dateStyle:'short'})}catch(e){record(e.name)}
record(new Date(NaN).toLocaleString('de-DE',{timeZone:'Made/Up'}));
class F extends Intl.DateTimeFormat{};const sub=new F('de-DE',{timeZone:'UTC'});record(sub instanceof F);record(sub instanceof Intl.DateTimeFormat);record(Object.prototype.toString.call(sub));record(sub.format(0));
`);
for(const zone of ['Europe/Berlin','Europe/London','America/New_York','America/Los_Angeles','America/Chicago','Asia/Tokyo','Asia/Kolkata','Australia/Sydney','Pacific/Auckland'])add('Zone transition data '+zone,`
const f=new Intl.DateTimeFormat('en-GB',{timeZone:'${zone}',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',timeZoneName:'longOffset'});
for(const t of [Date.UTC(1900,0,1),Date.UTC(1970,0,1),Date.UTC(2026,2,29,0,59,59),Date.UTC(2026,2,29,1),Date.UTC(2026,9,25,0,59,59),Date.UTC(2026,9,25,1),Date.UTC(2026,10,1,5,59,59),Date.UTC(2026,10,1,6),Date.UTC(2099,6,15)])record(f.format(t));
`);
for(const zone of ['Europe/Berlin','America/New_York'])add('Date realm DST disambiguation '+zone,`
for(const date of [new Date(2026,2,29,2,30),new Date(2026,9,25,2,30),new Date(2026,2,8,2,30),new Date(2026,10,1,1,30)]){record(date.toISOString());record(date.getTimezoneOffset());record(Date.parse(date.toString())===date.getTime());record(Date.parse(date.toUTCString())===date.getTime());}
const d=new Date(Date.UTC(2026,2,28,12));d.setDate(d.getDate()+1);record(d.toISOString());record(d.getHours());
record(new Date('2026-03-29T02:30:00').toISOString());record(new Date('2026-03-29').toISOString());
`,{DefaultTimeZone:zone});
for(const locale of ['de-DE','en-US','en-GB'])add('NumberFormat rounding and notation '+locale,`
for(const roundingMode of ['ceil','floor','expand','trunc','halfCeil','halfFloor','halfExpand','halfTrunc','halfEven'])for(const n of [-2.55,-2.5,-2.45,-0.05,-0,0,0.05,2.45,2.5,2.55,'9007199254740993.25']){const f=new Intl.NumberFormat('${locale}',{maximumFractionDigits:1,roundingMode});record(f.format(n));record(JSON.stringify(f.formatToParts(n)));}
for(const options of [{minimumSignificantDigits:3,maximumSignificantDigits:3},{maximumSignificantDigits:2},{maximumSignificantDigits:3,maximumFractionDigits:2,roundingPriority:'morePrecision'},{maximumSignificantDigits:3,maximumFractionDigits:2,roundingPriority:'lessPrecision'},{minimumFractionDigits:2,maximumFractionDigits:2,roundingIncrement:5},{minimumFractionDigits:2,maximumFractionDigits:2,roundingIncrement:25,roundingMode:'halfEven'},{notation:'scientific'},{notation:'engineering'},{notation:'compact'},{notation:'compact',compactDisplay:'long'},{notation:'compact',maximumFractionDigits:1}]){const f=new Intl.NumberFormat('${locale}',options);record(JSON.stringify(f.resolvedOptions()));for(const n of [0,-0,0.001234,1,1.025,1.125,1234,12345,123456,999950,1234567,1e20,NaN,Infinity]){record(f.format(n));record(JSON.stringify(f.formatToParts(n)));}}
`);
for(const locale of ['de-DE','en-US','en-GB'])add('NumberFormat CLDR names '+locale,`
for(const currency of ['EUR','USD','GBP','JPY'])for(const currencyDisplay of ['symbol','narrowSymbol','code','name']){const f=new Intl.NumberFormat('${locale}',{style:'currency',currency,currencyDisplay});record(JSON.stringify(f.resolvedOptions()));for(const n of [0,1,2,1234.56,-1,NaN]){record(f.format(n));record(JSON.stringify(f.formatToParts(n)));}}
for(const unit of ['meter','kilometer-per-hour','liter','celsius','megabyte','day'])for(const unitDisplay of ['short','narrow','long']){const f=new Intl.NumberFormat('${locale}',{style:'unit',unit,unitDisplay});record(JSON.stringify(f.resolvedOptions()));for(const n of [0,1,2,1.5,-1,NaN]){record(f.format(n));record(JSON.stringify(f.formatToParts(n)));}}
`);
add('NumberFormat invalid rounding options',String.raw`
for(const options of [{roundingIncrement:3},{roundingIncrement:5,maximumFractionDigits:2},{roundingIncrement:5,minimumSignificantDigits:2},{minimumSignificantDigits:4,maximumSignificantDigits:3},{maximumSignificantDigits:0},{minimumFractionDigits:3,maximumFractionDigits:2},{roundingPriority:'oops'}])try{new Intl.NumberFormat('de-DE',options)}catch(e){record(e.name)}
record(new Intl.NumberFormat('de-DE',{maximumSignificantDigits:3,maximumFractionDigits:999}).format(1234));
record((1234.56).toLocaleString('de-DE'));record(Number.prototype.toLocaleString.call(new Number(1234.56),'en-GB',{style:'currency',currency:'GBP'}));try{Number.prototype.toLocaleString.call('1')}catch(e){record(e.name)}
`);
add('British ListFormat punctuation',String.raw`
for(const type of ['conjunction','disjunction','unit'])for(const style of ['long','short','narrow']){const f=new Intl.ListFormat('en-GB',{type,style});record(f.format(['See','Wald','Berge']));record(JSON.stringify(f.formatToParts(['See','Wald','Berge'])));record(f.resolvedOptions().locale);}
`);
add('Date primitive conversion and component edges',String.raw`
const d=new Date(Date.UTC(2026,9,5,13,4,5));record((d+'').split(' (')[0]);record(+d);record(Date.prototype.toGMTString===Date.prototype.toUTCString);record(Date.prototype[Symbol.toPrimitive].call({valueOf(){return 1},toString(){return 'text'}},'default'));record(Date.prototype[Symbol.toPrimitive].call({valueOf(){return 1},toString(){return 'text'}},'number'));
for(const hint of ['bad',null,undefined])try{Date.prototype[Symbol.toPrimitive].call(d,hint)}catch(e){record(e.name)}
const invalid=new Date(NaN);record(invalid.toJSON());invalid.setUTCFullYear(2026);record(invalid.toISOString());
for(const source of ['2026-01-31T24:00:00.000Z','2026-01-31T24:00:00.001Z','-000000-01-01T00:00:00Z','+010000-01-01','2026-02-30','2026-13-01']){const time=Date.parse(source);record(Number.isNaN(time)?'NaN':new Date(time).toISOString());}
`);
add('DateTimeFormat Unicode hour cycles and midnight',String.raw`
for(const locale of ['de-DE-u-hc-h12','en-US-u-hc-h23','en-GB'])for(const hourCycle of ['h11','h12','h23','h24']){const f=new Intl.DateTimeFormat(locale,{timeZone:'UTC',hour:'numeric',minute:'numeric',hourCycle});record(f.format(0));record(JSON.stringify(f.resolvedOptions()));}
const log=[];const f=new Intl.DateTimeFormat('en-US-u-ca-gregory-nu-latn',{calendar:{toString(){log.push('calendar');return 'gregory'}},numberingSystem:{toString(){log.push('number');return 'latn'}},timeZone:'UTC'});record(log.join(','));record(f.resolvedOptions().locale);
for(const options of [{calendar:'-abc'},{numberingSystem:'la--tn'},{calendar:'123456789'}])try{new Intl.DateTimeFormat('de-DE',options)}catch(e){record(e.name)}
`);
add('URL setters, Windows files and opaque paths',String.raw`
for(const source of ['file:///C|/a/../x','file://C:/x','mailto:a b@example.test','foo:/a/b','foo:abc def','foo://UPPER.example/a?x=\u00e4','http://\u093eabc.de/','http://%ff/','http://a..b/'])try{record(new URL(source).href)}catch(e){record(e.name)}
for(const source of ['/x','../x'])record(new URL(source,'file:///C:/a/b').href);
const u=new URL('http://example.test:8080/a');for(const [key,value] of [['hostname','new.test:99'],['host','other.test:bad'],['protocol','https:'],['port','99abc'],['search','?x=\\path'],['pathname','\\x\\y']]){u[key]=value;record(u.href);}
const f=new URL('http://example.test/a');f.protocol='file:';record(f.href);f.protocol='https:';record(f.href);
`);
add('DateTimeFormat date-only time zone separators',String.raw`
for(const locale of ['de-DE','en-US','en-GB'])for(const options of [{timeZoneName:'short'},{year:'numeric',month:'long',day:'numeric',timeZoneName:'long'},{weekday:'long',timeZoneName:'short'},{minute:'numeric',timeZoneName:'short'}]){const f=new Intl.DateTimeFormat(locale,{timeZone:'UTC',...options});record(f.format(0));record(JSON.stringify(f.formatToParts(0)));}
`);
add('Currency default fraction digits from CLDR',`
for(const locale of ['de-DE','en-US','en-GB'])for(const currency of ${JSON.stringify(Intl.supportedValuesOf('currency'))}){const f=new Intl.NumberFormat(locale,{style:'currency',currency,currencyDisplay:'code'});record(f.resolvedOptions().maximumFractionDigits);record(f.format(1.234567));}
`);
const target=path.join(__dirname,'../tests/fixtures/javascript-text-data-native.json');fs.writeFileSync(target,JSON.stringify({versions:process.versions,cases:fixtures},null,2)+'\n');console.log('Generated',fixtures.length,'native text/data groups',fixtures.reduce((n,f)=>n+f.expected.length,0),'records');
