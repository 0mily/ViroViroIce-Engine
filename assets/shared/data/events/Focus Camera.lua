local function splitValues(value)
    if value == nil then return {} end

    local values = stringSplit(value, ',')
    for i = 1, #values do
        values[i] = stringTrim(values[i])
    end

    return values
end

local function essasBct(evilease)
    evilease = string.lower(stringTrim(evilease or 'classic'))

    if evilease == 'og' then return 'classic' end
    if evilease == 'inst' then return 'instant' end

    return evilease
end

function onEvent(name, v1, v2)
    if name ~= 'Focus Camera' then return end

    local focus = splitValues(v1)
    local movement = splitValues(v2)

    local target = string.lower(stringTrim(focus[1] or 'dad'))
    local x = tonumber(focus[2]) or 0
    local y = tonumber(focus[3]) or 0
    local evilease = essasBct(movement[1] or focus[4])
    local steps = tonumber(movement[2] or focus[5]) or 0

    changeFocus(target, x, y, evilease, steps)
end
