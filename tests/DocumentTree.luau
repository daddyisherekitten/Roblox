--!strict
return function(Parser: any,Node: any,fixtures: any)
	local function serialize(document: any): string
		local lines={}
		local function visit(node: any,depth: number)
			local prefix="| "..string.rep("  ",depth)
			if node.Kind=="Element" then
				local ns=if node.NamespaceURI=="http://www.w3.org/2000/svg" then "svg " elseif node.NamespaceURI=="http://www.w3.org/1998/Math/MathML" then "math " else ""
				table.insert(lines,prefix.."<"..ns..node.Name..">")
				local names={}; local values={}
                for name,value in node.Attributes do
                    local info=node.AttributeNamespaces and node.AttributeNamespaces[name]
                    local adjusted=if info then (info.Prefix or "xmlns").." "..info.LocalName else name
                    table.insert(names,adjusted); values[adjusted]=value
                end
                table.sort(names)
                for _,name in names do table.insert(lines,prefix.."  "..name..'="'..values[name]..'"') end
				if node.Content then table.insert(lines,prefix.."  content"); for _,child in node.Content.Children do visit(child,depth+2) end end
			elseif node.Kind=="Text" then table.insert(lines,prefix..'"'..node.Text..'"')
			elseif node.Kind=="Comment" then table.insert(lines,prefix.."<!-- "..node.Text.." -->")
			elseif node.Kind=="ProcessingInstruction" then table.insert(lines,prefix.."<?"..node.Target.." "..node.Text.."?>")
			elseif node.Kind=="DocumentType" then table.insert(lines,prefix.."<!DOCTYPE "..node.Name..(if node.PublicId~="" or node.SystemId~="" then ' "'..node.PublicId..'" "'..node.SystemId..'"' else "")..">") end
			for _,child in node.Children do assert(child.Parent==node,"Parser parent link"); visit(child,depth+1) end
		end
		for _,child in document.Children do visit(child,0) end
		return table.concat(lines,"\n")
	end
	local failed={}; local passed=0
	for _,case in fixtures.cases do
		local ok,actual=pcall(function() return serialize(Parser.parseDocument(case.html,{ScriptingEnabled=case.scripting,DisableDeclarativeShadowRoots=true})) end)
		if ok and actual==case.expected then passed+=1 else
			table.insert(failed,case.id)
			if #failed<=45 then print("TREE_FAILURE "..case.id.." "..string.format("%q",case.html).."\nEXPECTED\n"..case.expected.."\nACTUAL\n"..tostring(actual)) end
		end
	end
	print("TREE_RESULT "..passed.."/"..#fixtures.cases.." FAILED "..table.concat(failed,","))
	assert(#failed==0,"Document tree differs from independent reference cases")
	local streamed=0
	for _,chunkSize in {1,7,31}do for _,case in fixtures.cases do
		local session=Parser.newDocument('',{ScriptingEnabled=case.scripting,DisableDeclarativeShadowRoots=true,_ScriptCreated=true})
		for start=1,#case.html,chunkSize do
			local point=session.InsertionPoint;local stop=session:Insert(case.html:sub(start,start+chunkSize-1))
			while session:Advance(stop)do end;session.InsertionPoint=point
		end
		session:Close();while not session.Done do session:Advance()end
		local actual=serialize(session.Document)
		assert(actual==case.expected,'Incremental document tree '..case.id..' '..string.format('%q',case.html)..'\nEXPECTED\n'..case.expected..'\nACTUAL\n'..actual)
		session:Destroy();streamed+=1
	end end
	print('STREAM_TREE_RESULT '..streamed..'/'..(#fixtures.cases*3)..' shared tree references in 1/7/31-byte input chunks')
	local fragmentFailures={}
	for _,case in fixtures.fragments do
		local prefix,name=case.context:match("^(%S+) (%S+)$")
		local context=Node.element(name or case.context,{}); context.NamespaceURI=if prefix=="svg" then "http://www.w3.org/2000/svg" elseif prefix=="math" then "http://www.w3.org/1998/Math/MathML" else nil
		local owner=Node.document(); owner.Mode="no-quirks"; Node.append(owner,context)
		local ok,actual=pcall(function()return serialize(Parser.parseFragment(case.html,context,{ScriptingEnabled=case.scripting}))end)
		if not ok or actual~=case.expected then table.insert(fragmentFailures,case.id); print("FRAGMENT_FAILURE "..case.id.." "..case.context.." "..string.format("%q",case.html).."\nEXPECTED\n"..case.expected.."\nACTUAL\n"..tostring(actual)) end
	end
	print("FRAGMENT_RESULT "..(#fixtures.fragments-#fragmentFailures).."/"..#fixtures.fragments)
	assert(#fragmentFailures==0,"Contextual fragment differs from independent reference cases")
	for _,options in {{MaxNodes=3},{MaxDepth=1},{MaxBytes=2},{MaxNodes=0},{MaxDiagnostics=0}} do assert(not pcall(Parser.parseDocument,"<div>x</div>",options),"Document parser enforces limits") end
	local fragments=Parser.parse("<div>A</div><div>B</div>")
	assert(#fragments.Children==2 and fragments.Children[1].Parent==fragments,"Public fragment contract is retained")
	local modes={
		{'<!doctype html>',"no-quirks","html","",""},
		{'<!DOCTYPEhtml>',"no-quirks","html","",""},
		{'<!doctype>',"quirks","","",""},
		{'<!doctype html',"quirks","html","",""},
		{'<!doctype html PUBLIC>',"quirks","html","",""},
		{'<!doctype html PUBLIC "abc>',"quirks","html","abc",""},
		{'<!doctype html PUBLIC "abc',"quirks","html","abc",""},
		{'<!doctype html PUBLIC"abc">',"no-quirks","html","abc",""},
		{'<!doctype html SYSTEM "abc>',"quirks","html","","abc"},
		{'<!doctype html SYSTEM "abc"',"quirks","html","","abc"},
		{'<!doctype html SYSTEM "abc" trailing>',"no-quirks","html","","abc"},
		{'<!doctype html SYSTEM "abc" trailing',"no-quirks","html","","abc"},
		{'<!doctype html PUBLIC "abc""system">',"no-quirks","html","abc","system"},
		{'<!doctype html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">',"quirks","html","-//W3C//DTD HTML 4.01 Transitional//EN",""},
		{'<!doctype html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "">',"quirks","html","-//W3C//DTD HTML 4.01 Transitional//EN",""},
		{'<!doctype html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "system">',"limited-quirks","html","-//W3C//DTD HTML 4.01 Transitional//EN","system"},
		{'<!doctype html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN">',"limited-quirks","html","-//W3C//DTD XHTML 1.0 Transitional//EN",""},
		{'<!doctype html PUBLIC "-//Spyglass//DTD HTML 2.0 Extended//EN">',"quirks","html","-//Spyglass//DTD HTML 2.0 Extended//EN",""},
		{'<!doctype html PUBLIC "-//IETF//DTD HTML modern//EN">',"no-quirks","html","-//IETF//DTD HTML modern//EN",""},
		{'<!doctype html SYSTEM "http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd">',"quirks","html","","http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd"},
		{'<!doctype h\0tml PUBLIC "a\0b" "c\0d">',"quirks","h"..utf8.char(0xFFFD).."tml","a"..utf8.char(0xFFFD).."b","c"..utf8.char(0xFFFD).."d"},
	}
	for _,case in modes do
		local parsed=Parser.parseDocument(case[1]); local doctype=parsed.Children[1]
		assert(parsed.Mode==case[2] and doctype.Name==case[3] and doctype.PublicId==case[4] and doctype.SystemId==case[5],"Doctype state/mode: "..case[1])
	end
	local angles=string.rep("<",20000)
	local ordered=Parser.parseDocument('<div data-z="z" data-a="a"></div>').Body.Children[1]
	local cloned=Node.cloneNode(ordered,true)
	assert(cloned.AttributeOrder[1]=="data-z" and cloned.AttributeOrder[2]=="data-a","Data DOM clones retain parser attribute order")
	cloned.AttributeOrder[1]="independent";assert(ordered.AttributeOrder[1]=="data-z","Cloned attribute order belongs to the clone")
	assert(Node.textContent(Parser.parseDocument(angles))==angles,"Document text aggregation preserves invalid brackets without quadratic concatenation")
	local mirrored='<select><button><selectedcontent></selectedcontent></button><option selected><b>A</b><i>B</i></option></select>'
	local parsed=Parser.parseDocument(mirrored)
	assert(Node.textContent(parsed.Body.Children[1].Children[1])=="AB","Selected content initializes before parser publication")
	assert(not pcall(Parser.parseDocument,mirrored,{MaxNodes=parsed.NodeCount-1}),"Selected content clones obey the allocation budget")
	print("Document robustness: 21 doctype state/mode cases, text aggregation and selected-content clone budgets passed")
	print("Document tree: reference structures, attribute order/values, foreign content, templates, budgets and fragment compatibility passed")
end
