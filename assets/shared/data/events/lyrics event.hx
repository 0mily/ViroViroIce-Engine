// morra e pereça onEvent
import flixel.text.FlxTextFormat;
import flixel.text.FlxTextFormatMarkerPair;

var lyricTxt:FlxText;
var lyricBG:FlxSprite;

function onLoad(){
    lyricTxt = new FlxText(0, 0, 0);
    lyricTxt.borderSize = 0;
    lyricTxt.alignment = 'center';
    lyricTxt.visible = false;
    add(lyricTxt);

    lyricBG = new FlxSprite();
    lyricBG.makeGraphic(1, 1, FlxColor.BLACK);
    lyricBG.visible = false;
    add(lyricBG);
}

var underlineFormat = new FlxTextFormat(null, null, null, null, true);
var underlineMarkerPair = new FlxTextFormatMarkerPair(underlineFormat, "[u]");

var colorPattern = new EReg("\\[c\\](.*?)\\[c\\]\\(([0-9a-fA-F]{6})\\)", "g"); // FUN!!! https://tenor.com/pt-BR/view/durr-durr-emoji-durr-face-emoji-durr-tiktok-emoji-gif-7565955608204849028

function checkForFomats(txt:String){
    lyricTxt.applyMarkup(txt, [underlineMarkerPair]); // applies the other formats to get rid of their patterns first cuz if we don't do this the color format gets all fucked up

    var text:String = '';
    var textRaw:String = lyricTxt.text;
    var formatsToApply:Array<{start:Int, end:Int, color:Int}> = [];

    while (colorPattern.match(textRaw)) {
        var textToFormat:String = colorPattern.matched(1);
        var hexColor:String = colorPattern.matched(2);

        text += colorPattern.matchedLeft();

        var start:Int = text.length;
        var end:Int = start + textToFormat.length;
        var color:FlxColor = FlxColor.fromString('#$hexColor');
        formatsToApply.push({start: start, end: end, color: color});

        text += textToFormat;
        textRaw = colorPattern.matchedRight();
    }

    text += textRaw;

    lyricTxt.text = text;
    for (i in formatsToApply) {
        lyricTxt.addFormat(new FlxTextFormat(i.color), i.start, i.end);
    }
}

function lyric(txt:String, cam:Array<String>, size:String, pos:Array<String>, font:String, bgAlpha:String, txtColor:String, tag:String){
    if (txt == null || txt == '' || txt.length == 0){
        lyricBG.visible = false;
        lyricTxt.visible = false;
        lyricTxt.text = '';
        return;
    }
    
    checkForFomats(txt);
    lyricTxt.font = font;
    lyricTxt.size = size;
    lyricTxt.color = txtColor;
    lyricTxt.cameras = [cam[0] == 'Custom' ? cam[1] : cam[0]];
    lyricTxt.visible = true;

    var y:Float = ClientPrefs.data.downscroll ? 140 : FlxG.height - lyricTxt.height - 110;
    var position:Array<Float> = [x = Std.parseFloat(pos[0]), y = Std.parseFloat(pos[1]) == 0 ? y : Std.parseFloat(pos[1])];

    if (position.x != 0) lyricTxt.x = position.x; else lyricTxt.screenCenter();
    lyricTxt.y = position.y;

    lyricBG.cameras = [cam[0] == 'Custom' ? cam[1] : cam[0]];
    lyricBG.scale.set(lyricTxt.width + 10, lyricTxt.height + 5);
    lyricBG.updateHitbox();
    lyricBG.alpha = bgAlpha;
    centerBG();
    lyricBG.visible = true;

    var lTag:String = '';
    if (tag != null || tag != '' || tag.length > 0)
        lTag = tag;

    callOnScripts('onLyricLoad', [lTag]);
}

function centerBG(){
    lyricBG.x = lyricTxt.x + (lyricTxt.width / 2) - (lyricBG.width / 2);
    lyricBG.y = lyricTxt.y + (lyricTxt.height / 2) - (lyricBG.height / 2);
}

function onEvent(event:String, txt:String, cam:String, size:String, pos:String, font:String, bgAlpha:String, txtColor:String, tag:String){ // fuck you
    if (event == 'Lyrics Event')
        lyric(StringTools.replace(txt, '\\n', '\n'), cam.split(', '), size, pos.split(', '), font, bgAlpha, txtColor, tag);
}