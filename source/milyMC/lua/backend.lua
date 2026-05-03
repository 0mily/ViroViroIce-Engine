--[[ 
,---.    ,---..-./`)   .---.       ____     __  _ _    .-'''-.         ,---.    ,---.    ,-----.      ______         _______   .---.  .---.    ____    .-------. ,---------.
|    \  /    |\ .-.')  | ,_|       \   \   /  /( ' )  / _     \        |    \  /    |  .'  .-,  '.  |    _ `''.    /   __  \  |   |  |_ _|  .'  __ `. |  _ _   \\          \
|  ,  \/  ,  |/ `-' \,-./  )        \  _. /  '(_{;}_)(`' )/`--'        |  ,  \/  ,  | / ,-.|  \ _ \ | _ | ) _  \  | ,_/  \__) |   |  ( ' ) /   '  \  \| ( ' )  | `--.  ,---'
|  |\_   /|  | `-'`"`\  '_ '`)        _( )_ .'  (_,_)(_ o _).          |  |\_   /|  |;  \  '_ /  | :|( ''_'  ) |,-./  )       |   '-(_{;}_)|___|  /  ||(_ o _) /    |   \
|  _( )_/ |  | .---.  > (_)  )   ___(_ o _)'         (_,_). '.         |  _( )_/ |  ||  _`,/ \ _/  || . (_) `. |\  '_ '`)     |      (_,_)    _.-`   || (_,_).' __  :_ _:
| (_ o _) |  | |   | (  .  .-'  |   |(_,_)'         .---.  \  :        | (_ o _) |  |: (  '\_/ \   ;|(_    ._) ' > (_)  )  __ | _ _--.   | .'   _    ||  |\ \  |  | (_I_)
|  (_,_)  |  | |   |  `-'`-'|___|   `-'  /           \    `-'  |        |  (_,_)  |  | \ `"/  \  ) / |  (_.\.' / (  .  .-'_/  )|( ' ) |   | |  _( )_  ||  | \ `'   /(_(=)_)
|  |      |  | |   |   |        \\      /             \       /        |  |      |  |  '. \_/``".'  |       .'   `-'`-'     / (_{;}_)|   | \ (_ o _) /|  |  \    /  (_I_)
'--'      '--' '---'   `--------` `-..-'               `-...-'         '--'      '--'    '-----'    '-----'`       `._____.'  '(_,_) '---'  '.(_,_).' ''-'   `'-'   '---'
--]]

-- =========================================================================
-- You're free to put all your stuff down here! ^^
-- =========================================================================

DAD_Strum = "dad"
BF_Strum = "bf"
Strum_Gen = "gen"
dad_Strum = DAD_Strum
bf_Strum = BF_Strum
strum_Gen = Strum_Gen
strum_gen = Strum_Gen

-- TABELAS DO MODCHART
local mods = {}
local modTweens = {}
local defaultStrums = {}
local toggleStates = {}

local noteMods = {}
local noteTweens = {}
local customModifiers = {}
local customModifierOrder = {}
local scheduledEvents = {}

-- local MS_X = {90, 205, 315, 425, 730, 845, 955, 1065} -- talvez eu tenha esquecido pra que isso serve


local VP_X = 1280 / 2
local VP_Y = 720 / 2
local PERSPECTIVE_FL = 700
local UPSCROLL_Y = 50
local DOWNSCROLL_Y = 580
local depthSortDirty = false
local callExternalModchart = function() end

local function refreshScrollAnchors()
    local strumHeight = getPropertyFromGroup('strumLineNotes', 0, 'height') or 112
    if downscroll then
        DOWNSCROLL_Y = getPropertyFromGroup('strumLineNotes', 0, 'y') or ((screenHeight or 720) - strumHeight - 50)
        UPSCROLL_Y = 50
    else
        UPSCROLL_Y = getPropertyFromGroup('strumLineNotes', 0, 'y') or 50
        DOWNSCROLL_Y = (screenHeight or 720) - strumHeight - 50
    end
end

function onCreate()
    if awesomeLuaCreate then awesomeLuaCreate() end
    if modChartCreate then modChartCreate() end
    callExternalModchart('modChartCreate')
end

function onCreatePost()
    for i = 0, 7 do
        defaultStrums[i] = {
            x = getPropertyFromGroup('strumLineNotes', i, 'x'),
            y = getPropertyFromGroup('strumLineNotes', i, 'y'),
            angle = getPropertyFromGroup('strumLineNotes', i, 'angle'),
            scaleX = getPropertyFromGroup('strumLineNotes', i, 'scale.x'),
            scaleY = getPropertyFromGroup('strumLineNotes', i, 'scale.y'),
            z = 0
        }
    end
    refreshScrollAnchors()
    if modChartCreatePost then modChartCreatePost() end
    callExternalModchart('modChartCreatePost')
end

-- =========================================================================
-- HAXE TÁ DE PUTARIA
-- =========================================================================
                -- https://github.com/luapower/easing/tree/master eu te amo
local osEAD = {
    linear = function(t) return t end,
    quadIn = function(t) return t * t end,
    quadOut = function(t) return t * (2 - t) end,
    quadInOut = function(t) return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t end,
    cubeIn = function(t) return t * t * t end,
    cubeOut = function(t) local v = t - 1 return v * v * v + 1 end,
    sineIn = function(t) return 1 - math.cos(t * (math.pi / 2)) end,
    sineOut = function(t) return math.sin(t * (math.pi / 2)) end,
    sineInOut = function(t) return 0.5 * (1 - math.cos(math.pi * t)) end,
    circIn = function(t) return 1 - math.sqrt(1 - t * t) end,
    circOut = function(t) return math.sqrt(1 - (t - 1) ^ 2) end,
    backIn = function(t) local s = 1.70158 return t * t * ((s + 1) * t - s) end,
    backOut = function(t) local s = 1.70158 local v = t - 1 return v * v * ((s + 1) * v + s) + 1 end,
    expoIn = function(t) return t == 0 and 0 or 2 ^ (10 * (t - 1)) end,
    expoOut = function(t) return t == 1 and 1 or 1 - (2 ^ (-10 * t)) end
}

