function onCreate()
    for i = 1, 25 do
		precacheSound('jeffGameover/jeffGameover-'..i)
	end
end

function onCreatePost()
	if shadersEnabled == true then
		-- Sets up an haxe function needed for the shader to work
		runHaxeCode([[
            import flixel.math.FlxAngle;
			function setShaderFrameInfo(objectName:String) {
				var object:FlxSprite;
				switch(objectName) {
					case 'boyfriend':
                    	object = game.boyfriend;
                	case 'dad':
                    	object = game.dad;
                	case 'gf':
                    	object = game.gf;
                	default:
                    	object = game.getLuaObject(objectName);
				}

				object.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
            	{
					if (object.shader != null) {
						object.shader.setFloatArray('uFrameBounds', [object.frame.uv.x, object.frame.uv.y, object.frame.uv.width, object.frame.uv.height]);
                		object.shader.setFloat('angOffset', object.frame.angle * FlxAngle.TO_RAD);
					}
            	}
			}
        ]])

		-- Adds the shaders on the characters
		initLuaShader('dropShadow')
        for i, object in ipairs({'boyfriend', 'dad', 'gf'}) do
            setSpriteShader(object, 'dropShadow')
    		setShaderFloat(object, 'hue', -38)
    		setShaderFloat(object, 'saturation', -20)
    		setShaderFloat(object, 'contrast', -25)
    		setShaderFloat(object, 'brightness', -46)
			
            setShaderFloat(object, 'ang', math.rad(90))
    		setShaderFloat(object, 'str', 1)
    		setShaderFloat(object, 'dist', 15)
    		setShaderFloat(object, 'thr', 0.1)

			setShaderFloat(object, 'AA_STAGES', 2)
			setShaderFloatArray(object, 'dropColor', {223 / 255, 239 / 255, 60 / 255})
			runHaxeFunction('setShaderFrameInfo', {object})

			-- Checks if the character has a mask, and applies it to the shader if it does
			local imageFile = stringSplit(getProperty(object..'.imageFile'), '/')
			if checkFileExists('images/characters/masks/'..imageFile[#imageFile]..'_mask.png') then
				setShaderSampler2D(object, 'altMask', 'characters/masks/'..imageFile[#imageFile]..'_mask')
				setShaderFloat(object, 'thr2', 1)
				setShaderBool(object, 'useMask', true)
			else
				setShaderBool(object, 'useMask', false)
			end

			-- Specific values if the character is 'dad'
			if object == 'dad' then
				setShaderFloat(object, 'ang', math.rad(135))
    			setShaderFloat(object, 'thr', 0.3)
			end

			-- Specific values if any character is 'gf-pixel'
            if _G[object..'Name'] =='gf-tankmen' then
				setShaderFloat(object, 'thr2', 0.4)
			end
		end
	end
end

-- Death voiceline behavior
startedDeathSound = false
deathSoundEnded = false
function onUpdate(elapsed)
    if inGameOver == true and startedDeathSound == false then
		curAnim = getPropertyFromGameOver('boyfriend._lastPlayedAnimation')
		if curAnim == 'firstDeath' then
			animEnded = (getPropertyFromGameOver('boyfriend.animation.curAnim.finished') or getPropertyFromGameOver('boyfriend.atlas.anim.finished'))
			if animEnded == true then
				local jeffVariant = getRandomInt(1, 25)
				playSound('jeffGameover/jeffGameover-'..jeffVariant, 1, 'jeffVoiceline')
				startedDeathSound = true
			end
		end
	end
end

-- Needed to keep the sound at this volume during the voiceline
function onUpdatePost(elapsed)
	if inGameOver == true and deathSoundEnded == false then
		setSoundVolume(nil, 0.2)
	end
end

--[[
	Everything below is to make the characters bop their head on beat.
	It also randomly makes the sniper guy drink his mug.
]]
sniperSpecialAnim = false
function onCountdownTick(counter)
	-- Tankmen dancing during the countdown
	if lowQuality == false then
		if getRandomBool(2) and sniperSpecialAnim == false then
			playAnim('tankSniper', 'sip', true)
			runTimer('sipAnimLength', getProperty('tankSniper.animation.curAnim.numFrames') / 24)
			sniperSpecialAnim = true
		end

		if counter % 2 == 0 then
			if sniperSpecialAnim == false then
				playAnim('tankSniper', 'idle', true)
			end
			playAnim('tankGuy', 'idle', true)
		end
	end
end

function onBeatHit()
	-- Tankmen dancing on beat
	if lowQuality == false then
		if getRandomBool(2) and sniperSpecialAnim == false then
			playAnim('tankSniper', 'sip', true)
			runTimer('sipAnimLength', getProperty('tankSniper.animation.curAnim.numFrames') / 24)
			sniperSpecialAnim = true
		end

		if curBeat % 2 == 0 then
			if sniperSpecialAnim == false then
				playAnim('tankSniper', 'idle', true)
			end
			playAnim('tankGuy', 'idle', true)
		end
	end
end

function onTimerCompleted(tag, loops, loopsLeft)
	if tag == 'sipAnimLength' then
		sniperSpecialAnim = false
	end
end

-- Prevents the Game Over music to restart when you retry
local gameOverFinished = false
function onGameOverConfirm()
	gameOverFinished = true
end

function onSoundFinished(tag)
	if tag == 'jeffVoiceline' and gameOverFinished == false then
		soundFadeIn(nil, 4, 0.2, 1)
		deathSoundEnded = true
	end
end

-- Extra function needed for the stage's script
function getPropertyFromGameOver(property)
    if getPropertyFromClass('substates.GameOverSubstate', property) ~= nil then
        return getPropertyFromClass('substates.GameOverSubstate', property)
    else
        return getPropertyFromClass('substates.GameOverSubstate', 'instance.'..property)
    end
end