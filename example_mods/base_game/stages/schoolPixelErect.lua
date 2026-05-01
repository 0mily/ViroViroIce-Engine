function onCreate()
    --[[
        Add the animation through scripting since the Stage Editor
        doesn't support .txt files for animations.
    ]]
    addAnimation('trees', 'anim', {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18}, 12)

    -- Default Game Over
	setPropertyFromClass('substates.GameOverSubstate', 'characterName', 'bf-pixel-dead')
	setPropertyFromClass('substates.GameOverSubstate', 'deathSoundName', 'fnf_loss_sfx-pixel')
	setPropertyFromClass('substates.GameOverSubstate', 'loopSoundName', 'gameOver-pixel')
	setPropertyFromClass('substates.GameOverSubstate', 'endSoundName', 'gameOverEnd-pixel')
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
    		setShaderFloat(object, 'hue', -10)
    		setShaderFloat(object, 'saturation', -23)
    		setShaderFloat(object, 'contrast', 24)
    		setShaderFloat(object, 'brightness', -66)
			
            setShaderFloat(object, 'ang', math.rad(90))
    		setShaderFloat(object, 'str', 1)
    		setShaderFloat(object, 'dist', 5)
    		setShaderFloat(object, 'thr', 0.1)

			setShaderFloat(object, 'AA_STAGES', 0)
			setShaderFloatArray(object, 'dropColor', {82 / 255, 53 / 255, 29 / 255})
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

			-- Specific values if any character is 'gf-pixel'
			if _G[object..'Name'] == 'gf-pixel' then
				setShaderFloat(object, 'hue', -10)
    			setShaderFloat(object, 'saturation', -25)
    			setShaderFloat(object, 'contrast', 5)
    			setShaderFloat(object, 'brightness', -42)

				setShaderFloat(object, 'dist', 3)
    			setShaderFloat(object, 'thr', 0.3)
			end
		end
	end
end