function onCreate()
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

--[[
	This is kinda useless but fuck it, we ballin'.

	Basically, it makes so the solid color behind the stage is the same color
	as the sprite, expanding the stage correctly.

	Tip: If you don't understand this, just zoom the stage out enough
	to see the solid color and maybe turn off flashing lights to see better.
]]
function onUpdatePost(elapsed)
	if lowQuality == false then
		local framePos = {
			x = getProperty('mansion.pixels.width') * getProperty('mansion.frame.uv.x'),
			y = getProperty('mansion.pixels.height') * getProperty('mansion.frame.uv.y')
		}
		setProperty('solidBG.color', getPixelColor('mansion', framePos.x + 10, framePos.y))
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
        playAnim('mansion', 'lightning')
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
end