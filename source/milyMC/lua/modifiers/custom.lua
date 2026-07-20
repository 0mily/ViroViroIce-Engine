function defineMC(name, callbacks)
    name = normalizeModName(name)
    if name == '' then error('defineMC requires a modifier name.') end
    if type(callbacks) == 'function' then callbacks = {apply = callbacks} end
    if type(callbacks) ~= 'table' then error('defineMC callbacks must be a function or table.') end

    if callbacks.default ~= nil then
        modifierDefaults[name] = tonumber(callbacks.default) or 0
    end
    customModifiers[name] = callbacks

    local registered = false
    for _, current in ipairs(customModifierOrder) do
        if current == name then registered = true break end
    end
    if not registered then customModifierOrder[#customModifierOrder + 1] = name end
    table.sort(customModifierOrder, function(first, second)
        local a = tonumber(customModifiers[first].order) or 0
        local b = tonumber(customModifiers[second].order) or 0
        if a == b then return first < second end
        return a < b
    end)

    initMod(name)
    if type(callbacks.load) == 'function' then callbacks.load(name) end
    return name
end

function removeCustomMC(name)
    name = normalizeModName(name)
    local callbacks = customModifiers[name]
    if callbacks == nil then return false end
    if type(callbacks.destroy) == 'function' then pcall(callbacks.destroy, name) end
    customModifiers[name] = nil
    mods[name] = nil
    for index = #customModifierOrder, 1, -1 do
        if customModifierOrder[index] == name then table.remove(customModifierOrder, index) end
    end
    return true
end

local function mergeCustomResult(ctx, result)
    if type(result) ~= 'table' then return end
    for key, value in pairs(result) do ctx[key] = value end
end

local function applyCustomModifiers(ctx)
    for _, name in ipairs(customModifierOrder) do
        local callbacks = customModifiers[name]
        local value = getMod(name, ctx.isPlayer, ctx.strumID)
        local defaultValue = getModDefaultValue(name)
        if callbacks ~= nil and valueDiffers(value, defaultValue) then
            local enabled = true
            if type(callbacks.enabled) == 'function' then
                local ok, result = pcall(callbacks.enabled, ctx, value)
                enabled = ok and result ~= false
            end

            if enabled then
                ctx.modName = name
                ctx.value = value
                local callback = callbacks.apply
                if ctx.strumE then
                    callback = callbacks.strum or callbacks.receptor or callback
                else
                    callback = callbacks.note or callback
                    if ctx.isSustainNote then callback = callbacks.sustain or callback end
                end

                if type(callback) == 'function' then
                    local ok, result = pcall(callback, ctx, value)
                    if ok then
                        mergeCustomResult(ctx, result)
                    elseif debugPrint then
                        debugPrint('Custom modifier "' .. name .. '" failed: ' .. tostring(result))
                    end
                end
            end
        end
    end
end

function updateCustomModifiers(elapsed)
    for _, name in ipairs(customModifierOrder) do
        local callbacks = customModifiers[name]
        if callbacks ~= nil and type(callbacks.update) == 'function' then
            local ok, err = pcall(callbacks.update, elapsed, mods[name])
            if not ok and debugPrint then debugPrint('Custom modifier "' .. name .. '" update failed: ' .. tostring(err)) end
        end
    end
end

function destroyCustomModifiers()
    for _, name in ipairs(customModifierOrder) do
        local callbacks = customModifiers[name]
        if callbacks ~= nil and type(callbacks.destroy) == 'function' then pcall(callbacks.destroy, name) end
    end
end
