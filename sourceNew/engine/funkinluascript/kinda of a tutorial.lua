-- ==================================================================
-- conf shit
-- ==================================================================

function funkin.config(api)
    api.psych = false
end
-- tells the engine if the api used will be the Psych one or nah

-- ==================================================================
-- basic functions
-- ==================================================================

function funkin.load()
    -- load the stuff you want
end

function funkin.ready()
    -- quite similar to onCreatePost
end

function funkin.update(dt)
    -- updates...../?
end

function funkin.draw(dt)
    -- render every fucking frame
end

function funkin.build()
    -- builds the things you want to add. Basically working like some sorta of "addLuaObject"
end

function funkin.beatHit(beat)
    -- just beatHit
end

function funkin.stepHit(step)
    -- just stephit
end

function funkin.sectionHit(section)
    -- just sectionHit
end

function funkin.songStart()
    -- at song start.,...; yea
end

function funkin.noteHit(id, type, sus, strum, pre?, char)
    --[[ well, the same thing as goodNoteHit and OpponentNoteHit but now generic! Using "char"
    as the name of the charName, or "opp" and "ply" to generic dad and bf.]]
end

function funkin.noteMiss(id, type, sus, strum, pre?, char)
    -- yeah
end

function funkin.noteMissPress(id, type, sus, strum, pre?, char)
    -- yeah²
end

function funkin.event(name, early?, tag1, tag2, tag3 ..)
    -- well, events!!!
end

function funkin.endSong()
    -- end sg
end

function funkin.destroy()
    -- destroy
end

-- ==================================================================
-- substates
-- ==================================================================

function funkin.pause()
    -- when pauses
end

function funkin.resume()
    -- when resumes
end

function funkin.gameOver()
    -- when dies
end

function funkin.retry()
    -- when retries
end



--[[
=====================================================================
-- graphics
-- ==================================================================
    graphics are good to know what is:
    
    object fabric;
    
    object methods;
    
    direct properties
]]

-- ============
-- fabrics 
-- ============

local bg = funkin.graphics.newSprite('../week1/images/stageback')

local texty = funkin.graphics.newText('Hello World!')
local groupp = funkin.graphics.group()
local anim = funkin.graphics.animatedSprite('../week6/images/weeb/bgFreaks')

-- ============
-- sprites proxies
-- ============

sprite:x()
sprite:y()
sprite:position({})
sprite:width()
sprite:height()
sprite:alpha()
sprite:angle()
sprite:visible()
sprite:scroll({})
sprite:scale({})
sprite:origin({})
sprite:antialias() -- sprite:aa()
sprite:flipX()
sprite:flipY()
sprite:camera()
sprite:blend() -- (https://api.haxeflixel.com/flash/display/BlendMode.html)
sprite:color()
sprite:shader()
sprite:center()
sprite:before()
sprite:after()
sprite:add()
sprite:remove()
sprite:destroy()
sprite:load()
sprite:graphicSize() -- sprite:gphSize()
sprite:updateHitbox() -- sprite:hitbox()

-- ============
-- texts
-- ============

local txty = funkin.graphics.newText('Hello World!')
txty:position({100, 50})
txty:size(32)
txty:color({'FFFFFF', '000000'})
txty:border(2)
txty:font('vcr.ttf')
txty:italic(true)
txty:alignment('center') -- left; right; center; justify

scoretxt:setString('Score: 0 | Misses: 0 | Rating: ?')

-- ============
-- animated sprites
-- ============

local anim = funkin.graphics.animatedSprite('../week6/images/weeb/bgFreaks')
anim:addAnim('idle', 'BG girls group', 24, true)
anim:addAnim('idle-alt', 'BG fangirls dissuaded', 24, true)
anim:play('idle')



-- ==================================================================
-- Stage example
-- ==================================================================

local back
local floor
local front

function funkin.load()
    back = funkin.graphics.newSprite('back')
    back:position({-500, -300})
    back:scroll({0.86, 0.86})

    floor = funkin.graphics.newSprite('floor')
    floor:position({-500, -620})
    floor:scroll({1, 1})

    front = funkin.graphics.animatedSprite('front')
    front:addAnim('idle', 'idle animShit0', 24, false)
    front:position({-700, -400})
    front:scroll({1.3, 1.3})
    --front:front()
end

function funkin.build()
    funkin.add({back, floor, front})
    funkin.zIndex({'back', 1})
    funkin.zIndex({'floor', 2})
    funkin.zIndex({'front', 4})

    funkin.zIndex({'bfGroup', 'dadGroup', 'gfGroup', 3})
end

function funkin.beatHit()
    front:play('idle')
end