function getEaseValue(ratio, ease)
    local func = osEAD[ease] or osEAD.linear
    return func(ratio)
end

-- =========================================================================
-- Helpers
-- =========================================================================

function lerp(a, b, t)
    return a + (b - a) * t
end

local function clamp(v, minv, maxv)
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end

local explicitDefaultMods = {
    globalScale = 0
}

local function getModDefaultValue(modName)
    if explicitDefaultMods[modName] ~= nil then
        return explicitDefaultMods[modName]
    end
    return (modName:find('Alpha') or modName:find('Scale')) and 1 or 0
end

local function normalizeTarget(target)
    if target == nil then
        return Strum_Gen
    end

    if type(target) == "string" then
        local lowered = target:lower()

        if lowered == DAD_Strum or lowered == 'opponent' or lowered == 'dad_strum' then
            return DAD_Strum
        end
        if lowered == BF_Strum or lowered == 'player' or lowered == 'bf_strum' then
            return BF_Strum
        end
        if lowered == Strum_Gen or lowered == 'all' or lowered == 'both' or lowered == 'strum_gen' then
            return Strum_Gen
        end

        local lane = tonumber(target)
        if lane ~= nil then
            return math.max(0, math.min(7, math.floor(lane)))
        end
    elseif type(target) == "number" then
        return math.max(0, math.min(7, math.floor(target)))
    end

    return target
end

local function eachTargetLane(target, callback)
    target = normalizeTarget(target)

    if type(target) == "table" then
        for _, laneTarget in ipairs(target) do
            eachTargetLane(laneTarget, callback)
        end
        return
    end

    local startLane, endLane = 0, 7

    if target == DAD_Strum then
        startLane, endLane = 0, 3
    elseif target == BF_Strum then
        startLane, endLane = 4, 7
    elseif type(target) == "number" then
        startLane, endLane = target, target
    end

    for i = startLane, endLane do
        callback(i)
    end
end

local function getTargetCurrentMod(modName, target)
    target = normalizeTarget(target or Strum_Gen)
    initMod(modName)

    if type(target) == "number" then
        return getModDef(modName, target > 3, getModDefaultValue(modName), target)
    end

    if mods[modName][target] ~= nil then
        return mods[modName][target]
    end

    return mods[modName][Strum_Gen] ~= nil and mods[modName][Strum_Gen] or getModDefaultValue(modName)
end

local function normalizeScrollType(scrollType)
    local scrollName = tostring(scrollType or 'scrollMode')
    local lowered = scrollName:lower()

    if lowered == 'scroll' or lowered == 'scrollmode' or lowered == 'upscroll' or lowered == 'downscroll' then
        return 'scrollMode'
    end
    if lowered == 'opposite' or lowered == 'reverse' then
        return 'opposite'
    end
    if lowered == 'oppswap' or lowered == 'opponentswap' or lowered == 'swap' then
        return 'oppSwap'
    end

    return scrollName
end

local function makeModTable(defaultVal)
    local t = {
        [0] = defaultVal,
        [1] = defaultVal,
        [2] = defaultVal
    }
    for i = 0, 7 do
        t[i] = t[i] or defaultVal
    end
    return t
end

function initMod(modName)
    modName = tostring(modName)

    if not mods[modName] then
        local defaultVal = getModDefaultValue(modName)
        mods[modName] = {
            [DAD_Strum] = defaultVal,
            [BF_Strum] = defaultVal,
            [Strum_Gen] = defaultVal
        }
    end
end

local function applyModValue(modName, value, target)
    target = normalizeTarget(target or Strum_Gen)
    initMod(modName)

    if target == Strum_Gen then
        -- Atualiza todos
        mods[modName][DAD_Strum] = value
        mods[modName][BF_Strum] = value
        mods[modName][Strum_Gen] = value
        for i = 0, 7 do
            mods[modName][i] = value
        end
    elseif target == DAD_Strum then
        mods[modName][DAD_Strum] = value
        for i = 0, 3 do
            mods[modName][i] = value
        end
    elseif target == BF_Strum then
        mods[modName][BF_Strum] = value
        for i = 4, 7 do
            mods[modName][i] = value
        end
    else
        mods[modName][target] = value
    end
end

local function getTweenKey(tag, modName, target)
    target = normalizeTarget(target or Strum_Gen)
    return tostring(tag) .. '::' .. tostring(modName) .. '::' .. tostring(target)
end

local function clearModTweens(modName, target, exceptKey)
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

function defineModifier(modchart, callbacks)
    modchart = tostring(modchart)
    if type(callbacks) ~= 'table' then
        callbacks = {apply = callbacks}
    end

    customModifiers[modchart] = callbacks
    local alreadyRegistered = false
    for _, name in ipairs(customModifierOrder) do
        if name == modchart then
            alreadyRegistered = true
            break
        end
    end
    if not alreadyRegistered then
        table.insert(customModifierOrder, modchart)
    end

    initMod(modchart)
    return modchart
end

addCustomModifier = defineModifier

function clearModchart(modchart)
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

    target = normalizeTarget(target or Strum_Gen)
    initMod(modchart)
    local tweenKey = getTweenKey(tag, modchart, target)
    clearModTweens(modchart, target, tweenKey)

    local startVal = getTargetCurrentMod(modchart, target)

    if not duration or duration <= 0 then
        clearModTweens(modchart, target)
        applyModValue(modchart, intensity, target)
        if modChartTweenFinished then modChartTweenFinished(tag) end
        return
    end

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

