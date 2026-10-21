--!strict
local ElementNames=require(script.Parent.Parent.DOM.ElementNames)
-- HTML table interfaces use live child filters, never cached layout rows.
-- Every edit enters the common atomic DOM mutation path (selectors, observers,
-- retained controls, renderer reconciliation and custom-element reactions).
local VM=require(script.Parent.VM)
local Node=require(script.Parent.Parent.DOM.Node)
local Tables={}
local sections={thead=true,tbody=true,tfoot=true}
local sectionKeys={caption="caption",tHead="thead",tFoot="tfoot"}
local stringAttributes={
	table={align="align",bgColor="bgcolor",border="border",cellPadding="cellpadding",cellSpacing="cellspacing",frame="frame",rules="rules",summary="summary",width="width"},
	caption={align="align"},thead={align="align",ch="char",chOff="charoff",vAlign="valign"},tbody={align="align",ch="char",chOff="charoff",vAlign="valign"},tfoot={align="align",ch="char",chOff="charoff",vAlign="valign"},
	tr={align="align",ch="char",chOff="charoff",vAlign="valign",bgColor="bgcolor"},
	td={abbr="abbr",headers="headers",align="align",axis="axis",height="height",width="width",ch="char",chOff="charoff",vAlign="valign",bgColor="bgcolor"},
	th={abbr="abbr",headers="headers",align="align",axis="axis",height="height",width="width",ch="char",chOff="charoff",vAlign="valign",bgColor="bgcolor"},
	col={align="align",ch="char",chOff="charoff",vAlign="valign",width="width"},colgroup={align="align",ch="char",chOff="charoff",vAlign="valign",width="width"},
}
local html=ElementNames.html
local function filtered(parent,test)
	local result={};for _,child in parent.Children do if html(child) and test(child)then table.insert(result,child)end end;return result
end
local function first(parent,name)for _,child in parent.Children do if html(child,name)then return child end end;return nil end
function Tables.rows(parent:any):any
	if not html(parent,"table")then return filtered(parent,function(n)return ElementNames.htmlName(n)=="tr"end)end
	local result={}
	for _,phase in {"head","body","foot"}do
		for _,child in parent.Children do
			if html(child,"tr")and phase=="body"then table.insert(result,child)
			elseif html(child)and sections[ElementNames.htmlName(child)]and (if ElementNames.htmlName(child)=="thead"then "head"elseif ElementNames.htmlName(child)=="tfoot"then "foot"else "body")==phase then
				for _,row in child.Children do if html(row,"tr")then table.insert(result,row)end end
			end
		end
	end
	return result
