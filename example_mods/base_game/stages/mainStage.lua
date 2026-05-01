-- Sets up the sprites for the 'Dadbattle Spotlight' event if present in the chart
local eventInitialized = false
function onEventPushed(event, value1, value2, strumTime)
    if event == 'Dadbattle Spotlight' and eventInitialized == false then
        makeLuaSprite('blackenScreen', '', -800, -400)
		makeGraphic('blackenScreen', screenWidth * 2, screenHeight * 2, '000000')
		setScrollFactor('blackenScreen', 0, 0)
		addLuaSprite('blackenScreen', true)
		setProperty('blackenScreen.alpha', 0.25)
		setProperty('blackenScreen.visible', false)
			
		makeLuaSprite('spotlight', 'stage/spotlight', 400, -400)
		setBlendMode('spotlight', 'ADD')
		addLuaSprite('spotlight', true)
		setProperty('spotlight.alpha', 0.375)
		setProperty('spotlight.visible', false)

		smoke1OffsetY = getRandomFloat(-20, 20)
		smoke1Scale = getRandomFloat(1.1, 1.22)
		smoke1Velocity = getRandomFloat(15, 22)
		makeLuaSprite('smoke1', 'stage/smoke', -1350, 660 + smoke1OffsetY)
		setGraphicSize('smoke1', getProperty('smoke1.width') * smoke1Scale)
		setScrollFactor('smoke1', 1.2, 1.05)
		addLuaSprite('smoke1', true)
		setProperty('smoke1.alpha', 0)
		setProperty('smoke1.velocity.x', smoke1Velocity)

		smoke2OffsetY = getRandomFloat(-20, 20)
		smoke2Scale = getRandomFloat(1.1, 1.22)
		smoke2Velocity = getRandomFloat(-22, -15)
		makeLuaSprite('smoke2', 'stage/smoke', 1750, 660 + smoke2OffsetY)
		setGraphicSize('smoke2', getProperty('smoke2.width') * smoke2Scale)
		setScrollFactor('smoke2', 1.2, 1.05)
		addLuaSprite('smoke2', true)
		setProperty('smoke2.alpha', 0)
		setProperty('smoke2.flipX', true)
		setProperty('smoke2.velocity.x', smoke2Velocity)
    end
end

-- Behavior of the 'Dadbattle Spotlight' event
function onEvent(eventName, value1, value2, strumTime)
	if eventName == 'Dadbattle Spotlight' then
		value = tonumber(value1)
		if value == nil then
			value = 0
		end
		
		if value > 0 then
			if value == 1 then -- Activates the event
				setProperty('defaultCamZoom', getProperty('defaultCamZoom') + 0.12)
				setProperty('blackenScreen.visible', true)
				setProperty('spotlight.visible', true)
				setProperty('smoke1.visible', true)
				setProperty('smoke2.visible', true)
			end

			-- Moves the spotlight to its target
			local target = 'dad'
			if value > 2 then
				target = 'boyfriend'
			end
			runTimer('spotlightAppears', 0.12)
			setProperty('spotlight.x', getGraphicMidpointX(target) - getProperty('spotlight.width') / 2)
			setProperty('spotlight.y', getProperty(target..'.y') + getProperty(target..'.height') - getProperty('spotlight.height') + 50)
			doTweenAlpha('smoke1Appears', 'smoke1', 0.7, 1.5, 'quadInOut')
			doTweenAlpha('smoke2Appears', 'smoke2', 0.7, 1.5, 'quadInOut')
		else
			-- Deactivate the event
			setProperty('defaultCamZoom', getProperty('defaultCamZoom') - 0.12)
			setProperty('blackenScreen.visible', false)
			setProperty('spotlight.visible', false)
			doTweenAlpha('smoke1ByeBye', 'smoke1', 0, 0.7, 'linear')
			doTweenAlpha('smoke2ByeBye', 'smoke2', 0, 0.7, 'linear')
		end
	end
end

function onTimerCompleted(tag, loops, loopsLeft)
	if tag == 'spotlightAppears' then
		setProperty('spotlight.visible', true)
	end
end