function setStrumAlpha(s, a) applyStrumAction("setStrumAlpha", 'strumAlpha', checkOg(a, 1), 0, nil, s) end
function setStrumX(s, x)     applyStrumAction("setStrumX", 'strumX', checkOg(x, 0), 0, nil, s) end
function setStrumY(s, y)     applyStrumAction("setStrumY", 'strumY', checkOg(y, 0), 0, nil, s) end
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

function easeScroll(target, scrollType, duration, easeName, tag)
    local targetKey = normalizeTarget(target or Strum_Gen)
    local scrollName = normalizeScrollType(scrollType)
    local key = scrollName .. "_" .. tostring(targetKey)

    if toggleStates[key] == nil then
        toggleStates[key] = getTargetCurrentMod(scrollName, targetKey) >= 0.5
    end

    toggleStates[key] = not toggleStates[key]
    local targetVal = toggleStates[key] and 1 or 0

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
    endVal = endVal or 0     -- aí volta pro 0 pra quem for burro
    duration = duration or 0.5
    easeName = easeName or 'cubeOut'
    target = target or Strum_Gen

    setModchart(modName, startVal, target)
    easeModchart(tag, modName, endVal, duration, easeName, target)
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

-- =========================================================================
-- Callbacks extras
-- =========================================================================

function callExternalModchart(funcName, args)
    if callOnScripts then
        callOnScripts(funcName, args or {}, true, true)
    end
end

function onUpdate(elapsed)
    local toRemove = {}

    for key, data in pairs(modTweens) do
        data.time = data.time + elapsed
        local ratio = math.min(data.time / data.duration, 1)
        local easedRatio = getEaseValue(ratio, data.easeName)
        local val = lerp(data.startVal, data.targetVal, easedRatio)

        if mods[data.modName] then
            applyModValue(data.modName, val, data.target)
        end

        if ratio >= 1 then
            table.insert(toRemove, key)
            if modChartTweenFinished then
                modChartTweenFinished(data.tag)
            end
        end
    end

    for _, key in ipairs(toRemove) do
        modTweens[key] = nil
    end

    if modChartUpdate then modChartUpdate(elapsed) end
    callExternalModchart('modChartUpdate', {elapsed})
end

function onUpdatePost(elapsed)
    local currentSongPos = getSongPosition()
    local currentBeat = (currentSongPos / 1000) * (curBpm / 60)
    depthSortDirty = false

    for i = 0, 7 do
        updateNoteMath(i, true, i, currentSongPos, currentBeat)
    end

    for i = 0, getProperty('notes.length') - 1 do
        local noteData = getPropertyFromGroup('notes', i, 'noteData')
        local isDad = not getPropertyFromGroup('notes', i, 'mustPress')
        local strumID = noteData + (isDad and 0 or 4)

        updateNoteMath(i, false, strumID, currentSongPos, currentBeat)
    end

    if depthSortDirty then
        sortPseudo3DLayers()
    end

    if modChartUpdatePost then modChartUpdatePost(elapsed) end
    callExternalModchart('modChartUpdatePost', {elapsed})
end

function onBeatHit()
    if modChartBeatHit then modChartBeatHit() end
    callExternalModchart('modChartBeatHit')
end

function onStepHit()
    runScheduledEvents()
    if modChartStepHit then modChartStepHit() end
    callExternalModchart('modChartStepHit')
end

function onSectionHit()
    if modChartSectionHit then modChartSectionHit() end
    callExternalModchart('modChartSectionHit')
end

function onMoveCamera(focus)
    if modChartFocus then modChartFocus(focus) end
    callExternalModchart('modChartFocus', {focus})
end

function goodNoteHit(id, nd, nt, sus)
    if modChartBFNote then modChartBFNote(id, nd, nt, sus) end
    callExternalModchart('modChartBFNote', {id, nd, nt, sus})
end

function opponentNoteHit(id, nd, nt, sus)
    if modChartDADNote then modChartDADNote(id, nd, nt, sus) end
    callExternalModchart('modChartDADNote', {id, nd, nt, sus})
end

function goodNoteHitPre(id, nd, nt, sus)
    if modChartBFNotePre then modChartBFNotePre(id, nd, nt, sus) end
    callExternalModchart('modChartBFNotePre', {id, nd, nt, sus})
end

function opponentNoteHitPre(id, nd, nt, sus)
    if modChartDADNotePre then modChartDADNotePre(id, nd, nt, sus) end
    callExternalModchart('modChartDADNotePre', {id, nd, nt, sus})
end

function noteMiss(id, nd, nt, sus)
    if modChartMiss then modChartMiss(id, nd, nt, sus) end
    callExternalModchart('modChartMiss', {id, nd, nt, sus})
end

function noteMissPress(id, nd, nt, sus)
    if modChartMissPress then modChartMissPress(id, nd, nt, sus) end
    callExternalModchart('modChartMissPress', {id, nd, nt, sus})
end

function onSongStart()
    if modChartSongStart then modChartSongStart() end
    callExternalModchart('modChartSongStart')
end

-- =========================================================================
-- Math & Modifier Core
-- =========================================================================

local function getStrumPivot(strumID)
    local base = (strumID > 3) and 4 or 0

    local x = 0
    for i = base, base + 3 do
        x = x + defaultStrums[i].x
    end

    local pivotX = x / 4
    local pivotY = defaultStrums[base].y
    return pivotX, pivotY
end

local function getScrollBlend(isPlayer, strumID)
    return clamp(getModDef('scrollMode', isPlayer, downscroll and 0 or 1, strumID), 0, 1)
end

local function getOppositeBlend(isPlayer, strumID)
    return clamp(getMod('opposite', isPlayer, strumID), 0, 1)
end

local function clamp(v, minv, maxv) -- a lacração no mundo dos modcharts
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end

local function isOppSwapOn()
    return getMod('opponentSwap', false, 0) ~= 0 or getMod('oppSwap', false, 0) ~= 0
