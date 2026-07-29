local tobool = {TRUE = true, FALSE = false} -- deveria ter um "tobool" ou "toboolean" em lua viu -Shiho

function onEvent(event, value1, value2, value3)
    if event == 'Call Script' then
        local argsRaw = stringSplit(value3, '_ ')
        local args = {}

        for i = 1, #argsRaw do
            args[i] = convertThing(argsRaw[i])
        end

        if value2 == 'General' then
            callOnScripts(value1, args)
        elseif value2 == 'LuaScript' then
            callOnLuas(value1, args)
        else
            callOnHScript(value1, args)
        end
    end
end

function convertThing(thing)
    if tonumber(thing) ~= nil then
        return tonumber(thing)
    elseif thing == 'true' or thing == 'false' then
        return tobool[string.upper(thing)]
    elseif stringStartsWith(thing, "'") and stringEndsWith(thing, "'") or stringStartsWith(thing, '"') and stringEndsWith(thing, '"') then
        return string.sub(thing, 2, -2)
    else
        return thing
    end
end