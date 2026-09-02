luaDebugMode = true

function onLoad()
    --setProperty('camGame.bgColor', getColorFromHex('FFFFFF'))
    makeLuaText('loltxt', '', 0, 0, legendaY)
    setTextFont('loltxt', 'better-vcr.ttf')
    setTextSize('loltxt', 20)
    screenCenter('loltxt', 'x')
    setTextBorder('loltxt', 0)
    setObjectCamera('loltxt', 'other')
    addLuaText('loltxt')

    makeLuaSprite('lolbg')
    makeGraphic('lolbg', 1, 1, '000000')
    setObjectOrder('lolbg', getObjectOrder('loltxt')-1)
    setProperty('lolbg.alpha', 0.5)
    setProperty('lolbg.visible', false)
    setObjectCamera('lolbg', 'other')
    addLuaSprite('lolbg')
end

function lyric(txt)
    setTextString('loltxt', txt)
    screenCenter('loltxt', 'x')

    setProperty('loltxt.y', screenHeight - getProperty('loltxt.height') - 100)

    scaleObject('lolbg', getProperty('loltxt.width') + 10, getProperty('loltxt.height') + 5)
    setProperty('lolbg.visible', getTextString('loltxt') ~= '')
    centerBG()
end

function centerBG()
    setProperty('lolbg.x', getProperty('loltxt.x') + (getProperty('loltxt.width') / 2) - (getProperty('lolbg.width') / 2))
    setProperty('lolbg.y', getProperty('loltxt.y') + (getProperty('loltxt.height') / 2) - (getProperty('lolbg.height') / 2))
end

function onEvent(event, value1, value2, strumTime)
    if event == 'Lyrics Event' then
        lyric(value1)
    end
end