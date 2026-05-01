function onCreate()
	setBlendMode('shootingStar', 'ADD')
	setProperty('shootingStar.visible', false)

    precacheSound('carPass0')
	precacheSound('carPass1')
end

function onCreatePost()
	-- Creates the endless mists on the stage
	if lowQuality == false then
        mistData = {
            {mistImage = 'mistMid', scrollFactor = 1.1, alpha = 0.4, velocity = 1700, scale = 1.3, objectOrder = '', color = 0xC6BFDE},
            {mistImage = 'mistBack', scrollFactor = 1.2, alpha = 1, velocity = 2100, scale = 1, objectOrder = '', color = 0x6A4DA1},
            {mistImage = 'mistMid', scrollFactor = 0.8, alpha = 0.5, velocity = 900, scale = 1.5, objectOrder = 'car', color = 0xA7D9BE},
            {mistImage = 'mistBack', scrollFactor = 0.6, alpha = 1, velocity = 700, scale = 1.5, objectOrder = 'car', color = 0x9C77C7},
            {mistImage = 'mistMid', scrollFactor = 0.2, alpha = 1, velocity = 100, scale = 1.5, objectOrder = 'sky', color = 0xE7A480}
        }
        for mistNum, data in ipairs(mistData) do
			createInstance('mist'..mistNum, 'flixel.addons.display.FlxBackdrop', {nil, 0x01})
			loadGraphic('mist'..mistNum, 'limo/erect/'..data.mistImage)
			scaleObject('mist'..mistNum, data.scale, data.scale, false)
			setScrollFactor('mist'..mistNum, data.scrollFactor, data.scrollFactor)
            setBlendMode('mist'..mistNum, 'ADD')
            if data.objectOrder ~= '' then
                setObjectOrder('mist'..mistNum, getObjectOrder(data.objectOrder) + 1)
            end
            addLuaSprite('mist'..mistNum, true)
			setProperty('mist'..mistNum..'.alpha', data.alpha)
            setProperty('mist'..mistNum..'.color', data.color)
            setProperty('mist'..mistNum..'.velocity.x', data.velocity)
			callMethod('mist'..mistNum..'.setPosition', {-650, -100})
        end
    end

	-- Adds the shaders on the characters/sprites
	if shadersEnabled == true then
        initLuaShader('adjustColor')
        for i, object in ipairs({'boyfriend', 'dad', 'gf', 'car'}) do
            setSpriteShader(object, 'adjustColor')
            setShaderFloat(object, 'hue', -30)
            setShaderFloat(object, 'saturation', -20)
            setShaderFloat(object, 'contrast', 0)
            setShaderFloat(object, 'brightness', -30)
        end
		if lowQuality == false then
			for i = 1, 5 do
				setSpriteShader('henchman'..i, 'adjustColor')
				setShaderFloat('henchman'..i, 'hue', -30)
				setShaderFloat('henchman'..i, 'saturation', -20)
				setShaderFloat('henchman'..i, 'contrast', 0)
				setShaderFloat('henchman'..i, 'brightness', -30)
			end
		end
	end
end

