-- Oxi, sai daqui djabo
-- tá bom desculpa https://pbs.twimg.com/media/F5q6lGLXcAAMQsx?format=jpg&name=small

local bopÉREAL = false
local bopNum = 1
local bopType = 'beat'
local bopGame = 0
local bopHUD = 0

function onEvent(name, v1, v2)
    if name == 'Camera Module Bop' then

        if v2 == nil or v2 == '' then
            bopÉREAL = false
            return
        end

        local evilv1 = stringSplit(v1, ',')
        bopNum = tonumber(evilv1[1]) or 1
        bopType = string.lower(stringTrim(evilv1[2] or 'beat'))

        local evilv2 = stringSplit(v2, ',')
        bopGame = tonumber(evilv2[1]) or 0
        bopHUD = tonumber(evilv2[2]) or 0

        bopÉREAL = true
    end
end

function onBeatHit()
    if bopÉREAL and bopType == 'beat' then
        if curBeat % bopNum == 0 then
            triggerEvent('Add Camera Zoom', bopGame, bopHUD)
        end
    end
end

function onStepHit()
    if bopÉREAL and bopType == 'step' then
        if curStep % bopNum == 0 then
            triggerEvent('Add Camera Zoom', bopGame, bopHUD)
        end
    end
end

-- "ai mas é q tem q fazer bonitin pras pessoas tadinha delas"    ratifudê