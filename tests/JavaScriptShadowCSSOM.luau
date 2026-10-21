--!strict
-- Per-tree CSSOM ownership, cross-root sharing and lifecycle are independent
-- of the renderer's scoped selector implementation.
return function(Parser,Runtime,VM,Events)
	local document=Parser.parseDocument('<html><head><style id="document-style">.token { color: red; }</style></head><body><div id="a"></div><div id="b"></div></body></html>')
	local diagnostics={};local events=Events.new(error)
	local realm=Runtime.new(document,{Events=events,URL="https://example.test/shadow-cssom",Diagnostic=function(s)table.insert(diagnostics,s)end})
	local function run(code)realm:Run(code);realm:PumpTasks();assert(#diagnostics==0,table.concat(diagnostics," | "))end
	run([=[
	const check=(value,message)=>{if(!value)throw new Error(message);};
	const a=document.getElementById('a'),b=document.getElementById('b');
	const first=a.attachShadow({mode:'open'}),second=b.attachShadow({mode:'closed'});
	first.innerHTML='<style id="first-style">.first { color: green; }</style><div class="first">First</div>';
	second.innerHTML='<style id="second-style">.second { color: blue; }</style><div class="second">Second</div>';
	const dl=document.styleSheets,fl=first.styleSheets,sl=second.styleSheets;
	check(dl===document.styleSheets && fl===first.styleSheets && sl===second.styleSheets,'live list identities');
	check(dl.length===1 && fl.length===1 && sl.length===1,'sources scoped to separate roots');
	check(dl[0].ownerNode.id==='document-style' && fl[0].ownerNode.id==='first-style' && sl[0].ownerNode.id==='second-style','root owner nodes');
	check(fl[0]===first.querySelector('style').sheet && sl[0]===second.querySelector('style').sheet,'root node associations');
	const shared=new CSSStyleSheet();shared.replaceSync('.shared { color: purple; }');
	const other=new CSSStyleSheet();other.replaceSync('.other { color: orange; }');
	const components=new CSSStyleSheet();components.replaceSync(':host{display:block;background:#edf2e8}:host([tone="warm"]){background:#f6e6d8}.heading{color:green}slot[name="title"]::slotted(strong){font-weight:bold}slot[name="note"]::slotted(input){width:100%;min-width:0}.inside{padding:3px}');
	check(components.cssRules.length===6 && components.cssRules[0].selectorText===':host' && components.cssRules[4].selectorText==='slot[name="note"]::slotted(input)','constructed shadow selectors must survive context-free parsing before adoption');
	const da=document.adoptedStyleSheets,fa=first.adoptedStyleSheets,sa=second.adoptedStyleSheets;
	check(da!==fa && fa!==sa && sa!==da && fa===first.adoptedStyleSheets,'independent same-object adopted arrays');
	first.adoptedStyleSheets=[shared];second.adoptedStyleSheets=[shared];document.adoptedStyleSheets=[other];
	check(da.length===1 && da[0]===other && fa[0]===shared && sa[0]===shared,'shared sheet adoption is independent');
	fa.push(other);check(fa.length===2 && sa.length===1 && da.length===1,'array mutation stays in one root');
	shared.cssRules[0].style.color='teal';check(sa[0].cssRules[0].style.color==='teal','shared rules retain identity');
	fa.splice(0,1);check(fa[0]===other && sa[0]===shared,'unadopting in one root preserves other adoption');
	const original=first.querySelector('style'),oldSheet=original.sheet;
	second.append(original);check(fl.length===0 && sl.length===2 && original.sheet!==oldSheet && oldSheet.ownerNode===null,'moving a style changes its association');
	second.insertBefore(original,second.firstChild);check(sl[0].ownerNode===original,'tree-order source list');
	first.adoptedStyleSheets=[];second.adoptedStyleSheets=[];document.adoptedStyleSheets=[];
	check(fa.length===0 && sa.length===0 && da.length===0,'unadoption clears existing arrays');
	]=])
	local vm=realm.VM;local first=vm.Global.Bindings.first.Value.DOMNode;local second=vm.Global.Bindings.second.Value.DOMNode
	local shared=vm.Global.Bindings.shared.Value;local other=vm.Global.Bindings.other.Value
	vm:Install(function()
		assert(not realm.CSSOM:IsAdopted(shared)and not realm.CSSOM:IsAdopted(other),"Last unadoption releases reference count")
	end)
	run("first.adoptedStyleSheets=[shared];second.adoptedStyleSheets=[shared];")
	vm:Install(function()
		assert(realm.CSSOM:IsAdopted(shared))
		local firstSource,secondSource=realm.CSSOM:RenderAdopted(first),realm.CSSOM:RenderAdopted(second)
		assert(#firstSource==1 and #secondSource==1 and firstSource[1].Source==secondSource[1].Source,"Constructed sheet projects into every adopted root")
		assert(#realm.CSSOM:RenderAdopted(document)==0,"Shadow adoption leaked into document renderer")
	end)
	local foreignEvents=Events.new(error);local foreign=Runtime.new(Parser.parseDocument('<html><body></body></html>'),{Events=foreignEvents,Diagnostic=error})
	foreign:Run('globalThis.foreignSheet=new CSSStyleSheet();')
	vm.Global.Bindings.foreignSheet={Value=foreign.VM.Global.Bindings.foreignSheet.Value}
	run([=[
	let foreignError='';try{first.adoptedStyleSheets=[foreignSheet];}catch(e){foreignError=e.name;}
	check(foreignError==='NotAllowedError' && first.adoptedStyleSheets.length===0,'foreign constructor document guard');
	second.adoptedStyleSheets=[shared];const held=second.adoptedStyleSheets;
	const current=second.querySelector('style').sheet;b.remove();check(second.styleSheets.length===0 && current.ownerNode===null,'disconnected style association cleanup');
	document.body.append(b);check(second.styleSheets.length===2 && second.querySelector('style').sheet!==current,'reattachment produces new style associations');
	check(held===second.adoptedStyleSheets && held[0]===shared,'disconnection preserves root adopted arrays');
	]=])
	local firstArray,secondArray=realm.CSSOM:DocumentGet(first,"adoptedStyleSheets"),realm.CSSOM:DocumentGet(second,"adoptedStyleSheets")
	realm:Destroy();assert(vm.ObjectModel.Exotic[firstArray]==nil and vm.ObjectModel.Exotic[secondArray]==nil,"Disposal retained shadow observable-array handlers")
	assert(not realm.CSSOM:IsAdopted(shared));foreign:Destroy();events:Destroy();foreignEvents:Destroy()
	print("JavaScript shadow CSSOM: per-root sources/lists/adopted arrays, shared sheets, moves, constructor document guards and cleanup passed")
end
