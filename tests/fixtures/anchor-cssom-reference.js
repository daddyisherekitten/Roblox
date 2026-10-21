var log=[];
var sheet=new CSSStyleSheet();
sheet.replaceSync('@position-try --fit { left: 10px; top: 20px; width: anchor-size(width); margin-left: 3px; color: red; height: 5px !important; }');
var rule=sheet.cssRules[0];
log.push(String(sheet.cssRules.length));
log.push(String(rule instanceof CSSPositionTryRule));
log.push(String(rule instanceof CSSRule));
log.push(rule.name);
log.push(String(rule.type));
log.push(rule.style.getPropertyValue('left'));
log.push(rule.style.getPropertyValue('width'));
log.push(rule.style.getPropertyValue('color'));
log.push(rule.style.getPropertyValue('height'));
rule.style.left='15px';
rule.style.color='blue';
log.push(rule.style.getPropertyValue('left'));
log.push(rule.style.getPropertyValue('color'));
rule.style.setProperty('height','35px');
rule.style.setProperty('height','7px','important');
log.push(rule.style.getPropertyValue('height'));
log.push(rule.style.getPropertyPriority('height'));
rule.name='--other';
log.push(rule.name);
sheet.insertRule('@position-try --second { left: 2px; top: 4px; }',1);
log.push(sheet.cssRules[1].name);
rule.style.cssText='width: 25px; left: 12px; background: red; top: 3px !important;';
log.push(rule.style.getPropertyValue('width'));
log.push(rule.style.getPropertyValue('background'));
log.push(rule.style.getPropertyValue('top'));
log.push(rule.cssText);
var style=document.createElement('div').style;
for(var value of ['--fit','normal --fit','most-width --fit, flip-inline','none','most-height none','most-width','flip-inline most-width','inherit','initial','unset','revert','revert-layer','MOST-WIDTH --Fit','m\\6f st-width --fit','var(--order) --fit','most-width var(--fallbacks)']){
 style.cssText='position-try-order: most-height; position-try: '+value+';';
 log.push(style.length+'|'+style.positionTryOrder+'|'+style.positionTryFallbacks+'|'+style.positionTry+'|'+style.cssText);
}
style.cssText='position-try: most-width --fit, flip-inline !important;';
log.push(style.getPropertyPriority('position-try')+'|'+style.cssText);
style.positionTryFallbacks='none';
log.push(style.positionTry+'|'+style.cssText);
log.push(style.removeProperty('position-try')+'|'+style.cssText);
style.cssText='position-try: var(--options) !important;';
style.positionTryFallbacks='none';
log.push(style.positionTryOrder+'|'+style.positionTryFallbacks+'|'+style.positionTry+'|'+style.cssText);
for(var declaration of ['position-try-order: inherit;position-try-fallbacks: --fit','position-try-order: normal;position-try-fallbacks: initial','position-try-order: var(--order);position-try-fallbacks: --fit','position-try-order: most-width;position-try-fallbacks: var(--choices)','position-try-order: INITIAL;position-try-fallbacks: INITIAL','position-try-order: var(--same);position-try-fallbacks: var(--same)']){
 style.cssText=declaration;
 log.push(style.positionTryOrder+'|'+style.positionTryFallbacks+'|'+style.positionTry+'|'+style.cssText);
}
