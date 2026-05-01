function onCreate()
    -- Uses my custom camera event if present in your files, which can be found in my ports
    if checkFileExists('custom_events/Set Camera Target.lua') then
        addLuaScript('custom_events/Set Camera Target')
    end
    
    setProperty('lightning.visible', false)
    if lowQuality == false then
        createInstance('sky', 'flixel.addons.display.FlxTiledSprite', {nil, 4000, 495, true, false})
        loadGraphic('sky', 'streets/blazin/skyBlur')
        setObjectOrder('sky', getObjectOrder('skyAdd'))
        setScrollFactor('sky', 0, 0)
        addLuaSprite('sky')
        callMethod('sky.setPosition', {-700, -120})

        setBlendMode('skyAdd', 'ADD')
        setBlendMode('streetsMultiply', 'MULTIPLY')
        setBlendMode('lightenAdd', 'ADD')
        setProperty('skyAdd.alpha', 0)
        setProperty('streetsMultiply.alpha', 0)
        setProperty('lightenAdd.alpha', 0)
    end
end

function onCreatePost()
    -- Sets up the haxe commands needed for the stage's script
    runHaxeCode([[
        // Rain shader functions.
        function activateRainShader() FlxG.camera.setFilters([new ShaderFilter(game.getLuaObject('rainFilter').shader)]);
        function deactivateRainShader() FlxG.camera.setFilters([]);
    ]])

    if shadersEnabled == true then
        -- Adds the rain on the stage
        initLuaShader('rain')
        makeLuaSprite('rainFilter')
        setSpriteShader('rainFilter', 'rain')
        setShaderFloat('rainFilter', 'uScale', screenHeight / 200)
        setShaderFloat('rainFilter', 'uIntensity', 0.5)
        setShaderFloatArray('rainFilter', 'uRainColor', {102 / 255, 128 / 255, 204 / 255})
        setShaderFloatArray('rainFilter', 'uFrameBounds', {0, 0, screenWidth, screenHeight})
        runHaxeFunction('activateRainShader')
    end
    
    -- Makes it so the camera never moves during the song
    if isRunning('custom_events/Set Camera Target.lua') then
        triggerEvent('Set Camera Target', 'GF,125,-100', '0')
    else
        local cameraTargetGF = {
            x = getMidpointX('gf') + getProperty('gf.cameraPosition[0]') + getProperty('girlfriendCameraOffset[0]'),
            y = getMidpointY('gf') + getProperty('gf.cameraPosition[1]') + getProperty('girlfriendCameraOffset[1]')
        }
        setProperty('camFollow.x', cameraTargetGF.x + 125)
        setProperty('camFollow.y', cameraTargetGF.y - 100)
        callMethod('camGame.snapToTarget')
        setProperty('camGame.target', nil)
    end

    -- Darken the characters slightly and adds a fade-in transition for the stage
    cameraFlash('game', '000000', 1.5, true)
    setProperty('boyfriend.color', 0xDEDEDE)
    setProperty('dad.color', 0xDEDEDE)
    setProperty('gf.color', 0x888888)
end

local elapsedTime = 0
local timeScale = 1
local lightningActive = true
local lightningTimer = 3
function onUpdate(elapsed)
    -- This controls the movement of the sky on the stage
    if lowQuality == false then
        setProperty('sky.scrollX', getProperty('sky.scrollX') - elapsed * 35)
    end

    -- Makes the rain active and will increasingly slow it down if a note isn't hit
    if shadersEnabled == true then
        elapsedTime = elapsedTime + (elapsed * timeScale)
        setShaderFloat('rainFilter', 'uTime', elapsedTime)
        timeScale = math.smoothLerpPrecision(timeScale, 0.02, elapsed, 1.535, 1 / 100)
        setShaderFloatArray('rainFilter', 'uScreenResolution', {screenWidth, screenHeight})
        setShaderFloatArray('rainFilter', 'uCameraBounds', {getProperty('camGame.viewLeft'), getProperty('camGame.viewTop'), getProperty('camGame.viewRight'), getProperty('camGame.viewBottom')})
    end

    -- Lightning appears
    if lightningActive == true then
        lightningTimer = lightningTimer - elapsed
        if lightningTimer <= 0 then
            strikelightning()
            lightningTimer = getRandomFloat(7, 15)
        end
    end
end

-- Needed if we don't want the rain and lightning to affect the Game Over screen
function onGameOver()
    lightningActive = false
    if shadersEnabled == true then
        runHaxeFunction('deactivateRainShader')
    end
end

-- Needed since we don't want the lightning to be active during a cutscene
function onEndSong()
    lightningActive = false
end

-- This is makes the lightning strike, affecting the background and characters
local lightningOffset = 0
function strikelightning()
    if getRandomBool(65) then
        lightningOffset = getRandomInt(-250, 280)
    else
        lightningOffset = getRandomInt(780, 900)
    end
    local num = getRandomInt(1, 3)
    setProperty('lightning.visible', true)
    setProperty('lightning.x', lightningOffset)
    playAnim('lightning', 'anim')
    playSound('lightning/Lightning'..num)

    if flashingLights == true then
        if lowQuality == false then
            setProperty('skyAdd.alpha', 0.7)
            setProperty('streetsMultiply.alpha', 0.64)
            setProperty('lightenAdd.alpha', 0.3)
            doTweenAlpha('removeSkyAdd', 'skyAdd', 0, 1.5, 'linear')
            doTweenAlpha('removeStreetsMultiply', 'streetsMultiply', 0, 1.5, 'linear')
            doTweenAlpha('removeLightenAdd', 'lightenAdd', 0, 0.3, 'linear')
        end

        setProperty('boyfriend.color', 0x606060)
        setProperty('dad.color', 0x606060)
        setProperty('gf.color', 0x606060)
        doTweenColor('resetColorBF', 'boyfriend', '0xDEDEDE', 0.3, 'linear')
        doTweenColor('resetColorDad', 'dad', '0xDEDEDE', 0.3, 'linear')
        doTweenColor('resetColorGF', 'gf', '0x888888', 0.3, 'linear')
    end
end

-- Speeds up the rain's speed with each note hit, both from the opponent and the player
function goodNoteHit(membersIndex, noteData, noteType, isSustainNote)
    if shadersEnabled == true then
        timeScale = timeScale + 0.7
    end
end

function opponentNoteHit(membersIndex, noteData, noteType, isSustainNote)
    if shadersEnabled == true then
        timeScale = timeScale + 0.7
    end
end

-- Extra function needed for the stage's script
function math.smoothLerpPrecision(base, target, deltaTime, duration, precision)
    if deltaTime == 0 or precision ^ (deltaTime / duration) == 1 then
        return base
    end
    if base == target or precision ^ (deltaTime / duration) == 0 then
        return target
    end
    return target + (precision ^ (deltaTime / duration)) * (base - target)
end