function editingSelectorChecks() {
  const H='http://www.w3.org/1999/xhtml', records=[];
  document.body.innerHTML='';
  function add(name,e) {
    records.push({name,value:[e.matches(':read-write'),e.matches(':read-only'),e.isContentEditable]});
  }
  const host=document.createElement('section'),child=document.createElement('span'),island=document.createElement('div'),nested=document.createElement('strong');
  host.append(child,island);island.append(nested);document.body.append(host);
  for(const value of [null,'','true','TRUE','plaintext-only','false','inherit','invalid']){
    if(value===null)host.removeAttribute('contenteditable');else host.setAttribute('contenteditable',value);
    add('host '+String(value),host);add('inherit '+String(value),child);
  }
  host.contentEditable='true';island.contentEditable='false';add('blocked island',island);add('blocked descendant',nested);
  nested.contentEditable='plaintext-only';add('nested plaintext host',nested);
  island.removeAttribute('contenteditable');add('live unblock',island);add('live nested plaintext',nested);
  for(const kind of ['input','textarea']){
    const e=document.createElement(kind);host.append(e);e.contentEditable='true';
    add(kind+' inherited editing',e);e.readOnly=true;add(kind+' readonly editing',e);e.readOnly=false;e.disabled=true;add(kind+' disabled editing',e);
    e.disabled=false;if(kind==='input'){e.type='checkbox';add('checkbox editing',e);e.type='text';add('text editing',e);}
  }
  const prefixed=document.createElementNS(H,'h:span');host.append(prefixed);add('prefixed inherited editing',prefixed);
  prefixed.contentEditable='false';add('prefixed explicit false',prefixed);
  const detached=document.createElement('div');detached.contentEditable='plaintext-only';add('detached plaintext host',detached);
  const shadowHost=document.createElement('div');host.append(shadowHost);const shadow=shadowHost.attachShadow({mode:'open'}),shadowChild=document.createElement('span');shadow.append(shadowChild);
  add('shadow does not inherit editing',shadowChild);shadowChild.contentEditable='true';add('shadow own editing',shadowChild);
  const ordinary=document.createElement('p');document.body.append(ordinary);add('document editing off',ordinary);
  document.designMode='on';add('document editing on',ordinary);add('document explicit false',prefixed);
  detached.removeAttribute('contenteditable');add('document detached control',detached);
  document.designMode='off';add('document editing off again',ordinary);
  const target=document.createElement('div');document.body.append(target);target.append(child);add('reparent into noneditable',child);
  target.contentEditable='TRUE';add('live reparented editing',child);
  for(const kind of ['text','search','tel','url','email','password','date','datetime-local','month','week','time','number','range','color','checkbox','radio','file','hidden','submit','reset','button','image','TEXT','unknown','datetime']){
    const e=document.createElement('input');e.setAttribute('type',kind);e.required=true;e.placeholder='Hint';document.body.append(e);
    for(const readonly of [false,true]){
      e.readOnly=readonly;
      records.push({name:'input states '+kind+' readonly '+readonly,value:[':read-write',':read-only',':required',':optional',':placeholder-shown',':valid',':invalid'].map(selector=>e.matches(selector))});
    }
  }
  return records;
}
