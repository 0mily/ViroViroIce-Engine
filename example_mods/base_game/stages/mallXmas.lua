--[[
	Everything below is to make the characters bop their head on beat.
	It also checks if the 'Hey!' event is played to make the ones at the bottom cheer aswell.
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