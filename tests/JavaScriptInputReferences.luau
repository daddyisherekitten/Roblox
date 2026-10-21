--!strict
-- Native Chromium154 observations are retained in javascript-r04-input-browser.json.
return function(Parser,Runtime,Events)
 local messages={};local realm=Runtime.new(Parser.parseDocument('<!doctype html><html><body></body></html>'),{Events=Events.new(error),Diagnostic=function(m)table.insert(messages,m)end})
 realm:Run([=[
function check(v,m){if(!v)throw new Error(m)}
for(const dir of ['ltr','rtl','auto']){
 const p=document.createElement('p');p.dir=dir;p.textContent='אבגד הוז';document.body.append(p);const n=p.firstChild,s=getSelection(),values=[];
 for(const [direction,granularity] of [['right','character'],['left','character'],['forward','character'],['right','word'],['left','word'],['forward','lineboundary'],['backward','lineboundary']]){s.collapse(n,2);s.modify('move',direction,granularity);values.push(s.focusOffset)}
 check(values.join('|')===(dir==='ltr'?'3|1|3|5|0|8|0':'1|3|3|0|5|8|0'),'homogeneous RTL '+dir);s.removeAllRanges();p.remove();
}
let closed=false;function* roots(){try{yield {}}finally{closed=true}}try{getSelection().getComposedRanges({shadowRoots:roots()})}catch(e){check(e.name==='TypeError'&&!closed,'Chromium composed range conversion')}
let rangeClosed=false;function* targetRanges(){try{yield {}}finally{rangeClosed=true}}try{new InputEvent('beforeinput',{targetRanges:targetRanges()})}catch(e){check(e.name==='TypeError'&&!rangeClosed,'Chromium InputEvent conversion')}
const range=new StaticRange({startContainer:document.body,startOffset:0,endContainer:document.body,endOffset:0});
const input=new InputEvent('beforeinput',{inputType:'insertText',data:'A',targetRanges:[range]});const first=input.getTargetRanges(),second=input.getTargetRanges();
check(first.length===1&&first[0] instanceof StaticRange&&first[0]!==range&&first[0]!==second[0],'InputEvent copies StaticRange values');
first.length=0;check(input.getTargetRanges().length===1,'InputEvent arrays are fresh');
check(second[0].startContainer===document.body&&second[0].startOffset===0&&second[0].collapsed,'Copied target boundaries');
]=])
 assert(#messages==0,table.concat(messages,' | '));realm:Destroy()
 print('R04 native input references: direction/word/line, conversion errors and fresh StaticRange snapshots passed')
end
