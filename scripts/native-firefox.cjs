// Isolated headless Firefox WebDriver BiDi reference captures. This owns only
// its new process/profile and never attaches to an existing user browser.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
async function openFirefox(folder){
  const profile=path.join(folder,'firefox-'+Date.now()+'-'+process.pid);fs.mkdirSync(profile,{recursive:true});
  const child=cp.spawn(process.env.FIREFOX_BIN||'C:/Program Files/Mozilla Firefox/firefox.exe',[
    '--headless','--no-remote','--profile',profile,'--remote-debugging-port','0','about:blank',
  ],{windowsHide:true,stdio:['ignore','ignore','pipe']});
  let socket,nextId=0,stderr='',launchError;const pending=new Map();
  child.on('error',error=>{launchError=error;});child.stderr.on('data',chunk=>{stderr=(stderr+chunk).slice(-8192);});
  function send(method,params={}){return new Promise((resolve,reject)=>{
    const id=++nextId,timer=setTimeout(()=>{pending.delete(id);reject(new Error('BiDi timeout: '+method));},10000);
    pending.set(id,{resolve,reject,timer});socket.send(JSON.stringify({id,method,params}));
  });}
  async function close(){
    if(socket?.readyState===WebSocket.OPEN){try{await send('session.end');}catch{}socket.close();}
    if(child.exitCode===null)child.kill();
  }
  try{
    const deadline=Date.now()+10000;let endpoint;
    while(!endpoint){
      if(launchError)throw launchError;
      if(child.exitCode!==null||Date.now()>deadline)throw new Error('Firefox failed to start: '+stderr);
      endpoint=stderr.match(/WebDriver BiDi listening on (ws:\/\/[^\s]+)/)?.[1];
      if(!endpoint)await new Promise(resolve=>setTimeout(resolve,50));
    }
    socket=new WebSocket(endpoint+'/session');
    await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
    socket.addEventListener('message',message=>{
      const value=JSON.parse(message.data),entry=pending.get(value.id);if(!entry)return;
      pending.delete(value.id);clearTimeout(entry.timer);
      if(value.type==='error')entry.reject(new Error(value.error+': '+value.message));else entry.resolve(value.result);
    });
    socket.addEventListener('close',()=>{for(const entry of pending.values()){clearTimeout(entry.timer);entry.reject(new Error('Firefox closed'));}pending.clear();});
    const session=await send('session.new',{capabilities:{alwaysMatch:{}}});
    const context=(await send('browsingContext.getTree')).contexts[0].context;
    async function evaluate(expression){
      const value=await send('script.evaluate',{expression:'JSON.stringify('+expression+')',target:{context},awaitPromise:true});
      if(value.type!=='success')throw new Error('Firefox evaluation failed: '+JSON.stringify(value.exceptionDetails));
      return JSON.parse(value.result.value);
    }
    return {evaluate,close,capabilities:session.capabilities,
      async load(html){await send('browsingContext.navigate',{context,url:'data:text/html;charset=utf-8,'+encodeURIComponent(html),wait:'complete'});},
    };
  }catch(error){await close();throw error;}
}
module.exports={openFirefox};
