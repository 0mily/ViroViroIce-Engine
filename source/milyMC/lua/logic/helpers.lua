-- =========================================================================
-- Helpers
-- =========================================================================

function lerp(a, b, t)
    return a + (b - a) * t
end

MILYMC_NOTE_DATA = 1
MILYMC_NOTE_MUST_PRESS = 2
MILYMC_NOTE_IS_SUSTAIN = 3
MILYMC_NOTE_OFFSET_X = 4
MILYMC_NOTE_OFFSET_Y = 5
MILYMC_NOTE_DISTANCE = 6
MILYMC_NOTE_SPEED = 7
MILYMC_NOTE_SUSTAIN_PIXELS = 8
MILYMC_NOTE_MULT_ALPHA = 9
MILYMC_NOTE_IS_SUSTAIN_END = 10

local function clamp(v, minv, maxv)
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end

local explicitDefaultMods = {
    globalScale = 0,
    beatIntensity = 1,
    beatSusIntensity = 1
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
    beatkick = 'beatKick',
    beatintensity = 'beatIntensity',
    beatnoteintensity = 'beatIntensity',
    beatnotesintensity = 'beatIntensity',
    beaty = 'beatY',
    beatykick = 'beatYKick',
    beatsus = 'beatSusIntensity',
    beatsusintensity = 'beatSusIntensity',
    beatsustainintensity = 'beatSusIntensity',
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

local function getRuntimeModDefaultValue(modName)
    modName = normalizeModName(modName)

    if modName == 'scrollMode' then
        return downscroll and 0 or 1
    end
    return getModDefaultValue(modName)
end

local function modValueDiffers(value, defaultVal)
    if type(value) == 'number' and type(defaultVal) == 'number' then
        return math.abs(value - defaultVal) > 0.000001
    end
    return value ~= defaultVal
end

function _milyMCHasActiveNoteMath()
    for modName, values in pairs(mods) do
        local defaultVal = getRuntimeModDefaultValue(modName)

        if type(values) == 'table' then
            for _, value in pairs(values) do
                if modValueDiffers(value, defaultVal) then
                    return true
                end
            end
        elseif modValueDiffers(values, defaultVal) then
            return true
        end
    end

    return false
end

local function getLaneModValue(values, strumID, isPlayer, defaultVal)
    if type(values) ~= 'table' then
        return values
    end

    if values[strumID] ~= nil then
        return values[strumID]
    end

    local side = isPlayer and BF_Strum or DAD_Strum
    if values[side] ~= nil then
        return values[side]
    end
    if values[Strum_Gen] ~= nil then
        return values[Strum_Gen]
    end
    return defaultVal
end

local function laneHasActiveNoteMath(strumID)
    local isPlayer = strumID > 3

    for modName, values in pairs(mods) do
        local defaultVal = getRuntimeModDefaultValue(modName)
        if modValueDiffers(getLaneModValue(values, strumID, isPlayer, defaultVal), defaultVal) then
            return true
        end
    end

    return false
end

function _milyMCGetActiveLaneMask()
    local mask = {any = false}

    for i = 0, 7 do
        local active = laneHasActiveNoteMath(i)
        mask[i] = active
        if active then
            mask.any = true
        end
    end

    return mask
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

local function isTargetList(target)
    return type(normalizeTarget(target)) == "table"
end

local function getTargetKey(target)
    target = normalizeTarget(target or Strum_Gen)

    if type(target) ~= "table" then
        return tostring(target)
    end

    local lanes = {}
    eachTargetLane(target, function(i)
        table.insert(lanes, tostring(i))
    end)
    return "lanes[" .. table.concat(lanes, ",") .. "]"
end

local function targetsOverlap(a, b)
    a = normalizeTarget(a or Strum_Gen)
    b = normalizeTarget(b or Strum_Gen)

    if getTargetKey(a) == getTargetKey(b) then
        return true
    end

    local lanes = {}
    eachTargetLane(a, function(i)
        lanes[i] = true
    end)

    local overlaps = false
    eachTargetLane(b, function(i)
        if lanes[i] then
            overlaps = true
        end
    end)
    return overlaps
end

local function getTargetCurrentMod(modName, target)
    modName = normalizeModName(modName)
    target = normalizeTarget(target or Strum_Gen)
    initMod(modName)

    if type(target) == "table" then
        local firstLane = nil
        eachTargetLane(target, function(i)
            if firstLane == nil then firstLane = i end
        end)
        if firstLane ~= nil then
            return getModDef(modName, firstLane > 3, getModDefaultValue(modName), firstLane)
        end
        return getModDefaultValue(modName)
    end

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

    if type(target) == "table" then
        eachTargetLane(target, function(i)
            applyModValue(modName, value, i)
        end)
        return
    end

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
