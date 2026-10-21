const fs=require('node:fs'),path=require('node:path');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..'),folder=path.join(root,'build/quirks-layout-reference');fs.mkdirSync(folder,{recursive:true});
const image='<img id="target" width="120" height="80" src="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'120\' height=\'80\'%3E%3C/svg%3E">';
const probes=[
 ['empty root/body','',''],
 ['body without margins','body{margin:0}',''],
 ['half viewport','body{margin:0}#target{height:50%}','<div id="target"></div>'],
 ['half viewport with body margin','#target{height:50%}','<div id="target"></div>'],
 ['nested automatic block','body{margin:0}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['nested automatic edges','body{margin:0}#ancestor{padding:12px;border:2px solid;margin:4px}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['explicit ancestor','body{margin:0}#ancestor{height:300px}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['minimum automatic ancestor','body{margin:0}#ancestor{min-height:100px}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['maximum automatic ancestor','body{margin:0}#ancestor{max-height:100px}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['percentage chain','body{margin:0}#ancestor{height:50%}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['absolute automatic ancestor','body{margin:0}#ancestor{position:absolute;top:0}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['absolute stretched ancestor','body{margin:0}#ancestor{position:absolute;top:0;bottom:0}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['flex automatic ancestor','body{margin:0}#ancestor{display:flex;align-items:flex-start}#target{height:50%}#sibling{height:80px}','<section id="ancestor"><div id="target"></div><div id="sibling"></div></section>'],
 ['grid automatic ancestor','body{margin:0}#ancestor{display:grid;grid-template-columns:1fr 1fr;align-items:start}#target{height:50%}#sibling{height:80px}','<section id="ancestor"><div id="target"></div><div id="sibling"></div></section>'],
 ['floating automatic ancestor','body{margin:0}#ancestor{float:left;width:200px}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['root explicit height','body{margin:0}html{height:400px}#target{height:50%}','<div id="target"></div>'],
 ['root edges','html{margin:10px;padding:12px;border:2px solid}body{margin:4px;padding:6px;border:2px solid}#target{height:50%}','<div id="target"></div>'],
 ['body positioned absolute','body{position:absolute;margin:0}#target{height:50%}','<div id="target"></div>'],
 ['body explicit height','body{margin:0;height:200px}#target{height:50%}','<div id="target"></div>'],
 ['overflowing body','body{margin:0}#target{height:900px}','<div id="target"></div>'],
 ['root percentage height','html{height:50%}body{margin:0}#target{height:50%}','<div id="target"></div>'],
 ['root minimum height','html{min-height:800px}body{margin:0}#target{height:50%}','<div id="target"></div>'],
 ['root maximum height','html{max-height:200px}body{margin:0}#target{height:50%}','<div id="target"></div>'],
 ['body minimum height','body{margin:0;min-height:800px}#target{height:50%}','<div id="target"></div>'],
 ['body maximum height','body{margin:0;max-height:200px}#target{height:50%}','<div id="target"></div>'],
 ['body edges','body{margin:10px;padding:12px;border:2px solid}#target{height:50%}','<div id="target"></div>'],
 ['automatic height percentage minimum','body{margin:0}#target{min-height:50%}','<div id="target"></div>'],
 ['fixed height percentage maximum','body{margin:0}#target{height:500px;max-height:50%}','<div id="target"></div>'],
 ['percentage height minimum','body{margin:0}#target{height:50%;min-height:90%}','<div id="target"></div>'],
 ['percentage height maximum','body{margin:0}#target{height:50%;max-height:10%}','<div id="target"></div>'],
 ['nested percentage minimum','body{margin:0}#target{min-height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['nested percentage maximum','body{margin:0}#target{height:500px;max-height:10%}','<section id="ancestor"><div id="target"></div></section>'],
 ['flow root automatic ancestor','body{margin:0}#ancestor{display:flow-root;padding:12px}#target{height:50%}','<section id="ancestor"><div id="target"></div></section>'],
 ['sticky percentage height','body{margin:0}#target{position:sticky;height:50%}','<div id="target"></div>'],
 ['percentage expression','body{margin:0}#target{height:calc(50% - 20px)}','<div id="target"></div>'],
 ['empty margin chain','body{margin:0}#ancestor{height:10px;margin-bottom:12px}#target{margin:20px 0 -4px}#sibling{height:10px;margin-top:-8px}','<section id="ancestor"></section><div id="target"></div><div id="sibling"></div>'],
 ['empty ending margin chain','body{margin:0;padding:1px}#ancestor{height:10px;margin-bottom:12px}#target{margin:20px 0 -4px}','<section id="ancestor"></section><div id="target"></div>'],
 ['block image percentage','body{margin:0}#target{display:block;height:50%}',image],
 ['block image nested percentage','body{margin:0}#target{display:block;height:50%}','<section id="ancestor">'+image+'</section>'],
 ['block image percentage minimum','body{margin:0}#target{display:block;min-height:50%}',image],
 ['block image percentage maximum','body{margin:0}#target{display:block;max-height:10%}',image],
 ['block image constrained height','body{margin:0}#target{display:block;height:50%;min-height:90%}',image],
 ['block image automatic width','body{margin:0}#target{display:block;width:auto;height:50%}',image],
 ['floating image intrinsic width','body{margin:0}#ancestor{float:left}#target{display:block;width:auto;height:50%}','<section id="ancestor">'+image+'</section>'],
 ['nested floating image intrinsic width','body{margin:0}#ancestor{float:left}#target{display:block;width:auto;height:50%}','<section id="ancestor"><div>'+image+'</div></section>'],
 ...[
  ['fixed content height','height:100px'],['fixed border height','height:100px;box-sizing:border-box'],
  ['minimum height','min-height:100px'],['maximum height','height:100px;max-height:60px'],
  ['auto cell percentage','height:50%'],['auto cell percentage minimum','min-height:50%'],
  ['auto cell percentage maximum','height:100px;max-height:10%'],
 ].map(([name,value])=>['table '+name,'body{margin:0;font-size:0;line-height:0}table{width:200px;border-spacing:0}td{padding:10px;border:2px solid;'+value+'}',
  '<table id="ancestor"><tr><td id="target"></td></tr></table>']),
 ['table spanning height','body{margin:0;font-size:0;line-height:0}table{border-spacing:2px}td{padding:1px;height:90px}',
  '<table id="ancestor"><tr><td id="target" rowspan="2"></td></tr><tr></tr></table>'],
 ...[
  ['adjacent inline images','',''],['spaced inline images',' ','body{word-spacing:5px}'],
  ['specified cell width','','td{width:30px}'],['block images','','img{display:block}'],
 ].map(([name,gap,css])=>['table '+name,'body{margin:0;font-size:0;line-height:0}table{width:30px;border-spacing:0}td{padding:0}img{width:20px;height:10px}'+css,
  '<table id="ancestor"><tr><td id="target">'+image.replace('id="target"','')+gap+image.replace('id="target"','id="sibling"')+'</td></tr></table>']),
 ...[
  ['specified empty width','width:100px',''],['nowrap specified width','width:100px','nowrap'],
  ['nowrap overridden wrap','width:100px;white-space:normal','nowrap'],['nowrap zero width','width:0','nowrap'],
  ['nowrap percentage width','width:50%','nowrap'],
 ].map(([name,value,attr])=>['table '+name,'body{margin:0;word-spacing:5px}table{width:30px;border-spacing:0;font-size:0;line-height:0}td{padding:0;'+value+'}',
  '<table id="ancestor"><tr><td id="target" '+attr+'>X Y Z</td></tr></table>']),
 ...['100','0','50%',' 100tail','100.5','100.%','100. %','+100','-100','.5','1e2',''].map(value=>[
  'table nowrap width attribute '+JSON.stringify(value),'body{margin:0;word-spacing:5px;font-size:0;line-height:0}table{width:30px;border-spacing:0;font-size:0;line-height:0}td{padding:0}',
  '<table id="ancestor"><tr><td id="target" nowrap width="'+value+'">X Y Z</td></tr></table>']),
 ...[['override','width:20px'],['normal','white-space:normal'],['nowrap','white-space:nowrap'],['revert width','width:revert'],['revert white-space','white-space:revert'],['revert layer','width:revert-layer']].map(([name,css])=>[
  'table hinted '+name,'body{margin:0;word-spacing:5px;font-size:0;line-height:0}table{width:30px;border-spacing:0;font-size:0;line-height:0}td{padding:0;'+css+'}',
  '<table id="ancestor"><tr><td id="target" nowrap width="100">X Y Z</td></tr></table>']),
 ...[['table width','<table id="target" width="120"><tr><td></td></tr></table>'],
  ['table zero width','<table id="target" width="0"><tr><td></td></tr></table>'],
  ['cell height','<table id="ancestor"><tr><td id="target" height="40"></td></tr></table>'],
  ['row height','<table id="ancestor"><tr id="target" height="40"><td></td></tr></table>'],
  ['group height','<table id="ancestor"><tbody id="target" height="40"><tr><td></td></tr></tbody></table>'],
  ['column width','<table id="ancestor"><col width="80"><tr><td id="target"></td></tr></table>'],
  ['column group width','<table id="ancestor"><colgroup width="80"></colgroup><tr><td id="target"></td></tr></table>'],
 ].map(([name,body])=>['table hinted '+name,'body{margin:0;font-size:0;line-height:0}table{border-spacing:0}td{padding:0}',body]),
 ...[
  ['automatic rows','height:40px','','<tr id="sibling"><td></td></tr><tr><td></td></tr>'],
  ['unequal fixed rows','height:60px','','<tr id="sibling" style="height:10px"><td></td></tr><tr style="height:20px"><td></td></tr>'],
  ['fixed and automatic rows','height:40px','','<tr id="sibling" style="height:10px"><td></td></tr><tr><td></td></tr>'],
  ['percentage','height:50%','height:100px','<tr id="sibling"><td></td></tr>'],
  ['percentage with gaps','height:50%','height:100px;border-spacing:2px','<tr id="sibling"><td></td></tr>'],
  ['larger than table','height:60px','height:40px','<tr id="sibling"><td></td></tr>'],
  ['empty','height:40px','',''],
  ['empty spaced','height:40px','border-spacing:2px',''],
  ['empty percentage','height:50%','height:100px',''],
  ['empty collapsed','height:40px','border-collapse:collapse',''],
  ['paint rows','height:40px;background:red','background:blue','<tr id="sibling"><td></td></tr><tr><td></td></tr>'],
  ['paint empty','height:40px;background:red','background:blue',''],
  ['minimum ignored','min-height:40px','','<tr id="sibling"><td></td></tr>'],
  ['maximum ignored','height:40px;max-height:10px','','<tr id="sibling"><td></td></tr>'],
  ['spanning cell','height:40px','','<tr id="sibling"><td rowspan="2" style="height:10px"></td></tr><tr></tr>'],
 ].map(([name,group,table,rows])=>['table group '+name,'body{margin:0;font-size:0;line-height:0}table{width:100px;font-size:0;line-height:0;border-spacing:0;'+table+'}td{padding:0}#target{'+group+'}',
  '<table id="ancestor"><tbody id="target">'+rows+'</tbody><tbody><tr><td style="height:10px"></td></tr></tbody></table>']),
 ['table last empty group','body{margin:0;font-size:0;line-height:0}table{width:100px;border-spacing:2px;font-size:0;line-height:0}td{padding:0}',
  '<table id="ancestor"><tbody><tr id="sibling"><td style="height:10px"></td></tr></tbody><tbody id="target" style="height:40px"></tbody></table>'],
 ...[
  ['empty','<table id="target"></table>'],['empty group','<table id="target"><tbody></tbody></table>'],
  ['empty caption','<table id="target"><caption></caption></table>'],
  ['empty column group','<table id="target"><colgroup></colgroup></table>'],
  ['column','<table id="target"><colgroup><col></colgroup></table>'],
  ['CSS empty','<div id="target" style="display:table"></div>'],
 ].map(([name,body])=>['table collapse '+name,'body{margin:0;font-size:0;line-height:0}#target{width:200px;height:100px;padding:10px;border:2px solid}',body]),
 ...[
  ['reset typography',''],['explicit inherit','table{font:inherit;white-space:inherit;text-align:inherit;color:inherit}'],
  ['initial color','table{color:initial}'],['own color and decoration','table{color:blue;text-decoration:overline}'],
 ].map(([name,css])=>['table '+name,'body{margin:0;color:green;font-size:30px;font-weight:700;font-style:italic;line-height:50px;white-space:nowrap;text-align:right;text-decoration:underline}section{color:red}table{width:200px;border-spacing:0}td{padding:0}'+css,
  '<section id="ancestor"><table id="target"><tr><td><div style="height:10px"></div></td></tr></table></section>']),
 ...[
  ['baseline',image,''],['middle',image,'#target{vertical-align:middle}'],
  ['top',image,'#target{vertical-align:top}'],['bottom',image,'#target{vertical-align:bottom}'],
  ['break between images',image+'<br>'+image.replace('id="target"','id="sibling"'),''],
  ['break alone','<br>',''],['empty inline','<span></span>'+image,''],
  ['empty inline side padding','<span style="padding-left:1px"></span>'+image,''],
  ['collapsed whitespace inline','<span> </span>'+image,''],
  ['collapsed padded whitespace inline','<span style="padding-left:1px"> </span>'+image,''],
  ['space across whitespace inline','X <span> </span> X'+image,'body{word-spacing:5px}'],
  ['space across padded whitespace inline','X <span style="padding-left:1px"> </span> X'+image,'body{word-spacing:5px}'],
  ['preserved whitespace inline','<span style="white-space:pre"> </span>'+image,''],
  ['zero-size text','X'+image,''],
  ['space across empty inline','X <span></span> X'+image,'body{word-spacing:5px}'],
  ['space across padded empty inline','X <span style="padding-left:1px"></span> X'+image,'body{word-spacing:5px}'],
  ['space after leading empty inline',' <span></span> '+image,'body{word-spacing:5px}'],
  ['space after leading padded inline',' <span style="padding-left:1px"></span> '+image,'body{word-spacing:5px}'],
  ['padded text inline','X<span style="padding:0 1px">Y</span>X'+image,''],
  ['background text inline','X<span style="background:blue">Y Z</span>X'+image,'body{word-spacing:5px}'],
 ].map(([name,body,css])=>['inline '+name,'body{margin:0;font-size:0;line-height:100px}#target,#sibling{width:30px;height:20px}'+css,body]),
 ];
(async()=>{
 const browser=await openBrowser(folder),cases=[];
 try{
  const userAgent=await browser.evaluate('navigator.userAgent');
  async function snapshot(height){
   await browser.send('Emulation.setDeviceMetricsOverride',{width:800,height,deviceScaleFactor:1,mobile:false});
   const boxes=await browser.evaluate(`(()=>{const list=[['html',document.documentElement],['body',document.body],...['ancestor','target','sibling'].map(id=>[id,document.getElementById(id)])];return list.filter(([,e])=>e).map(([id,e])=>{const r=e.getBoundingClientRect();return{id,x:r.x,y:r.y,width:r.width,height:r.height}})})()`);
   const layoutWidth=(await browser.send('Page.getLayoutMetrics')).cssLayoutViewport.clientWidth;
   return{viewport:[800,height],layoutWidth,boxes};
  }
  for(const[mode,doctype]of[['no-quirks','<!doctype html>'],['limited-quirks','<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">'],['quirks','']]){
   for(const[name,css,body]of probes){
    const html=doctype+'<html><head></head><body>'+body+'</body></html>';
    await browser.load(doctype+'<html><head><style>'+css+'</style></head><body>'+body+'</body></html>');
    const initial=await snapshot(600),resizes=[];
    const computed=await browser.evaluate(`(()=>{const node=document.getElementById('target');if(!node)return null;const s=getComputedStyle(node);return{fontSize:parseFloat(s.fontSize),fontWeight:Number(s.fontWeight),fontStyle:s.fontStyle,whiteSpace:s.whiteSpace,color:s.color,boxSizing:s.boxSizing}})()`);
    let afterBodyColor;
    if(['table reset typography','table explicit inherit','table initial color','table own color and decoration'].includes(name)) {
     afterBodyColor=await browser.evaluate(`(()=>{document.body.style.color='purple';return getComputedStyle(document.getElementById('target')).color})()`);
    }
    for(const height of[320,900,600,600])resizes.push(await snapshot(height));
    let dimensionMutations;
    if(name==='table nowrap width attribute "100"'){
     dimensionMutations=[];
     for(const value of['50%','0','100','-10',null]){
      await browser.evaluate(`(()=>{const e=document.getElementById('target');const v=${JSON.stringify(value)};if(v===null)e.removeAttribute('width');else e.setAttribute('width',v)})()`);
      dimensionMutations.push({value,...await snapshot(600)});
     }
    }
    let groupMutations;
    if(name==='table group automatic rows'||name==='table group empty'){
     groupMutations=[];
     for(const value of['80px','20px','0px','40px']){
      await browser.evaluate(`document.getElementById('target').style.height=${JSON.stringify(value)}`);
      groupMutations.push({value,...await snapshot(600)});
     }
    }
    let groupColorMutations;
    if(name.startsWith('table group paint ')){
     groupColorMutations=[];
     for(const value of['green','rgba(0,128,0,0.5)','red']){
      const color=await browser.evaluate(`(()=>{const e=document.getElementById('target');e.style.background=${JSON.stringify(value)};const parts=getComputedStyle(e).backgroundColor.match(/[0-9.]+/g).map(Number);return[parts[0],parts[1],parts[2],parts[3]??1]})()`);
      groupColorMutations.push({value,color,...await snapshot(600)});
     }
    }
    cases.push({name:mode+' '+name,mode,html,css,computed,afterBodyColor,dimensionMutations,groupMutations,groupColorMutations,...initial,resizes});
   }
  }
  fs.writeFileSync(path.join(root,'tests/fixtures/quirks-layout-browser.json'),JSON.stringify({browser:userAgent,captured:'2026-10-09',standards:['https://quirks.spec.whatwg.org/#the-percentage-height-calculation-quirk','https://quirks.spec.whatwg.org/#the-html-element-fills-the-viewport-quirk','https://quirks.spec.whatwg.org/#the-body-element-fills-the-html-element-quirk','https://quirks.spec.whatwg.org/#the-line-height-calculation-quirk','https://quirks.spec.whatwg.org/#the-blocks-ignore-line-height-quirk'],cases},null,2)+'\n');
  console.log('Quirks layout: '+cases.length+' native block-height/viewport reference scenes captured.');
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
