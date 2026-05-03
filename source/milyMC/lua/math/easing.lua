-- https://github.com/luapower/easing/tree/master eu te amo

-- mesmo colocando no source, eu me recuso a usar o do haxe por pura e honesta PREGUIÇA
local osEAD = {
    linear = function(t) return t end,
    quadIn = function(t) return t * t end,
    quadOut = function(t) return t * (2 - t) end,
    quadInOut = function(t) return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t end,
    cubeIn = function(t) return t * t * t end,
    cubeOut = function(t) local v = t - 1 return v * v * v + 1 end,
    sineIn = function(t) return 1 - math.cos(t * (math.pi / 2)) end,
    sineOut = function(t) return math.sin(t * (math.pi / 2)) end,
    sineInOut = function(t) return 0.5 * (1 - math.cos(math.pi * t)) end,
    circIn = function(t) return 1 - math.sqrt(1 - t * t) end,
    circOut = function(t) return math.sqrt(1 - (t - 1) ^ 2) end,
    backIn = function(t) local s = 1.70158 return t * t * ((s + 1) * t - s) end,
    backOut = function(t) local s = 1.70158 local v = t - 1 return v * v * ((s + 1) * v + s) + 1 end,
    expoIn = function(t) return t == 0 and 0 or 2 ^ (10 * (t - 1)) end,
    expoOut = function(t) return t == 1 and 1 or 1 - (2 ^ (-10 * t)) end
}

function getEaseValue(ratio, ease)
    local func = osEAD[ease] or osEAD.linear
    return func(ratio)
end

