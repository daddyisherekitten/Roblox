--!strict
-- Interface descriptors invoke the same native bridge as direct node access.
local Reflection=require(script.Parent.DOMReflection)
local Interfaces={}
function Interfaces.install(vm: any,globals: any,ctx: any): any
	local U,N=vm.Model.Undefined,vm.Model.Null
	local function fail(message)ctx.Error("TypeError",message)end
	local function native(name,length,call)
		local fn={Kind="native-function",Prototype=vm.Prototypes.Function,Call=call,Values={name=name,length=length}}
		vm.DefineProperty(fn,"name",vm.Object({value=name,configurable=true},N));vm.DefineProperty(fn,"length",vm.Object({value=length,configurable=true},N));return fn
	end
	local function prototype(name)
		local constructor=globals[name];return if constructor then vm.Get(constructor,"prototype")else nil
	end
	local function define(target,key,descriptor)vm.DefineProperty(target,key,vm.Object(descriptor,N))end
	local function receiver(self,kind,tag,html)
		local node=ctx.Unwrap(self)
		if kind and node.Kind~=kind then fail("Incompatible DOM interface receiver")end
		if html and node.NamespaceURI~=nil and node.NamespaceURI~="http://www.w3.org/1999/xhtml"then fail("Incompatible HTML interface receiver")end
		if tag and not table.find(tag,node.LocalName or node.Name)then fail("Incompatible HTML interface receiver")end
		return node
	end
	local function properties(interface,read,write,kind,tag)
		local proto=prototype(interface);if not proto then return end
		local html=interface:sub(1,4)=="HTML"
		local writable={};for key in(write or""):gmatch("%S+")do writable[key]=true end
		for key in read:gmatch("%S+")do
			define(proto,key,{get=native("get "..key,0,function(_,self)return ctx.NativeRead(receiver(self,kind,tag,html),key)end),
				set=if writable[key]then native("set "..key,1,function(args,self)ctx.NativeSet(receiver(self,kind,tag,html),key,if args[1]~=nil then args[1]else U,true);return U end)else U,
				enumerable=true,configurable=true})
		end
	end
	local function methods(interface,names,kind,tag)
		local proto=prototype(interface);if not proto then return end
		for key,length in names do
			define(proto,key,{value=native(key,length,function(args,self)
				local node=receiver(self,kind,tag,interface:sub(1,4)=='HTML');local value=ctx.NativeRead(node,key);if not vm.Model.callable(value)then fail("DOM operation is not supported by this receiver")end
				return if type(value)=="function"then value(args,self)else vm:Call(value,args,self)
			end),writable=true,enumerable=true,configurable=true})
		end
	end
	local collectionPrototypes={}
	for _,name in {"NodeList","HTMLCollection","NamedNodeMap","DOMImplementation"}do
		local proto=vm.Object({});local ctor=native(name,0,function()fail("Illegal "..name.." constructor")end)
		define(ctor,"prototype",{value=proto});define(proto,"constructor",{value=ctor,writable=true,configurable=true});define(proto,vm.SymbolToStringTag,{value=name,configurable=true});globals[name]=ctor;vm.Global.Bindings[name]={Value=ctor};collectionPrototypes[name]=proto
		local function brand(self)if type(self)~="table"or(self.DOMCollectionKind~=name and not(name=='NodeList'and self.DOMCollectionKind=='RadioNodeList'))or type(self.Get)~="function"then fail("Illegal "..name.." receiver")end;return self end
		if name~="DOMImplementation"then define(proto,"length",{get=native("get length",0,function(_,self)return brand(self).Get("length")end),enumerable=true,configurable=true})end
		local lengths=if name=="NodeList"then {item=1,keys=0,values=0,entries=0,forEach=1}elseif name=="HTMLCollection"then {item=1,namedItem=1}elseif name=="NamedNodeMap"then {item=1,getNamedItem=1,getNamedItemNS=2,setNamedItem=1,setNamedItemNS=1,removeNamedItem=1,removeNamedItemNS=2}else{hasFeature=0,createDocumentType=3,createDocument=2,createHTMLDocument=0}
		for key,length in lengths do define(proto,key,{value=native(key,length,function(args,self)local value=brand(self).Get(key);return if type(value)=="function"then value(args,self)else vm:Call(value,args,self)end),writable=true,enumerable=true,configurable=true})end
	end
	local radio=vm.Object({},collectionPrototypes.NodeList);local radioCtor=native('RadioNodeList',0,function()fail('Illegal RadioNodeList constructor')end)
	define(radioCtor,'prototype',{value=radio});define(radio,'constructor',{value=radioCtor,writable=true,configurable=true});define(radio,vm.SymbolToStringTag,{value='RadioNodeList',configurable=true})
	local function radioBrand(self)if type(self)~='table'or self.DOMCollectionKind~='RadioNodeList'then fail('Illegal RadioNodeList receiver')end;return self end
	define(radio,'value',{get=native('get value',0,function(_,self)return radioBrand(self).Get('value')end),set=native('set value',1,function(args,self)radioBrand(self).Set('value',if args[1]~=nil then args[1]else U,true);return U end),enumerable=true,configurable=true})
	globals.RadioNodeList=radioCtor;vm.Global.Bindings.RadioNodeList={Value=radioCtor};collectionPrototypes.RadioNodeList=radio
	local xml=vm.Object({},prototype("Document"));local xmlCtor=native("XMLDocument",0,function()fail("Illegal XMLDocument constructor")end)
	define(xmlCtor,"prototype",{value=xml});define(xml,"constructor",{value=xmlCtor,writable=true,configurable=true});define(xml,vm.SymbolToStringTag,{value="XMLDocument",configurable=true});globals.XMLDocument=xmlCtor;vm.Global.Bindings.XMLDocument={Value=xmlCtor}
	for _,interface in {"DocumentType","CDATASection","ProcessingInstruction","Attr"}do
		if not globals[interface]then local proto=vm.Object({},prototype(if interface=="CDATASection"then"Text"elseif interface=="ProcessingInstruction"then"CharacterData"else"Node"));local ctor=native(interface,0,function()fail("Illegal "..interface.." constructor")end)
			define(ctor,"prototype",{value=proto});define(proto,"constructor",{value=ctor,writable=true,configurable=true});define(proto,vm.SymbolToStringTag,{value=interface,configurable=true});globals[interface]=ctor;vm.Global.Bindings[interface]={Value=ctor}
		end
	end
	properties("Node","nodeType nodeName baseURI isConnected ownerDocument parentNode parentElement childNodes firstChild lastChild previousSibling nextSibling nodeValue textContent","nodeValue textContent")
	properties("Document","implementation URL documentURI compatMode characterSet charset inputEncoding contentType doctype documentElement head body title defaultView readyState hidden visibilityState currentScript activeElement designMode images embeds plugins links forms scripts","body title designMode","Document")
	properties("Element","namespaceURI prefix localName tagName id className classList attributes children childElementCount firstElementChild lastElementChild previousElementSibling nextElementSibling innerHTML outerHTML","id className classList innerHTML outerHTML","Element")
	properties("CharacterData","data length previousElementSibling nextElementSibling","data")
	properties("Text","wholeText")
	properties('HTMLTemplateElement','content',nil,'Element',{'template'})
	properties('HTMLMapElement','areas',nil,'Element',{'map'})
	properties("DocumentType","name publicId systemId",nil,"DocumentType")
	properties("ProcessingInstruction","target",nil,"ProcessingInstruction")
	properties("Attr","name namespaceURI prefix localName value ownerElement specified","value","Attr")
	methods("Document",{open=0,close=0,write=0,writeln=0,createElement=1,createElementNS=2,createTextNode=1,createComment=1,createCDATASection=1,createProcessingInstruction=2,createDocumentFragment=0,createAttribute=1,createAttributeNS=2,getElementById=1,importNode=1,adoptNode=1,getElementsByName=1,getElementsByTagName=1,getElementsByTagNameNS=2,getElementsByClassName=1,querySelector=1,querySelectorAll=1,append=0,prepend=0,replaceChildren=0,getAnimations=0},"Document")
	methods("Element",{getElementsByTagName=1,getElementsByTagNameNS=2,getElementsByClassName=1,getAttributeNS=2,hasAttributeNS=2,setAttributeNS=3,removeAttributeNS=2,getAttributeNode=1,getAttributeNodeNS=2,setAttributeNode=1,setAttributeNodeNS=1,removeAttributeNode=1,moveBefore=2,animate=1,getAnimations=0},"Element")
	methods("CharacterData",{substringData=2,appendData=1,insertData=2,deleteData=2,replaceData=3})
	methods("Text",{splitText=1})
	methods('HTMLSelectElement',{showPicker=0},'Element',{'select'})
	local genericNames={};for key in Reflection.Generic do table.insert(genericNames,key)end;table.sort(genericNames);local joined=table.concat(genericNames," ");properties("HTMLElement",joined,joined,"Element")
	properties("HTMLElement","isContentEditable",nil,"Element")
	local grouped={}
	for tag,fields in Reflection.Tags do local sample=ctx.CreateElement(tag);local proto=vm.GetPrototype(sample);local interface=vm.Get(vm.Get(proto,"constructor"),"name")
		if type(interface)=="string"and interface~="HTMLElement"then local group=grouped[interface];if not group then group={Tags={},Fields={}};grouped[interface]=group end;table.insert(group.Tags,tag);for key in fields do group.Fields[key]=true end end
	end
	for interface,group in grouped do
		local names,writable={},{}
		for key in group.Fields do
			table.insert(names,key)
			local readonly=false;for _,tag in group.Tags do local spec=Reflection.Tags[tag][key];if type(spec)=='table'and spec[2]=='readonly'then readonly=true;break end end
			if not readonly then table.insert(writable,key)end
		end
		table.sort(names);table.sort(writable);properties(interface,table.concat(names," "),table.concat(writable," "),"Element",group.Tags)
	end
	return {XMLDocumentPrototype=xml,CollectionPrototypes=collectionPrototypes}
end
return Interfaces
