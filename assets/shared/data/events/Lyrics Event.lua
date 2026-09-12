luaDebugMode = true

function onLoad()
    makeLuaText('lyricTxt')
    setTextBorder('lyricTxt', 0)
    setScrollFactor('lyricTxt', 1, 1)
    addLuaText('lyricTxt')
    addToGroup('lyricGrp', 'lyricTxt')

    makeLuaSprite('lyricBG')
    makeGraphic('lyricBG', 1, 1, '000000')
    setObjectOrder('lyricBG', getObjectOrder('lyricTxt')-1)
    setProperty('lyricBG.visible', false)
    addLuaSprite('lyricBG')
    addToGroup('lyricGrp', 'lyricBG')

    runHaxeCode([[
        import flixel.text.FlxTextFormat;
        import flixel.text.FlxTextFormatMarkerPair;

        var underlineFormat = new FlxTextFormat(null, null, null, null, true);
        var underlineMarkerPair = new FlxTextFormatMarkerPair(underlineFormat, "[u]");

        var colorPattern = new EReg("\\[c\\](.*?)\\[c\\]\\(([0-9a-fA-F]{6})\\)", "g"); // FUN!!! https://tenor.com/pt-BR/view/durr-durr-emoji-durr-face-emoji-durr-tiktok-emoji-gif-7565955608204849028

        function checkForFomats(txt:String){
            getLuaObject('lyricTxt').applyMarkup(txt, [underlineMarkerPair]); // applies the other formats to get rid of their patterns first cuz if we don't do this the color format gets all fucked up

            var text:String = '';
            var textRaw:String = getLuaObject('lyricTxt').text;
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

            getLuaObject('lyricTxt').text = text;
            for (i in formatsToApply) {
                getLuaObject('lyricTxt').addFormat(new FlxTextFormat(i.color), i.start, i.end);
            }
        }
    ]])
end

function lyric(txt, cam, size, pos, font, bgAlpha, txtColor, tag)
    if txt == nil or txt == '' or string.len(txt) == 0 then
        setProperty('lyricBG.visible', false)
        setProperty('lyricTxt.visible', false)
        setTextString('lyricTxt', '')
        return
    end
    
    runHaxeFunction('checkForFomats', {txt})
    setTextFont('lyricTxt', font)
    setTextSize('lyricTxt', size)
    setTextColor('lyricTxt', txtColor)
    setObjectCamera('lyricTxt', (cam[1] == 'Custom' and cam[2] or cam[1]))
    setProperty('lyricTxt.visible', true)

    local y = (downscroll and 140 or screenHeight - getProperty('lyricTxt.height') - 110)
    local position = {x = tonumber(pos[1]), y = (tonumber(pos[2]) == 0 and y or tonumber(pos[2]))}

    if position.x ~= 0 then setProperty('lyricTxt.x', position.x) else screenCenter('lyricTxt', 'x') end
    setProperty('lyricTxt.y', position.y)

    setObjectCamera('lyricBG', (cam[1] == 'Custom' and cam[2] or cam[1]))
    scaleObject('lyricBG', getProperty('lyricTxt.width') + 10, getProperty('lyricTxt.height') + 5)
    setProperty('lyricBG.alpha', bgAlpha)
    centerBG()
    setProperty('lyricBG.visible', true)

    callOnScripts('onLyricLoad')
    if tag ~= nil or tag ~= '' or string.len(tag) > 0 then callOnScripts('onLyricTag', {tag}) end
end

function centerBG()
    setProperty('lyricBG.x', getProperty('lyricTxt.x') + (getProperty('lyricTxt.width') / 2) - (getProperty('lyricBG.width') / 2))
    setProperty('lyricBG.y', getProperty('lyricTxt.y') + (getProperty('lyricTxt.height') / 2) - (getProperty('lyricBG.height') / 2))
end

function onEvent(event, txt, cam, size, pos, font, bgAlpha, txtColor, tag)
    if event == 'Lyrics Event' then
        lyric(string.gsub(txt, '\\n', '\n'), stringSplit(cam, ', '), size, stringSplit(pos, ', '), font, bgAlpha, txtColor, tag)
    end
end