function onCreate()
	precacheSound('train_passes')
end

-- Adds the shaders on the characters/sprites
function onCreatePost()
	if shadersEnabled == true then
        initLuaShader('adjustColor')
        for i, object in ipairs({'boyfriend', 'dad', 'gf', 'train'}) do
            setSpriteShader(object, 'adjustColor')
            setShaderFloat(object, 'hue', -26)
            setShaderFloat(object, 'saturation', -16)
            setShaderFloat(object, 'contrast', 0)
            setShaderFloat(object, 'brightness', -5)
        end
	end
end

-- Sets up the sprites for the 'Philly Glow' event if present in the chart
local eventInitialized = false
function onEventPushed(event, value1, value2, strumTime)
    if event == 'Philly Glow' and eventInitialized == false then
        makeLuaSprite('blackenScreen', '', screenWidth * -0.5, screenHeight * -0.5)
		makeGraphic('blackenScreen', screenWidth * 2, screenHeight * 2, '000000')
		setObjectOrder('blackenScreen', getObjectOrder('street'))
		addLuaSprite('blackenScreen')
		setProperty('blackenScreen.visible', false)

		makeLuaSprite('windowEvent', 'philly/window', -255, 45)
		setGraphicSize('windowEvent', getProperty('windowEvent.width') * 0.9)
		setScrollFactor('windowEvent', 0.3, 0.3)
		setObjectOrder('windowEvent', getObjectOrder('blackenScreen') + 1)
		addLuaSprite('windowEvent')
		setProperty('windowEvent.visible', false)

		makeLuaSprite('gradient', 'philly/gradient', -400, 225)
		setGraphicSize('gradient', 2000, 400)
		setScrollFactor('gradient', 0, 0.75)
		setObjectOrder('gradient', getObjectOrder('windowEvent') + 1)
		addLuaSprite('gradient')
		setProperty('gradient.visible', false)
		if flashingLights == false then
			setProperty('gradient.alpha', 0.7)
		end
			
		phillyGlowParticles = {}
		precacheImage('philly/particle')
		selectedEventColor = -1
		windowsEventColors = {
			0x31A2FD,
			0x31FD8C,
			0xFB33F5,
			0xFD4531,
			0xFBA633
		}
		-- Custom color variables because we can't change color properties with Lua
		streetColors = { -- * 0.5 Brightness
			0x025497,
			0x029745,
			0x960391,
			0x971102,
			0x965903
		}
		if flashingLights == false then
			charactersColors = { -- * 0.5 Saturation
				0x639CCA,
				0x63CA91,
				0xC964C5,
				0xCA6D63,
				0xC99F64
			}
		else
			charactersColors = { -- * 0.75 Saturation
				0x499EE4,
				0x49E48F,
				0xE24BDD,
				0xE45949,
				0xE2A34B
			}
		end
		eventInitialized = true
    end
end

-- All of this down below is to make the mechanics of the stage work
selectedColor = -1 
windowsColors = {
	0x2663AC,
	0x329A6D,
	0x502D64,
	0x932C28,
	0xB66F43
}

isTrainMoving = false
trainFrameTiming = 0
startedMoving = false

trainCars = 8
isTrainFinished = false
trainCooldown = 0
function onUpdate(elapsed)
	-- Handles the train's movement
	if isTrainMoving == true then
		trainFrameTiming = trainFrameTiming + elapsed

		if trainFrameTiming >= 1 / 24 then
			updateTrainPos()
			trainFrameTiming = 0
		end
	end

	-- Progressively fades out the windows
	setProperty('windows.alpha', getProperty('windows.alpha') - (crochet / 1000) * elapsed * 1.5)
end

-- Event stuff
function onUpdatePost(elapsed)
	if eventInitialized == true then
		updateFlash(elapsed)
		updateGradient(elapsed)
		updateParticles(elapsed)
	end
end

