--!strict
return function(TypeAhead)
	local time=0
	local search=TypeAhead.new(function() return time end)
	local c={Type='select',Options={
		{Caption='Standard'}, {Caption='Klein',Disabled=true}, {Caption='Kompakt'}, {Caption='Komfort'},
		{Caption='Kurz'}, {Caption='  Quick Start'}, {Caption='Äpfel'}, {Caption='42'},
	}}
	local handled,index=search:Find(c,1,'K'); assert(handled and index == 3)
	_,index=search:Find(c,3,'k'); assert(index == 4,'Repeated initial cycles forward')
	_,index=search:Find(c,4,'k'); assert(index == 5)
	_,index=search:Find(c,5,'k'); assert(index == 3,'Cycle wraps and skips disabled options')
	_,index=search:Find(c,3,'o'); assert(index == 3,'Extending a prefix keeps a matching current option')
	_,index=search:Find(c,3,'m'); assert(index == 3)
	_,index=search:Find(c,3,'f'); assert(index == 4,'Combined letters find a longer prefix')
	time=1; _,index=search:Find(c,4,'s'); assert(index == 1,'A one-second pause starts a new search')
	search:Reset(); _,index=search:Find(c,1,'ä'); assert(index == 7,'Latin case mapping includes umlauts')
	search:Reset(); _,index=search:Find(c,1,'4'); assert(index == 8)
	search:Reset(); assert(not search:Find(c,1,' '),'Space without a prefix keeps dropdown activation')
	local current=1
	for character in ('quick start'):gmatch('.') do
		handled,index=search:Find(c,current,character); assert(handled and index == 6); current=index
	end
	search:Reset(); handled,index=search:Find(c,1,'z'); assert(handled and index == nil)
	assert(not search:Find(c,1,'Escape') and not search:Find(c,1,'\n'))
	c.Disabled=true; assert(not search:Find(c,1,'k')); c.Disabled=false
	local other={Type='select',Options={{Caption='Kabel'}}}
	_,index=search:Find(other,0,'k'); assert(index == 1,'Changing controls clears a previous prefix')
	handled,index=search:Find({Type='select',Options={}},0,'k'); assert(handled and index == nil)
	print('Select typeahead: prefixes, timeout, repeated-letter cycling, disabled options, labels, umlauts, digits, spaces and empty lists passed')
end
