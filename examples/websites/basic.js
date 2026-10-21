$.fn.random = function() {
  return this.eq(Math.floor(Math.random() * this.length));
}

function BuildWiki($WikiData){
	var html = "";
	
	for(var i =0; i < $WikiData.length; i++){
		var siteData = $WikiData[i].split("|");
		var css = "";
		
		if(siteData[3] === "1"){
			css = "visted";
		}
		
		html = html + "<li><a class = '" + css + "' onMouseOver='LinkHover()' onMouseOut='LinkOut()' onClick=\"SiteClick('http://" + siteData[0] + ".ann')\">" + siteData[1] + "</a> - " + siteData[2] + "</li>";
	}
	
	$("#wikiLinks").append(html);
}

function ApplyNudityFilter(){
	$('.nudity').css('-webkit-filter','blur(18px)');
}

function PickPTag(index,hash){
	$('.PTAG').random().text(index + ' - ' + hash);
}

function PickCPTag(){
	var picked = $('.CPTAG').random();
	
	$(picked).attr('onMouseOver', 'LinkHover()');
	$(picked).attr('onMouseOut', 'LinkOut()');
	$(picked).attr('onClick', 'PlainKeyShow()');
}

function PickCFTag(){
	var picked = $('.CFTAG').random();
	
	$(picked).attr('onMouseOver', 'LinkHover()');
	$(picked).attr('onMouseOut', 'LinkOut()');
	$(picked).attr('onClick', 'FileKeyShow()');
}

function randomIntFromInterval(min,max){
    return Math.floor(Math.random()*(max-min+1)+min);
}

function PickHotSpot(){
	SetHotSpot($('.hotZone').random());
}

function SetHotSpot(theHotSpot){
	$(theHotSpot).attr('onMouseOver', 'LinkHover()');
	$(theHotSpot).attr('onMouseOut', 'LinkOut()');
	$(theHotSpot).attr('onClick', 'HotSpotHit()');
}

function PlaceKey(theKeyToPlace){
	if($('#keySpot').length == 0){
		var width = ($(window).width() * 0.8);
		var height = ($(window).height() * 0.8);
		var setX = randomIntFromInterval(10, width);
		var setY = randomIntFromInterval(10, height);
		var html = '<div id = "keySpot" style="top:' + setY + 'px; left:' + setX + 'px;">' + theKeyToPlace + '</div>';
		$("body").append(html);
	}
}