function onBeatHit()
	-- Train's cooldown before the next passage
	if isTrainMoving == false then
		trainCooldown = trainCooldown + 1
	end

	-- Changes the windows' color
	if curBeat % 4 == 0 then
		selectedColor = getRandomInt(1, #windowsColors, tostring(selectedColor))
		setProperty('windows.alpha', 1)
		setProperty('windows.color', windowsColors[selectedColor])
	end
	
	-- Makes the train start moving
	if curBeat % 8 == 4 and getRandomBool(30) and isTrainMoving == false and trainCooldown > 8 then
		isTrainMoving = true
		trainCooldown = getRandomInt(-4, 0)
		playSound('train_passes', 1, 'trainSound')
	end
end

-- Updates the train's "animation" and blows GF's hair
function updateTrainPos()
	if getSoundTime('trainSound') >= 4700 then
		startedMoving = true
		setVar('startedMoving', startedMoving)
		playAnim('gf', 'hairBlow')
		setProperty('gf.specialAnim', true)
	end

	if startedMoving == true then
		setProperty('train.x', getProperty('train.x') - 400)
		if getProperty('train.x') < -2000 and isTrainFinished == false then
			setProperty('train.x', -1150)
			trainCars = trainCars - 1

			if trainCars <= 0 then
				isTrainFinished = true
			end
		end
		if getProperty('train.x') < -4000 and isTrainFinished == true then
			trainReset()
		end
	end
end

-- Resets the train position and stops GF's blowing hair
function trainReset()
	isTrainMoving = false
	trainCars = 8
	isTrainFinished = false
	startedMoving = false
	setVar('startedMoving', startedMoving)
	setProperty('train.x', screenWidth + 200)

	setProperty('gf.danced', false)
	playAnim('gf', 'hairFall')
	setProperty('gf.specialAnim', true)
end

-- Everything from this point is for the 'Philly Glow' event
function onEvent(eventName, value1, value2, strumTime)
	if eventName == 'Philly Glow' then
		if value1 == '0' then -- Deactivates the event
			selectedEventColor = -1

			if getProperty('gradient.visible') == true then
				if flashingLights == false then
					doFlash(0xFFFFFF, 0.15, 0.5, true)
				else
					doFlash(0xFFFFFF, 0.15, 1, true)
				end

				if cameraZoomOnBeat == true then
					setProperty('camGame.zoom', getProperty('camGame.zoom') + 0.5)
					setProperty('camHUD.zoom', getProperty('camHUD.zoom') + 0.1)
				end

				setProperty('blackenScreen.visible', false)
				setProperty('windowEvent.visible', false)
				setProperty('gradient.visible', false)
				for num = 1, #phillyGlowParticles do
					if luaSpriteExists('particle'..num) then
						removeLuaSprite('particle'..num)
					end
					table.remove(phillyGlowParticles, 1)
				end

				-- Re-enabling the shaders here since we removed them
				for i, object in ipairs({'boyfriend', 'dad', 'gf'}) do
					if shadersEnabled == true then
						setSpriteShader(object, 'adjustColor')
						setShaderFloat(object, 'hue', -26)
						setShaderFloat(object, 'saturation', -16)
						setShaderFloat(object, 'contrast', 0)
						setShaderFloat(object, 'brightness', -5)
					end
				end

				setProperty('boyfriend.color', 0xFFFFFF)
				setProperty('dad.color', 0xFFFFFF)
				setProperty('gf.color', 0xFFFFFF)
				setProperty('street.color', 0xFFFFFF)
			end
		elseif value1 == '1' then -- Activates the event, and/or chooses a random color
			selectedEventColor = getRandomInt(1, #windowsEventColors, tostring(selectedEventColor))

			if getProperty('gradient.visible') == false then
				if flashingLights == false then
					doFlash(0xFFFFFF, 0.15, 0.5, true)
				else
					doFlash(0xFFFFFF, 0.15, 1, true)
				end

				if cameraZoomOnBeat == true then
					setProperty('camGame.zoom', getProperty('camGame.zoom') + 0.5)
					setProperty('camHUD.zoom', getProperty('camHUD.zoom') + 0.1)
				end

				setProperty('blackenScreen.visible', true)
				setProperty('windowEvent.visible', true)
				setProperty('gradient.visible', true)

				if shadersEnabled == true then
					for i, object in ipairs({'boyfriend', 'dad', 'gf'}) do
						-- Removing the shader here, else the colors get funky
						removeSpriteShader(object)
					end
				end
			elseif flashingLights == true then
				doFlash(windowsEventColors[selectedEventColor], 0.5, 0.25, true)
			end

			setProperty('windowEvent.color', windowsEventColors[selectedEventColor])
			setProperty('gradient.color', windowsEventColors[selectedEventColor])
			for num = 1, #phillyGlowParticles do
				setProperty('particle'..num..'.color', windowsEventColors[selectedEventColor])
			end

			setProperty('boyfriend.color', charactersColors[selectedEventColor])
			setProperty('dad.color', charactersColors[selectedEventColor])
			setProperty('gf.color', charactersColors[selectedEventColor])
			setProperty('street.color', streetColors[selectedEventColor])
		elseif value1 == '2' then -- Resets gradient, and creates new particles
			if lowQuality == false then
				particlesNum = getRandomInt(8, 12)
				particleWidth = 2000 / particlesNum
				for y = 1, 3 do
					for x = 1, particlesNum do
						offsetX = getRandomFloat(-particleWidth / 5, particleWidth / 5)
						offsetY = getRandomFloat(0, 125)
						createParticle(-400 + particleWidth * x + offsetX, 425 + (offsetY + y * 40), windowsEventColors[selectedEventColor])
					end
				end
			end
			setGraphicSize('gradient', 2000, 400)
			setProperty('gradient.y', 225)
			if flashingLights == false then
				setProperty('gradient.alpha', 0.7)
			else
				setProperty('gradient.alpha', 1)
			end
		end
	end
end

-- Custom flash function needed to recreate the 'Philly Glow' event accurately
local flashDuration = 0
function doFlash(color, duration, startAlpha, forced)
	if forced == false and getProperty('flash.alpha') > 0 then
		return nil
	end
	if duration == 0 then
		duration = 0.000001
	end
	makeLuaSprite('flash', '', screenWidth * -0.5, screenHeight * -0.5)
	makeGraphic('flash', screenWidth * 2, screenHeight * 2)
	addLuaSprite('flash', true)
	setProperty('flash.color', color)
	setProperty('flash.alpha', startAlpha)
	flashDuration = duration / startAlpha
end

-- Creates the particles when the gradient resets
function createParticle(x, y, color)
	local particleTag = 'particle'..#phillyGlowParticles + 1
	local lifeTime = getRandomFloat(0.6, 0.9)
	local decay = getRandomFloat(0.8, 1)
	local scale = getRandomFloat(0.75, 1)
	scrollFactor = {x = getRandomFloat(0.3, 0.75), y = getRandomFloat(0.65, 0.75)}
	velocity = {x = getRandomFloat(-40, 40), y = getRandomFloat(-175, -250)}
	acceleration = getRandomFloat(-10, 10)

	makeLuaSprite(particleTag, 'philly/particle', x, y)
	scaleObject(particleTag, scale, scale)
	setScrollFactor(particleTag, scrollFactor.x, scrollFactor.y)
	setObjectOrder(particleTag, getObjectOrder('gradient') + 1)
	addLuaSprite(particleTag)
	setProperty(particleTag..'.color', color)
	setProperty(particleTag..'.velocity.x', velocity.x)
	setProperty(particleTag..'.velocity.y', velocity.y)
	setProperty(particleTag..'.acceleration.x', acceleration)
	setProperty(particleTag..'.acceleration.y', 25)
	if flashingLights == false then
		setProperty(particleTag..'.alpha', 0.5)
		decay = decay * 0.5
	end

	table.insert(phillyGlowParticles, {lifeTime = lifeTime, decay = decay, scale = scale})
end

-- Updates the custom flash animation
function updateFlash(elapsed)
	if luaSpriteExists('flash') then
		if getProperty('flash.alpha') > 0 then
			setProperty('flash.alpha', getProperty('flash.alpha') - (elapsed / flashDuration))
		else
			removeLuaSprite('flash')
		end
	end
end

-- Makes the gradient shrink overtime
function updateGradient(elapsed)
	curHeight = math.round(getProperty('gradient.height') - 1000 * elapsed)
	if curHeight > 0 then
		setGraphicSize('gradient', 2000, curHeight)
		setProperty('gradient.y', 225 + (400 - getProperty('gradient.height')))
		if flashingLights == false then
			setProperty('gradient.alpha', 0.7)
		else
			setProperty('gradient.alpha', 1)
		end
	else
		setProperty('gradient.alpha', 0)
		setProperty('gradient.y', -5000)
	end
end

-- Updates the particles and removes them overtime
function updateParticles(elapsed)
	for num = 1, #phillyGlowParticles do
		if luaSpriteExists('particle'..num) then
			phillyGlowParticles[num].lifeTime = phillyGlowParticles[num].lifeTime - elapsed
			local lifeTime = phillyGlowParticles[num].lifeTime
			local decay = phillyGlowParticles[num].decay
			local scale = phillyGlowParticles[num].scale

			if lifeTime < 0 then
				phillyGlowParticles[num].lifeTime = 0
				setProperty('particle'..num..'.alpha', getProperty('particle'..num..'.alpha') - decay * elapsed)
				if getProperty('particle'..num..'.alpha') > 0 then
					scaleObject('particle'..num, scale * getProperty('particle'..num..'.alpha'), scale * getProperty('particle'..num..'.alpha'))
				else
					removeLuaSprite('particle'..num)
				end
			end
		end
	end
end

-- Extra function needed for the stage's script
function math.round(num)
	if num % 1 < 0.5 then
		return math.floor(num)
	else
		return math.ceil(num)
	end
end