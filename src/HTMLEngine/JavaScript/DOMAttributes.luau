--!strict
local Names=require(script.Parent.DOMNames)
local Markup=require(script.Parent.DOMMarkup)
local VM=require(script.Parent.VM)
local Store=require(script.Parent.Parent.DOM.AttributeStore)
local Attributes={}
function Attributes.new(ctx: any): any
	local api={};local maps=setmetatable({},{__mode="kv"})
	local function string(value)return ctx.String(if value==nil then VM.Undefined else value)end
	local function htmlCase(node,name)return if (node.NamespaceURI==nil or node.NamespaceURI==Names.HTML)and(node.OwnerDocument or ctx.Document).IsHTML~=false then name:lower()else name end
	local function create(owner,name,namespace,localName,prefix)
		local raw={Kind="Attr",Name=name,Text="",NamespaceURI=namespace or"",LocalName=localName or name,Prefix=prefix,Children={},Parent=nil}
		return ctx.Allocate(raw,owner)
	end
	local function materialize(node,name)
		if node.Attributes[name]==nil then return nil end
		node.AttributeNodes=node.AttributeNodes or{};local raw=node.AttributeNodes[name]
		if not raw then local info=node.AttributeNamespaces and node.AttributeNamespaces[name];raw=create(node.OwnerDocument or ctx.Document,Store.name(node,name),Store.namespace(node,name),info and info.LocalName,info and info.Prefix);raw.OwnerElement=node;raw.StorageKey=name;node.AttributeNodes[name]=raw end
		raw.Text=node.Attributes[name];return raw
	end
	local expanded=Store.expanded
	local function detach(node,name)
		local raw=materialize(node,name);if raw then raw.Text=node.Attributes[name];raw.OwnerElement=nil;raw.StorageKey=nil;node.AttributeNodes[name]=nil end;return raw
	end
	local function setNode(node,value)
		local raw=ctx.Unwrap(value);if raw.Kind~="Attr"then ctx.Error("TypeError","Expected an Attr")end
		if raw.OwnerElement and raw.OwnerElement~=node then ctx.Error("InUseAttributeError","Attribute is already owned by another element")end
		local uri=Names.namespace(raw.NamespaceURI)
		local oldName=expanded(node,uri,raw.LocalName)
		local old=if oldName then materialize(node,oldName)else nil;if old==raw then return value end
		local destination=oldName or Store.destination(node,uri,raw.LocalName,raw.Prefix)
		-- The shared mutation publishes the Attr identity after validation and
		-- before synchronous resource/custom-element callbacks can observe it.
		ctx.Attribute(node,destination,raw.Text,uri,{Namespace=uri,LocalName=raw.LocalName,Prefix=raw.Prefix,QualifiedName=raw.Name},raw)
		return ctx.Wrap(old)
	end
	function api:Changed(node,name,value)
		local raw=node.AttributeNodes and node.AttributeNodes[name]
		if raw then if value==nil then raw.OwnerElement=nil;raw.StorageKey=nil;node.AttributeNodes[name]=nil else raw.Text=value end end
		if value==nil and node.AttributeNamespaces then node.AttributeNamespaces[name]=nil end
	end
	function api:Get(node,key)
		if node.Kind=="Attr"then
			if key=="name"or key=="nodeName"then return true,node.Name elseif key=="value"or key=="nodeValue"or key=="textContent"then return true,if node.OwnerElement then node.OwnerElement.Attributes[node.StorageKey or node.Name]or node.Text else node.Text
			elseif key=="ownerElement"then return true,ctx.Wrap(node.OwnerElement)elseif key=="specified"then return true,true elseif key=="namespaceURI"then return true,Names.namespace(node.NamespaceURI)or VM.Null elseif key=="prefix"then return true,node.Prefix or VM.Null elseif key=="localName"then return true,node.LocalName elseif key=="nodeType"then return true,2 end
			return false
		elseif node.Kind=="Document"and(key=="createAttribute"or key=="createAttributeNS")then return true,function(args)
			ctx.RequireArgs(args,if key=="createAttributeNS"then 2 else 1)
			local name=string(args[if key=="createAttributeNS"then 2 else 1]);local namespace,localName,prefix
			if key=="createAttributeNS"then namespace,localName,prefix=Names.extract(if args[1]==VM.Null or args[1]==VM.Undefined then nil else string(args[1]),name,ctx.Error)
			else if node.IsHTML~=false then name=name:lower()end;if not Names.validAttribute(name)then ctx.Error("InvalidCharacterError","Invalid attribute name")end end
			return ctx.Wrap(create(node,name,namespace,localName,prefix))
		end end
		if node.Kind~="Element"then return false end
		if key=="getAttributeNode"or key=="getAttributeNodeNS"then return true,function(args)
			ctx.RequireArgs(args,if key=="getAttributeNodeNS"then 2 else 1)
			local name=if key=="getAttributeNodeNS"then expanded(node,if args[1]==VM.Null or args[1]==VM.Undefined then nil else string(args[1]),string(args[2]))else Store.qualified(node,htmlCase(node,string(args[1])))
			return ctx.Wrap(if name then materialize(node,name)else nil)
		end end
		if key=="setAttributeNode"or key=="setAttributeNodeNS"then return true,function(args)ctx.RequireArgs(args,1);return setNode(node,args[1])end end
		if key=="removeAttributeNode"then return true,function(args)
			ctx.RequireArgs(args,1);local raw=ctx.Unwrap(args[1]);if raw.Kind~="Attr"then ctx.Error("TypeError","Expected Attr")end
			if raw.OwnerElement~=node then ctx.Error("NotFoundError","Attribute does not belong to this element")end
			local name=raw.StorageKey or raw.Name;detach(node,name);ctx.Attribute(node,name,nil);return args[1]
		end end
		if key=="getAttributeNS"or key=="hasAttributeNS"or key=="removeAttributeNS"then return true,function(args)
			ctx.RequireArgs(args,2);local name=expanded(node,if args[1]==VM.Null or args[1]==VM.Undefined then nil else string(args[1]),string(args[2]))
			if key=="getAttributeNS"then return if name then node.Attributes[name]else VM.Null elseif key=="hasAttributeNS"then return name~=nil elseif name then ctx.Attribute(node,name,nil)end;return VM.Undefined
		end end
		if key=="setAttributeNS"then return true,function(args)
			ctx.RequireArgs(args,3);local name=string(args[2]);local namespace,localName,prefix=Names.extract(if args[1]==VM.Null or args[1]==VM.Undefined then nil else string(args[1]),name,ctx.Error);local value=string(args[3]);local existing=expanded(node,namespace,localName)
			local destination=existing or Store.destination(node,namespace,localName,prefix)
			-- Namespace/prefix metadata belongs to the attribute before its change
			-- steps run: script/resource hooks and reentrant author code can read it.
			local oldInfo=existing and node.AttributeNamespaces and node.AttributeNamespaces[existing]
			ctx.Attribute(node,destination,value,namespace,{Namespace=namespace,LocalName=localName,Prefix=if existing then oldInfo and oldInfo.Prefix else prefix,QualifiedName=if existing then Store.name(node,existing)else name})
		end end
		if key=="attributes"then
			if not maps[node]then maps[node]={DOMCollectionKind="NamedNodeMap",GetPrototype=function()return ctx.Prototype("NamedNodeMap")end,Get=function(property)
				if type(property)=="table"then return VM.Undefined end
				local names=Markup.attributeNames(node)
				if property=="length"then return #names elseif property=="item"then return function(args)ctx.RequireArgs(args,1);local index=ctx.Uint(args[1]);return ctx.Wrap(names[index+1]and materialize(node,names[index+1]))end
				elseif property=="getNamedItem"or property=="getNamedItemNS"then local _,method=self:Get(node,if property=="getNamedItem"then"getAttributeNode"else"getAttributeNodeNS");return method
				elseif property=="setNamedItem"or property=="setNamedItemNS"then local _,method=self:Get(node,if property=="setNamedItem"then"setAttributeNode"else"setAttributeNodeNS");return method
				elseif property=="removeNamedItem"or property=="removeNamedItemNS"then return function(args)
					local _,get=self:Get(node,if property=="removeNamedItem"then"getAttributeNode"else"getAttributeNodeNS");local raw=get(args);if raw==VM.Null then ctx.Error("NotFoundError","Attribute is absent")end;local _,remove=self:Get(node,"removeAttributeNode");return remove({raw})
				end end
				local index=tonumber(property);local name=if index and index>=0 and index%1==0 and tostring(index)==property then names[index+1]elseif htmlCase(node,property)==property then Store.qualified(node,property)else nil
				return if name and node.Attributes[name]~=nil then ctx.Wrap(materialize(node,name))else VM.Undefined
			end,Keys=function(enumerable)
				local values={};local keys=Markup.attributeNames(node)
				for index in keys do table.insert(values,tostring(index-1))end
				if not enumerable then for _,key in keys do
					local name=Store.name(node,key)
					if htmlCase(node,name)==name and name~="length"and name~="item"and not table.find(values,name)then table.insert(values,name)end
				end end
				return values
			end}end
			return true,maps[node]
		end
		return false
	end
	function api:Set(node,key,value)
		if node.Kind=="Attr"and(key=="value"or key=="nodeValue"or key=="textContent")then local text=if value==VM.Null and key~="value"then""else string(value);if node.OwnerElement then ctx.Attribute(node.OwnerElement,node.StorageKey or node.Name,text)else node.Text=text end;return true end
		return false
	end
	return api
end
return Attributes