end
local function cells(parent)return filtered(parent,function(n)return ElementNames.htmlName(n)=="td"or ElementNames.htmlName(n)=="th"end)end
function Tables.new(ctx:any):any
	local bridge={};local collections=setmetatable({},{__mode="k"})
	function bridge:CompatibleMethod(origin,receiver,key)
		if not self:Has(origin,key)then return true end
		if not html(receiver)then return false end
		if sections[ElementNames.htmlName(origin)]then return sections[ElementNames.htmlName(receiver)]==true end
		return ElementNames.htmlName(origin)==ElementNames.htmlName(receiver)
	end
	local function collection(node,key,entries)
		local cached=collections[node];if not cached then cached={};collections[node]=cached end
		if not cached[key]then cached[key]=ctx.CollectionView(entries,true)end;return cached[key]
	end
	local function number(value,unsigned)
		-- ToNumber can run author conversion code, so collect live rows afterwards.
		local primitive=if ctx.ToPrimitive then ctx.ToPrimitive(value,"number")else value
		if type(primitive)=="table"and (primitive.Kind=="symbol"or primitive.Kind=="bigint")then ctx.DOMError("TypeError","Cannot convert table index to a number")end
		local n=VM.number(primitive);if n~=n or n==math.huge or n==-math.huge or n==0 then return 0 end
		n=(if n<0 then math.ceil(n)else math.floor(n))%4294967296
		return if unsigned or n<2147483648 then n else n-4294967296
	end
	local function newElement(name)return ctx.Allocate(Node.element(name,{}))end
	local function insert(parent,child,before)return ctx.Mutate(parent,{child},before,nil)end
	local function remove(parent,child)return ctx.Mutate(parent,{},nil,{child})end
	local function sectionBefore(node,name)
		if name=="caption"then return node.Children[1]end
		if name=="thead"then for _,child in node.Children do if html(child)and ElementNames.htmlName(child)~="caption"and ElementNames.htmlName(child)~="colgroup"then return child end end end
		return nil
	end
	function bridge:Has(node,key)
		if not html(node)then return false end
		local name=ElementNames.htmlName(node)
		if stringAttributes[name]and stringAttributes[name][key]then return true end
		if name=="table"then return sectionKeys[key]~=nil or key=="rows"or key=="tBodies"or key=="createCaption"or key=="deleteCaption"or key=="createTHead"or key=="deleteTHead"or key=="createTFoot"or key=="deleteTFoot"or key=="createTBody"or key=="insertRow"or key=="deleteRow"end
		if sections[name]then return key=="rows"or key=="insertRow"or key=="deleteRow"end
		if name=="tr"then return key=="cells"or key=="rowIndex"or key=="sectionRowIndex"or key=="insertCell"or key=="deleteCell"end
		if name=="td"or name=="th"then return key=="colSpan"or key=="rowSpan"or key=="cellIndex"or key=="scope"or key=="noWrap"end
		return (name=="col"or name=="colgroup")and key=="span"
	end
	function bridge:Get(node,key)
		ctx.Check();if not self:Has(node,key)then return false,VM.Undefined end
		local name=ElementNames.htmlName(node);local attrs=stringAttributes[name]
		if attrs and attrs[key]then return true,node.Attributes[attrs[key]]or ""end
		if key=="scope"then local raw=(node.Attributes.scope or ""):lower();return true,if raw=="row"or raw=="col"or raw=="rowgroup"or raw=="colgroup"then raw else ""end
		if key=="noWrap"then return true,node.Attributes.nowrap~=nil end
		if key=="colSpan"or key=="rowSpan"or key=="span"then
			local maximum=if key=="rowSpan"then 65534 else 1000
			local raw=node.Attributes[key:lower()];local digits=raw and raw:match("^[ \t\r\n\f]*%+?(%d+)");local n=digits and tonumber(digits)
			return true,if not n or(n==0 and key~="rowSpan")then 1 else math.min(n,maximum)
		end
		if sectionKeys[key]then return true,ctx.Wrap(first(node,sectionKeys[key]))end
		if key=="rows"then return true,collection(node,key,function()return Tables.rows(node)end)end
		if key=="tBodies"then return true,collection(node,key,function()return filtered(node,function(n)return ElementNames.htmlName(n)=="tbody"end)end)end
		if key=="cells"then return true,collection(node,key,function()return cells(node)end)end
		if key=="cellIndex"then return true,if html(node.Parent,"tr")then (table.find(cells(node.Parent),node)or 0)-1 else -1 end
		if key=="rowIndex"or key=="sectionRowIndex"then
			local parent=node.Parent;local owner=parent
			if key=="rowIndex"and html(parent)and sections[ElementNames.htmlName(parent)]then owner=parent.Parent end
			return true,if html(owner,"table")or(key=="sectionRowIndex"and html(owner)and sections[ElementNames.htmlName(owner)])then (table.find(Tables.rows(owner),node)or 0)-1 else -1
		end
		if key=="createCaption"or key=="createTHead"or key=="createTFoot"then
			local tag=if key=="createCaption"then "caption"elseif key=="createTHead"then "thead"else "tfoot"
			return true,function()ctx.Check();local existing=first(node,tag);if existing then return ctx.Wrap(existing)end;local made=newElement(tag);insert(node,made,sectionBefore(node,tag));return ctx.Wrap(made)end
		end
		if key=="deleteCaption"or key=="deleteTHead"or key=="deleteTFoot"then
			local tag=if key=="deleteCaption"then "caption"elseif key=="deleteTHead"then "thead"else "tfoot"
			return true,function()ctx.Check();local existing=first(node,tag);if existing then remove(node,existing)end;return VM.Undefined end
		end
		if key=="createTBody"then return true,function()
			ctx.Check();local bodies=filtered(node,function(n)return ElementNames.htmlName(n)=="tbody"end);local last=bodies[#bodies]
			local before=if last then node.Children[(table.find(node.Children,last)or 0)+1]else nil;local made=newElement("tbody");insert(node,made,before);return ctx.Wrap(made)
		end end
		if key=="insertRow"or key=="insertCell"then return true,function(args)
			ctx.Check();local index=if args[1]==nil or args[1]==VM.Undefined then -1 else number(args[1],false)
			local entries=if key=="insertCell"then cells(node)else Tables.rows(node)
			if index < -1 or index>#entries then ctx.DOMError("IndexSizeError","Table insertion index is out of range")end
			local made=newElement(if key=="insertCell"then "td"else "tr");local owner,before=node,nil
			if name=="table"then
				if #entries==0 then
					local bodies=filtered(node,function(n)return ElementNames.htmlName(n)=="tbody"end);owner=bodies[#bodies]
					if not owner then owner=newElement("tbody");Node.append(owner,made);insert(node,owner,nil);return ctx.Wrap(made)end
				elseif index==-1 or index==#entries then owner=entries[#entries].Parent
				else before=entries[index+1];owner=before.Parent end
			elseif index~=-1 and index<#entries then before=entries[index+1]end
			insert(owner,made,before);return ctx.Wrap(made)
		end end
		if key=="deleteRow"or key=="deleteCell"then return true,function(args)
			ctx.Check();ctx.RequireArgs(args,1);local index=number(args[1],false)
			local entries=if key=="deleteCell"then cells(node)else Tables.rows(node)
			if index < -1 or index>=#entries then ctx.DOMError("IndexSizeError","Table deletion index is out of range")end
			local target=entries[if index==-1 then #entries else index+1];if target then remove(target.Parent,target)end;return VM.Undefined
		end end
		return true,VM.Undefined
	end
	function bridge:Set(node,key,value,strict)
		ctx.Check();if not self:Has(node,key)then return false end
		local attrs=stringAttributes[ElementNames.htmlName(node)]
		if attrs and attrs[key]then ctx.Attribute(node,attrs[key],ctx.ReflectedString(value));return true end
		if key=="scope"then ctx.Attribute(node,"scope",ctx.ReflectedString(value));return true end
		if key=="noWrap"then ctx.Attribute(node,"nowrap",if VM.truth(value)then ""else nil);return true end
		if key=="span"or key=="colSpan"or key=="rowSpan"then
			local n=number(value,true);n=math.min(if key=="rowSpan"then 65534 else 1000,n);if n==0 and key~="rowSpan"then n=1 end
			ctx.Attribute(node,key:lower(),tostring(n));return true
		end
		if ElementNames.htmlName(node)=="table"and sectionKeys[key]then
			local tag=sectionKeys[key];local child
			if value~=VM.Null and value~=VM.Undefined and value~=nil then
				child=ctx.Unwrap(value)
				if not html(child,tag)then ctx.DOMError("HierarchyRequestError","Incorrect table section element")end
			end
			local old=first(node,tag);if old then remove(node,old)end
			if child then insert(node,child,sectionBefore(node,tag))end;return true
		end
		-- Readonly attributes ignore sloppy writes; operation members can be own
		-- expandos in the ordinary wrapper, so leave those to its setter.
		if key=="rows"or key=="tBodies"or key=="cells"or key=="rowIndex"or key=="sectionRowIndex"or key=="cellIndex"then
			if strict~=false then ctx.DOMError("TypeError","Read-only table property: "..key)end;return true
		end
		return false
	end
	return bridge
end
return Tables
