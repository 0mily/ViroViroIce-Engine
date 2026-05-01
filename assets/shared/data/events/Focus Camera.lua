local function getCamPos(char)
    local x, y = 0, 0

    if char == 'bf' or char == 'boyfriend' or char == '0' then
        x = getMidpointX('boyfriend') - 100
            + getProperty('boyfriend.cameraPosition[0]')
            + getProperty('boyfriendCameraOffset[0]')

        y = getMidpointY('boyfriend') - 100
            + getProperty('boyfriend.cameraPosition[1]')
            + getProperty('boyfriendCameraOffset[1]')

    elseif char == 'dad' or char == '1' then
        x = getMidpointX('dad') + 150
            + getProperty('dad.cameraPosition[0]')
            + getProperty('opponentCameraOffset[0]')

        y = getMidpointY('dad') - 100
            + getProperty('dad.cameraPosition[1]')
            + getProperty('opponentCameraOffset[1]')

    elseif char == 'gf' or char == '2' then
        x = getMidpointX('gf')
            + getProperty('gf.cameraPosition[0]')
            - getProperty('girlfriendCameraOffset[0]')

        y = getMidpointY('gf')
            + getProperty('gf.cameraPosition[1]')
            - getProperty('girlfriendCameraOffset[1]')
    end

    return x, y
end -- eu nsei quem fez isso, mas salvou minha vida, chupa p slice nazista

function onEvent(name, v1, v2)
    if name ~= 'Focus Camera' then return end

    local evilv1 = stringSplit(v1, ',')
    local char = string.lower(stringTrim(evilv1[1] or 'dad'))
    local offX = tonumber(evilv1[2]) or 0
    local offY = tonumber(evilv1[3]) or 0

    local evilv2 = stringSplit(v2, ',')
    local evilease = string.lower(stringTrim(evilv2[1] or 'linear'))
    local steps = tonumber(evilv2[2]) or 0

    local baseX, baseY = getCamPos(char)
    local targetX = baseX + offX
    local targetY = baseY + offY

    setProperty('isCameraOnForcedPos', true) -- trabalhando sério.

    cancelTween('camFollowX')
    cancelTween('camFollowY')

    if evilease == 'og' then
        setProperty('cameraSpeed', 1)
        triggerEvent('Camera Follow Pos', targetX, targetY)
        return
    end

    if evilease == 'inst' then
        setProperty('cameraSpeed', 0)

        setProperty('camFollow.x', targetX)
        setProperty('camFollow.y', targetY)

        return
    end

    setProperty('cameraSpeed', 1)

    local time = 0
    if steps > 0 then
        time = steps * (stepCrochet / 1000)
    end

    doTweenX('camFollowX', 'camFollow', targetX, time, evilease)
    doTweenY('camFollowY', 'camFollow', targetY, time, evilease)
end