-- Sets up the sprites for the 'Kill Henchmen' event if present in the chart
local eventInitialized = false
function onEventPushed(event, value1, value2, strumTime)
    if event == 'Kill Henchmen' and lowQuality == false and eventInitialized == false then
		makeLuaSprite('lightPole', 'limo/gore/metalPole', -500, 220)
		setScrollFactor('lightPole', 0.4, 0.4)
		setObjectOrder('lightPole', getObjectOrder('limoBG'))
		addLuaSprite('lightPole')
		setProperty('lightPole.visible', false)

		makeAnimatedLuaSprite('henchmanCorpse1', 'limo/gore/noooooo', -500, getProperty('lightPole.y') - 130)
		addAnimationByPrefix('henchmanCorpse1', 'anim', 'Henchmen on rail')
		setScrollFactor('henchmanCorpse1', 0.4, 0.4)
		setObjectOrder('henchmanCorpse1', getObjectOrder('henchman1'))
		addLuaSprite('henchmanCorpse1')
		setProperty('henchmanCorpse1.visible', false)

		makeAnimatedLuaSprite('henchmanCorpse2', 'limo/gore/noooooo', -500, getProperty('lightPole.y'))
		addAnimationByPrefix('henchmanCorpse2', 'anim', 'henchman death')
		setScrollFactor('henchmanCorpse2', 0.4, 0.4)
		setObjectOrder('henchmanCorpse2', getObjectOrder('henchman1'))
		addLuaSprite('henchmanCorpse2')
		setProperty('henchmanCorpse2.visible', false)

		makeLuaSprite('light', 'limo/gore/coldHeartKiller', getProperty('lightPole.x') - 180, getProperty('lightPole.y') - 80)
		setScrollFactor('light', 0.4, 0.4)
		setObjectOrder('light', getObjectOrder('car'))
		addLuaSprite('light')
		setProperty('light.visible', false)

		-- This acts as a precache, it will never be actually used
		makeAnimatedLuaSprite('henchmanBlood', 'limo/gore/stupidBlood', -400, -400)
		addAnimationByPrefix('henchmanBlood', 'anim', 'blood', 24, false)
		setScrollFactor('henchmanBlood', 0.4, 0.4)
		setObjectOrder('henchmanBlood', getObjectOrder('car'))
		addLuaSprite('henchmanBlood')
		setProperty('henchmanBlood.alpha', 0.01)

		if shadersEnabled == true then
			for i, object in ipairs({'lightPole', 'light', 'henchmanCorpse1', 'henchmanCorpse2'}) do
				setSpriteShader(object, 'adjustColor')
				setShaderFloat(object, 'hue', -30)
				setShaderFloat(object, 'saturation', -20)
				setShaderFloat(object, 'contrast', 0)
				setShaderFloat(object, 'brightness', -30)
			end
		end

		precacheSound('dancerdeath')
		eventInitialized = true
    end
end

-- This controls the movement of the mists on the stage
local elapsedTime = 0
function onUpdate(elapsed)
	if lowQuality == false then
		elapsedTime = elapsedTime + elapsed
		setProperty('mist1.y', 100 + (math.sin(elapsedTime) * 200))
		setProperty('mist2.y', 0 + (math.sin(elapsedTime * 0.8) * 100))
		setProperty('mist3.y', -20 + (math.sin(elapsedTime * 0.5) * 200))
		setProperty('mist4.y', -180 + (math.sin(elapsedTime * 0.4) * 300))
		setProperty('mist5.y', -450 + (math.sin(elapsedTime * 0.2) * 150))
	end
end

-- Event stuff
function onUpdatePost(elapsed)
	if eventInitialized == true then
		updateKillingState(elapsed)
		updateHenchmenParticles()
	end
end

-- All of this down below is to make the mechanics of the stage work
henchmenDanced = true
carCanDrive = true
lastShootingStar = 0
shootingStarInterval = 2
function onBeatHit()
	-- Henchmen dancing on beat
	if lowQuality == false then
		henchmenDanced = not henchmenDanced
		if henchmenDanced == true then
			for i = 1, 5 do
				playAnim('henchman'..i, 'danceLeft', true)
			end
		else
			for i = 1, 5 do
				playAnim('henchman'..i, 'danceRight', true)
			end
		end
	end

	-- Car moving
	if getRandomBool(10) and carCanDrive == true then
		carDrive()
	end

	-- Shooting stars!
	if getRandomBool(10) and curBeat > lastShootingStar + shootingStarInterval then
		shootingStarAppear()
	end
end

-- Resets the car position
function resetCar()
	local carPosY = getRandomInt(140, 250)
	setProperty('car.x', -12600)
	setProperty('car.y', carPosY)
	setProperty('car.velocity.x', 0)
	carCanDrive = true
end

-- Moves the car from left to right with a random velocity
function carDrive()
	carCanDrive = false
	local soundNum = getRandomInt(0, 1)
	local carVelocity = getRandomInt(30600, 39600)
	playSound('carPass'..soundNum, 0.7)
	setProperty('car.velocity.x', carVelocity)
	runTimer('carReset', 2)
