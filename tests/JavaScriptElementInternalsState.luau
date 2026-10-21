--!strict
-- UA restoration uses an explicit host signal. It is not a fake JavaScript
-- method, and the callback receives a fresh FormData copy of the stored list.
return function(Parser,Runtime,Events)
	local diagnostics,values={},{}
	local document=Parser.parseDocument('<html><body></body></html>')
	local events=Events.new(error)
	local runtime=Runtime.new(document,{Events=events,URL='https://example.test/components',ControlAdapter={},MaxSteps=200000,
		Console=function(_,value)table.insert(values,value)end,Diagnostic=function(value)table.insert(diagnostics,value)end})
	runtime:Run([=[
	class RestorableNote extends HTMLElement {
	 static formAssociated=true;
	 constructor(){super();this.i=this.attachInternals();}
	 formStateRestoreCallback(state,mode){console.log(mode+':'+state.get('draft'));state.set('draft','callback edit');this.i.setFormValue(state.get('draft'),state);}
	}
	customElements.define('restorable-note',RestorableNote);
	const note=document.createElement('restorable-note');document.body.append(note);
	const state=new FormData();state.append('draft','original');state[Symbol.iterator]=()=>{throw new Error('author iterator must not run')};note.i.setFormValue('submission',state);state.set('draft','author edit');
	]=])
	local snapshot=runtime.CustomElements.Internals:CaptureState(document)
	assert(#snapshot==1,'FACE state snapshot missed retained node')
	runtime:Run("note.i.setFormValue('changed','different');FormData.prototype.append=function(){throw new Error('replaced method')};globalThis.FormData=function(){throw new Error('replaced constructor')};")
	runtime.VM:ExecuteHost(function()runtime.CustomElements.Internals:RestoreState(snapshot,'restore')end)
	runtime.VM:ExecuteHost(function()runtime.CustomElements.Internals:RestoreState(snapshot,'autocomplete')end)
	assert(#diagnostics==0,table.concat(diagnostics,' | '))
	assert(#values==2 and values[1]=='restore:original'and values[2]=='autocomplete:original','Restoration mutated source snapshot or used mutable author constructor')
	runtime:Destroy();events:Destroy()
	local sourceEvents,targetEvents=Events.new(error),Events.new(error)
	local source=Runtime.new(Parser.parseDocument('<html><body><div id="declarative"><template shadowrootmode="open" shadowrootclonable shadowrootcustomelementregistry><span>Declarative</span></template></div></body></html>'),{Events=sourceEvents,URL='https://example.test/source',ControlAdapter={},Schedule=function()end})
	local ownerReports=0
	local target=Runtime.new(Parser.parseDocument('<html><body><form id="destination"></form></body></html>'),{Events=targetEvents,URL='https://example.test/destination',ControlAdapter={ReportValidity=function()ownerReports+=1 end},Schedule=function()end})
	source:Run([=[
	 globalThis.reactions=[];
	 class ForeignField extends HTMLElement {
	  static formAssociated=true;
	  constructor(){super();this.i=this.attachInternals();this.i.setFormValue('fresh');}
	  adoptedCallback(oldDocument,newDocument){reactions.push('adopted:'+(oldDocument!==newDocument));}
	  connectedCallback(){reactions.push('connected');}
	  disconnectedCallback(){reactions.push('disconnected');}
	  formAssociatedCallback(form){reactions.push('form:'+(form?form.id:'none'));}
	 }
	 const scoped=new CustomElementRegistry();scoped.define('foreign-field',ForeignField);
	 const field=document.createElement('foreign-field',{customElementRegistry:scoped});field.setAttribute('name','value');field.i.setFormValue('retained');document.body.append(field);reactions.length=0;
	 const late=document.createElement('late-field',{customElementRegistry:scoped});
	 class GlobalField extends HTMLElement {constructor(){super();this.marker='source';}}
	 customElements.define('global-field',GlobalField);const globalField=document.createElement('global-field');
	 const globalHost=document.createElement('div');globalHost.attachShadow({mode:'open',clonable:true}).innerHTML='<span>Global</span>';
	 const nullHost=document.createElement('div');nullHost.attachShadow({mode:'open',clonable:true,customElementRegistry:null}).innerHTML='<span>Null</span>';
	 const declarativeHost=document.getElementById('declarative');if(declarativeHost.shadowRoot.customElementRegistry!==null||declarativeHost.shadowRoot.firstChild.customElementRegistry!==null)throw new Error('Declarative keep-null registry initialization');
	]=])
	for _,name in {'field','ForeignField','late','globalField','GlobalField','scoped','globalHost','nullHost','declarativeHost'}do target.VM.Global.Bindings[name]={Value=source.VM.Global.Bindings[name].Value}end
	target.VM.Global.Bindings.sourceRegistry={Value=source.VM.Global.Bindings.scoped.Value}
	target:Run([=[
	 const form=document.getElementById('destination');form.append(field);
	 if(field.ownerDocument!==document||field.i.form!==form||!(field instanceof ForeignField)||field.customElementRegistry!==sourceRegistry||new FormData(form).get('value')!=='retained')throw new Error('Foreign FACE adoption');
	 let invalidEvents=0;document.addEventListener('invalid',e=>{if(e.target===field)invalidEvents++},true);field.i.setValidity({customError:true},'Required');field.i.states.add('changed');
	 if(field.i.checkValidity()||field.i.reportValidity()||invalidEvents!==2)throw new Error('Destination invalid event path');field.i.setValidity({});
	 const clone=field.cloneNode(true);form.append(clone);
	 if(!(clone instanceof ForeignField)||clone.ownerDocument!==document||clone.customElementRegistry!==sourceRegistry||clone.i.form!==form||new FormData(form).getAll('value').join('|')!=='retained|fresh')throw new Error('Foreign registry clone');
	 document.body.append(late.cloneNode());
	 document.body.append(globalField);if(!(globalField instanceof GlobalField)||globalField.customElementRegistry!==customElements||globalField.marker!=='source')throw new Error('Global registry adoption reassigns registry while retaining definition');
	 const globalCopy=globalField.cloneNode();document.body.append(globalCopy);if(globalCopy instanceof GlobalField||globalCopy.customElementRegistry!==customElements||globalCopy.marker!==undefined)throw new Error('Global clone uses destination registry');
	 customElements.define('global-field',class extends HTMLElement{constructor(){super();this.marker='destination'}});if(globalCopy.marker!=='destination'||globalField.marker!=='source')throw new Error('Destination definition upgrades only undefined clones');
	 document.body.append(globalHost,nullHost);const globalHostCopy=globalHost.cloneNode(true),nullHostCopy=nullHost.cloneNode(true);
	 if(globalHost.shadowRoot.customElementRegistry!==customElements||globalHostCopy.shadowRoot.customElementRegistry!==customElements||globalHostCopy.shadowRoot.firstChild.customElementRegistry!==customElements)throw new Error('Global shadow registry adoption/clone');
	 if(nullHost.shadowRoot.customElementRegistry!==customElements||nullHostCopy.shadowRoot.customElementRegistry!==customElements||nullHostCopy.shadowRoot.firstChild.customElementRegistry!==null)throw new Error('Imperative null shadow root adoption and retained null descendants');
	 document.body.append(declarativeHost);const declarativeCopy=declarativeHost.cloneNode(true);if(declarativeHost.shadowRoot.customElementRegistry!==null||declarativeCopy.shadowRoot.customElementRegistry!==null||declarativeCopy.shadowRoot.firstChild.customElementRegistry!==null)throw new Error('Declarative keep-null registry adoption/clone');
	 form.removeChild(field);if(field.i.form!==null)throw new Error('Foreign FACE detachment');
	]=])
	source:Run([=[
	 if(reactions.join('|')!=='disconnected|adopted:true|connected|form:destination|connected|form:destination|disconnected|form:none')throw new Error('Foreign lifecycle order '+reactions.join('|'));
	 class LateField extends HTMLElement {constructor(){super();this.marker='upgraded';}}
	 scoped.define('late-field',LateField);
	]=])
	target:Run("if(document.querySelector('late-field').marker!=='upgraded')throw new Error('Foreign registry definition upgrades adopted document');")
	assert(#source.Diagnostics==0 and #target.Diagnostics==0,table.concat(source.Diagnostics,' | ')..table.concat(target.Diagnostics,' | '))
	local rawField=target.DOM.Unwrap(target.VM.Global.Bindings.field.Value)
	assert(target.Pending[rawField]and target.Pending[rawField].Attributes.internals and not(source.Pending[rawField]and source.Pending[rawField].Attributes.internals),'Adopted internals state and validity mutations must notify the destination host')
	assert(ownerReports==1,'Adopted validity reporting must use the destination input host')
	source:Destroy();target:Destroy();sourceEvents:Destroy();targetEvents:Destroy()
	print('ElementInternals restoration/realms: intrinsic FormData snapshots, fresh state, retained registry/prototype, clone/adoption lifecycle, destination form/invalid/paint hosts and later upgrades passed')
end
