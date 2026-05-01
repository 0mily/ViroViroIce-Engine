function onCreate()
    -- Default Game Over
	setPropertyFromClass('substates.GameOverSubstate', 'characterName', 'bf-pixel-dead')
	setPropertyFromClass('substates.GameOverSubstate', 'deathSoundName', 'fnf_loss_sfx-pixel')
	setPropertyFromClass('substates.GameOverSubstate', 'loopSoundName', 'gameOver-pixel')
	setPropertyFromClass('substates.GameOverSubstate', 'endSoundName', 'gameOverEnd-pixel')
end

function onCreatePost()
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

	-- Adds a trail behind the opponent
	createInstance('dadTrail', 'flixel.addons.effects.FlxTrail', {instanceArg('dad'), nil, 4, 24, 0.3, 0.069})
	setObjectOrder('dadTrail', getObjectOrder('dadGroup'))
	addInstance('dadTrail')

    if shadersEnabled == true then
		-- Adds the shaders on the characters
		initLuaShader('dropShadow')
        for i, object in ipairs({'boyfriend', 'dad', 'gf'}) do
			setSpriteShader(object, 'dropShadow')
			setShaderFloat(object, 'hue', -28)
    		setShaderFloat(object, 'saturation', -20)
    		setShaderFloat(object, 'contrast', 31)
    		setShaderFloat(object, 'brightness', -66)
			
			setShaderFloat(object, 'ang', math.rad(120))
			setShaderFloat(object, 'str', 1)
			setShaderFloat(object, 'dist', 4)
    		setShaderFloat(object, 'thr', 0.1)

			setShaderFloat(object, 'AA_STAGES', 0)
			setShaderFloatArray(object, 'dropColor', {82 / 255, 29 / 255, 75 / 255})
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

			-- Specific values if the character is 'dad' or 'gf'
			if object == 'dad' then
				setShaderFloat(object, 'ang', math.rad(105))
				setShaderFloat(object, 'str', 0.34)
				setShaderFloat(object, 'dist', 3)
			elseif object == 'gf' then
				setShaderFloat(object, 'ang', math.rad(90))
			end

			-- Specific values if any character is 'gf-pixel'
			if _G[object..'Name'] == 'gf-pixel' then
				setShaderFloat(object, 'hue', -28)
    			setShaderFloat(object, 'saturation', -20)
    			setShaderFloat(object, 'contrast', 11)
    			setShaderFloat(object, 'brightness', -42)

				setShaderFloat(object, 'dist', 3)
				setShaderFloat(object, 'thr', 0.3)
			end
        end

		-- Adds the shaders on the sprites
		if lowQuality == false then
			initLuaShader('wiggle')
			wiggleData = {
				spikesBG = {speed = 2 * 0.8, frequency = 4 * 0.4, amplitude = 0.011},
				schoolEvil = {speed = 2, frequency = 4, amplitude = 0.017},
				streetEvil = {speed = 2, frequency = 4, amplitude = 0.007},
				backSpike = {speed = 2, frequency = 4, amplitude = 0.01}
			}

			for object, data in pairs(wiggleData) do
				setSpriteShader(object, 'wiggle')
				setShaderFloat(object, 'uSpeed', data.speed)
				setShaderFloat(object, 'uFrequency', data.frequency)
				setShaderFloat(object, 'uWaveAmplitude', data.amplitude)
				setShaderInt(object, 'effectType', 0)
			end
		end
    end
end

-- Updates the 'wiggle' shader for every object
local elapsedTime = 0
function onUpdate(elapsed)
	if shadersEnabled == true and lowQuality == false then
		elapsedTime = elapsedTime + elapsed
        for i, object in ipairs({'spikesBG', 'schoolEvil', 'streetEvil', 'backSpike'}) do
		    setShaderFloat(object, 'uTime', elapsedTime)
        end
	end
end