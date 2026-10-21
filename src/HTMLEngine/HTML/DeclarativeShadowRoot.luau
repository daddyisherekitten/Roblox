--!strict
-- One eligibility check for document parsing and the legacy source scanner.
local Shadow={}
local Names=require(script.Parent.Parent.DOM.ElementNames)
local Template=require(script.Parent.Parent.DOM.TemplateDocument)
local function eligible(host: any): boolean
	if not host or host.Kind~='Element' or host.NamespaceURI and host.NamespaceURI~='http://www.w3.org/1999/xhtml' or host.InternalShadowRoot then return false end
	return Names.shadow(Names.htmlName(host)) and not(host.CustomElementDefinition and host.CustomElementDefinition.DisableShadow)
end
function Shadow.create(template: any,host: any): any
	local mode=string.lower(template.Attributes.shadowrootmode or '')
	if not template.Content or (mode~='open' and mode~='closed') or not eligible(host) then return nil end
	local root=template.Content
	root.Kind='ShadowRoot';root.Host=host;root.Mode=mode;root.Declarative=true
	Template.assign(root,host.OwnerDocument or template.OwnerDocument)
	root.SlotAssignment=if string.lower(template.Attributes.shadowrootslotassignment or '')=='manual' then 'manual'else 'named'
	root.Clonable=template.Attributes.shadowrootclonable~=nil
	root.Serializable=template.Attributes.shadowrootserializable~=nil
	root.DelegatesFocus=template.Attributes.shadowrootdelegatesfocus~=nil
	if template.Attributes.shadowrootcustomelementregistry~=nil then
		root.KeepCustomElementRegistryNull=true;root.CustomElementRegistryInitialized=true;root.CustomElementRegistry=nil
	end
	host.InternalShadowRoot=root;if mode=='open' then host.ShadowRoot=root end
	return root
end
return Shadow
