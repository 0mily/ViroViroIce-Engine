local validStrumOptions = {
    x = true,
    y = true,
    z = true,
    alpha = true,
    angle = true,
    scale = true
}

local function normalizeStrumOption(option)
    option = tostring(option or ''):lower()
    if not validStrumOptions[option] then
        error('Invalid strum option "' .. option .. '". Use X, Y, Z, Alpha, Angle or Scale.')
    end
    return option
end

local function getStrumDefault(option)
    return (option == 'alpha' or option == 'scale') and 1 or 0
end

local function ensureStrumValues(lane)
    local values = strumValues[lane]
    if values == nil then
        values = {x = 0, y = 0, z = 0, alpha = 1, angle = 0, scale = 1}
        strumValues[lane] = values
    end
    return values
end

local function applyStrumValue(option, value, target)
    option = normalizeStrumOption(option)
    value = tonumber(value) or getStrumDefault(option)
    eachTargetLane(target, function(lane)
        ensureStrumValues(lane)[option] = value
    end)
end

local function getTargetCurrentStrum(option, target)
    option = normalizeStrumOption(option)
    local lanes = targetLanes(target)
    if #lanes < 1 then return getStrumDefault(option) end
    return ensureStrumValues(lanes[1])[option]
end

local function getStrumValue(lane, option)
    option = normalizeStrumOption(option)
    return ensureStrumValues(lane)[option]
end