end

-- There's a shooting star! Make a wish!
function shootingStarAppear()
	lastShootingStar = curBeat
	shootingStarInterval = getRandomInt(4, 8)
	local pos = {x = getRandomInt(50, 900), y = getRandomInt(-10, 20)}
	local flipX = getRandomBool(50)

	setProperty('shootingStar.x', pos.x)
	setProperty('shootingStar.y', pos.y)
	setProperty('shootingStar.flipX', flipX)
	playAnim('shootingStar', 'anim', true)

	--[[ 
		Doing this because it freaks out sometimes for whatever reason if
		it's still visible at the end of the animation.
	]]
	setProperty('shootingStar.visible', true)
	runTimer('shootingStarReset', getProperty('shootingStar.animation.curAnim.numFrames') / 24)
end

function onTimerCompleted(tag, loops, loopsLeft)
	if tag == 'carReset' then
		resetCar()
	end
	if tag == 'shootingStarReset' then
		setProperty('shootingStar.visible', false)
	end
end

-- Everything from this point is for the 'Kill Henchmen' event
function eventEarlyTrigger(eventName, value1, value2, strumTime)
	if name == 'Kill Henchmen' then
		return 280 -- Ensures that the sound plays on beat
	end
end

function onEvent(eventName, value1, value2, strumTime)
	if eventName == 'Kill Henchmen' then
		killHenchmen()
	end
end

local curKillState = 0
local henchmenParticles = {}
local limoSpeed = 0
-- Activates the event
function killHenchmen()
	if lowQuality == false then
		if curKillState == 0 then
			setProperty('lightPole.x', -400)
			setProperty('lightPole.visible', true)
			setProperty('light.visible', true)
			setProperty('henchmanCorpse1.visible', false)
			setProperty('henchmanCorpse2.visible', false)
			curKillState = 1
			addAchievementScore('roadkill_enthusiast')
		end
	end
end

