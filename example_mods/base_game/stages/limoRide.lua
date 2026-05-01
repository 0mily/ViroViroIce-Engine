function onCreate()
    precacheSound('carPass0')
	precacheSound('carPass1')
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
		addAnimationByPrefix('henchmanCorpse2', 'anim', 'henchmen death')
		setScrollFactor('henchmanCorpse2', 0.4, 0.4)
		setObjectOrder('henchmanCorpse2', getObjectOrder('henchman1'))
		addLuaSprite('henchmanCorpse2')
		setProperty('henchmanCorpse2.visible', false)

		makeLuaSprite('light', 'limo/gore/coldHeartKiller', getProperty('lightPole.x') - 180, getProperty('lightPole.y') - 80)
		setScrollFactor('light', 0.4, 0.4)
		setObjectOrder('light', getObjectOrder('car'))
		addLuaSprite('light')
		setProperty('light.visible', false)

		-- This acts as a precache, it will actually never be used
		makeAnimatedLuaSprite('henchmanBlood', 'limo/gore/stupidBlood', -400, -400)
		addAnimationByPrefix('henchmanBlood', 'anim', 'blood', 24, false)
		setScrollFactor('henchmanBlood', 0.4, 0.4)
		setObjectOrder('henchmanBlood', getObjectOrder('car'))
		addLuaSprite('henchmanBlood')
		setProperty('henchmanBlood.alpha', 0.01)

		precacheSound('dancerdeath')
		eventInitialized = true
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

function onTimerCompleted(tag, loops, loopsLeft)
	if tag == 'carReset' then
		resetCar()
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

-- This function controls the event entirely, based on the 'curKillState'
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
					end

					-- Creates the henchmen's blood
					henchmanBloodTag = 'henchmanBlood'..henchmanNum
					makeAnimatedLuaSprite(henchmanBloodTag, 'limo/gore/stupidBlood', getProperty('henchman'..henchmanNum..'.x') - 110, getProperty('henchman'..henchmanNum..'.y') + 20)
					addAnimationByPrefix(henchmanBloodTag, 'anim', 'blood', 24, false)
					setScrollFactor(henchmanBloodTag, 0.4, 0.4)
					setObjectOrder(henchmanBloodTag, getObjectOrder('light'))
					addLuaSprite(henchmanBloodTag)
                    table.insert(henchmenParticles, henchmanBloodTag)
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
	elseif curKillState == 3 then -- The limo comes back with new henchmen
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
	elseif curKillState == 4 then -- The limo and henchmen finally get back to their original positions
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

-- This function is what makes the henchmen's body parts and blood dissapear once their animation is finished
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