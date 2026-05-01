function onCreate()
    makeLuaText('loltxt', '', 1000, 0, 0)
    setTextAlignment('loltxt', 'center')
    setTextSize('loltxt', 26)
    setTextBorder('loltxt', 0, '000000')
    setObjectCamera('loltxt', 'other')
    addLuaText('loltxt')

    makeLuaSprite('lolbg', nil, 0, 0)
    makeGraphic('lolbg', screenWidth, 50, '000000')
    setObjectCamera('lolbg', 'other')
    setProperty('lolbg.alpha', 0.7)
    addLuaSprite('lolbg')

    setProperty('loltxt.visible', false)
    setProperty('lolbg.visible', false)
end

function onEvent(name, v1, v2)
    if name == 'Lyrics Event' then
        
        if v1 == nil or v1 == '' then
            setProperty('loltxt.visible', false)
            setProperty('lolbg.visible', false)
            return -- me sinto profissional
        end

        v1 = string.gsub(v1, "\\n", "\n")

        setTextString('loltxt', v1)
        setProperty('loltxt.visible', true)
        setProperty('lolbg.visible', true)

        screenCenter('loltxt', 'x')

        local ypreto = downscroll and 100 or 550
        setProperty('loltxt.y', ypreto)

        local ybranco = 12
        local racismo = getProperty('loltxt.height')

        makeGraphic('lolbg', screenWidth, racismo + ybranco * 2, '000000')

        setProperty('lolbg.x', 0)
        setProperty('lolbg.y', ypreto - ybranco)
    end
end