end

local function getVisualStrumID(strumID)
    if isOppSwapOn() then
        return (strumID > 3) and (strumID - 4) or (strumID + 4)
    end
    return strumID
end

local function getOppSwapBlend(isPlayer, strumID)
    local swapVal = getMod('oppSwap', isPlayer, strumID)
    local altSwapVal = getMod('opponentSwap', isPlayer, strumID)

    if math.abs(altSwapVal) > math.abs(swapVal) then
        swapVal = altSwapVal
    end

    return clamp(swapVal, 0, 1)
end

local function getEffectiveScrollBlend(isPlayer, strumID)
    local scrollBlend = getScrollBlend(isPlayer, strumID)
    return lerp(scrollBlend, 1 - scrollBlend, getOppositeBlend(isPlayer, strumID))
end

local function getStrumYFromBlend(scrollBlend)
    refreshScrollAnchors()
    return lerp(DOWNSCROLL_Y, UPSCROLL_Y, clamp(scrollBlend, 0, 1))
end

local function getOtherSideStrumID(strumID)
    return (strumID > 3) and (strumID - 4) or (strumID + 4)
end

local function buildLaneState(strumID)
    local isPlayer = (strumID > 3)
    local col = strumID % 4
    local def = defaultStrums[strumID]
    local scrollBlend = getEffectiveScrollBlend(isPlayer, strumID)

    local state = {
        strumID = strumID,
        isPlayer = isPlayer,
        col = col,
        x = def.x + getModDef('strumX' .. strumID, isPlayer, 0, strumID) + getMod('bumpX', isPlayer, strumID),
        y = getStrumYFromBlend(scrollBlend) + getModDef('strumY' .. strumID, isPlayer, 0, strumID),
        angle = def.angle + getModDef('strumAngle' .. strumID, isPlayer, 0, strumID),
        scaleX = def.scaleX * getModDef('strumScale' .. strumID, isPlayer, 1, strumID),
        scaleY = def.scaleY * getModDef('strumScale' .. strumID, isPlayer, 1, strumID),
        alpha = getModDef('strumAlpha' .. strumID, isPlayer, 1, strumID),
        scrollBlend = scrollBlend
    }

    local middleVal = getMod('middle', isPlayer, strumID)
    if middleVal ~= 0 then
        local centerOffset = 412
        local sideX = centerOffset + (col * 112)
        state.x = lerp(state.x, sideX, middleVal)
    end

    local middle2Val = getMod('middle2', isPlayer, strumID)
    if middle2Val ~= 0 then
        local extremidadesX = {[0] = 90, [1] = 205, [2] = 955, [3] = 1065}
        local targetX = extremidadesX[col]
        
        state.x = lerp(state.x, targetX, middle2Val)
    end

    return state
end

local function blendLaneStates(fromState, toState, ratio)
    return {
        strumID = fromState.strumID,
        isPlayer = fromState.isPlayer,
        col = fromState.col,
        x = lerp(fromState.x, toState.x, ratio),
        y = lerp(fromState.y, toState.y, ratio),
        angle = lerp(fromState.angle, toState.angle, ratio),
        scaleX = lerp(fromState.scaleX, toState.scaleX, ratio),
        scaleY = lerp(fromState.scaleY, toState.scaleY, ratio),
        alpha = lerp(fromState.alpha, toState.alpha, ratio),
        scrollBlend = lerp(fromState.scrollBlend, toState.scrollBlend, ratio)
    }
end

local function getCurrentLinePivot(strumID)
    local isPlayer = (strumID > 3)
    local base = isPlayer and 4 or 0
    local swapBlend = getOppSwapBlend(isPlayer, strumID)
    local sumX, sumY = 0, 0
    local otherSumX, otherSumY = 0, 0

    for i = base, base + 3 do
        local lane = buildLaneState(i)
        sumX = sumX + lane.x
        sumY = sumY + lane.y
    end

    local pivotX = sumX / 4
    local pivotY = sumY / 4

    if swapBlend ~= 0 then
        local otherBase = isPlayer and 0 or 4
        for i = otherBase, otherBase + 3 do
            local otherLane = buildLaneState(i)
            otherSumX = otherSumX + otherLane.x
            otherSumY = otherSumY + otherLane.y
        end

        pivotX = lerp(pivotX, otherSumX / 4, swapBlend)
        pivotY = lerp(pivotY, otherSumY / 4, swapBlend)
    end

    return pivotX, pivotY
end

local function projectPseudo3D(x, y, z)
    local halfX = VP_X
    local halfY = VP_Y

    local fov = math.pi / 2 -- e obgda pro schmoovin' q fez isso antes e eu to adaptando em lua leroleroleroooo
    local aspect = 1
    local near = 0
    local far = 2

    local depth = z / PERSPECTIVE_FL
    depth = clamp(depth, -1, 0.999)

    local shit = depth - 1
    if shit > 0 then shit = 0 end

    local ta = math.tan(fov / 2)
    if ta == 0 then ta = 0.0001 end

    local a = (near + far) / (near - far)
    local b = (2 * near * far) / (near - far)

    local zProj = (a * shit + b)

    if math.abs(zProj) < 0.0001 then
        zProj = 0.0001
    end

    local outX = halfX + (((x - halfX) * aspect / ta) / zProj)
    local outY = halfY + (((y - halfY) / ta) / zProj)

    return outX, outY, zProj
end