-- This function controls the events entirely, based on the 'curKillState'
function updateKillingState(elapsed)
	if curKillState == 1 then -- Henchmen all die :(
		setProperty('lightPole.x', getProperty('lightPole.x') + 5000 * elapsed)
		setProperty('light.x', getProperty('lightPole.x') - 180)
		setProperty('henchmanCorpse1.x', getProperty('light.x') - 50)
		setProperty('henchmanCorpse2.x', getProperty('light.x') + 35)

		for henchmanNum = 1, 5 do
			if getProperty('henchman'..henchmanNum..'.x') < screenWidth * 1.5 and getProperty('light.x') > -200 + 300 * henchmanNum then
				if henchmanNum == 1 then
					playSound('dancerdeath', 0.5)
				end
				if henchmanNum % 2 == 1 then
					if henchmanNum ~= 3 then
						animString = ' '
					else
						animString = ' 2 '
					end

					-- Creates the henchmen's flying body parts
					for limbNum, data in ipairs({{offsetX = 200, offsetY = 0, limbPart = 'leg'}, {offsetX = 160, offsetY = 200, limbPart = 'arm'}, {offsetX = 0, offsetY = 50, limbPart = 'head'}}) do
						henchmanLimbTag = 'henchmanLimb'..henchmanNum..''..limbNum
						makeAnimatedLuaSprite(henchmanLimbTag, 'limo/gore/noooooo', getProperty('henchman'..henchmanNum..'.x') + data.offsetX, getProperty('henchman'..henchmanNum..'.y') + data.offsetY)
						addAnimationByPrefix(henchmanLimbTag, 'anim', 'hench '..data.limbPart..' spin'..animString..'PINK', 24, false)
						setScrollFactor(henchmanLimbTag, 0.4, 0.4)
						setObjectOrder(henchmanLimbTag, getObjectOrder('light'))
						addLuaSprite(henchmanLimbTag)
						table.insert(henchmenParticles, henchmanLimbTag)

						if shadersEnabled == true then
							setSpriteShader(henchmanLimbTag, 'adjustColor')
							setShaderFloat(henchmanLimbTag, 'hue', -30)
							setShaderFloat(henchmanLimbTag, 'saturation', -20)
							setShaderFloat(henchmanLimbTag, 'contrast', 0)
							setShaderFloat(henchmanLimbTag, 'brightness', -30)
						end
					end

					-- Creates the henchmen's blood
					henchmanBloodTag = 'henchmanBlood'..henchmanNum
					makeAnimatedLuaSprite(henchmanBloodTag, 'limo/gore/stupidBlood', getProperty('henchman'..henchmanNum..'.x') - 110, getProperty('henchman'..henchmanNum..'.y') + 20)
					addAnimationByPrefix(henchmanBloodTag, 'anim', 'blood', 24, false)
					setScrollFactor(henchmanBloodTag, 0.4, 0.4)
					setObjectOrder(henchmanBloodTag, getObjectOrder('light'))
					addLuaSprite(henchmanBloodTag)
					table.insert(henchmenParticles, henchmanBloodTag)

					if shadersEnabled == true then
						setSpriteShader(henchmanBloodTag, 'adjustColor')
						setShaderFloat(henchmanBloodTag, 'hue', -30)
						setShaderFloat(henchmanBloodTag, 'saturation', -20)
						setShaderFloat(henchmanBloodTag, 'contrast', 0)
						setShaderFloat(henchmanBloodTag, 'brightness', -30)
					end
				elseif henchmanNum == 2 then
					setProperty('henchmanCorpse1.visible', true)
				elseif henchmanNum == 4 then
					setProperty('henchmanCorpse2.visible', true)
				end

				setProperty('henchman'..henchmanNum..'.x', getProperty('henchman'..henchmanNum..'.x') + screenWidth * 2)
			end
		end

		if getProperty('lightPole.x') > screenWidth * 2 then
			for i, object in ipairs({'lightPole', 'light', 'henchmanCorpse1', 'henchmanCorpse2'}) do
				setProperty(object..'.x', -500)
				setProperty(object..'.visible', false)
			end
			limoSpeed = 800
			curKillState = 2
		end
	elseif curKillState == 2 then -- The limo starts to back track off-screen
		limoSpeed = limoSpeed - 4000 * elapsed
		setProperty('limoBG.x', getProperty('limoBG.x') - limoSpeed * elapsed)
		if getProperty('limoBG.x') > screenWidth * 1.5 then
			limoSpeed = 3000
			curKillState = 3
		end
	elseif curKillState == 3 then -- The limo comes back with new henchman
		limoSpeed = limoSpeed - 2000 * elapsed
		if limoSpeed < 1000 then
			limoSpeed = 1000
		end

		setProperty('limoBG.x', getProperty('limoBG.x') - limoSpeed * elapsed)
		if getProperty('limoBG.x') < -275 then
			curKillState = 4
			limoSpeed = 800
		end
		
		for i = 1, 5 do
			setProperty('henchman'..i..'.x', getProperty('limoBG.x') + 300 * i)
		end
	elseif curKillState == 4 then -- The limo and henchman finally get back to their original positions
		limoBGPosX = math.lerp(-200, getProperty('limoBG.x'), math.exp(-elapsed * 9))
		setProperty('limoBG.x', limoBGPosX)

		if math.round(getProperty('limoBG.x')) == -200 then
			setProperty('limoBG.x', -200)
			curKillState = 0
			henchmenParticles = {}
		end

		for i = 1, 5 do
			setProperty('henchman'..i..'.x', getProperty('limoBG.x') + 300 * i)
		end
	end
end

-- This function is what makes the henchman's body parts and blood dissapear once their animation is finished
function updateHenchmenParticles()
	if lowQuality == false then
		for i, henchmanParticle in ipairs(henchmenParticles) do
			if luaSpriteExists(henchmanParticle) then
				if getProperty(henchmanParticle..'.animation.curAnim.finished') then
					removeLuaSprite(henchmanParticle)
				end
			end
		end
	end
end

-- Extra functions needed for the stage's script
function math.lerp(a, b, ratio)
	return a + ratio * (b - a)
end

function math.round(num)
	if num % 1 < 0.5 then
		return math.floor(num)
	else
		return math.ceil(num)
	end
end