// Capture versioned CLDR patterns and IANA transitions from the native ICU
// reference. These are static runtime data, never a host formatter fallback.
const fs=require('fs');const path=require('path');
const root=path.resolve(__dirname,'..');
const locales=['de-DE','en-US','en-GB'];
const zones=['Europe/Berlin','Europe/London','America/New_York','America/Los_Angeles','America/Chicago','Asia/Tokyo','Asia/Kolkata','Australia/Sydney','Pacific/Auckland'];
const reference=Date.UTC(2026,10,23,17,4,5,123);
function lua(value){if(value===null)return 'nil';if(typeof value==='string')return JSON.stringify(value);if(typeof value==='number'||typeof value==='boolean')return String(value);if(Array.isArray(value))return '{'+value.map(lua).join(',')+'}';return '{'+Object.entries(value).map(([k,v])=>'['+JSON.stringify(k)+']='+lua(v)).join(',')+'}';}
const fields={year:['','numeric','2-digit'],month:['','numeric','2-digit','long','short','narrow'],day:['','numeric','2-digit'],weekday:['','long','short','narrow'],era:['','long','short','narrow']};
function combinations(entries,fn,options={},values=[]){if(!entries.length){fn(options,values);return;}const [[key,variants],...rest]=entries;for(const value of variants){const next={...options};if(value)next[key]=value;else delete next[key];combinations(rest,fn,next,[...values,value]);}}
function pattern(formatter){const resolved=formatter.resolvedOptions();const alternate=formatter.formatToParts(Date.UTC(2006,1,3,7,4,5,123));const joined=formatter.formatToParts(reference).map(p=>p.value).join('');const formatted=formatter.format(reference);if(formatted!==joined&&formatted!==joined.replaceAll('\u202f',' '))throw Error('Unmodelled native ICU literal difference');return {FormatNarrowSpace:formatted!==joined,Parts:formatter.formatToParts(reference).map(p=>{
 if(p.type==='literal')return {Literal:p.value};let width=resolved[p.type]||'';let names;
 if(p.type==='month'&&!/^\d+$/.test(p.value))names=Array.from({length:12},(_,m)=>formatter.formatToParts(Date.UTC(2026,m,23,17,4,5,123)).find(part=>part.type==='month').value);
 if(p.type==='weekday')names=Array.from({length:7},(_,d)=>formatter.formatToParts(Date.UTC(2026,10,22+d,17,4,5,123)).find(part=>part.type==='weekday').value);
 if(p.type==='era')names=[formatter.formatToParts(-62167219200000).find(part=>part.type==='era').value,p.value];
 if(!width){if(p.type==='year')width=p.value.length===2?'2-digit':'numeric';else if(['month','day','hour','minute','second'].includes(p.type)&&!names){const value=alternate.find(part=>part.type===p.type).value;width=value.startsWith('0')?'2-digit':'numeric';}else if(p.type==='timeZoneName')width=p.value.length>3?'long':'short';}
 return {Field:p.type,Width:width,...(names?{Names:names}:{})};}),Resolved:resolved};}
