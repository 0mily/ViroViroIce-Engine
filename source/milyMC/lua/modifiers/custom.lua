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
