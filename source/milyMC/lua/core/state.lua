milyMC = milyMC or {}

local DAD_STRUM = 'opp'
local BF_STRUM = 'ply'
local ALL_STRUMS = 'all'

local mods = {}
local modifierDefaults = {
    beatIntensity = 1,
    beatSusIntensity = 1
}
local modTweens = {}
local scheduledEvents = {}
local tagBindings = {}
local actionOwners = {}
local tagCounter = 0

local strumValues = {}
local defaultStrums = {}

local customModifiers = {}
local customModifierOrder = {}

local VP_X = 1280 / 2
local VP_Y = 720 / 2
local PERSPECTIVE_FL = 700
local UPSCROLL_Y = 50
local DOWNSCROLL_Y = 580
local depthSortDirty = false

local function refreshViewport()
    VP_X = (screenWidth or 1280) / 2
    VP_Y = (screenHeight or 720) / 2
end

local function refreshScrollAnchors()
    refreshViewport()
    local strumHeight = getPropertyFromGroup('strumLineNotes', 0, 'height') or 112
    local defaultY = defaultStrums[0] and defaultStrums[0].y
    local fallbackTopY = 50
    local fallbackBottomY = (screenHeight or 720) - strumHeight - 50

    if defaultY ~= nil and defaultY > ((screenHeight or 720) * 0.5) then
        DOWNSCROLL_Y = defaultY
        UPSCROLL_Y = fallbackTopY
    else
        UPSCROLL_Y = defaultY or fallbackTopY
        DOWNSCROLL_Y = fallbackBottomY
    end
end

local function callMilyMCScripts(luaName, hscriptName, args)
    args = args or {}
    if callOnLuas then callOnLuas('milyMC.' .. luaName, args, true, true) end
    if callOnHScript then callOnHScript(hscriptName, args, true, true) end
end

function onCreate()
    luaDebugMode = false
    callMilyMCScripts('loadPre', 'onMCloadPre')
    callMilyMCScripts('load', 'onMCload')
end

function onCreatePost()
    refreshViewport()
    for i = 0, 7 do
        defaultStrums[i] = {
            x = getPropertyFromGroup('strumLineNotes', i, 'x'),
            y = getPropertyFromGroup('strumLineNotes', i, 'y'),
            angle = getPropertyFromGroup('strumLineNotes', i, 'angle'),
            scaleX = getPropertyFromGroup('strumLineNotes', i, 'scale.x'),
            scaleY = getPropertyFromGroup('strumLineNotes', i, 'scale.y')
        }
        strumValues[i] = strumValues[i] or {
            x = 0, y = 0, z = 0, alpha = 1, angle = 0, scale = 1
        }
    end
    refreshScrollAnchors()
    callMilyMCScripts('loadPost', 'onMCloadPost')
end
