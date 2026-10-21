--!strict
return function(Selectors: any)
	local function element(name: string, id: string?): any
		return {Kind='Element', Name=name, Attributes={id=id}, Children={}}
	end
	local parent=element('section')
	local first,middle,last=element('p','first'),element('aside','middle'),element('p','last')
	parent.Children={first,{Kind='Text',Text=' gap '},middle,{Kind='Comment',Text='gap'},last}
	for _,child in parent.Children do child.Parent=parent end
	local function matches(node: any, source: string): boolean
		local compiled=Selectors.compile(source)
		assert(compiled,source)
		return Selectors.matches(node,compiled)
	end
	assert(matches(first,':first-child:nth-child(1):nth-of-type(1)'))
	assert(matches(last,'aside + p:last-child:nth-child(3):nth-of-type(2):nth-last-of-type(1)'))
	assert(matches(last,'#first ~ #last') and not matches(first,'#last ~ #first'))
	assert(matches(middle,':only-of-type') and not matches(middle,':only-child'))
	assert(matches(last,':IS(p, div):NOT(aside):NTH-CHILD(odd)'))
	assert(matches(first,':is(p,:unsupported())')and matches(first,':where(p,#missing::before)'),
		'Forgiving selector lists keep a valid branch when another branch is invalid or a pseudo-element')
	assert(not matches(first,':is(:unsupported(),::before)')and not matches(first,':where()'),
		'A valid empty forgiving list matches no element')
	assert(Selectors.compile(':not(p,:unsupported())')==nil and Selectors.compile(':has(p,::before)')==nil,
		'Non-forgiving selector lists reject the complete list')
	local visible=Selectors.compile(':focus-visible')
	assert(visible and Selectors.matches(first,visible,{['focus-visible']=first}) and not Selectors.matches(middle,visible,{['focus-visible']=first}) and not Selectors.matches(parent,visible,{['focus-visible']=first}))
	local disabledInput=element('input');disabledInput.Attributes.disabled=''
	assert(matches(disabledInput,'input:disabled') and matches(disabledInput,':read-only') and not matches(disabledInput,':enabled'))
	local editableInput=element('input');editableInput.Attributes.type='email'
	assert(matches(editableInput,'input:enabled:read-write') and not matches(editableInput,':read-only'))
	local toggle=element('input');toggle.Attributes.type='checkbox'
	local checked=Selectors.compile(':checked')
	assert(checked and not Selectors.matches(toggle,checked))
	assert(Selectors.matches(toggle,checked,{['form-state']={[toggle]={Type='checkbox',Checked=true}}}))
	local email=element('input');email.Attributes.type='email';email.Attributes.required='';email.Attributes.placeholder='Mail'
	assert(matches(email,':invalid:placeholder-shown') and not matches(email,':user-invalid'))
	local userState={['form-state']={[email]={Type='email',Value='broken',Required=true,UserEdited=true}}}
	assert(Selectors.matches(email,Selectors.compile(':user-invalid:not(:placeholder-shown)'),userState))
	local region=element('section')
	local holder=element('div','holder')
	local choice=element('input','choice');choice.Attributes.type='checkbox'
	local target=element('p','target')
	region.Children={holder,target};holder.Parent=region;target.Parent=region;holder.Children={choice};choice.Parent=holder
	local checkedState={['form-state']={[choice]={Type='checkbox',Checked=true}}}
	assert(Selectors.matches(holder,Selectors.compile('div:has(> input:checked)'),checkedState))
	assert(Selectors.matches(region,Selectors.compile('section:has(#choice:checked)'),checkedState))
	assert(Selectors.matches(holder,Selectors.compile('div:has(+ p)'),checkedState))
	assert(not Selectors.matches(holder,Selectors.compile('div:has(+ input)'),checkedState))
	assert(matches(parent,':first-child:last-child:only-child:nth-child(1):nth-last-of-type(1)'),
		'Detached elements are their own inclusive sibling set')
	local html='http://www.w3.org/1999/xhtml'
	local prefixed=element('p:div');prefixed.LocalName='div';prefixed.NamespaceURI=html;prefixed.Attributes.title='one'
	local upper=assert(Selectors.compile('DIV[TITLE]'))
	prefixed.OwnerDocument={Kind='Document',IsHTML=true}
	assert(Selectors.matches(prefixed,upper),'HTML document folds selector names against expanded local names')
	prefixed.OwnerDocument={Kind='Document',IsHTML=false}
	assert(not Selectors.matches(prefixed,upper),'The same compiled selector follows adoption into XML')
	prefixed.OwnerDocument={Kind='Document',IsHTML=true}
	assert(Selectors.matches(prefixed,upper),'Adoption back to HTML restores folding without recompilation')
	prefixed.LocalName='DIV'
	assert(not Selectors.matches(prefixed,assert(Selectors.compile('DIV'))),'HTML lowercases selectors, not script-created DOM local names')
	prefixed.OwnerDocument.IsHTML=false
	assert(Selectors.matches(prefixed,assert(Selectors.compile('DIV'))),'The same uppercase local name remains exact in XML')
	local legacy=element('p');local explicit=element('prefix:p');explicit.LocalName='p';explicit.NamespaceURI=html
	local siblings=element('div');siblings.Children={legacy,explicit};legacy.Parent=siblings;explicit.Parent=siblings
	assert(Selectors.matches(legacy,assert(Selectors.compile('h|p',nil,{h=html})))and not matches(legacy,'|p'),'Legacy HTML namespace agrees with explicit namespaced parser nodes')
	assert(matches(explicit,'p:nth-of-type(2):last-of-type')and matches(legacy,'p:first-of-type'),'Of-type ignores prefixes and groups legacy/explicit HTML expanded names')

	-- DOM changes must take effect immediately, without stale sibling indexes.
	local translated=element('p');translated.Parent=parent;parent.Attributes.lang='en';translated.Attributes.lang='de-Latn-DE-1996'
	assert(matches(translated,':lang(de-DE)') and matches(translated,':lang("de-*-DE")') and matches(translated,':lang("*-DE")'))
	assert(matches(translated,':lang(fr,"de-*-1996")') and not matches(translated,':lang(en)'))
	translated.Attributes.lang='de-x-DE';assert(not matches(translated,':lang(de-DE)'),'Private-use singleton blocks subtag skipping')
	translated.Attributes.lang='de-DE-x-goethe';assert(matches(translated,':lang(de-DE)'))
	translated.Attributes.lang='und';assert(matches(translated,':lang("*")') and not matches(translated,':lang("")'))
	translated.Attributes.lang='';assert(matches(translated,':lang("")') and not matches(translated,':lang("*")'))
	translated.Attributes.lang=nil;translated.Attributes['xml:lang']='fr-CH'
	assert(matches(translated,':lang(en)')and not matches(translated,':lang(fr)'),'A literal HTML xml:lang attribute has no language semantics')
	translated.AttributeNamespaces={['xml:lang']={Namespace='http://www.w3.org/XML/1998/namespace',LocalName='lang',Prefix='xml'}}
	assert(matches(translated,':lang(fr)') and not matches(translated,':lang(en)'),'Nearest language attribute wins over ancestors')
	translated.Attributes.lang='en';assert(matches(translated,':lang(fr)'),'Namespaced lang takes precedence over HTML lang')
	translated.Attributes['xml:lang']=nil;translated.Attributes['other:lang']='it';translated.AttributeNamespaces={['other:lang']={Namespace='http://www.w3.org/XML/1998/namespace',LocalName='lang',Prefix='other'}}
	assert(matches(translated,':lang(it)'),'XML language uses namespace and local name, not a fixed prefix')
	translated.Attributes['other:lang']=nil;translated.Attributes.lang=nil;translated.AttributeNamespaces=nil;assert(matches(translated,':lang(en)'))
	translated.NamespaceURI='http://www.w3.org/2000/svg';translated.Attributes.lang='fr';assert(matches(translated,':lang(fr)'),'SVG supports unnamespaced lang')
	translated.NamespaceURI='http://www.w3.org/1998/Math/MathML';assert(matches(translated,':lang(en)'),'A MathML lang attribute does not override the inherited language')
	translated.NamespaceURI=nil
	translated.Attributes.lang='de--DE';assert(not matches(translated,':lang("*")'))
	translated.Attributes.lang='åå';assert(not matches(translated,':lang(åå)'))
	translated.Attributes.lang='de-Latn-DE';assert(not matches(translated,':lang("de--DE")') and not matches(translated,':lang("de-123456789")'))
	translated.Attributes.lang='DE-Latn-de';assert(matches(translated,':lang("dE-*-DE")'))
	parent.Attributes.lang=nil
	parent.Children={last,first,middle}
	assert(matches(last,':first-child:nth-of-type(1)'))
	assert(not matches(last,'#first ~ #last') and matches(first,'#last + #first'))
	parent.Children={first,middle}
	last.Parent=nil
	assert(matches(last,':only-child') and not matches(last,'#first ~ #last'))

	-- Count semantic reads rather than timing: one failed ~ match must be linear
	-- in siblings even when the sought ID is absent near the end of a large DOM.
	local reads,count=0,2048
	local metadata={__index=function(_,key)
		if key=='Kind' then reads+=1;return 'Element' end
		return nil
	end}
	parent.Children={}
	for i=1,count do
		local child=setmetatable({Name='div',Attributes={id=tostring(i)},Children={},Parent=parent},metadata)
		table.insert(parent.Children,child)
	end
	assert(not matches(parent.Children[count],'#missing ~ div'))
	assert(reads<=count*3,'General sibling selection must scan the sibling sequence once')
	print('Selectors: sibling combinators, structural pseudos, detached/mutated nodes and linear scan budget passed')
end
