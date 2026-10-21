--!strict
-- This proves parsing/preservation only. It deliberately makes no assertion
-- that an arbitrary retained attribute changes a control, layout or resource.
return function(Parser: any,registry: any)
	local checks=0
	local wrappers={caption={"<table>","</table>"},col={"<table><colgroup>","</colgroup></table>"},colgroup={"<table>","</table>"},
		tbody={"<table>","</table>"},thead={"<table>","</table>"},tfoot={"<table>","</table>"},tr={"<table><tbody>","</tbody></table>"},
		td={"<table><tbody><tr>","</tr></tbody></table>"},th={"<table><tbody><tr>","</tr></tbody></table>"},
		option={"<select>","</select>"},optgroup={"<select>","</select>"}}
	local void={area=true,base=true,br=true,col=true,embed=true,hr=true,img=true,input=true,link=true,meta=true,source=true,track=true,wbr=true}
	for _,entry in registry.entries do
		local name=if entry.attribute=="data-*" then "data-audit" else entry.attribute
		for _,label in entry.appliesTo do
			local tag=if label:sub(1,13)=="HTML elements" then "div" elseif label:find("form-associated custom",1,true) then "audit-field" else label:match("^([a-z][a-z0-9%-]*)")
			assert(tag,"Unrecognized applicability: "..label)
			for _,variant in {{'="a &amp; &notin; &#x80;"',"a & ∉ €"},{'="false"',"false"},{"", ""},{'=first '..name..'=second',"first"}} do
				local source="<"..tag.." data-audit-node=yes "..name..variant[1]..">"..(if void[tag] then "" else "</"..tag..">")
				local wrap=wrappers[tag]; if wrap then source=wrap[1]..source..wrap[2] end
				local doc=Parser.parseDocument(source); local pending={doc}; local target=nil
				while #pending>0 do local node=table.remove(pending); if node.Attributes and node.Attributes["data-audit-node"]=="yes" then target=node; break end; for _,child in node.Children do table.insert(pending,child) end end
				assert(target and target.Name==tag and target.Attributes[name]==variant[2],"Attribute parsing: "..entry.id.." on "..tag.." "..variant[1]); checks+=1
			end
		end
	end
	print("Attribute catalog: "..checks.." parsing-only cases passed across "..#registry.entries.." applicability groups")
end
