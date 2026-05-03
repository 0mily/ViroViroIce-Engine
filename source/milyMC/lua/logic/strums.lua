-- =========================================================================
-- Strum Utilities
-- =========================================================================

local function checkOg(val, defaultVal)
    if val == 'og' or val == 'OG' then return defaultVal end
    local num = tonumber(val)
    return num ~= nil and num or defaultVal
end

function applyStrumAction(tag, modName, val, duration, ease, target)
    eachTargetLane(target, function(i)
        local finalMod = modName .. i
        initMod(finalMod)

        if duration and duration > 0 then
            easeModchart(tag .. "_" .. i, finalMod, val, duration, ease, i)
        else
            setModchart(finalMod, val, i)
        end
    end)
end

-- SETTERS instantÃ¢neos
function setStrumAlpha(s, a) applyStrumAction("setStrumAlpha", 'strumAlpha', checkOg(a, 1), 0, nil, s) end
function setStrumX(s, x)     applyStrumAction("setStrumX", 'strumX', checkOg(x, 0), 0, nil, s) end
function setStrumY(s, y)     applyStrumAction("setStrumY", 'strumY', checkOg(y, 0), 0, nil, s) end
function setStrumZ(s, z)     applyStrumAction("setStrumZ", 'strumZ', checkOg(z, 0), 0, nil, s) end
function setStrumAngle(s, a) applyStrumAction("setStrumAngle", 'strumAngle', checkOg(a, 0), 0, nil, s) end
function setStrumScale(s, sc)applyStrumAction("setStrumScale", 'strumScale', checkOg(sc, 1), 0, nil, s) end

-- caralho que trampo podia ser mais facil tb
function strumTweenAlpha(a, b, c, d, e)
    local tag, s, val, dur, ease
    if type(a) == "string" then
        tag, s, val, dur, ease = a, b, c, d, e
    else
        s, val, dur, ease = a, b, c, d
        tag = "strumAlpha_" .. tostring(s) .. "_" .. tostring(os.clock())
    end
    applyStrumAction(tag, 'strumAlpha', checkOg(val, 1), dur, ease, s)
end

function tweenStrumX(a, b, c, d, e)
    local tag, s, val, dur, ease
    if type(a) == "string" then
        tag, s, val, dur, ease = a, b, c, d, e
    else
        s, val, dur, ease = a, b, c, d
        tag = "strumX_" .. tostring(s) .. "_" .. tostring(os.clock())
    end
    applyStrumAction(tag, 'strumX', checkOg(val, 0), dur, ease, s)
end

function tweenStrumY(a, b, c, d, e)
    local tag, s, val, dur, ease
    if type(a) == "string" then
        tag, s, val, dur, ease = a, b, c, d, e
    else
        s, val, dur, ease = a, b, c, d
        tag = "strumY_" .. tostring(s) .. "_" .. tostring(os.clock())
    end
    applyStrumAction(tag, 'strumY', checkOg(val, 0), dur, ease, s)
end

function tweenStrumZ(a, b, c, d, e)
    local tag, s, val, dur, ease
    if type(a) == "string" then
        tag, s, val, dur, ease = a, b, c, d, e
    else
        s, val, dur, ease = a, b, c, d
        tag = "strumZ_" .. tostring(s) .. "_" .. tostring(os.clock())
    end
    applyStrumAction(tag, 'strumZ', checkOg(val, 0), dur, ease, s)
end

function tweenStrumAngle(a, b, c, d, e)
    local tag, s, val, dur, ease
    if type(a) == "string" then
        tag, s, val, dur, ease = a, b, c, d, e
    else
        s, val, dur, ease = a, b, c, d
        tag = "strumAngle_" .. tostring(s) .. "_" .. tostring(os.clock())
    end
    applyStrumAction(tag, 'strumAngle', checkOg(val, 0), dur, ease, s)
end

function tweenStrumScale(a, b, c, d, e)
    local tag, s, val, dur, ease
    if type(a) == "string" then
        tag, s, val, dur, ease = a, b, c, d, e
    else
        s, val, dur, ease = a, b, c, d
        tag = "strumScale_" .. tostring(s) .. "_" .. tostring(os.clock())
    end
    applyStrumAction(tag, 'strumScale', checkOg(val, 1), dur, ease, s)
end

easeStrumX = tweenStrumX
easeStrumY = tweenStrumY
easeStrumZ = tweenStrumZ
easeStrumAngle = tweenStrumAngle
easeStrumScale = tweenStrumScale
easeStrumAlpha = strumTweenAlpha

