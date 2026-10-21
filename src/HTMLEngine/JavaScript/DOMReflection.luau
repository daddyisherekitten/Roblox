--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- Declarative HTML reflection routes through the same mutation/dirty-tree hook.
-- State, resource geometry and platform methods continue to use their hosts.
local VM=require(script.Parent.VM)
local AttributeValues=require(script.Parent.Parent.HTML.AttributeValues)
local FormOwner=require(script.Parent.Parent.DOM.FormOwner)
local Work=require(script.Parent.Parent.WorkContext)
local Reflection={}
local generic={title="title",lang="lang",dir={"dir","enum",{"ltr","rtl","auto"},""},accessKey="accesskey",
	contentEditable={"contenteditable","enum",{"true","false","plaintext-only"},"inherit"},inputMode={"inputmode","enum",{"none","text","tel","url","email","numeric","decimal","search"},""},
	enterKeyHint={"enterkeyhint","enum",{"enter","done","go","next","previous","search","send"},""},draggable={"draggable","bool-enum"},
	spellcheck={"spellcheck","spell"},translate={"translate","translate"},tabIndex={"tabindex","tab"},inert={"inert","boolean"},
	autofocus={"autofocus","boolean"},nonce="nonce",slot="slot",
	headingOffset={"headingoffset","clamped-unsigned",0,8},headingReset={"headingreset","boolean"},
	autocapitalize={"autocapitalize","capitalization"},autocorrect={"autocorrect","correction"},writingSuggestions={"writingsuggestions","suggestions"}}
local formInheriting={button=true,fieldset=true,input=true,output=true,select=true,textarea=true}
local capitalization={off="none",none="none",on="sentences",sentences="sentences",words="words",characters="characters"}
local function capitalizationHint(node)
	local raw=node.Attributes.autocapitalize
	if raw~=nil and raw~=""then return capitalization[raw:lower()]or"sentences"end
	local owner=if formInheriting[ElementNames.htmlName(node)]then FormOwner.resolve(node)else nil
	if owner then return capitalizationHint(owner)end
	return ""
end
local function correction(node)
	local kind=node.Attributes.type and node.Attributes.type:lower()
	if ElementNames.htmlName(node)=="input"and(kind=="url"or kind=="email"or kind=="password")then return false end
	local raw=node.Attributes.autocorrect
	if raw==nil and formInheriting[ElementNames.htmlName(node)]then
		local owner=FormOwner.resolve(node);raw=owner and owner.Attributes.autocorrect
	end
	return raw==nil or raw:lower()~="off"
end
local function suggestions(node)
	while node and node.Kind=="Element"do
		Work.checkpoint()
		local raw=node.Attributes.writingsuggestions
		if raw~=nil then return if raw:lower()=="false"then"false"else"true"end
		-- The standard inherits through parentElement, not a shadow host or slot.
		node=node.Parent
	end
	return "true"
