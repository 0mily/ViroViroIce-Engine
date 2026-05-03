local function getTweenKey(tag, modName, target)
    modName = normalizeModName(modName)
    target = normalizeTarget(target or Strum_Gen)
    return tostring(tag) .. '::' .. tostring(modName) .. '::' .. tostring(target)
end

local function clearModTweens(modName, target, exceptKey)
    modName = normalizeModName(modName)
    target = normalizeTarget(target or Strum_Gen)

    for key, data in pairs(modTweens) do
        if key ~= exceptKey and data.modName == modName and tostring(normalizeTarget(data.target or Strum_Gen)) == tostring(target) then
            modTweens[key] = nil
        end
    end
end

function addModchart(modchart)
    initMod(modchart)
    if debugPrint then
        debugPrint(modchart .. " Modchart loaded successfully!")
    end
end

function clearModchart(modchart)
    modchart = normalizeModName(modchart)

    if mods[modchart] then
        mods[modchart] = nil
        if debugPrint then
            debugPrint("Modchart removido: " .. modchart)
        end
    end
end

function queueSet(step, modchart, value, target)
    table.insert(scheduledEvents, {
        kind = 'set',
        step = step or 0,
        modchart = modchart,
        value = value or 0,
        target = target
    })
end

function queueEase(step, endStep, modchart, value, easeName, target)
    table.insert(scheduledEvents, {
        kind = 'ease',
        step = step or 0,
        endStep = endStep or step or 0,
        modchart = modchart,
        value = value or 0,
        ease = easeName or 'linear',
        target = target
    })
end

function queueSetP(step, modchart, percent, target)
    queueSet(step, modchart, (percent or 0) * 0.01, target)
end

function queueEaseP(step, endStep, modchart, percent, easeName, target)
    queueEase(step, endStep, modchart, (percent or 0) * 0.01, easeName, target)
end

local function runScheduledEvents()
    for i = #scheduledEvents, 1, -1 do
        local event = scheduledEvents[i]
        if curStep >= event.step then
            if event.kind == 'ease' then
                local steps = math.max((event.endStep or event.step) - event.step, 0)
                local duration = (steps * (stepCrochet or 0)) / 1000
                easeModchart('queue_' .. tostring(event.modchart) .. '_' .. tostring(event.step), event.modchart, event.value, duration, event.ease, event.target)
            else
                setModchart(event.modchart, event.value, event.target)
            end
            table.remove(scheduledEvents, i)
        end
    end
end

function setModchart(modchart, value, target)
    modchart = normalizeModName(modchart)
    target = normalizeTarget(target or Strum_Gen)
    clearModTweens(modchart, target)
    applyModValue(modchart, value, target)
end

function easeModchart(a, b, c, d, e, f)
    local tag, modchart, intensity, duration, ease, target

    if type(b) == "string" then
        tag = a
        modchart = b
        intensity = c
        duration = d
        ease = e
        target = f
    else
        modchart = a
        intensity = b
        duration = c
        ease = d
        target = e
        tag = tostring(modchart) .. "_" .. tostring(target or Strum_Gen) .. "_" .. tostring(os.clock())
    end

    modchart = normalizeModName(modchart)
    target = normalizeTarget(target or Strum_Gen)
    initMod(modchart)
    local tweenKey = getTweenKey(tag, modchart, target)

    local startVal = getTargetCurrentMod(modchart, target)

    if not duration or duration <= 0 then
        clearModTweens(modchart, target)
        applyModValue(modchart, intensity, target)
        if modChartTweenFinished then modChartTweenFinished(tag) end
        return
    end

    clearModTweens(modchart, target, tweenKey)
    modTweens[tweenKey] = {
        tag = tag,
        modName = modchart,
        target = target,
        startVal = startVal,
        targetVal = intensity,
        duration = duration,
        time = 0,
        easeName = ease or 'linear'
    }
end

function getMod(modchart, isPlayer, strumID)
    modchart = normalizeModName(modchart)
    local t = mods[modchart]
    if not t then return 0 end

    if strumID ~= nil and t[strumID] ~= nil then
        return t[strumID]
    end

    local side = isPlayer and BF_Strum or DAD_Strum
    if t[side] ~= nil then return t[side] end
    if t[Strum_Gen] ~= nil then return t[Strum_Gen] end
    return 0
end

function getModDef(modchart, isPlayer, defaultVal, strumID)
    modchart = normalizeModName(modchart)
    local t = mods[modchart]
    if not t then return defaultVal end

    if strumID ~= nil and t[strumID] ~= nil then
        return t[strumID]
    end

    local side = isPlayer and BF_Strum or DAD_Strum
    if t[side] ~= nil then return t[side] end
    if t[Strum_Gen] ~= nil then return t[Strum_Gen] end
    return defaultVal
end

-- Callback opcional de fim de tween
function modChartTweenFinished(tag)
end