function legacyUpdateNoteMath(objID, strumE, strumID, songPos, beat)
    if isOppSwapOn() then
        strumID = getVisualStrumID(strumID)
    end

    local isPlayer = (strumID > 3)
    local col = strumID % 4
    local def = defaultStrums[strumID]


    local curX, curY, curAngle = def.x, def.y, def.angle
    local curScaleX, curScaleY = def.scaleX, def.scaleY
    local curAlpha = strumE and getPropertyFromGroup('strumLineNotes', objID, 'alpha') or getPropertyFromGroup('notes', objID, 'alpha')
    local curZ = 0
    local eLonga = (not strumE) and getPropertyFromGroup('notes', objID, 'isSustainNote')

    if not strumE then
        local offsetX = getPropertyFromGroup('notes', objID, 'offsetX') or 0
        local offsetY = getPropertyFromGroup('notes', objID, 'offsetY') or 0

        curX = getPropertyFromGroup('strumLineNotes', strumID, 'x') + offsetX
        curY = getPropertyFromGroup('notes', objID, 'y') + offsetY
    end

    -- ALPHA
    local alphaVal = getModDef('strumAlpha' .. strumID, isPlayer, 1, strumID)
    curAlpha = alphaVal

    curX = curX + getModDef('strumX' .. strumID, isPlayer, 0, strumID)
    curY = curY + getModDef('strumY' .. strumID, isPlayer, 0, strumID)
    curX = curX + getMod('bumpX', isPlayer, strumID)
    curAngle = curAngle + getModDef('strumAngle' .. strumID, isPlayer, 0, strumID)
    curScaleX = curScaleX * getModDef('strumScale' .. strumID, isPlayer, 1, strumID)
    curScaleY = curScaleY * getModDef('strumScale' .. strumID, isPlayer, 1, strumID)
    curAlpha = curAlpha * getModDef('strumAlpha' .. strumID, isPlayer, 1, strumID)
    

    

    -- OPPOSITE (smooth scroll)
    local oppVal = getMod('opposite', isPlayer, strumID)
    local isUpscroll = not downscroll
    local receptorY = def.y

    if oppVal ~= 0 then
        local oppTargetY = isUpscroll and 580 or 50
        receptorY = lerp(def.y, oppTargetY, oppVal)

        if strumE then
            curY = receptorY
        else
            local noteDist = curY - def.y
            local newDist = lerp(noteDist, -noteDist, oppVal)
            curY = receptorY + newDist
        end
    end

    -- DRUNK
    local drunkVal = getMod('drunk', isPlayer, strumID)
    if drunkVal ~= 0 then
        local noteOffset = strumE and 0 or (curY * 0.01)
        local drunkTime = ((songPos / 1000) * 2) + (col * 0.5) + noteOffset
        curX = curX + drunkVal * (math.cos(drunkTime) * 40) -- que eu esqueci

        if eLonga then
            local waveDeriv = -math.sin(drunkTime)
            curAngle = curAngle + (waveDeriv * drunkVal * 15)
        end
    end

    -- FLOAT (com Z)
    local floatVal = getMod('float', isPlayer, strumID)
    if floatVal ~= 0 then
        local noteOffset = strumE and 0 or (curY * 0.01)
        local floatTime = ((songPos / 1000) * 2) + (col * 0.6) + noteOffset
        curX = curX + floatVal * (math.cos(floatTime) * 30)
        curY = curY + floatVal * (math.cos(floatTime) * 30)
        curZ = curZ + floatVal * (math.sin(floatTime * 1.3) * 100) + 30

        if eLonga then
            local waveDeriv = -math.sin(floatTime)
            curAngle = curAngle + (waveDeriv * floatVal * 6)
        end
    end

    -- BEAT
    local beatVal = getMod('beat', isPlayer, strumID)
    if beatVal ~= 0 then
        local beatOffset = (col * 0.2) + (strumE and 0 or (curY * 0.005))
        local beatMath = beatOffset + beat

        curX = curX + math.sin(beatMath) * 150 * beatVal
        curY = curY + math.sin(beatMath) * 50 * beatVal

        if eLonga then
            local waveDeriv = math.cos(beatMath)
            curAngle = curAngle + (waveDeriv * beatVal * 36)
            curX = curX + (waveDeriv * beatVal * 10)
            curY = curY + (waveDeriv * beatVal * 6)
        end
    end

    -- TEMNA AHH EFFECT
    local beatVal = getMod('temna', isPlayer, strumID)
    if beatVal ~= 0 then
        local beatOffset = (col * 0.2) + (strumE and 0)
        local beatMath = beatOffset + beat

        curX = curX + math.sin(beatMath) * 150 * beatVal

        if eLonga then
            local waveDeriv = math.cos(beatMath)
            curAngle = curAngle + (waveDeriv * beatVal * 36)
            curX = curX + (waveDeriv * beatVal * 10)
        end
    end

    -- Spin (2D)
    local spinVal = getMod('spin', isPlayer, strumID)
    -- Adicionamos "and not eLonga" para ignorar sustains
    if spinVal ~= 0 and not eLonga then
        curAngle = curAngle + (spinVal * 360)
    end

    -- rZ Se tudo der certo eu me mato hj em nome de Jesus
    local rotX = getMod('rX', isPlayer, strumID)
    local rotY = getMod('rY', isPlayer, strumID)
    local rotZ = getMod('rZ', isPlayer, strumID)

    if rotX ~= 0 or rotY ~= 0 or rotZ ~= 0 then

        local startIdx = isPlayer and 4 or 0
        local endIdx = isPlayer and 7 or 3
        local pivotX = (defaultStrums[startIdx].x + defaultStrums[endIdx].x) / 2
        local pivotY = 720 / 2

        local relX = curX - pivotX
        local relY = curY - pivotY
        local relZ = curZ

        local radX = rotX * math.pi * 2
        local radY = rotY * math.pi * 2
        local radZ = rotZ * math.pi * 2

        local cZ, sZ = math.cos(radZ), math.sin(radZ)
        local x1 = relX * cZ - relY * sZ
        local y1 = relX * sZ + relY * cZ
        local z1 = relZ
        
        curAngle = curAngle + (rotZ * 360)

        local cX, sX = math.cos(radX), math.sin(radX)
        local x2 = x1
        local y2 = y1 * cX - z1 * sX
        local z2 = y1 * sX + z1 * cX

        local cY, sY = math.cos(radY), math.sin(radY)
        local x3 = x2 * cY + z2 * sY
        local y3 = y2
        local z3 = -x2 * sY + z2 * cY

        curX = x3 + pivotX
        curY = y3 + pivotY
        curZ = z3
    end



    -- Z-AXIS
    local zVal = getMod('z', isPlayer, strumID)
    if zVal ~= 0 then
        curZ = curZ + zVal
    end

    if curZ ~= 0 then
        local px, py, pz = projectPseudo3D(curX, curY, curZ)

        curX = px
        curY = py

        -- o scale acompanha a profundidade
        local depthScale = 1 / math.max(0.001, pz)
        curScaleX = curScaleX * depthScale
        curScaleY = curScaleY * depthScale
    end

    -- MIDDLE
    local middleVal = getMod('middle', isPlayer, strumID)
    if middleVal ~= 0 then
        local centerOffset = 412
        local sideX = centerOffset + (col * 112)
        curX = lerp(curX, sideX, middleVal)
    end

    --[[function spinShot(tag, target, modName, intensity)
    setModchart(modName, intensity, target)
    easeModchart(tag, modName, 0, 1.2, 'expoOut', target)
    end]]

    -- APPLY SHIT IDK
    local group = strumE and 'strumLineNotes' or 'notes'
    setPropertyFromGroup(group, objID, 'x', curX)
    setPropertyFromGroup(group, objID, 'y', curY)
    setPropertyFromGroup(group, objID, 'angle', curAngle)
    setPropertyFromGroup(group, objID, 'scale.x', curScaleX)
    setPropertyFromGroup(group, objID, 'alpha', curAlpha)

    local isUpscroll = isUpscrollFor(isPlayer, strumID)

    if not eLonga then
            setPropertyFromGroup(group, objID, 'scale.y', curScaleY)
    else
        local rabo = (getPropertyFromGroup(group, objID, 'frameHeight') or getPropertyFromGroup(group, objID, 'height')) * curScaleY
    local flip = (oppVal > 0.5 and isUpscroll) or (not isUpscroll)
    setPropertyFromGroup(group, objID, 'flipY', flip)
    setPropertyFromGroup(group, objID, 'x', curX + 25)

    if flip then -- reminder de arrumar isso
        setPropertyFromGroup(group, objID, 'y', curY - 120 + (rabo * 1))
    else
        setPropertyFromGroup(group, objID, 'y', curY + 20 - (rabo * 0.5))
    end
    end


    if curZ ~= 0 then -- schmoovin referencias!!!!!
    local voltaZ = math.max(curZ, -PERSPECTIVE_FL + 1)
    local tamainZ = PERSPECTIVE_FL / (PERSPECTIVE_FL + voltaZ)

    curScaleX = curScaleX * tamainZ
    curScaleY = curScaleY * tamainZ

    curX = VP_X + (curX - VP_X) * tamainZ
    curY = VP_Y + (curY - VP_Y) * tamainZ
