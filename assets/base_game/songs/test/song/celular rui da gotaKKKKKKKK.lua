local ativo = true
local cmesar = false

function onPause() -- eu creio q isso nn funciona
    if ativo and not cmesar then
        return Function_Stop
    end
    return Function_Continue
end

function onStartCountdown()
    if ativo and not cmesar then -- é roubar a mema base de outra coisa q fiz uns meses atrás
        createAvisin()
        return Function_Stop
    end
    return Function_Continue
end

function createAvisin()
    local lang = getPropertyFromClass('backend.ClientPrefs', 'data.language')
    local restoLore = ''

    if lang == 'pt-BR' then
        restoLore = 'essa música é feita apenas para testar coisas novas da engine. Sinta-se livre para jogar.'
    else
        restoLore = 'this song is made only to test new things in the engine. Feel free to play.'
    end

    makeLuaSprite('pauseBG', '', 0, 0)
    makeGraphic('pauseBG', screenWidth, screenHeight, '000000')
    setProperty('pauseBG.alpha', 0.5)
    setObjectCamera('pauseBG', 'other')
    addLuaSprite('pauseBG', true)

    makeLuaText('warningTitle', 'ROUBEI CÓDIGO ANTIGO', screenWidth, 0, screenHeight * 0.30)
    setTextAlignment('warningTitle', 'center')
    setTextSize('warningTitle', 50)
    setTextColor('warningTitle', 'FFFF00')
    setObjectCamera('warningTitle', 'other')
    addLuaText('warningTitle')

    makeLuaText('warningResto',
        restoLore,
        screenWidth - 200,
        100,
        screenHeight * 0.45
    )
    setTextAlignment('warningResto', 'center')
    setTextSize('warningResto', 24)
    setTextColor('warningResto', 'FFFFFF')
    setObjectCamera('warningResto', 'other')
    addLuaText('warningResto')

    makeLuaText('warningLegal', 'press LEFT [<] to continue', screenWidth, 0, screenHeight * 0.70)

    setTextAlignment('warningLegal', 'center')
    setTextSize('warningLegal', 22)
    setTextColor('warningLegal', 'FFFFFF')
    setObjectCamera('warningLegal', 'other')
    addLuaText('warningLegal')

    doTweenAlpha('oLoop1', 'warningLegal', 0, 1, 'sineInOut')
end

function onTweenCompleted(tag)
    if tag == 'oLoop1' then
        doTweenAlpha('oLoop2EletricBoogaloo', 'warningLegal', 1, 1, 'sineInOut')
    elseif tag == 'oLoop2EletricBoogaloo' then
        doTweenAlpha('oLoop1', 'warningLegal', 0, 1, 'sineInOut')
    end
end

function onUpdate()
    if ativo and not cmesar then
        if keyJustPressed('left') then
            cmesar = true

            playSound('clickText', 1)

            removeLuaSprite('pauseBG', true)
            removeLuaText('warningTitle', true)
            removeLuaText('warningResto', true)
            removeLuaText('warningLegal', true)

            startCountdown()
        end
    end
end