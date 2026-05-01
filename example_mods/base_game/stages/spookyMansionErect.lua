function onCreate()
	if lowQuality == false then
		setProperty('mansion.alpha', 0)
		setProperty('stairs.alpha', 0)
	end

	if flashingLights == true then
		makeLuaSprite('lightningFlash', '', -800, -400)
		makeGraphic('lightningFlash', screenWidth * 2, screenHeight * 2, 'FFFFFF')
		setScrollFactor('lightningFlash', 0, 0)
		setBlendMode('lightningFlash', 'ADD')
		addLuaSprite('lightningFlash', true)
		setProperty('lightningFlash.alpha', 0)
	end

    precacheSound('thunder_1')
	precacheSound('thunder_2')
end

function onCreatePost()
	if shadersEnabled == true then
        initLuaShader('rain')
        setSpriteShader('trees', 'rain')
        setShaderFloat('trees', 'uScale', screenHeight / 200 * 2)
        setShaderFloat('trees', 'uIntensity', 0.4)
        setShaderBool('trees', 'uSpriteMode', true)
		setShaderFloatArray('trees', 'uRainColor', {102 / 255, 128 / 255, 204 / 255})
		setShaderFloatArray('trees', 'uScreenResolution', {screenWidth, screenHeight})
		setShaderFloatArray('trees', 'uCameraBounds', {0, 0, screenWidth, screenHeight})

		-- Runs an haxe command needed for the shader to work
		runHaxeCode([[
            var trees = game.getLuaObject('trees');
            trees.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
            {
                trees.shader.setFloatArray('uFrameBounds', [trees.frame.uv.x, trees.frame.uv.y, trees.frame.uv.width, trees.frame.uv.height]);
            }
        ]])
    end

	--[[
		This is to make the stage usable with other characters that don't have their dark variant.
		Go see the scripts for 'bf-dark', 'spooky-dark', or 'gf-dark' to see how they work,
		and use it for other characters that have dark variants (like Pico for example).
	]]
	for i, character in ipairs({'boyfriend', 'dad', 'gf'}) do
		if not stringEndsWith(_G[character..'Name'], '-dark') then
			setProperty(character..'.color', 0x070711)
		end
	end
end

-- Makes the rain active.
local elapsedTime = 0
function onUpdate(elapsed)
    if shadersEnabled == true then
        elapsedTime = elapsedTime + elapsed
		setShaderFloat('trees', 'uTime', elapsedTime)
    end
end

-- All of this down below is to make the mechanics of the stage work
lastLightningStrike = 0
lightningInterval = 8
function onBeatHit()
	-- Lightning appears
	if getRandomBool(10) and curBeat > lastLightningStrike + lightningInterval then
		strikeLightning()
	end
end

-- This makes the lightning strike, affecting the background and characters
function strikeLightning()
	lastLightningStrike = curBeat
	lightningInterval = getRandomInt(8, 24)
    
	local soundNum = getRandomInt(1, 2)
	playSound('thunder_'..soundNum)
    if lowQuality == false then
		setProperty('mansion.alpha', 1)
		setProperty('stairs.alpha', 1)

		for i, character in ipairs({'boyfriend', 'dad', 'gf'}) do
			if stringEndsWith(_G[character..'Name'], '-dark') then
				setProperty(character..'.alpha', 0)
			else
				-- Support for non '-dark' variants
				setProperty(character..'.color', 0xFFFFFF)
			end
		end

		runTimer('delayLightningBack', 0.06)
		runTimer('startLightningBack', 0.12)
	end

    for i, character in ipairs({'boyfriend', 'dad', 'gf'}) do
        if callMethod(character..'.hasAnimation', {'scared'}) then
	        playAnim(character, 'scared', true)
        end
    end
    
    if cameraZoomOnBeat == true then
		setProperty('camGame.zoom', getProperty('camGame.zoom') + 0.015)
		setProperty('camHUD.zoom', getProperty('camHUD.zoom') + 0.03)

		if getProperty('camZooming') == false then
			doTweenZoom('zoomBack', 'camGame', getProperty('defaultCamZoom'), 0.5, 'linear')
			doTweenZoom('zoomBackHUD', 'camHUD', 1, 0.5, 'linear')
		end
	end
	
	if flashingLights == true then
		setProperty('lightningFlash.alpha', 0.4)
		doTweenAlpha('flashAlphaTween', 'lightningFlash', 0.5, 0.075, 'linear')
		runTimer('delayFlashAphaBack', 0.15)
	end
end

function onTimerCompleted(tag, loops, loopsLeft)
	if tag == 'delayFlashAphaBack' then
		doTweenAlpha('flashAphaBack', 'lightningFlash', 0, 0.25, 'linear')
	end
	if tag == 'delayLightningBack' then
		setProperty('mansion.alpha', 0)
		setProperty('stairs.alpha', 0)

		for i, character in ipairs({'boyfriend', 'dad', 'gf'}) do
			if stringEndsWith(_G[character..'Name'], '-dark') then
				setProperty(character..'.alpha', 1)
			else
				-- Support for non '-dark' variants
				setProperty(character..'.color', 0x070711)
			end
		end
	end
	if tag == 'startLightningBack' then
		setProperty('mansion.alpha', 1)
		setProperty('stairs.alpha', 1)
		doTweenAlpha('mansionAlphaBack', 'mansion', 0, 1.5, 'linear')
		doTweenAlpha('stairsAlphaBack', 'stairs', 0, 1.5, 'linear')

		for i, character in ipairs({'boyfriend', 'dad', 'gf'}) do
			if stringEndsWith(_G[character..'Name'], '-dark') then
				setProperty(character..'.alpha', 0)
				doTweenAlpha(character..'alphaBack', character, 1, 1.5, 'linear')
			else
				-- Support for non '-dark' variants
				setProperty(character..'.color', 0xFFFFFF)
				doTweenColor(character..'colorBack', character, '070711', 1.5, 'linear')
			end
		end
	end
end