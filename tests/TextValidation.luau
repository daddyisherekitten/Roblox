--!strict
return function(Parser,DOM,State,Text,URL,Model,loadRenderTree,loadWordLayout,loadBlockLayout)
	for _,value in {'a@b','a+b@example.com','.a..b@example.com',"o'hara@example.org",'x@xn--bcher-kva.de'} do assert(Text.email(value),value) end
	for _,value in {'a','a@','@b','a@@b','a b@example.com','a@-b.com','a@b-.com','a@b..com','a@b.','a@'..string.rep('b',64),'x@y,z@w'} do assert(not Text.email(value),value) end
	assert(Text.email('a@b,c@d',true) and not Text.email('a@b,',true))
	assert(Text.sanitize('email',' \ta@b\r\n ') == 'a@b')
	assert(Text.sanitize('email',' a@b, c@d ',true) == 'a@b,c@d')
	assert(Text.sanitize('url',' https://example.com\r\n ') == 'https://example.com')
	assert(Text.sanitize('text',' a ') == ' a ' and Text.sanitize('textarea','a\r\nb\rc') == 'a\nb\nc')
	assert(Text.length(utf8.char(0x1f600)) == 2 and Text.length('a'..utf8.char(0x301)) == 2)
	assert(Text.minimum('5') == 5 and Text.minimum('0') == 0 and Text.minimum('-1') == nil and Text.minimum('no') == nil)
	assert(URL.valid('file://[::1]/demo') and URL.valid('custom://999.1.1.1') and not URL.valid('http://1..2'))
	for _,value in {'https://example.com','http://localhost:8080/a?q=1#x','https://example.com/a b','ftp://user:pass@example.com','https://[::1]:443/','http://127.0.0.1','http://0x7f000001','mailto:a@b','urn:example:animal','data:text/plain,hello','file:///C:/demo.html'} do assert(URL.valid(value),value) end
	for _,value in {'example.com','/relative','//example.com','https://','https://a b','https://:80','https://a:65536','https://a:abc','https://[wrong]','https://[1:2:3]','https://[1:::2]','https://[:1::]','https://[::1]:bad','https://999.1.1.1','https://a%20b','https://a%zz'} do assert(not URL.valid(value),value) end
	local function setup(markup)
		local document=Parser.parse('<form id="f">'..markup..'</form>')
		local controls={}
		local function walk(node)
			if node.Name == 'input' or node.Name == 'textarea' or node.Name == 'button' then table.insert(controls,State.create(node)) end
			for _,child in node.Children or {} do walk(child) end
		end
		walk(document)
		local log={}
		local events={Emit=function(_,node,kind,data) table.insert(log,{Node=node,Kind=kind,Data=data}); return {DefaultPrevented=false} end}
		local model=Model.new(document,controls,events,function() end)
		function model:Focus(c) self.Focused=c end
		local form=DOM.findById(document,'f')
		local function valid(expected,submitter)
			table.clear(log); model.Focused=nil; model:Submit(form,submitter)
			assert(#log == 1 and log[1].Kind == (if expected then 'submit' else 'invalid'))
			assert((model.Focused ~= nil) == not expected)
		end
		return model,controls,valid,form,log
	end
	local model,c,valid=setup('<input id="e" name="email" type="email" value=" a@b "><input id="u" name="url" type="url">')
	assert(c[1].Type == 'email' and c[1].Value == 'a@b' and c[1].DefaultValue == 'a@b' and c[2].Type == 'url')
	valid(true); model:SetValue(c[1],'invalid',true); valid(false)
	model:SetValue(c[1],'',true); valid(true)
	c[1].Required=true; valid(false); model:SetValue(c[1],'test@example.org'); valid(true)
	model:SetValue(c[2],'example.org'); valid(false)
	model:SetValue(c[2],'https://example.org'); valid(true)
	local entries=model:Data(c[1].Form); assert(#entries == 2 and entries[1].Value == 'test@example.org')
	model,c,valid=setup('<input type="email" multiple value="a@b, c@d">')
	assert(c[1].Value == 'a@b,c@d'); valid(true)
	model:SetValue(c[1],'a@b,'); valid(false)
	model,c,valid=setup('<textarea minlength="5">abc</textarea>')
	valid(true) -- Default values are not user edits.
	model:SetValue(c[1],'ab',true); valid(false)
	model:SetValue(c[1],'ab'); valid(true) -- Even assigning the same value clears edit provenance.
	model:SetValue(c[1],'abc',true); valid(false)
	model:SetValue(c[1],'abcde',true); valid(true)
	model:SetValue(c[1],'',true); valid(true)
	c[1].Required=true; valid(false); c[1].Required=false
	model:SetValue(c[1],'a',true); model:Reset(c[1].Form); valid(true)
	assert(c[1].Value == 'abc' and not c[1].UserEdited)
	model,c,valid=setup('<input type="password" minlength="3" maxlength="4">')
	model:SetValue(c[1],utf8.char(0x1f600),true); valid(false)
	model:SetValue(c[1],utf8.char(0x1f600)..'a',true); valid(true)
	model:SetValue(c[1],'abcdef',true); assert(c[1].Value == 'abcd'); valid(true)
	model,c,valid=setup('<textarea minlength="4"></textarea>')
	model:SetValue(c[1],'a\r\nb',true); assert(c[1].Value == 'a\nb'); valid(false)
	model,c,valid=setup('<input type="email" value="bad" disabled><input type="url" value="bad" readonly><input type="number" minlength="10" value="1">')
	valid(true); assert(c[3].MinLength == nil)
	local form
	model,c,valid,form=setup('<input type="email" value="bad"><button formnovalidate>Skip</button>')
	valid(false); valid(true,c[2]); form.Attributes.novalidate=''; valid(true)
	model,c,valid=setup('<input pattern="[A-Z]{2}" value="AB">')
	valid(true);model:SetValue(c[1],'ab');valid(false)
	c[1].Node.Attributes.pattern='[';valid(true)
	c[1].DOMCustomValidity='Native custom error';valid(false)
	c[1].Node.Attributes.readonly='';valid(true)
	local factory={create=function(class,parent,props)
		assert(class ~= 'TextButton' and class ~= 'ImageButton')
		local gui=table.clone(props); gui.Parent=parent; gui.ClassName=class; return gui
	end,modifier=function(_,_,props) return table.clone(props) end}
	local tree=loadRenderTree(factory).build(Parser.parse('<input type="text"><input type="email"><input type="url">'),{},error,function(font) return font end)
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size) return {X=#text*5,Y=size} end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides)
	loadBlockLayout(overrides).arrange(tree,1000,0,0,function() return true end)
	local reference=tree.Controls[1].Item
	for index=2,3 do
		local item=tree.Controls[index].Item
		assert(item.Editor.ClassName == 'TextBox' and item.BoxHeight == reference.BoxHeight and item.BoxWidth == reference.BoxWidth)
		assert(item.Editor.TextSize == reference.Editor.TextSize and item.Editor.Position[2] == reference.Editor.Position[2])
	end
	print('Text validation: email/URL syntax, sanitization, UTF-16 minlength, edit provenance/reset, submission/focus/bypass and identical field metrics passed')
end
