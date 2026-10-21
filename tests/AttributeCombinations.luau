--!strict
return function(Parser: any,Node: any,Runtime: any,Events: any,State: any,Model: any,loadRenderTree: any,loadWordLayout: any,loadBlockLayout: any)
	local doc=Parser.parseDocument([=[<!doctype html><html lang="de"><body>
<form id="one"><fieldset disabled="false"><legend><input id="exempt" name="exempt" value="yes"></legend><input id="blocked" name="blocked" required></fieldset>
<input id="external" name="external" form="two" value="belongs-to-two"><input id="unowned" form="" name="none" value="none">
<input id="check" name="check" type="checkbox" checked="false"><input id="readonly" required readonly>
<input id="limited" minlength=" +2tail" maxlength=" +4tail"><input id="number" type="number" maxlength="0" value="10">
<select id="choice"><option selected="false" value="a">A<option selected value="b">B</select>
<div spellcheck="false" translate="no"><span id="inherited" spellcheck="nonsense" translate="nonsense">X</span><span id="override" spellcheck translate="">Y</span></div>
<input id="sized" size=" +6tail"><textarea id="area" cols=" +8tail" rows=" +3tail"></textarea><select id="many" multiple size="0"><option>A<option>B</select>
<input id="unknown" type="made-up" value="a&#10;b"><input id="disabled" disabled="false" required>
</form><form id="two"></form><table><tr><td id="span" colspan="2tail" rowspan="0">Cell</td></tr></table>
</body></html>]=])
	local events=Events.new(error)
	local realm=Runtime.new(doc,{URL="https://example.test/attributes",Events=events,ControlAdapter={},Schedule=function()end})
	realm:Run([=[
function check(value,message){if(!value)throw new Error(message);}
const q=id=>document.getElementById(id);
check(q('check').checked&&q('check').defaultChecked,'checked=false is present, therefore true');
q('check').checked=false;check(q('check').defaultChecked&&!q('check').checked,'current value does not remove default attribute');
q('check').removeAttribute('checked');q('check').setAttribute('checked','');check(!q('check').checked&&q('check').defaultChecked,'dirty checked state survives attribute changes');
check(q('blocked').willValidate===false&&q('exempt').willValidate,'fieldset first legend exception affects validation');
check(q('readonly').readOnly&&!q('readonly').willValidate&&q('readonly').validity.valid,'readonly+required does not validate');
check(q('disabled').disabled&&!q('disabled').willValidate,'disabled=false disables');
check(q('external').form===q('two')&&q('unowned').form===null,'explicit form overrides/empty form removes ancestor owner');
q('external').setAttribute('form','missing');check(q('external').form===null,'missing form does not fall back to ancestor');q('external').removeAttribute('form');check(q('external').form===q('one'),'removing form restores owner');
check(q('limited').minLength===2&&q('limited').maxLength===4,'HTML integer prefix parsing');
q('limited').value='abcdef';check(q('limited').value==='abcdef'&&!q('limited').validity.tooLong,'script values are not truncated or user length errors');
q('limited').maxLength=3;check(q('limited').getAttribute('maxlength')==='3','IDL setter mutates content attribute');
let negative=false;try{q('limited').maxLength=-1;}catch(e){negative=e.name==='IndexSizeError';}check(negative&&q('limited').maxLength===3,'invalid IDL setter is atomic');
check(q('choice').value==='b'&&!q('choice').options[0].selected&&q('choice').options[0].defaultSelected,'last selected wins in a single select');
check(q('inherited').spellcheck===false&&q('inherited').translate===false&&q('override').spellcheck&&q('override').translate,'invalid enumerated values inherit; empty overrides');
check(q('sized').size===6&&q('area').cols===8&&q('area').rows===3&&q('many').size===0,'numeric size reflection');
let zero=false;try{q('sized').size=0;}catch(e){zero=e.name==='IndexSizeError';}check(zero&&q('sized').size===6,'positive size setter rejects zero');
q('sized').setAttribute('size','0');q('area').setAttribute('rows','bad');check(q('sized').size===20&&q('area').rows===2,'invalid size defaults');
q('sized').size=-1;q('many').size=-1;q('area').cols=2147483648;
check(q('sized').size===20&&q('sized').getAttribute('size')==='20'&&q('many').size===0&&q('area').cols===20,'WebIDL unsigned conversion followed by reflected range defaults');
q('sized').setAttribute('size','2147483648');check(q('sized').size===20,'out-of-range parsed size uses reflection default');
check(q('unknown').type==='text'&&q('unknown').value==='ab','invalid type uses text sanitization');
check(q('span').colSpan===2&&q('span').rowSpan===0,'table span normalization');
q('one').reset();check(q('check').checked&&q('choice').value==='b'&&q('limited').value==='','reset restores attributes, not current values');
]=])
	assert(#realm.Diagnostics==0,table.concat(realm.Diagnostics,"\n")); realm:Destroy(); events:Destroy()
	local limited=State.create(Node.findById(doc,"limited")); limited.Node.Attributes.maxlength="4tail"; limited=State.create(limited.Node)
	local number=State.create(Node.findById(doc,"number")); assert(number.MaxLength==nil,"maxlength does not constrain number")
	local model=Model.new(doc,{limited,number},{Emit=function() return {DefaultPrevented=false} end},function()end)
	model:SetValue(limited,"a"..utf8.char(0x1F600).."bc",true); assert(limited.Value=="a"..utf8.char(0x1F600).."b","User maxlength counts UTF-16 and preserves a surrogate pair")
	model:SetValue(limited,"abcdef",false); assert(limited.Value=="abcdef","Script values retain length"); model:Destroy()
	local factory={create=function(class,parent,props) local gui=table.clone(props); gui.ClassName=class; gui.Parent=parent; return gui end,modifier=function(_,_,props) return table.clone(props) end}
	local render=loadRenderTree(factory)
	local page=render.build(Parser.parseDocument('<input id="a" size="6tail"><input id="b" size="6"><input id="zero" size="0"><input id="default"><textarea id="ta" cols="8tail" rows="3tail"></textarea><textarea id="tb" cols="8" rows="3"></textarea>'),{},error,function(font)return font end)
	local byId={}; for _,control in page.Controls do byId[control.Node.Attributes.id]=control end
	assert(byId.a.Item.IntrinsicWidth==byId.b.Item.IntrinsicWidth and byId.zero.Item.IntrinsicWidth==byId.default.Item.IntrinsicWidth,"Size parsing also controls actual intrinsic width")
	assert(byId.ta.Item.IntrinsicWidth==byId.tb.Item.IntrinsicWidth and byId.ta.Item.IntrinsicHeight==byId.tb.Item.IntrinsicHeight,"Textarea cols/rows affect actual geometry")
	local overrides={['Layout/TextMeasure']={measure=function(text,_,size)return {X=#text*5,Y=size}end}}
	overrides['Layout/WordLayout']=loadWordLayout(overrides); loadBlockLayout(overrides).arrange(page,700,0,0,function()return true end)
	assert(byId.a.Item.OuterWidth==byId.b.Item.OuterWidth and byId.ta.Item.OuterHeight==byId.tb.Item.OuterHeight,"Attribute dimensions reach the arranged layout")
	print("Attribute combinations: actual control/DOM/validation/form/reset and rendered size paths passed")
end