end
local tags={
	a={href={"href","url"},target="target",download="download",ping="ping",rel="rel",hreflang="hreflang",type="type",referrerPolicy="referrerpolicy"},
	area={href={"href","url"},target="target",download="download",alt="alt",coords="coords",shape="shape",rel="rel"},
	base={href={"href","url","document"},target="target"},blockquote={cite={"cite","url"}},q={cite={"cite","url"}},del={cite={"cite","url"},dateTime="datetime"},ins={cite={"cite","url"},dateTime="datetime"},
	data={value="value"},time={dateTime="datetime"},label={htmlFor="for"},legend={align="align"},
	meta={name="name",httpEquiv="http-equiv",content="content",scheme="scheme"},link={href={"href","url"},rel="rel",media="media",hreflang="hreflang",type="type",as="as",crossOrigin={"crossorigin","nullable-enum",{"anonymous","use-credentials"},"anonymous"},referrerPolicy="referrerpolicy"},
	style={media="media",type="type"},img={name="name",alt="alt",src={"src","url"},srcset="srcset",sizes="sizes",crossOrigin={"crossorigin","nullable-enum",{"anonymous","use-credentials"},"anonymous"},useMap="usemap",isMap={"ismap","boolean"},loading={"loading","enum",{"lazy","eager"},"eager"},decoding={"decoding","enum",{"sync","async","auto"},"auto"}},
	iframe={src={"src","url"},srcdoc="srcdoc",name="name",allow="allow",allowFullscreen={"allowfullscreen","boolean"},loading={"loading","enum",{"lazy","eager"},"eager"},referrerPolicy="referrerpolicy"},
	video={poster={"poster","usv-url"},width={"width","unsigned",0},height={"height","unsigned",0},playsInline={"playsinline","boolean"},videoWidth={"","readonly",0},videoHeight={"","readonly",0}},
	source={src={"src","usv-url"},type="type",srcset={"srcset","usv"},sizes="sizes",media="media",width={"width","unsigned",0},height={"height","unsigned",0}},track={src={"src","url"},kind={"kind","enum",{"subtitles","captions","descriptions","chapters","metadata"},"subtitles"},srclang="srclang",label="label",default={"default","boolean"}},
	form={name="name",action={"action","url","document"},method={"method","enum",{"get","post","dialog"},"get"},enctype={"enctype","enum",{"application/x-www-form-urlencoded","multipart/form-data","text/plain"},"application/x-www-form-urlencoded"},encoding={"enctype","enum",{"application/x-www-form-urlencoded","multipart/form-data","text/plain"},"application/x-www-form-urlencoded"},target="target",autocomplete={"autocomplete","enum",{"on","off"},"on"},acceptCharset="accept-charset",rel="rel"},
	input={accept="accept",alt="alt",src={"src","url"},autocomplete="autocomplete",formAction={"formaction","url","document"},formMethod={"formmethod","enum",{"get","post","dialog"},"get"},formEnctype={"formenctype","enum",{"application/x-www-form-urlencoded","multipart/form-data","text/plain"},"application/x-www-form-urlencoded"},formTarget="formtarget",formNoValidate={"formnovalidate","boolean"}},
	button={formAction={"formaction","url","document"},formMethod={"formmethod","enum",{"get","post","dialog"},"get"},formEnctype={"formenctype","enum",{"application/x-www-form-urlencoded","multipart/form-data","text/plain"},"application/x-www-form-urlencoded"},formTarget="formtarget",formNoValidate={"formnovalidate","boolean"}},
	textarea={autocomplete="autocomplete",wrap={"wrap","enum",{"soft","hard"},"soft"}},select={autocomplete="autocomplete"},optgroup={label="label"},fieldset={name="name"},output={name="name"},
	details={open={"open","boolean"},name="name"},dialog={open={"open","boolean"},returnValue={"","state"}},map={name="name"},object={data={"data","url"},type="type",name="name",useMap="usemap"},embed={src={"src","url"},type="type",name="name"},
}
for _,name in {"input","textarea"} do
	tags[name].maxLength={"maxlength","length",-1}; tags[name].minLength={"minlength","length",-1}
