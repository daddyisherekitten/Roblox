--!strict
return function(Edit)
	local value=Edit.describe('Hé 🌲','Hé 森🌲',nil)
	assert(value.data=='森'and value.inputType=='insertText'and not value.isComposing)
	local replaced=Edit.describe('a🙂b','a🧑‍🎨b',nil);assert(replaced.data=='🧑‍🎨','Unicode replacement keeps complete UTF-8 characters')
	local backspace=Edit.describe('a🙂b','ab','deleteContentBackward')
	assert(backspace.data==nil and backspace.inputType=='deleteContentBackward')
	local unknown=Edit.describe('ab','a',nil)
	assert(unknown.data==nil and unknown.inputType=='','An unobserved native deletion does not invent a key or paste operation')
	local line=Edit.describe('a','a\n','insertLineBreak');assert(line.inputType=='insertLineBreak'and line.data==nil)
	print('Native text edits: Unicode insert/replacement, observed deletion hints and honest composition limits passed')
end
