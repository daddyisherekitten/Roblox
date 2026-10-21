--!strict
return function(loadDemoStatus)
	local attributes, messages, errors = {Status="loading"}, {}, {}
	local page={Root={GetAttribute=function(_,key) return attributes[key] end}}
	local startup={Visible=true}
	local update=loadDemoStatus(page,startup,function(message) table.insert(errors,message) end,function(message) table.insert(messages,message) end)
	update(); assert(#messages == 0)
	page.LastLayoutStats={Mode="full",Recomputed=100,Reused=0}
	attributes.Presented=false;attributes.Status="ready";update()
	assert(#messages==0 and not startup.Visible,'The loading viewport stays blank and does not report ready while SVG uploads are pending')
	attributes.Presented=true
	attributes.Status="ready"; update()
	assert(#messages == 1 and not startup.Visible,"The startup status hides after the first ready layout")
	-- Both queued callbacks read the final status after a fast layout -> ready pair.
	attributes.Status="layout"
	local first,second=update,update
	page.LastLayoutStats={Mode="partial",Recomputed=5,Reused=78}
	attributes.Status="ready"; first(); second()
	assert(#messages == 2,"One completed layout must print only once with deferred status callbacks")
	-- A genuinely new layout must still be reported, even with identical statistics.
	page.LastLayoutStats={Mode="partial",Recomputed=5,Reused=78}
	update(); update(); assert(#messages == 3)
	attributes.Status="layout"; update(); assert(#messages == 3)
	page.LastLayoutStats={Mode="full",Recomputed=100,Reused=0}
	attributes.Status="ready"; update(); assert(#messages == 4)
	attributes.Status="error"; attributes.Error="Test error"; update()
	assert(errors[1] == "Test error")
	print("Demo status: deferred callbacks report each completed layout once; real later layouts and errors remain visible")
end