local function tweenSimpleMod(defaultTag, modName, a, b, c, d, e)
    local tag, target, val, dur, ease
    if type(a) == "string" then
        tag, target, val, dur, ease = a, b, c, d, e
    else
        target, val, dur, ease = a, b, c, d
        tag = defaultTag .. "_" .. tostring(target or Strum_Gen) .. "_" .. tostring(os.clock())
    end
    easeModchart(tag, modName, checkOg(val, 0), dur, ease, target or Strum_Gen)
end

function setTransformX(target, value) setModchart('transformX', checkOg(value, 0), target or Strum_Gen) end
function setTransformY(target, value) setModchart('transformY', checkOg(value, 0), target or Strum_Gen) end
function setTransformZ(target, value) setModchart('transformZ', checkOg(value, 0), target or Strum_Gen) end
function tweenTransformX(a, b, c, d, e) tweenSimpleMod('transformX', 'transformX', a, b, c, d, e) end
function tweenTransformY(a, b, c, d, e) tweenSimpleMod('transformY', 'transformY', a, b, c, d, e) end
function tweenTransformZ(a, b, c, d, e) tweenSimpleMod('transformZ', 'transformZ', a, b, c, d, e) end
easeTransformX = tweenTransformX
easeTransformY = tweenTransformY
easeTransformZ = tweenTransformZ

function easeScroll(target, scrollType, a, b, c, d)
    local targetKey = normalizeTarget(target or Strum_Gen)
    local scrollName = normalizeScrollType(scrollType)
    local key = scrollName .. "_" .. tostring(targetKey)
    local targetVal, duration, easeName, tag

    if type(b) == "number" or d ~= nil then
        targetVal = tonumber(a) or 0
        duration = b
        easeName = c
        tag = d
        toggleStates[key] = targetVal >= 0.5
    else
        duration = a
        easeName = b
        tag = c

        if toggleStates[key] == nil then
            toggleStates[key] = getTargetCurrentMod(scrollName, targetKey) >= 0.5
        end

        toggleStates[key] = not toggleStates[key]
        targetVal = toggleStates[key] and 1 or 0
    end

    easeModchart(tag or key, scrollName, targetVal, duration, easeName, targetKey)
end
function setScroll(target, scrollType, value, duration, easeName, tag)
    local targetKey = normalizeTarget(target or Strum_Gen)
    local scrollName = normalizeScrollType(scrollType)
    easeModchart(tag or (scrollName .. "_" .. tostring(targetKey)), scrollName, value, duration, easeName, targetKey)
end

function kickModchart(modchart, val1, val2, duration, easeName, target)
    target = target or Strum_Gen
    setModchart(modchart, val1, target)
    easeModchart(modchart, val2, duration, easeName, target)
end

function kickShot(tag, target, modName, startVal, endVal, duration, easeName) --imagina mudar a wiki dnv
    endVal = endVal or 0     -- aí­ volta pro 0 pra quem for burro
    duration = duration or 0.5
    easeName = easeName or 'cubeOut'
    target = target or Strum_Gen
    modName = normalizeModName(modName)

    setModchart(modName, startVal, target)
    easeModchart(tag, modName, endVal, duration, easeName, target)

    if modName == 'beat' then
        local beatTag = tostring(tag or 'beat') .. '_kick'
        setModchart('beatKick', startVal, target)
        easeModchart(beatTag, 'beatKick', endVal, duration, easeName, target)
    end
end

function kickIn(tag, target, intensity, duration, easeName)
    intensity = intensity or 0.25
    kickShot(tag or "kickIn", target, 'globalScale', -math.abs(intensity), 0, duration or 0.4, easeName or 'cubeOut')
end

function kickOut(tag, target, intensity, duration, easeName)
    intensity = intensity or 0.25
    kickShot(tag or "kickOut", target, 'globalScale', math.abs(intensity), 0, duration or 0.4, easeName or 'cubeOut')
end

function kickPulse(tag, target, intensity, duration, easeName)
    intensity = intensity or 0.35
    kickShot(tag or "kickPulse", target, 'globalScale', math.abs(intensity), 0, duration or 0.55, easeName or 'expoOut')
end

function kickEarthquake(tag, target, intensity, duration, easeName)
    intensity = intensity or 1
    kickShot(tag or "kickEarthquake", target, 'earthquake', intensity, 0, duration or 0.45, easeName or 'cubeOut')
end

function kickSusPulse(tag, target, intensity, duration, easeName)
    intensity = intensity or 1
    kickShot(tag or "kickSusPulse", target, 'susPulse', intensity, 0, duration or 0.5, easeName or 'expoOut')
end

