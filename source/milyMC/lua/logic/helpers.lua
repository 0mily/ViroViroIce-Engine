local function lerp(a, b, ratio) -- larp
    return a + (b - a) * ratio
end

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local MILYMC_NOTE_INDEX = 1
local MILYMC_NOTE_DATA = 2
local MILYMC_NOTE_MUST_PRESS = 3
local MILYMC_NOTE_IS_SUSTAIN = 4
local MILYMC_NOTE_OFFSET_X = 5
local MILYMC_NOTE_OFFSET_Y = 6
local MILYMC_NOTE_DISTANCE = 7
local MILYMC_NOTE_SPEED = 8
local MILYMC_NOTE_SUSTAIN_PIXELS = 9
local MILYMC_NOTE_MULT_ALPHA = 10
local MILYMC_NOTE_IS_SUSTAIN_END = 11

local function normalizeModName(name)
    return name == nil and '' or tostring(name)
end

local function getModDefaultValue(name)
    name = normalizeModName(name)
    if name == 'scrollMode' then return downscroll and 0 or 1 end
    if modifierDefaults[name] ~= nil then return modifierDefaults[name] end
    if name:find('Alpha') or name:find('Scale') then return 1 end
    return 0
end

local function normalizeTarget(target)
    if target == nil then return ALL_STRUMS end

    if type(target) == 'table' then return target end
    if type(target) == 'number' then
        return clamp(math.floor(target), 0, 7)
    end
    if type(target) ~= 'string' then return ALL_STRUMS end

    local name = target:lower()
    if name == 'opp' or name == 'opponent' or name == 'dad' or name == 'p2' then
        return DAD_STRUM
    end
    if name == 'ply' or name == 'player' or name == 'bf' or name == 'p1' then
        return BF_STRUM
    end
    if name == 'all' or name == 'both' then return ALL_STRUMS end

    local lane = tonumber(name)
    if lane ~= nil then return clamp(math.floor(lane), 0, 7) end
    error('Invalid MilyMC target "' .. tostring(target) .. '".')
end

local function eachTargetLane(target, callback)
    target = normalizeTarget(target)
    if type(target) == 'table' then
        local visited = {}
        for _, item in ipairs(target) do
            eachTargetLane(item, function(lane)
                if not visited[lane] then
                    visited[lane] = true
                    callback(lane)
                end
            end)
        end
        return
    end

    local first, last = 0, 7
    if target == DAD_STRUM then
        first, last = 0, 3
    elseif target == BF_STRUM then
        first, last = 4, 7
    elseif type(target) == 'number' then
        first, last = target, target
    end
    for lane = first, last do callback(lane) end
end

local function targetLanes(target)
    local lanes = {}
    eachTargetLane(target, function(lane) lanes[#lanes + 1] = lane end)
    table.sort(lanes)
    return lanes
end

local function getTargetKey(target)
    return table.concat(targetLanes(target), ',')
end

local function targetsOverlap(first, second)
    local lanes = {}
    eachTargetLane(first, function(lane) lanes[lane] = true end)
    local overlaps = false
    eachTargetLane(second, function(lane)
        if lanes[lane] then overlaps = true end
    end)
    return overlaps
end

local function initMod(name)
    name = normalizeModName(name)
    if mods[name] == nil then mods[name] = {} end
    return name
end

local function applyModValue(name, value, target)
    name = initMod(name)
    value = tonumber(value) or getModDefaultValue(name)
    eachTargetLane(target, function(lane) mods[name][lane] = value end)
end

local function getMod(name, isPlayer, strumID)
    name = normalizeModName(name)
    local lane = strumID
    if lane == nil then lane = isPlayer and 4 or 0 end
    local values = mods[name]
    if values ~= nil and values[lane] ~= nil then return values[lane] end
    return getModDefaultValue(name)
end

local function getModDef(name, isPlayer, defaultValue, strumID)
    local values = mods[normalizeModName(name)]
    local lane = strumID
    if lane == nil then lane = isPlayer and 4 or 0 end
    if values ~= nil and values[lane] ~= nil then return values[lane] end
    return defaultValue
end

local function getTargetCurrentMod(name, target)
    local lanes = targetLanes(target)
    if #lanes < 1 then return getModDefaultValue(name) end
    return getMod(name, lanes[1] > 3, lanes[1])
end

local function valueDiffers(value, defaultValue)
    return math.abs((tonumber(value) or 0) - (tonumber(defaultValue) or 0)) > 0.000001
end

local function laneHasActiveMath(lane)
    for name, values in pairs(mods) do
        if values[lane] ~= nil and valueDiffers(values[lane], getModDefaultValue(name)) then
            return true
        end
    end

    local values = strumValues[lane]
    if values ~= nil then
        if valueDiffers(values.x, 0) or valueDiffers(values.y, 0) or valueDiffers(values.z, 0)
            or valueDiffers(values.angle, 0) or valueDiffers(values.alpha, 1) or valueDiffers(values.scale, 1) then
            return true
        end
    end
    return false
end

function _milyMCGetActiveLaneMask()
    local mask = {any = false}
    for lane = 0, 7 do
        mask[lane] = laneHasActiveMath(lane)
        if mask[lane] then mask.any = true end
    end
    return mask
end
