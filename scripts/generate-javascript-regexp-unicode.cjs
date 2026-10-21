// Reproducible Unicode 17.0 tables for ECMAScript RegExp. No runtime network use.
// Unicode data files: https://www.unicode.org/license.txt
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),cache=path.join(root,'build/javascript-regexp/unicode');
const base='https://www.unicode.org/Public/17.0.0/ucd/';
const names=['UnicodeData.txt','Scripts.txt','ScriptExtensions.txt','PropList.txt','DerivedCoreProperties.txt','DerivedNormalizationProps.txt','PropertyAliases.txt','PropertyValueAliases.txt','CaseFolding.txt','emoji/emoji-data.txt','../emoji/emoji-sequences.txt','../emoji/emoji-zwj-sequences.txt'];
fs.mkdirSync(cache,{recursive:true});
function lines(text){return text.split(/\r?\n/).map(l=>l.split('#')[0].trim()).filter(Boolean).map(l=>l.split(';').map(v=>v.trim()));}
function range(value){const p=value.split('..').map(x=>parseInt(x,16));return [p[0],p[1]??p[0]];}
function merge(list){list.sort((a,b)=>a[0]-b[0]);const out=[];for(const [a,b]of list){const p=out.at(-1);if(p&&a<=p[1]+1)p[1]=Math.max(b,p[1]);else out.push([a,b]);}return out;}
async function main(){
 const data={};for(const name of names){const file=path.join(cache,name.replaceAll('/','-'));if(!fs.existsSync(file)){const response=await fetch(new URL(name,base));if(!response.ok)throw Error(name+': '+response.status);fs.writeFileSync(file,await response.text());}data[name]=fs.readFileSync(file,'utf8');}
 const props=new Map(),aliases=new Map(),fold=new Map(),upper=new Map();
 function add(key,a,b=a){if(!props.has(key))props.set(key,[]);props.get(key).push([a,b]);}
 const pa=lines(data['PropertyAliases.txt']),va=lines(data['PropertyValueAliases.txt']);
 const scriptNames=new Map();for(const row of va)if(row[0]==='sc')for(const name of row.slice(1))scriptNames.set(name,row[2]);
 let first;for(const row of lines(data['UnicodeData.txt'])){const cp=parseInt(row[0],16);if(row[1].endsWith(', First>')){first=cp;continue;}const start=row[1].endsWith(', Last>')?first:cp;add('gc='+row[2],start,cp);if(row[9]==='Y')add('binary=Bidi_Mirrored',start,cp);if(row[12])upper.set(cp,parseInt(row[12],16));}
 const assigned=merge([...props].filter(([k])=>k.startsWith('gc=')).flatMap(([,v])=>v));let cursor=0;for(const [a,b]of assigned){if(a>cursor)add('gc=Cn',cursor,a-1);cursor=b+1;}if(cursor<=0x10ffff)add('gc=Cn',cursor,0x10ffff);
 for(const family of ['L','M','N','P','S','Z','C']){const ranges=[...props].filter(([k])=>k.startsWith('gc='+family)&&k.length===5).flatMap(([,v])=>v);props.set('gc='+family,ranges);}
 props.set('gc=LC',['Lu','Ll','Lt'].flatMap(k=>props.get('gc='+k)));props.set('binary=Assigned',assigned);add('binary=ASCII',0,127);add('binary=Any',0,0x10ffff);
 for(const row of lines(data['Scripts.txt'])){const [a,b]=range(row[0]);add('sc='+row[1],a,b);}
 const scriptAssigned=merge([...props].filter(([k])=>k.startsWith('sc=')).flatMap(([,v])=>v));cursor=0;for(const [a,b]of scriptAssigned){if(a>cursor)add('sc=Unknown',cursor,a-1);cursor=b+1;}if(cursor<=0x10ffff)add('sc=Unknown',cursor,0x10ffff);
 const extensionRows=lines(data['ScriptExtensions.txt']).map(row=>({range:range(row[0]),names:row[1].split(/\s+/).map(n=>scriptNames.get(n))}));
 for(const [key,ranges]of [...props])if(key.startsWith('sc=')){
  const name=key.slice(3);const out=[];
  for(const [a,b]of ranges){let segments=[[a,b]];for(const row of extensionRows){const [x,y]=row.range;if(y<a||x>b)continue;segments=segments.flatMap(([l,r])=>y<l||x>r?[[l,r]]:[[l,Math.min(r,x-1)],[Math.max(l,y+1),r]].filter(([u,v])=>u<=v));}out.push(...segments);}
  for(const row of extensionRows)if(row.names.includes(name))out.push(row.range);props.set('scx='+name,out);
 }
 const permitted=new Set(('ASCII ASCII_Hex_Digit Alphabetic Any Assigned Bidi_Control Bidi_Mirrored Case_Ignorable Cased Changes_When_Casefolded Changes_When_Casemapped Changes_When_Lowercased Changes_When_NFKC_Casefolded Changes_When_Titlecased Changes_When_Uppercased Dash Default_Ignorable_Code_Point Deprecated Diacritic Emoji Emoji_Component Emoji_Modifier Emoji_Modifier_Base Emoji_Presentation Extended_Pictographic Extender Grapheme_Base Grapheme_Extend Hex_Digit IDS_Binary_Operator IDS_Trinary_Operator ID_Continue ID_Start Ideographic Join_Control Logical_Order_Exception Lowercase Math Noncharacter_Code_Point Pattern_Syntax Pattern_White_Space Quotation_Mark Radical Regional_Indicator Sentence_Terminal Soft_Dotted Terminal_Punctuation Unified_Ideograph Uppercase Variation_Selector White_Space XID_Continue XID_Start').split(' '));
 for(const file of ['PropList.txt','DerivedCoreProperties.txt','DerivedNormalizationProps.txt','emoji/emoji-data.txt'])for(const row of lines(data[file]))if(permitted.has(row[1])){const [a,b]=range(row[0]);add('binary='+row[1],a,b);}
 for(const row of pa){const canonical=row[1];if(permitted.has(canonical))for(const alias of row)aliases.set(alias,'binary='+canonical);}
 for(const name of ['ASCII','Any','Assigned'])aliases.set(name,'binary='+name);
 for(const row of va){if(row[0]==='gc')for(const alias of row.slice(1)){aliases.set(alias,'gc='+row[1]);for(const prefix of ['gc','General_Category'])aliases.set(prefix+'='+alias,'gc='+row[1]);}if(row[0]==='sc')for(const alias of row.slice(1))for(const prefix of ['sc','Script','scx','Script_Extensions'])aliases.set(prefix+'='+alias,(prefix==='sc'||prefix==='Script'?'sc=':'scx=')+row[2]);}
 for(const row of lines(data['CaseFolding.txt']))if(row[1]==='C'||row[1]==='S')fold.set(parseInt(row[0],16),parseInt(row[2],16));
 const stringProperties=new Map();for(const name of ['../emoji/emoji-sequences.txt','../emoji/emoji-zwj-sequences.txt'])for(const row of lines(data[name])){if(!stringProperties.has(row[1]))stringProperties.set(row[1],[]);const list=stringProperties.get(row[1]);if(row[0].includes('..')){const [a,b]=range(row[0]);for(let cp=a;cp<=b;cp++)list.push([cp]);}else list.push(row[0].split(/\s+/).map(cp=>parseInt(cp,16)));}stringProperties.set('RGI_Emoji',[...stringProperties.values()].flat());
 let out='--!strict\n-- Generated by scripts/generate-javascript-regexp-unicode.cjs. Unicode 17.0.0.\n-- Source: https://www.unicode.org/Public/17.0.0/ucd/ ; license: https://www.unicode.org/license.txt\nreturn {Version="17.0.0",Properties={\n';
 for(const [key,ranges]of [...props].sort(([a],[b])=>a.localeCompare(b)))out+=' ['+JSON.stringify(key)+']={'+merge(ranges).flat().join(',')+'},\n';
 out+='},Aliases={\n';for(const [alias,key]of [...aliases].sort(([a],[b])=>a.localeCompare(b)))if(props.has(key))out+=' ['+JSON.stringify(alias)+']='+JSON.stringify(key)+',\n';
 out+='},Fold={'+[...fold].map(([a,b])=>'['+a+']='+b).join(',')+'},Upper={'+[...upper].map(([a,b])=>'['+a+']='+b).join(',')+'},StringProperties={\n';for(const [name,values]of stringProperties)out+=' ['+JSON.stringify(name)+']={'+values.map(v=>'{'+v.join(',')+'}').join(',')+'},\n';out+='}}\n';
 const target=path.join(root,'src/HTMLEngine/JavaScript/RegExpUnicode.luau');fs.writeFileSync(target,out);console.log('Generated '+props.size+' property range tables, '+aliases.size+' aliases and '+fold.size+' fold mappings: '+out.length+' bytes');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