end

 
end

local function projectPseudo3DEnhanced(x, y, z)
    local depth = math.max(80, PERSPECTIVE_FL - z)
    local scale = PERSPECTIVE_FL / depth
    local outX = VP_X + (x - VP_X) * scale
    local outY = VP_Y + (y - VP_Y) * scale

    return outX, outY, scale
end

function sortPseudo3DLayers()
    if not runHaxeCode then
        return
    end

    runHaxeCode([[
        var sortPseudoDepth = function(a:Dynamic, b:Dynamic) {
            if (a == null || b == null) return 0;

            var az:Float = (a.scale != null ? a.scale.x : 1);
            var bz:Float = (b.scale != null ? b.scale.x : 1);

            if (az < bz) return -1;
            if (az > bz) return 1;
            if (a.y < b.y) return -1;
            if (a.y > b.y) return 1;
            return 0;
        };

        if (game.notes != null && game.notes.members != null) {
            game.notes.members.sort(sortPseudoDepth);
        }
        
        // A PARTE QUE DAVA SORT NAS STRUMLINENOTES FOI DELETADA!
    ]])
end
local function getNoteTravelDistance(distance, isPlayer, strumID, col, beat)
    local sign = distance < 0 and -1 or 1
    local magnitude = math.abs(distance)
    local dashVal = getMod('noteDash', isPlayer, strumID)
    if dashVal ~= 0 then
        local farFactor = math.sqrt(clamp(magnitude / 700, 0, 1))
        
        local beatPush = 1 + (math.max(0, math.sin((beat * math.pi) + (col * 0.35))) * 0.2)
        
        magnitude = magnitude * (1 + (farFactor * dashVal * 0.5 * beatPush))
    end

    -- AJUSTE DO NOTESLOW
    local slowVal = getMod('noteSlow', isPlayer, strumID)
    if slowVal ~= 0 then
        local range = 500
        local halfFactor = clamp((range - magnitude) / range, 0, 1)
        
        magnitude = magnitude * (1 + (halfFactor * (slowVal * 0.6)))
    end

    return sign * magnitude
end

local function applyCustomModifiers(ctx)
    for _, name in ipairs(customModifierOrder) do
        local callbacks = customModifiers[name]
        local value = getMod(name, ctx.isPlayer, ctx.strumID)

        if callbacks ~= nil and value ~= 0 then
            ctx.modName = name
            ctx.value = value

            local fn = callbacks.apply
            if ctx.strumE then
                fn = callbacks.strum or callbacks.receptor or fn
            else
                fn = callbacks.note or fn
                if ctx.isSustainNote then
                    fn = callbacks.sustain or fn
                end
            end

            if fn ~= nil then
                local ok, err = pcall(fn, ctx, value)
                if not ok and debugPrint then
                    debugPrint('Custom modifier "' .. name .. '" failed: ' .. tostring(err))
                end
            end
        end
    end
