// don't forget about those
var steps = 6;
var data = [];



function presentWiki(wikiLink){
    $('#wiki3').hide().text(wikiLink).fadeIn();
}

function generateNewData() {
    data = [];
    for(var i = 0; i < steps; i++) {
        data.push( { order: [], current: 0 });
        while(data[i].order.length < 3) {
            var randomNumber = Math.floor(Math.random() * 3) + 1;
            if ($.inArray(randomNumber, data[i].order) == -1) {
                data[i].order.push(randomNumber);
            }
        }
    }
    resetPuzzle();
}

function resetPuzzle() {
    for(var i = 0; i < steps; i++) {
        data[i].current = 0;
    }
    $('.puzzle-spot').removeAttr('onMouseOver onMouseOut onClick').removeClass('clicked');
    $('.puzzle-spot[data-step="1"]').attr({
        'onMouseOver': 'LinkHover()',
        'onMouseOut': 'LinkOut()',
        'onClick': 'SolvePuzzle(this)'
    });
}

function resetStep(step) {
    if (typeof step != 'undefined' && step >= 0 && step < steps) {
        data[step].current = 0;
        $('.puzzle-spot[data-step="'+ (step + 1) + '"]').attr({
            'onMouseOver': 'LinkHover()',
            'onMouseOut': 'LinkOut()',
            'onClick': 'SolvePuzzle(this)'
        }).removeClass('clicked');
    }
}

function SolvePuzzle(e) {
    var $this = $(e);
    var step = $this.data('step') - 1;
    var pick = $this.data('pick');
    var shouldClick = data[step].order[data[step].current];
    if (pick == shouldClick) {
        puzzleClickedGood();
        data[step].current++;
        $('.puzzle-spot[data-step="'+ (step + 1) + '"][data-pick="' + pick + '"]')
            .addClass('clicked')
            .removeAttr('onMouseOver onMouseOut onClick');
        if (data[step].current >= 3) {
            var solvedSteps = 0;
            for(var i = 0; i < steps; i++) {
                solvedSteps += (data[i].current >= 3 ? 1 : 0);
            }
            if (solvedSteps >= steps) {
                puzzleSolved();
            } else {
                $('.puzzle-spot[data-step="' + (step + 2) + '"]').attr({
                    'onMouseOver': 'LinkHover()',
                    'onMouseOut': 'LinkOut()',
                    'onClick': 'SolvePuzzle(this)'
                });
            }
        }
    } else {
        puzzleClickedWrong();
        // If user fucked up should we reset only this one segment (step)
        // or whole puzzle?
        //resetPuzzle();
        //resetStep(step);
        resetPuzzle();
    }
}

$(document).ready(function() {
    generateNewData();
});