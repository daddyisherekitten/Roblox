function htmlExpandedHostChecks(){
  const H='http://www.w3.org/1999/xhtml',records=[];
  function make(name,attrs){const n=document.createElementNS(H,'h:'+name);for(const key of Object.keys(attrs||{}))n.setAttribute(key,attrs[key]);return n;}
  function run(name,fn){try{records.push({name:name,value:fn()});}catch(error){records.push({name:name,value:{error:error.name}});}}
  run('prefixed-shadow-host',()=>{const h=make('div'),r=h.attachShadow({mode:'open'});return [h.shadowRoot===r,r.host===h,h.localName,h.prefix];});
  for(const ns of [null,'urn:foreign'])run('foreign-shadow-'+String(ns),()=>{const h=document.createElementNS(ns,'div');try{Element.prototype.attachShadow.call(h,{mode:'open'});return 'accepted';}catch(error){return error.name;}});
  run('prefixed-slot-assignment',()=>{const h=make('div'),r=h.attachShadow({mode:'open'}),s=make('slot'),n=make('span');r.append(s);h.append(n);return [s.constructor.name,s.assignedNodes()[0]===n,n.assignedSlot===s];});
  run('prefixed-manual-slot',()=>{const h=make('div'),r=h.attachShadow({mode:'open',slotAssignment:'manual'}),s=make('slot'),n=make('span');r.append(s);h.append(n);s.assign(n);return s.assignedNodes()[0]===n;});
  run('prefixed-slot-dynamic',()=>{const h=make('div'),r=h.attachShadow({mode:'open'}),s=make('slot',{name:'one'}),t=make('slot',{name:'two'}),n=make('input',{slot:'one'});r.append(s,t);h.append(n);const first=n.assignedSlot===s;n.slot='two';return [first,n.assignedSlot===t,s.assignedNodes().length,t.assignedNodes()[0]===n];});
  run('prefixed-slot-flatten-fallback',()=>{const h=make('div'),r=h.attachShadow({mode:'open'}),s=make('slot'),nested=make('slot',{name:'nested'}),text=document.createTextNode('fallback');nested.append(text);s.append(nested);r.append(s);return [s.assignedNodes().length,s.assignedNodes({flatten:true})[0]===text];});
  run('prefixed-shadow-clone',()=>{const h=make('div'),r=h.attachShadow({mode:'open',clonable:true}),s=make('slot');r.append(s);const c=h.cloneNode(true);return [c.shadowRoot!==null,c.shadowRoot.host===c,c.shadowRoot.firstChild.localName,c.shadowRoot.firstChild.prefix];});
  for(const name of ['div','span','table','tbody','tr','td','input','button','textarea','select','a','x-expanded-unregistered'])run('display-'+name,()=>{const h=make(name);document.body.append(h);const value=getComputedStyle(h).display;h.remove();return value;});
  for(const ns of [null,'urn:foreign'])run('foreign-display-'+String(ns),()=>{const h=document.createElementNS(ns,'div');document.body.append(h);const value=getComputedStyle(h).display;h.remove();return value;});
  for(const name of ['svg','math'])run('HTML-unknown-'+name,()=>{const h=make(name);document.body.append(h);const value=[h.constructor.name,getComputedStyle(h).display];h.remove();return value;});
  run('summary-UA-contexts',()=>{const d=make('details'),s=make('summary'),second=make('summary'),outside=make('summary');d.append(s,second);document.body.append(d,outside);const before=[getComputedStyle(s).display,getComputedStyle(s).listStyleType,getComputedStyle(second).display,getComputedStyle(outside).display];d.open=true;before.push(getComputedStyle(s).listStyleType);d.remove();outside.remove();return before;});
  run('prefixed-bidi-direction',()=>{const h=make('bdi');h.textContent='שלום';document.body.append(h);const value=[getComputedStyle(h).direction,getComputedStyle(h).unicodeBidi];h.remove();return value;});
  run('prefixed-bdo-direction',()=>{const h=make('bdo',{dir:'rtl'});document.body.append(h);const value=[getComputedStyle(h).direction,getComputedStyle(h).unicodeBidi];h.remove();return value;});
  run('prefixed-input-auto-direction',()=>{const h=make('input',{dir:'auto'});h.value='שלום';document.body.append(h);const first=getComputedStyle(h).direction;h.value='English';const value=[first,getComputedStyle(h).direction,h.getAttribute('value')];h.remove();return value;});
  run('prefixed-auto-excludes-bdi',()=>{const h=make('div',{dir:'auto'}),b=make('bdi');b.textContent='שלום';h.append(b,document.createTextNode('English'));document.body.append(h);const value=[getComputedStyle(h).direction,getComputedStyle(b).direction];h.remove();return value;});
  return records;
}
function htmlExpandedMountedSetup(){
  const H='http://www.w3.org/1999/xhtml';function make(name,id,style){const n=document.createElementNS(H,'h:'+name);n.id=id;if(style)n.setAttribute('style',style);return n;}
  const panel=make('div','expanded-panel','width:240px;box-sizing:border-box;padding:10px;border:2px solid #123456'),inside=make('div','expanded-inside','height:20px'),edit=make('input','expanded-edit','display:block;width:100px;height:30px;box-sizing:border-box;padding:0;border:1px solid black;margin:0');edit.value='typed';panel.append(inside,edit);
  const after=make('div','expanded-after','height:12px'),host=make('div','expanded-host','width:160px'),light=make('div','expanded-light','height:24px');light.slot='one';host.append(light);const shadow=host.attachShadow({mode:'open'}),surface=make('div','expanded-shadow-surface','height:18px'),slot=make('slot','expanded-slot','display:block');slot.name='one';shadow.append(surface,slot);
  document.body.append(panel,after,host);
  return [panel,inside,edit,after,host,light,surface].map(n=>{const r=n.getBoundingClientRect();return {id:n.id,rect:[r.x,r.y,r.width,r.height],display:getComputedStyle(n).display};});
}
