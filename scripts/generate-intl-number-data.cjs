// Snapshot CLDR number affixes from the native reference, including grammatical
// one/other currency and unit names. No hand-picked translation substitutions.
const fs=require('fs'),path=require('path');const root=path.resolve(__dirname,'..');
function lua(value){if(typeof value==='string')return JSON.stringify(value);if(typeof value==='number')return String(value);if(Array.isArray(value))return '{'+value.map(lua).join(',')+'}';return '{'+Object.entries(value).map(([k,v])=>'['+JSON.stringify(k)+']='+lua(v)).join(',')+'}';}
function affix(f,n,kind){return f.formatToParts(n).filter(p=>p.type===kind||p.type==='literal').map(p=>[p.type,p.value]);}
const data={Version:{ICU:process.versions.icu,CLDR:process.versions.cldr},Locales:{}};
const units=Intl.supportedValuesOf('unit');const compounds=[];for(const unit of units)for(const denominator of ['second','minute','hour','day'])compounds.push(unit+'-per-'+denominator);
for(const locale of ['de-DE','en-US','en-GB']){const record={Currencies:{},Units:{},Compact:{}};data.Locales[locale]=record;
for(const currency of Intl.supportedValuesOf('currency')){const f=new Intl.NumberFormat(locale,{style:'currency',currency,currencyDisplay:'name',maximumFractionDigits:0});const digits=new Intl.NumberFormat(locale,{style:'currency',currency}).resolvedOptions().maximumFractionDigits;const symbols={};for(const currencyDisplay of ['symbol','narrowSymbol'])symbols[currencyDisplay]=new Intl.NumberFormat(locale,{style:'currency',currency,currencyDisplay}).formatToParts(1).find(p=>p.type==='currency').value;record.Currencies[currency]={Digits:digits,Names:[affix(f,1,'currency'),affix(f,2,'currency')],Symbols:symbols};}
for(const unit of [...units,...compounds]){record.Units[unit]={};for(const unitDisplay of ['long','short','narrow']){const f=new Intl.NumberFormat(locale,{style:'unit',unit,unitDisplay});record.Units[unit][unitDisplay]=[affix(f,1,'unit'),affix(f,2,'unit')];}}
for(const compactDisplay of ['short','long']){record.Compact[compactDisplay]={};for(const exponent of [3,6,9,12]){const f=new Intl.NumberFormat(locale,{notation:'compact',compactDisplay,maximumFractionDigits:0});record.Compact[compactDisplay][exponent]=[affix(f,10**exponent,'compact'),affix(f,2*10**exponent,'compact')];}}
}
fs.writeFileSync(path.join(root,'src/HTMLEngine/JavaScript/IntlNumberData.luau'),'--!strict\n-- Generated CLDR number affixes by scripts/generate-intl-number-data.cjs.\nreturn '+lua(data)+'\n');console.log('Generated versioned number affixes',data.Version,'simple units',units.length,'compounds',compounds.length);
