// Own isolated headless Chromium. Shared programs also run in the engine VM.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {openBrowser}=require('./native-browser.cjs');
const root=path.resolve(__dirname,'..');
const programs=[
 ['priorities',`var log=[];var c=new TaskController({priority:'background'});var jobs=[];jobs.push(scheduler.postTask(()=>log.push('dynamic'),{signal:c.signal}));jobs.push(scheduler.postTask(()=>log.push('visible')));jobs.push(scheduler.postTask(()=>log.push('blocking'),{priority:'user-blocking'}));c.setPriority('user-blocking');Promise.all(jobs).then(()=>{globalThis.result=log.join('|')});`],
 ['yield-through-await',`var log=[];var c=new TaskController({priority:'background'});var jobs=[];jobs.push(scheduler.postTask(async()=>{log.push('start');await Promise.resolve();await scheduler.yield();log.push('resume');await scheduler.yield();log.push('again')},{signal:c.signal}));jobs.push(scheduler.postTask(()=>log.push('peer'),{priority:'background'}));Promise.all(jobs).then(()=>{globalThis.result=log.join('|')});`],
 ['then-context',`var log=[];var c=new TaskController({priority:'background'});var jobs=[];jobs.push(scheduler.postTask(()=>Promise.resolve().then(()=>scheduler.yield()).then(()=>log.push('continued')),{signal:c.signal}));jobs.push(scheduler.postTask(()=>log.push('blocking'),{priority:'user-blocking'}));jobs.push(scheduler.postTask(()=>log.push('peer'),{priority:'background'}));Promise.all(jobs).then(()=>{globalThis.result=log.join('|')});`],
 ['invalid-options',`var log=[];var jobs=[];for(const x of [{delay:-1},{delay:Infinity},{delay:1n},{priority:'bad'},{signal:null},4])jobs.push(scheduler.postTask(()=>{},x).then(()=>log.push('resolved'),e=>log.push(e.name)));Promise.all(jobs).then(()=>{globalThis.result=log.join('|')});`],
 ['priority-events',`var log=[],c=new TaskController({priority:'background'}),d=TaskSignal.any([],{priority:c.signal});d.onprioritychange=e=>log.push('child:'+e.previousPriority+':'+d.priority);c.signal.onprioritychange=e=>{log.push('root:'+e.previousPriority+':'+c.signal.priority);try{c.setPriority('background')}catch(x){log.push(x.name)}};c.setPriority('user-blocking');c.setPriority('user-blocking');globalThis.result=log.join('|');`],
 ['abort-after-start',`var log=[],c=new TaskController();var release;var entered=new Promise(r=>release=r);var a=scheduler.postTask(async()=>{log.push('start');await entered;await scheduler.yield();log.push('forbidden')},{signal:c.signal}).catch(e=>log.push('abort:'+e));scheduler.postTask(()=>{c.abort('reason');release()},{priority:'background'});a.then(()=>{globalThis.result=log.join('|')});`],
 ['event-conversion-order',`var log=[];try{new TaskPriorityChangeEvent({toString(){log.push('type');return 'priority'}},4)}catch(e){log.push(e.name)}try{new TaskPriorityChangeEvent({toString(){throw 'type-error'}},4)}catch(e){log.push(e)}globalThis.result=log.join('|');`],
 ['abort-running-value',`var c=new TaskController();scheduler.postTask(()=>{c.abort('stopped');return 42},{signal:c.signal}).then(value=>globalThis.result='value:'+value,e=>globalThis.result='abort:'+e);`],
 ['abort-running-throw',`var c=new TaskController();scheduler.postTask(()=>{c.abort('stopped');throw 27},{signal:c.signal}).then(value=>globalThis.result='value:'+value,e=>globalThis.result='abort:'+e);`],
 ['returned-thenable-context',`var log=[],c=new TaskController();scheduler.postTask(()=>{Promise.resolve().then(()=>{c.abort('stopped');return {then(resolve){scheduler.yield().then(()=>{log.push('resolved');resolve()},e=>{log.push('abort:'+e);resolve()})}}}).then(()=>globalThis.result=log.join('|'))},{signal:c.signal}).catch(()=>{});`],
 ['scheduler-property',`var d=Object.getOwnPropertyDescriptor(globalThis,'scheduler');globalThis.result=JSON.stringify([typeof d.get,typeof d.set,d.enumerable,d.configurable,'writable' in d]);`],
 ['scheduler-replaceable',`var d=Object.getOwnPropertyDescriptor(globalThis,'scheduler'),o={},out=[];for(var fn of [()=>d.get.call(o),()=>d.set.call(o,9)])try{fn();out.push('unexpected')}catch(e){out.push(e.name)}out.push(d.get.call(null)===scheduler);scheduler=17;var replaced=Object.getOwnPropertyDescriptor(globalThis,'scheduler');out.push(scheduler,replaced.value,replaced.writable,replaced.enumerable,replaced.configurable,Object.hasOwn(o,'scheduler'));globalThis.result=JSON.stringify(out);`],
];
(async()=>{
 const browser=await openBrowser(path.join(root,'build/engine-expansion-20261018/scheduler-reference'));
 try{
  const version=await browser.send('Browser.getVersion'),records=[];
  for(const [name,source]of programs){
   await browser.load('<!doctype html><title>Scheduling reference</title>');
   await browser.evaluate(source);
   const result=await browser.evaluate(`new Promise((resolve,reject)=>{let count=0;function poll(){if(globalThis.result!==undefined)return resolve(globalThis.result);if(++count>1000)return reject(Error('Reference did not settle'));setTimeout(poll,2)}poll()})`);
   records.push({name,source,result});
  }
  const reference='https://wicg.github.io/scheduling-apis/';
  const response=await fetch(reference);if(!response.ok)throw Error('Scheduling reference HTTP '+response.status);
  const standard=await response.text(),snapshot='build/engine-expansion-20261018/scheduler-standard.html';fs.writeFileSync(path.join(root,snapshot),standard);
  const output={schema:1,capturedAt:new Date().toISOString(),browser:version.product,reference,standard:{documentDate:'30 May 2025',snapshot,sha256:crypto.createHash('sha256').update(standard).digest('hex')},scope:'Strict intra-Scheduler priority and continuation ordering, Promise inheritance, IDL failures, dynamic events and abort; no UA task-source/native compositor timing guarantee',records};
  fs.writeFileSync(path.join(root,'tests/fixtures/javascript-scheduler-native.json'),JSON.stringify(output,null,2)+'\n');
  console.log('Scheduler reference:',records.length,'isolated native programs');for(const record of records)console.log(record.name+': '+record.result);
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
