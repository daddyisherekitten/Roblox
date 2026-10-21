--!strict
return function(Parser,Runtime,Events)
	local document=Parser.parseDocument('<html><body><div id="tile" style="width:120px;color:red"></div></body></html>');local diagnostics={}
	local runtime=Runtime.new(document,{Events=Events.new(error),Diagnostic=function(message)table.insert(diagnostics,message)end})
	local ok,err=runtime:Run([=[
	function assert(value, message) { if (!value) throw new Error(message); }
	const tile=document.getElementById('tile');
	assert(typeof Element.prototype.animate==='function' && typeof Document.prototype.getAnimations==='function', 'standard animation entry points');
	const borrowed=Element.prototype.animate.call(tile,[{opacity:0},{opacity:1}],100);
	assert(borrowed instanceof Animation && document.getAnimations().includes(borrowed), 'borrowed prototype operation reaches same backend');borrowed.cancel();
	assert(CSS.highlights instanceof HighlightRegistry, 'registry interface brand');
	assert(CSS.supports('width','1in') && CSS.supports('selector(:nth-child(2n of .x))'), 'shared syntax support');
	assert(CSS.escape('1 café')==='\\31 \\ café', 'escape serialization');
	const px=CSS.px(120);
	assert(px instanceof CSSUnitValue && px instanceof CSSNumericValue && px instanceof CSSStyleValue, 'value brands');
	assert(String(px)==='120px' && px.unit==='px' && px.value===120, 'scalar representation');
	assert(CSS.in(1).to('px').value===96 && CSS.cm(2.54).equals(CSS.px(96)), 'absolute conversion');
	assert(CSS.ms(1000).to('s').value===1 && CSS.turn(.5).to('deg').value===180, 'time and angle conversion');
	let errors=0;try { CSS.em(1).to('px'); } catch(e) { errors++; }
	try { CSS.px(Infinity); } catch(e) { errors++; }
	try { CSS.escape(Symbol()); } catch(e) { errors++; }
	assert(errors===3, 'conversion and WebIDL errors');
	assert(tile.attributeStyleMap===tile.attributeStyleMap, 'same object');
	assert(tile.computedStyleMap()===tile.computedStyleMap(),'SameObject computed map');
	const alternate=document.createElement('p');alternate.style.width='30px';
	assert(tile.computedStyleMap===alternate.computedStyleMap && tile.computedStyleMap.call(alternate)===alternate.computedStyleMap(),'Shared method uses its actual receiver');
	assert(tile.attributeStyleMap.get('width').value===120, 'read declared width');
	tile.attributeStyleMap.set('width',CSS.px(240));
	assert(tile.style.width==='240px' && tile.attributeStyleMap.get('width').value===240, 'write through existing declaration');
	tile.style.width='35%';assert(tile.attributeStyleMap.get('width').unit==='percent', 'live reflection');
	assert(CSSStyleValue.parse('display','block') instanceof CSSKeywordValue, 'keyword reification');
	assert(CSSStyleValue.parse('margin','1px 2px').constructor===CSSStyleValue,'A valid unrepresentable shorthand stays opaque');
	const opaque=CSSStyleValue.parse('color','rgb(1, 2, 3)');
	tile.attributeStyleMap.set('color',opaque);
	try { tile.attributeStyleMap.set('background-color',opaque); } catch(e) { errors++; }
	try { tile.attributeStyleMap.set('width',CSS.s(1)); } catch(e) { errors++; }
	assert(errors===5 && tile.style.width==='35%', 'atomic invalid map values');
	assert(tile.attributeStyleMap.has('color') && !tile.attributeStyleMap.has('height'), 'map presence');
	const entries=[...tile.attributeStyleMap];assert(entries.length===2 && entries[0][0]==='color', 'sorted map iteration');
	tile.attributeStyleMap.delete('width');assert(tile.attributeStyleMap.get('width')===undefined, 'delete');
	tile.attributeStyleMap.clear();assert(tile.style.cssText==='', 'clear');
	const text=document.createTextNode('abc');tile.appendChild(text);
	const r1=new Range();r1.setStart(text,0);r1.setEnd(text,1);
	const r2=new Range();r2.setStart(text,1);r2.setEnd(text,2);
	const r3=new Range();r3.setStart(text,2);r3.setEnd(text,3);
	const highlight=new Highlight(r1,r2,r1);assert(highlight.size===2,'range set uniqueness');
	const iterator=highlight.values();assert(iterator.next().value===r1,'range order');
	highlight.delete(r1);highlight.add(r3);assert(iterator.next().value===r2 && iterator.next().value===r3,'live set iterator across deletion');
	highlight.priority=-1.9;assert(highlight.priority===-1,'signed priority truncation');
	CSS.highlights.set('sample',highlight);const registryIterator=CSS.highlights.keys();
	CSS.highlights.delete('sample');CSS.highlights.set('sample',highlight);
	assert(registryIterator.next().value==='sample' && registryIterator.next().done && CSS.highlights.size===1,'registry reinsert has no duplicates');
	CSS.highlights.set('later',highlight);assert(registryIterator.next().done,'completed iterator stays completed');
	let visits=0;CSS.highlights.forEach(function(value,key,map){visits++;assert(value===highlight && map===CSS.highlights,'registry callback');});
	assert(visits===2,'registry active insertion entries');CSS.highlights.clear();
	]=])
	assert(ok,tostring(err));assert(#diagnostics==0,table.concat(diagnostics,' | '));runtime:Destroy()
	print('Typed OM: scalar brands, conversions, atomic map writes, identity, live reflection and iteration passed')
end
