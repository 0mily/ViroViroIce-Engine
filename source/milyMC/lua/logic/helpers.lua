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

local modAliases = {
    reverse = 'opposite',
    opposite = 'opposite',
    scroll = 'scrollMode',
    scrollmode = 'scrollMode',
    upscroll = 'scrollMode',
    downscroll = 'scrollMode',
    oppswap = 'oppSwap',
    opponentswap = 'oppSwap',
    swap = 'oppSwap',
    receptorscroll = 'receptorScroll',
    receptorscrol = 'receptorScroll',
    centered = 'middle',
    center = 'middle',

    transformx = 'transformX',
    transformy = 'transformY',
    transformz = 'transformZ',
    strumz = 'strumZ',
    globalshiftx = 'transformX',
    globalshifty = 'transformY',
    globalshiftz = 'transformZ',

    rx = 'rX',
    rotx = 'rX',
    rotatex = 'rX',
    ry = 'rY',
    roty = 'rY',
    rotatey = 'rY',
    rz = 'rZ',
    rotz = 'rZ',
    rotatez = 'rZ',

    centerrx = 'centerRX',
    centerrotx = 'centerRX',
    centerrotatex = 'centerRX',
    centerry = 'centerRY',
    centerroty = 'centerRY',
    centerrotatey = 'centerRY',
    centerrz = 'centerRZ',
    centerrotz = 'centerRZ',
    centerrotatez = 'centerRZ',
    crx = 'centerRX',
    cry = 'centerRY',
    crz = 'centerRZ',

    localrx = 'rX',
    localrotx = 'rX',
    localrotatex = 'rX',
    localry = 'rY',
    localroty = 'rY',
    localrotatey = 'rY',
    localrz = 'rZ',
    localrotz = 'rZ',
    localrotatez = 'rZ',

    tipz = 'tipZ',
    tipzspeed = 'tipZSpeed',
    tipzperiod = 'tipZPeriod',
    tipzoffset = 'tipZOffset',
    drunkspeed = 'drunkSpeed',
    drunkperiod = 'drunkPeriod',
    drunkoffset = 'drunkOffset',
    tipsyspeed = 'tipsySpeed',
    tipsyperiod = 'tipsyPeriod',
    tipsyoffset = 'tipsyOffset',
    noteangle = 'noteAngle',
    receptorangle = 'receptorAngle',
    hiddenoffset = 'hiddenOffset',
    suddenoffset = 'suddenOffset',
    minix = 'miniX',
    miniy = 'miniY',
    receptorscalex = 'receptorScaleX',
    receptorscaley = 'receptorScaleY',
    notescalex = 'noteScaleX',
    notescaley = 'noteScaleY',
    globalscale = 'globalScale',
    noteslow = 'noteSlow',
    notedash = 'noteDash',
    earthquakex = 'earthquakeX',
    earthquakey = 'earthquakeY',
    suspulse = 'susPulse'
}

local function normalizeModName(modName)
    if modName == nil then return '' end

    local raw = tostring(modName)
    local lowered = raw:lower()
    local alias = modAliases[lowered]
    if alias ~= nil then
        return alias
    end

    local lane, axis = lowered:match('^rotate(%d+)([xyz])$')
    if lane ~= nil then
        return 'r' .. lane .. axis:upper()
    end

    lane, axis = lowered:match('^rot(%d+)([xyz])$')
    if lane ~= nil then
        return 'r' .. lane .. axis:upper()
    end

    lane, axis = lowered:match('^centerrotate(%d+)([xyz])$')
    if lane ~= nil then
        return 'centerR' .. lane .. axis:upper()
    end

    lane, axis = lowered:match('^centerrot(%d+)([xyz])$')
    if lane ~= nil then
        return 'centerR' .. lane .. axis:upper()
    end

    lane, axis = lowered:match('^centerr(%d+)([xyz])$')
    if lane ~= nil then
        return 'centerR' .. lane .. axis:upper()
    end

    lane, axis = lowered:match('^localrotate(%d+)([xyz])$')
    if lane ~= nil then
        return 'r' .. lane .. axis:upper()
    end

    lane, axis = lowered:match('^localrot(%d+)([xyz])$')
    if lane ~= nil then
        return 'r' .. lane .. axis:upper()
    end

    axis, lane = lowered:match('^strum([xyz])(%d+)$')
    if lane ~= nil then
        return 'strum' .. axis:upper() .. lane
    end

    return raw
end

local function getModDefaultValue(modName)
    modName = normalizeModName(modName)

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
    modName = normalizeModName(modName)
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
    return normalizeModName(scrollType or 'scrollMode')
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
    modName = normalizeModName(modName)

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
    modName = normalizeModName(modName)
    target = normalizeTarget(target or Strum_Gen)
    initMod(modName)

    if target == Strum_Gen then
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

