--[[ 
,---.    ,---..-./`)   .---.       ____     __  _ _    .-'''-.         ,---.    ,---.    ,-----.      ______         _______   .---.  .---.    ____    .-------. ,---------.
|    \  /    |\ .-.')  | ,_|       \   \   /  /( ' )  / _     \        |    \  /    |  .'  .-,  '.  |    _ `''.    /   __  \  |   |  |_ _|  .'  __ `. |  _ _   \\          \
|  ,  \/  ,  |/ `-' \,-./  )        \  _. /  '(_{;}_)(`' )/`--'        |  ,  \/  ,  | / ,-.|  \ _ \ | _ | ) _  \  | ,_/  \__) |   |  ( ' ) /   '  \  \| ( ' )  | `--.  ,---'
|  |\_   /|  | `-'`"`\  '_ '`)        _( )_ .'  (_,_)(_ o _).          |  |\_   /|  |;  \  '_ /  | :|( ''_'  ) |,-./  )       |   '-(_{;}_)|___|  /  ||(_ o _) /    |   \
|  _( )_/ |  | .---.  > (_)  )   ___(_ o _)'         (_,_). '.         |  _( )_/ |  ||  _`,/ \ _/  || . (_) `. |\  '_ '`)     |      (_,_)    _.-`   || (_,_).' __  :_ _:
| (_ o _) |  | |   | (  .  .-'  |   |(_,_)'         .---.  \  :        | (_ o _) |  |: (  '\_/ \   ;|(_    ._) ' > (_)  )  __ | _ _--.   | .'   _    ||  |\ \  |  | (_I_)
|  (_,_)  |  | |   |  `-'`-'|___|   `-'  /           \    `-'  |        |  (_,_)  |  | \ `"/  \  ) / |  (_.\.' / (  .  .-'_/  )|( ' ) |   | |  _( )_  ||  | \ `'   /(_(=)_)
|  |      |  | |   |   |        \\      /             \       /        |  |      |  |  '. \_/``".'  |       .'   `-'`-'     / (_{;}_)|   | \ (_ o _) /|  |  \    /  (_I_)
'--'      '--' '---'   `--------` `-..-'               `-...-'         '--'      '--'    '-----'    '-----'`       `._____.'  '(_,_) '---'  '.(_,_).' ''-'   `'-'   '---'
--]]

-- =========================================================================
-- You're free to put all your stuff down here! ^^
-- =========================================================================

DAD_Strum = "dad"
BF_Strum = "bf"
Strum_Gen = "gen"
dad_Strum = DAD_Strum
bf_Strum = BF_Strum
strum_Gen = Strum_Gen
strum_gen = Strum_Gen

local mods = {}
local modTweens = {}
local defaultStrums = {}
local toggleStates = {}

local noteMods = {}
local noteTweens = {}
local customModifiers = {}
local customModifierOrder = {}
local scheduledEvents = {}

-- local MS_X = {90, 205, 315, 425, 730, 845, 955, 1065} -- talvez eu tenha esquecido pra que isso serve


local VP_X = 1280 / 2
local VP_Y = 720 / 2
local PERSPECTIVE_FL = 700
local UPSCROLL_Y = 50
local DOWNSCROLL_Y = 580
local depthSortDirty = false
local callExternalModchart = function() end

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

function onCreate()
    if awesomeLuaCreate then awesomeLuaCreate() end
    if modChartCreate then modChartCreate() end
    callExternalModchart('modChartCreate')
end

function onCreatePost()
    refreshViewport()
    for i = 0, 7 do
        defaultStrums[i] = {
            x = getPropertyFromGroup('strumLineNotes', i, 'x'),
            y = getPropertyFromGroup('strumLineNotes', i, 'y'),
            angle = getPropertyFromGroup('strumLineNotes', i, 'angle'),
            scaleX = getPropertyFromGroup('strumLineNotes', i, 'scale.x'),
            scaleY = getPropertyFromGroup('strumLineNotes', i, 'scale.y'),
            z = 0
        }
    end
    refreshScrollAnchors()
    if modChartCreatePost then modChartCreatePost() end
    callExternalModchart('modChartCreatePost')
end