const data={Versions:{Node:process.versions.node,ICU:process.versions.icu,CLDR:process.versions.cldr,TZ:process.versions.tz,Unicode:process.versions.unicode},Locales:{}};
for(const locale of locales){const record={Dates:{},Times:{},Styles:{},Months:{},Weekdays:{},Eras:{},DayPeriods:{}};data.Locales[locale]=record;
combinations(Object.entries(fields),(options,values)=>{
 if(!Object.keys(options).length)return;
 const p=pattern(new Intl.DateTimeFormat(locale,{...options,timeZone:'UTC'}));
 function separator(extra,target){const joined=new Intl.DateTimeFormat(locale,{...options,...extra,timeZone:'UTC'}).formatToParts(reference);let last=-1,first=joined.length;for(let i=0;i<joined.length;i++){if(['year','month','day','weekday','era'].includes(joined[i].type))last=i;if(joined[i].type===target&&first===joined.length)first=i;}return joined.slice(last+1,first).map(x=>x.value).join('');}
 p.Join=separator({hour:'numeric',minute:'numeric'},'hour');
 p.ZoneJoin=separator({timeZoneName:'short'},'timeZoneName');
 record.Dates[values.join('|')]=p;
});
combinations([['hour',['','numeric','2-digit']],['minute',['','numeric','2-digit']],['second',['','numeric','2-digit']],['fractionalSecondDigits',['',1,2,3]],['hourCycle',['h11','h12','h23','h24']]],(options,values)=>{if(!options.hour&&!options.minute&&!options.second&&!options.fractionalSecondDigits)return;const p=pattern(new Intl.DateTimeFormat(locale,{...options,timeZone:'UTC'}));record.Times[values.join('|')]=p;});
for(const dateStyle of ['','full','long','medium','short'])for(const timeStyle of ['','full','long','medium','short'])for(const hourCycle of ['h11','h12','h23','h24']){if(!dateStyle&&!timeStyle)continue;const options={timeZone:'UTC',hourCycle};if(dateStyle)options.dateStyle=dateStyle;if(timeStyle)options.timeStyle=timeStyle;record.Styles[[dateStyle,timeStyle,hourCycle].join('|')]=pattern(new Intl.DateTimeFormat(locale,options));}
for(const style of ['long','short','narrow']){record.Months[style]=Array.from({length:12},(_,m)=>new Intl.DateTimeFormat(locale,{month:style,timeZone:'UTC'}).format(Date.UTC(2026,m,23)));record.Weekdays[style]=Array.from({length:7},(_,d)=>new Intl.DateTimeFormat(locale,{weekday:style,timeZone:'UTC'}).format(Date.UTC(2026,10,22+d)));record.Eras[style]=[new Intl.DateTimeFormat(locale,{era:style,timeZone:'UTC'}).formatToParts(-62167219200000).find(p=>p.type==='era').value,new Intl.DateTimeFormat(locale,{era:style,timeZone:'UTC'}).formatToParts(reference).find(p=>p.type==='era').value];}
for(const cycle of ['h11','h12'])record.DayPeriods[cycle]=[0,13].map(hour=>new Intl.DateTimeFormat(locale,{hour:'numeric',hourCycle:cycle,timeZone:'UTC'}).formatToParts(Date.UTC(2026,10,23,hour)).find(p=>p.type==='dayPeriod').value);
}
const zoneData={Version:process.versions.tz,Start:Date.UTC(1900,0,1),End:Date.UTC(2101,0,1),Zones:{}};
function offsetOf(formatter,time){const value=formatter.formatToParts(time).find(p=>p.type==='timeZoneName').value;if(value==='GMT')return 0;const m=value.match(/^GMT([+-])(\d+):(\d+)(?::(\d+))?$/);if(!m)throw Error(value);return (m[1]==='-'?-1:1)*(Number(m[2])*3600+Number(m[3])*60+Number(m[4]||0));}
for(const zone of zones){const formatter=new Intl.DateTimeFormat('en-US',{timeZone:zone,timeZoneName:'longOffset'});const initial=offsetOf(formatter,zoneData.Start);const transitions=[];let previous=initial;for(let t=zoneData.Start+86400000;t<=zoneData.End;t+=86400000){const current=offsetOf(formatter,t);if(current!==previous){let low=t-86400000,high=t;while(high-low>1000){const mid=Math.floor((low+high)/2000)*1000;if(offsetOf(formatter,mid)===previous)low=mid;else high=mid;}transitions.push([high,current]);previous=current;}}
const names={};for(const locale of locales){names[locale]={};for(const style of ['short','long','shortGeneric','longGeneric'])names[locale][style]=[Date.UTC(2026,0,15),Date.UTC(2026,6,15)].map(t=>new Intl.DateTimeFormat(locale,{timeZone:zone,timeZoneName:style}).formatToParts(t).find(p=>p.type==='timeZoneName').value);}
zoneData.Zones[zone]={Initial:initial,Transitions:transitions,Names:names,WinterOffset:offsetOf(formatter,Date.UTC(2026,0,15))};}
// Intern identical patterns and omit repeated locale metadata. Loading Intl
// does not allocate a fresh CLDR token tree for every option combination.
data.Patterns=[];data.Names=[];const patterns=new Map(),nameSets=new Map();
for(const record of Object.values(data.Locales))for(const kind of ['Dates','Times','Styles'])for(const [key,p] of Object.entries(record[kind])){
 p.Parts=p.Parts.map(token=>{if(token.Literal!==undefined)return ['literal',token.Literal];const result=[token.Field,token.Width];if(token.Names){const key=JSON.stringify(token.Names);if(!nameSets.has(key)){data.Names.push(token.Names);nameSets.set(key,data.Names.length);}result.push(nameSets.get(key));}return result;});
 p.Resolved=Object.fromEntries(Object.entries(p.Resolved).filter(([key])=>['year','month','day','weekday','era','hour','minute','second','fractionalSecondDigits','hourCycle','hour12'].includes(key)));
 const serialized=JSON.stringify(p);if(!patterns.has(serialized)){data.Patterns.push(p);patterns.set(serialized,data.Patterns.length);}record[kind][key]=patterns.get(serialized);
}
fs.writeFileSync(path.join(root,'src/HTMLEngine/JavaScript/IntlDateData.luau'),'--!strict\n-- Generated native CLDR/ICU snapshot by scripts/generate-intl-date-data.cjs.\nreturn '+lua(data)+'\n');
fs.writeFileSync(path.join(root,'src/HTMLEngine/JavaScript/IntlTimeZoneData.luau'),'--!strict\n-- Generated IANA transitions from native ICU; 1900-2100, explicit zone profile.\nreturn '+lua(zoneData)+'\n');
fs.writeFileSync(path.join(root,'scripts/data/intl-date-manifest.json'),JSON.stringify({...data.Versions,Locales:locales,Zones:zones,Start:zoneData.Start,End:zoneData.End},null,2)+'\n');
console.log('Generated date/zone data:',data.Versions,locales.length,'locales',zones.length,'zones');