end

function updateNoteMath(objID, strumE, strumID, songPos, beat)
    local isPlayer = (strumID > 3)
    local col = strumID % 4
    local laneState = buildLaneState(strumID)
    local swapBlend = getOppSwapBlend(isPlayer, strumID)

    if swapBlend ~= 0 then
        laneState = blendLaneStates(laneState, buildLaneState(getOtherSideStrumID(strumID)), swapBlend)
    end

    local curX, curY, curAngle = laneState.x, laneState.y, laneState.angle
    local curScaleX, curScaleY = laneState.scaleX, laneState.scaleY
    local curAlpha = strumE and 1 or (getPropertyFromGroup('notes', objID, 'alpha') or 1)
    local curZ = 0
    local eLonga = (not strumE) and getPropertyFromGroup('notes', objID, 'isSustainNote')
    local noteDistance = 0

    if not strumE then
        local offsetX = getPropertyFromGroup('notes', objID, 'offsetX') or 0
        local offsetY = getPropertyFromGroup('notes', objID, 'offsetY') or 0
        noteDistance = getPropertyFromGroup('notes', objID, 'distance') or 0

        local travelDistance = getNoteTravelDistance(noteDistance, isPlayer, strumID, col, beat)
        local scrollSign = lerp(-1, 1, laneState.scrollBlend)

        curX = curX + offsetX
        curY = curY + offsetY + (travelDistance * scrollSign)

        local zigzagVal = getMod('zigzag', isPlayer, strumID)
        if zigzagVal ~= 0 then
            local alignBlend = clamp(math.abs(travelDistance) / 240, 0, 1)
            local zigzagWave = math.sin((math.abs(travelDistance) * 0.03) + ((songPos / 1000) * 5) + (col * 0.7))
            curX = curX + (zigzagWave * 48 * zigzagVal * alignBlend)
        end
    end

    local globalScale = math.max(0.05, 1 + getMod('globalScale', isPlayer, strumID))
    curScaleX = curScaleX * globalScale
    curScaleY = curScaleY * globalScale
    curAlpha = curAlpha * laneState.alpha

    local drunkVal = getMod('drunk', isPlayer, strumID)
    if drunkVal ~= 0 then
        local noteOffset = strumE and 0 or (noteDistance * 0.01)
        local drunkTime = ((songPos / 1000) * 2) + (col * 0.5) + noteOffset
        curX = curX + (drunkVal * math.cos(drunkTime) * 40)

        if eLonga then
            local waveDeriv = -math.sin(drunkTime)
            curAngle = curAngle + (waveDeriv * drunkVal * 15)
        end
    end

    local floatVal = getMod('float', isPlayer, strumID)
    if floatVal ~= 0 then
        local noteOffset = strumE and 0 or (noteDistance * 0.01)
        local floatTime = ((songPos / 1000) * 2) + (col * 0.6) + noteOffset
        curX = curX + (floatVal * math.cos(floatTime) * 30)
        curY = curY + (floatVal * math.cos(floatTime) * 30)
        curZ = curZ + (floatVal * math.sin(floatTime * 1.3) * 100) + 30

        if eLonga then
            local waveDeriv = -math.sin(floatTime)
            curAngle = curAngle + (waveDeriv * floatVal * 6)
        end
    end

    local beatVal = getMod('beat', isPlayer, strumID)
    if beatVal ~= 0 then
        local beatOffset = (col * 0.2) + (strumE and 0 or (noteDistance * 0.005))
        local beatMath = beatOffset + beat

        curX = curX + (math.sin(beatMath) * 150 * beatVal)
        curY = curY + (math.sin(beatMath) * 50 * beatVal)

        if eLonga then
            local waveDeriv = math.cos(beatMath)
            curAngle = curAngle + (waveDeriv * beatVal * 36)
            curX = curX + (waveDeriv * beatVal * 10)
            curY = curY + (waveDeriv * beatVal * 6)
        end
    end

    local beatZVal = getMod('beatZ', isPlayer, strumID)
    if beatZVal ~= 0 then
        local beatZMath = beat + (col * 0.2) + (strumE and 0 or (math.abs(noteDistance) * 0.003))
        local beatPulse = math.sin(beatZMath)

        curX = curX + (beatPulse * 90 * beatZVal)
        curY = curY + (beatPulse * 30 * beatZVal)
        curZ = curZ + (math.max(0, beatPulse) * 140 * beatZVal)
    end

    local temnaVal = getMod('temna', isPlayer, strumID)
    if temnaVal ~= 0 then
        local temnaMath = (col * 0.2) + beat
        curX = curX + (math.sin(temnaMath) * 150 * temnaVal)

        if eLonga then
            local waveDeriv = math.cos(temnaMath)
            curAngle = curAngle + (waveDeriv * temnaVal * 36)
            curX = curX + (waveDeriv * temnaVal * 10)
        end
    end

    local earthquakeVal = getMod('earthquake', isPlayer, strumID)
    if earthquakeVal ~= 0 then
        local quakeTime = (songPos / 1000) * 40
        curX = curX + (math.sin(quakeTime + objID + (col * 3)) * 8 * earthquakeVal)
        curY = curY + (math.cos((quakeTime * 1.27) + objID + (col * 2)) * 6 * earthquakeVal)
    end

    local earthquakeValx = getMod('earthquakeX', isPlayer, strumID)
    if earthquakeValx ~= 0 then
        local quakeTime = (songPos / 1000) * 40
        curX = curX + (math.sin(quakeTime + objID + (col * 3)) * 8 * earthquakeValx)
    end

    local earthquakeValy = getMod('earthquakeY', isPlayer, strumID)
    if earthquakeValy ~= 0 then
        local quakeTime = (songPos / 1000) * 40
        curY = curY + (math.cos((quakeTime * 1.27) + objID + (col * 2)) * 6 * earthquakeValy)
    end

    local susPulseVal = getMod('susPulse', isPlayer, strumID)
    if susPulseVal ~= 0 and eLonga then
        local susPulseTime = (beat * 2) + (math.abs(noteDistance) * 0.015) + (col * 0.4)
        curX = curX + (math.sin(susPulseTime) * 24 * susPulseVal)
        curAngle = curAngle + (math.cos(susPulseTime) * 10 * susPulseVal)
    end

    local spinVal = getMod('spin', isPlayer, strumID)
    if spinVal ~= 0 and not eLonga then
        curAngle = curAngle + (spinVal * 360)
    end

    local rotX = getMod('rX', isPlayer, strumID)
    local rotY = getMod('rY', isPlayer, strumID)
    local rotZ = getMod('rZ', isPlayer, strumID)

    if rotX ~= 0 or rotY ~= 0 or rotZ ~= 0 then
        local pivotX, pivotY = getCurrentLinePivot(strumID)
        pivotY = lerp(pivotY, VP_Y, 0.35)

        local rotationBaseX = curX
        local preservedXOffset = 0
        if not strumE then
            rotationBaseX = laneState.x
            preservedXOffset = curX - laneState.x
        end

        local relX = rotationBaseX - pivotX
        local relY = curY - pivotY
        local relZ = curZ

        local radX = rotX * math.pi * 2
        local radY = rotY * math.pi * 2
        local radZ = rotZ * math.pi * 2

        local cZ, sZ = math.cos(radZ), math.sin(radZ)
        local x1 = relX * cZ - relY * sZ
        local y1 = relX * sZ + relY * cZ
        local z1 = relZ
        curAngle = curAngle + (rotZ * 360)

        local cX, sX = math.cos(radX), math.sin(radX)
        local x2 = x1
        local y2 = y1 * cX - z1 * sX
        local z2 = y1 * sX + z1 * cX

        local cY, sY = math.cos(radY), math.sin(radY)
        local x3 = x2 * cY + z2 * sY
        local y3 = y2
        local z3 = -x2 * sY + z2 * cY

        curX = x3 + pivotX
        curY = y3 + pivotY
        curZ = clamp(z3, -PERSPECTIVE_FL * 0.8, PERSPECTIVE_FL * 0.8)

        if not strumE then
            local yawDampen = math.max(0.2, math.abs(math.cos(radY)))
            curX = curX + (preservedXOffset * yawDampen)
        end
    end

    local zVal = getMod('z', isPlayer, strumID)
    if zVal ~= 0 then
        curZ = curZ + zVal
    end

    local ctx = {
        objID = objID,
        strumE = strumE,
        strumID = strumID,
        isPlayer = isPlayer,
        col = col,
        songPos = songPos,
        beat = beat,
        x = curX,
        y = curY,
        angle = curAngle,
        scaleX = curScaleX,
        scaleY = curScaleY,
        alpha = curAlpha,
        z = curZ,
        distance = noteDistance,
        isSustainNote = eLonga,
        scrollBlend = laneState.scrollBlend
    }

    applyCustomModifiers(ctx)

    curX = ctx.x or curX
    curY = ctx.y or curY
    curAngle = ctx.angle or curAngle
    curScaleX = ctx.scaleX or curScaleX
    curScaleY = ctx.scaleY or curScaleY
    curAlpha = ctx.alpha or curAlpha
    curZ = ctx.z or curZ

    if curZ ~= 0 then
        local px, py, depthScale = projectPseudo3DEnhanced(curX, curY, curZ)
        curX = px
        curY = py
        curScaleX = curScaleX * depthScale
        curScaleY = curScaleY * depthScale
        depthSortDirty = true
    end

    local group = strumE and 'strumLineNotes' or 'notes'
    setPropertyFromGroup(group, objID, 'x', curX)
    setPropertyFromGroup(group, objID, 'y', curY)
    setPropertyFromGroup(group, objID, 'angle', curAngle)
    setPropertyFromGroup(group, objID, 'scale.x', curScaleX)
    setPropertyFromGroup(group, objID, 'alpha', curAlpha)

    local isUpscroll = laneState.scrollBlend >= 0.5

    if not eLonga then
        setPropertyFromGroup(group, objID, 'scale.y', curScaleY)
    else
        local strumWidth = getPropertyFromGroup('strumLineNotes', strumID, 'width') or 112
        local strumHeight = getPropertyFromGroup('strumLineNotes', strumID, 'height') or 112
        local frameWidth = getPropertyFromGroup(group, objID, 'frameWidth') or getPropertyFromGroup(group, objID, 'width') or strumWidth

        setPropertyFromGroup(group, objID, 'flipY', false)
        setPropertyFromGroup(group, objID, 'flipX', not isUpscroll)
        setPropertyFromGroup(group, objID, 'angle', isUpscroll and curAngle or (180 - curAngle))
        setPropertyFromGroup(group, objID, 'x', curX + ((strumWidth - frameWidth) * 0.5))
        setPropertyFromGroup(group, objID, 'y', curY + (strumHeight * 0.5))
    end
end

-- =========================================================================
-- da modchrst
-- =========================================================================

function awesomeLuaCreate()
    luaDebugMode = false
end
function modChartCreate()
end

function modChartCreatePost()
end

function modChartUpdate(elapsed)
end

function modChartUpdatePost(elapsed)
end

function modChartStepHit()
end

function modChartBeatHit()
end

function modChartSectionHit()
end

function modChartFocus(focus)
end

function modChartBFNote(id, nd, nt, sus)
end

function modChartDADNote(id, nd, nt, sus)
end

function modChartBFNotePre(id, nd, nt, sus)
end

function modChartDADNotePre(id, nd, nt, sus)
end

function modChartMiss(id, nd, nt, sus)
end

function modChartMissPress(id, nd, nt, sus)
end

function modChartSongStart()
end
