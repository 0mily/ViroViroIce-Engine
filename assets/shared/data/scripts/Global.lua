
--[[

 __      ____      _______ ______            
 \ \    / /\ \    / /_   _|  ____|           
  \ \  / /  \ \  / /  | | | |__              
   \ \/ /    \ \/ /   | | |  __|             
    \  /      \  /   _| |_| |____            
     \/___ _   \/ __|_____|______|    _      
    / ____| |    / __ \|  _ \   /\   | |     
   | |  __| |   | |  | | |_) | /  \  | |     
   | | |_ | |   | |  | |  _ < / /\ \ | |     
   | |__| | |___| |__| | |_) / ____ \| |____ 
    \_____|______\____/|____/_/    \_\______|
                                             
    Mily_0                                         



  here you can uhmmmm well, change stuff that happens on the songs, not exactly on the menus or anything but... you get it.

]]

-- ===================================================
-- CONFIGURATION (CHANGE THIS TO YOUR LIKING!!)
-- ===================================================

local ScoreTxtOverIcons = true
-- Shiho finge q tem mais coisa pfv





--btw, if you don't know what you're doing, don't change anything below this. Only use the configuration up there.

-- ===================================================
-- CALLBACKS OR SMTH
-- ===================================================


function onCreatePost()
    pixelRender_createPost()
    miku_createPost()
        hud_createPost()
end

function onUpdate()
    miku_onUpdate()
        hud_onUpdate()
end

function onUpdatePost()
    hud_UpdatePost() -- acabei nem usando lol
end

function onGoodNoteHit(id, direction, noteType, isSustainNote)
    hud_BFNoteHit() -- supostamente para usar num bump de score na hud, porém eu sou muito ruim em tudo shiho me ajuda e faz isso por mim, acho q quebrei meu próprio codigo pq ironicamente foi mais facil fazer em haxe essa prr
end

function onSongStart()
        hud_SongStart()
end

-- ===================================================
-- WEEK 6 EFFECT (YOU CAN ADD YOUR OWN SONGS HERE!!)
-- ===================================================

function pixelRender_createPost()
    if pixelRender and stageUI == 'pixel' then
        setProperty("camGame.pixelPerfectRender", true)
    end
end

-- ===================================================
-- MIKU EASTER EGG
-- ===================================================

local mikutrue = false
local oldAssFreak = nil
local penis = nil
local mikudsidea = false

function miku_createPost()
    mikudsidea = allowMiku and stageUI == 'pixel'

    addCharacterToList('bf-miku', 'bf')
    makeLuaSprite('mikuon', 'game/playablemiku', 840, 0)
    setObjectCamera('mikuon', 'hud')
    addLuaSprite('mikuon', true)

    makeLuaSprite('mimimi','game/playablemiku BG', 0, 0)
	setGraphicSize('mimimi',1280,720)
	setObjectCamera('mimimi','camHud')
	updateHitbox('mimimi')
	addLuaSprite('mimimi', false);
	setProperty('mimimi.alpha', 0)

end

function miku_onUpdate(elapsed)

    if mikudsidea then
        return
    end

    if getPropertyFromClass('flixel.FlxG', 'keys.justPressed.M') and stageUI ~= 'pixel' then
        
        if not mikutrue then
            oldAssFreak = getProperty('boyfriend.curCharacter')
            penis = getPropertyFromClass('openfl.Lib', 'application.window.title')
            triggerEvent('Change Character', 'bf', 'bf-miku')
            triggerEvent('Hey!', '', '')
            triggerEvent('Add Camera Zoom', '0.05', '0.1')
            setPropertyFromClass('openfl.Lib', 'application.window.title', 'Friday Night Funkin\': MikuMikuIce')
            doTweenAngle('jequitiousla', 'iconP1', 360, 1, 'elasticOut') -- 🔥
            mikutrue = true
            mikuLegal()
            playMikuRandom()
            roxo()
        else
            triggerEvent('Change Character', 'bf', oldAssFreak or 'bf')
            setPropertyFromClass('openfl.Lib', 'application.window.title', penis or 'Friday Night Funkin\': ViroViroIce')
            doTweenAngle('thumbs1up', 'iconP1', 0, 1, 'elasticOut') -- 🔥
            playSound('ouch', 1.3)
            mikutrue = false
        end
    end

end

local mikus = 0

function mikuLegal()
    mikus = mikus + 1
    local tag = 'oi' .. mikus

    makeLuaSprite(tag, 'game/playablemiku', 840, 0)
    setObjectCamera(tag, 'hud')
    addLuaSprite(tag, true)

    setProperty(tag .. '.alpha', 1)
    
    doTweenX(tag .. 'Tween', tag, -40, 0.7, 'circOut')
    doTweenAlpha(tag .. 'Alpha', tag, 0, 1.2, 'quadIn')
end

function roxo()
    setProperty('mimimi.alpha', 1)
    doTweenAlpha('mimimiAlpha', 'mimimi', 0, 1.2, 'quadIn')
end

function onTweenCompleted(tag)
    if string.find(tag, 'oi') and string.find(tag, 'Alpha') then
        local spr = string.gsub(tag, 'Alpha', '')
        removeLuaSprite(spr, true)
    end
end

function playMikuRandom()
    local random = getRandomInt(1, 5)
    playSound('miku_' .. random, 1)
end


-- ===================================================
-- HUD THING
-- ===================================================

