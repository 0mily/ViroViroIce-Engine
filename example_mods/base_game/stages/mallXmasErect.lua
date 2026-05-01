function onCreatePost()
	if shadersEnabled == true then
		-- Adds the shaders on the characters/sprites
        initLuaShader('adjustColor')
        for i, object in ipairs({'boyfriend', 'dad', 'gf', 'santa'}) do
            setSpriteShader(object, 'adjustColor')
            setShaderFloat(object, 'hue', 5)
			setShaderFloat(object, 'saturation', 20)
            setShaderFloat(object, 'contrast', 0)
            setShaderFloat(object, 'brightness', 0)
        end

		--[[
			Adding shader on them because MrCatz seems to have forgotten
			to add them in when exporting the spritesheet. Oops :p
			TODO: Probably manually modify the PNG to correct the color scheme somehow.
		]]
		setSpriteShader('bottomBoppers', 'adjustColor')
		setShaderFloat('bottomBoppers', 'hue', 15)
		setShaderFloat('bottomBoppers', 'saturation', 0)
        setShaderFloat('bottomBoppers', 'contrast', 0)
        setShaderFloat('bottomBoppers', 'brightness', 20)	
	end
end

--[[
	Everything below is to make the characters bop their head on beat.
	It also checks if the 'Hey!' event is played to make the ones at the bottom cheer aswell.
	
	Credits to MrCatz for making the 'Hey!' animation for this Erect stage.
]]
local heyTimer = 0
function onUpdate(elapsed)
	-- Handles the 'Hey!' behavior of the bottom characters
	if heyTimer > 0 then
		heyTimer = heyTimer - elapsed
		if heyTimer <= 0 then
			playAnim('bottomBoppers', 'idle', true)
			heyTimer = 0
		end
	end
end

function onCountdownTick(swagCounter)
	-- Crowd dancing during the countdown
	if lowQuality == false then
		playAnim('topBoppers', 'idle', true)
	end
	playAnim('bottomBoppers', 'idle', true)
	playAnim('santa', 'idle', true)
end

function onBeatHit()
	-- Crowd dancing on beat
	if lowQuality == false then
		playAnim('topBoppers', 'idle', true)
	end
	if heyTimer <= 0 then
		playAnim('bottomBoppers', 'idle', true)
	end
	playAnim('santa', 'idle', true)
end

-- Makes the bottom characters do their 'Hey!' animation
function onEvent(eventName, value1, value2)
	if eventName == 'Hey!' then
		if value1 ~= '0' or string.lower(value1) ~= 'bf' or string.lower(value1) ~= 'boyfriend' then
			playAnim('bottomBoppers', 'hey', true)
			if value2 == '' then
				heyTimer = 0.6
			else
				heyTimer = tonumber(value2)
			end
		end
	end
end