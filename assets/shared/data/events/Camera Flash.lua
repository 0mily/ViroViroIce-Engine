local function clean(value, fallback)
    value = stringTrim(value or '')
    if value == '' then return fallback end
    return value
end

function onEvent(name, value1, value2, strumTime, value3)
    if name ~= 'Camera Flash' then return end

    local camera = clean(value1, 'game')
    local duration = tonumber(value2) or 1
    local color = clean(value3, 'FFFFFF')

    if tonumber(value1) ~= nil then
        duration = tonumber(value1) or duration
        camera = clean(value2, 'game')
    end

    cameraFlash(camera, color, duration, true)
end