end
tags.input.size={"size","positive",20}
tags.textarea.cols={"cols","positive",20}; tags.textarea.rows={"rows","positive",2}
tags.select.size={"size","unsigned",0}
Reflection.Generic=generic;Reflection.Tags=tags
function Reflection.new(ctx: any): any
	local api={}
	local function spec(node,key)
		local name=ElementNames.htmlName(node);if not name then return nil end
		return (tags[name]and tags[name][key])or generic[key]
	end
	function api:Get(node,key)
		local s=spec(node,key);if not s then return false end
		if type(s)=="string"then return true,node.Attributes[s]or""end
		local name,kind=s[1],s[2];local raw=node.Attributes[name]
		if kind=="capitalization"then return true,capitalizationHint(node)
		elseif kind=="correction"then return true,correction(node)
		elseif kind=="suggestions"then return true,suggestions(node)end
		if kind=="boolean"then return true,raw~=nil elseif kind=="state"then return true,node.DialogReturnValue or""end
		if kind=="usv"then return true,ctx.String(raw or"",true)end
		if kind=="clamped-unsigned"then return true,AttributeValues.clampedNonnegative(raw,s[3],s[4])end
		if kind=="readonly"then return true,s[3]end
		if kind=="url"or kind=="usv-url"then
			local value=if raw==nil and s[3]~="document"then''else ctx.ResolveURL(node,raw or'')
			return true,if kind=='usv-url'then ctx.String(value,true)else value
		end
		if kind=="tab"then local n=raw and tonumber(raw:match("^[\t\n\f\r ]*([%+%-]?%d+)"));return true,if n and n>=-2147483648 and n<=2147483647 then n else if ElementNames.htmlName(node)=="a"and node.Attributes.href~=nil or ElementNames.htmlName(node)=="area"or ElementNames.htmlName(node)=="input"or ElementNames.htmlName(node)=="button"or ElementNames.htmlName(node)=="select"or ElementNames.htmlName(node)=="textarea"then 0 else -1 end
		local lower=raw and raw:lower()
		if kind=="bool-enum"then return true,if lower=="true"then true elseif lower=="false"then false else ElementNames.htmlName(node)=="img"or(ElementNames.htmlName(node)=="a"and node.Attributes.href~=nil)end
		if kind=="spell"then
			local current=node
			while current do
				local value=current.Attributes and current.Attributes.spellcheck
				if value~=nil then value=value:lower(); if value=="false" then return true,false elseif value=="true" or value=="" then return true,true end end
				current=current.Parent
			end
			return true,true
		end
		if kind=="length" or kind=="positive" or kind=="unsigned" then
			local value=AttributeValues.nonnegative(raw,2147483647)
			return true,if value and (kind~="positive" or value>0) then value else s[3]
		end
		if kind=="translate"then
			local current=node;while current do local value=current.Attributes and current.Attributes.translate;if value~=nil then value=value:lower();if value=="no"then return true,false elseif value=="yes"or value==""then return true,true end end;current=current.Parent end;return true,true
		end
		if kind=="nullable-enum"and raw==nil then return true,VM.Null end
		return true,if lower and table.find(s[3],lower)then lower elseif key=="contentEditable"and raw==""then"true"else s[4]
	end
	function api:Set(node,key,value)
		local s=spec(node,key);if not s then return false end
		if type(s)=="string"then ctx.Attribute(node,s,ctx.String(value));return true end
		local kind=s[2];local text
		if kind=="readonly"then return false end
		if kind=="state"then node.DialogReturnValue=ctx.String(value);return true
		elseif kind=="usv-url"or kind=="usv"then text=ctx.String(value,true)
		elseif kind=="boolean"then text=if VM.truth(value)then""else nil
		elseif kind=="bool-enum"or kind=="spell"then text=if VM.truth(value)then"true"else"false"
		elseif kind=="correction"then text=if VM.truth(value)then"on"else"off"
		elseif kind=="translate"then text=if VM.truth(value)then"yes"else"no"
		elseif kind=="tab"then local number=ctx.Long(value);text=tostring(number)
		elseif kind=="length" then local number=ctx.Long(value); if number<0 then ctx.Error("IndexSizeError","Length cannot be negative") end; text=tostring(number)
		elseif kind=="positive" or kind=="unsigned" or kind=="clamped-unsigned" then
			local number=ctx.Long(value)%4294967296; if kind=="positive" and number==0 then ctx.Error("IndexSizeError","Size must be greater than zero") end
			text=tostring(if number<=2147483647 then number else s[3])
		elseif kind=="nullable-enum"and value==VM.Null then text=nil
		else text=ctx.String(value);if key=="contentEditable"then text=text:lower();if text~="inherit"and text~="true"and text~="false"and text~="plaintext-only"then ctx.Error("SyntaxError","Invalid contentEditable value")end;if text=="inherit"then text=nil end end end
		ctx.Attribute(node,s[1],text);return true
	end
	return api
end
return Reflection
