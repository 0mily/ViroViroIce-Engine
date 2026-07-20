local easing = {
    linear = function(t) return t end,
    quadin = function(t) return t * t end,
    quadout = function(t) return t * (2 - t) end,
    quadinout = function(t) return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t end,
    cubein = function(t) return t * t * t end,
    cubeout = function(t) local v = t - 1 return v * v * v + 1 end,
    cubeinout = function(t)
        if t < 0.5 then return 4 * t * t * t end
        local v = (2 * t) - 2
        return 0.5 * v * v * v + 1
    end,
    sinein = function(t) return 1 - math.cos(t * math.pi * 0.5) end,
    sineout = function(t) return math.sin(t * math.pi * 0.5) end,
    sineinout = function(t) return 0.5 * (1 - math.cos(math.pi * t)) end,
    circin = function(t) return 1 - math.sqrt(1 - t * t) end,
    circout = function(t) return math.sqrt(1 - (t - 1) ^ 2) end,
    circinout = function(t)
        if t < 0.5 then return 0.5 * (1 - math.sqrt(1 - 4 * t * t)) end
        local v = (2 * t) - 2
        return 0.5 * (math.sqrt(1 - v * v) + 1)
    end,
    backin = function(t) local s = 1.70158 return t * t * ((s + 1) * t - s) end,
    backout = function(t) local s, v = 1.70158, t - 1 return v * v * ((s + 1) * v + s) + 1 end,
    expoin = function(t) return t == 0 and 0 or 2 ^ (10 * (t - 1)) end,
    expoout = function(t) return t == 1 and 1 or 1 - 2 ^ (-10 * t) end,
    expoinout = function(t)
        if t == 0 or t == 1 then return t end
        if t < 0.5 then return 0.5 * 2 ^ ((20 * t) - 10) end
        return 1 - 0.5 * 2 ^ ((-20 * t) + 10)
    end
}

local easeAliases = { -- vai que
    quad = 'quadout',
    cube = 'cubeout',
    cubic = 'cubeout',
    cubicout = 'cubeout',
    cubicin = 'cubein',
    cubicinout = 'cubeinout',
    sine = 'sineout',
    circ = 'circout',
    back = 'backout',
    expo = 'expoout'
}

local function getEaseValue(ratio, name)
    local key = tostring(name or 'linear'):lower():gsub('[%s_%-]', '')
    key = easeAliases[key] or key
    return (easing[key] or easing.linear)(ratio)
end
