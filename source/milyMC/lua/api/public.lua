milyMC = milyMC or {}

local customCallbacks = {}

local function callbackFlags(callbacks)
    local flags = 0
    if type(callbacks.apply) == 'function' then flags = flags + 1 end
    if type(callbacks.note) == 'function' then flags = flags + 2 end
    if type(callbacks.sustain) == 'function' then flags = flags + 4 end
    if type(callbacks.strum) == 'function' or type(callbacks.receptor) == 'function' then flags = flags + 8 end
    if type(callbacks.enabled) == 'function' then flags = flags + 16 end
    if type(callbacks.update) == 'function' then flags = flags + 32 end
    return flags
end

local function customCallback(callbacks, phase)
    if phase == 'strum' then
        return callbacks.strum or callbacks.receptor or callbacks.apply
    elseif phase == 'sustain' then
        return callbacks.sustain or callbacks.note or callbacks.apply
    elseif phase == 'note' then
        return callbacks.note or callbacks.apply
    end
    return callbacks[phase]
end

function _milyMCInvokeCustom(name, phase, first, second)
    local callbacks = customCallbacks[tostring(name or '')]
    if callbacks == nil then
        if phase == 'enabled' then return true end
        return first
    end

    local callback = customCallback(callbacks, phase)
    if type(callback) ~= 'function' then
        if phase == 'enabled' then return true end
        return first
    end

    local result = callback(first, second)
    if phase == 'note' or phase == 'sustain' or phase == 'strum' then
        if type(first) ~= 'table' then first = {} end
        if type(result) == 'table' and result ~= first then
            for key, value in pairs(result) do first[key] = value end
        end
        return first
    end
    return result
end

function defineMC(name, callbacks)
    name = tostring(name or ''):match('^%s*(.-)%s*$')
    if name == '' then error('defineMC requires a modifier name.') end
    if type(callbacks) == 'function' then callbacks = {apply = callbacks} end
    if type(callbacks) ~= 'table' then error('defineMC callbacks must be a function or table.') end

    customCallbacks[name] = callbacks
    _milyMCRegisterCustom(name, tonumber(callbacks.default) or 0, tonumber(callbacks.order) or 0, callbackFlags(callbacks))
    if type(callbacks.load) == 'function' then callbacks.load(name) end
    return name
end

function removeCustomMC(name)
    name = tostring(name or ''):match('^%s*(.-)%s*$')
    local callbacks = customCallbacks[name]
    local destroyed = false
    if callbacks ~= nil and type(callbacks.destroy) == 'function' then
        pcall(callbacks.destroy, name)
        destroyed = true
    end
    customCallbacks[name] = nil
    return _milyMCRemoveCustom(name, destroyed)
end
