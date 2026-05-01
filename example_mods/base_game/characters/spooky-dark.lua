--[[
    This is the script for the characters when they're in the 'spookyErect' stage.
    Just set the character's name, and this script will handle the rest on its own,
    so you can use it on other characters.

    WARNING!: This script is meant to be used on the dark variant of the character's sprite.
    If you don't have them, just use your normal character, 
    since the 'spookyErect' stage has a way to deal with those.
    Also, make sure that the normal and dark variants of your character have the same frames and offsets in their animation,
    or else the script won't be able to sync them up.
]]
local characterName = 'spooky-dark' -- Set your character's name here
local characterPos = {}
local isPlayer = false
local propertyTracker = {
    {'x', nil},
    {'y', nil},
    {'color', nil},
    {'scrollFactor.x', nil},
    {'scrollFactor.y', nil},
    {'angle', nil},
    {'antialiasing', nil},
    {'visible', nil}
}
function onCreatePost()
    characterType = getCharacterType(characterName)
    characterPos = {x = getProperty(characterType..'.x'), y = getProperty(characterType..'.y')}
    if characterType == 'boyfriend' then
        isPlayer = true
    end
    createInstance(characterType..'Light', 'objects.Character', {characterPos.x, characterPos.y, characterName:gsub('-dark', ''), isPlayer})
    setObjectOrder(characterType..'Light', getObjectOrder(characterType..'Group'))
    addInstance(characterType..'Light')
end

function onUpdatePost(elapsed)
    for property = 1, #propertyTracker do
        if propertyTracker[property][2] ~= getProperty(characterType..'.'..propertyTracker[property][1]) then
            propertyTracker[property][2] = getProperty(characterType..'.'..propertyTracker[property][1])
            setProperty(characterType..'Light.'..propertyTracker[property][1], propertyTracker[property][2])
        end
    end
    if getObjectOrder(characterType..'Light') ~= getObjectOrder(characterType..'Group') - 1 then
        setObjectOrder(characterType..'Light', getObjectOrder(characterType..'Group'))
    end
    if getProperty(characterType..'.alpha') < 1 then
        setProperty(characterType..'Light.alpha', 1)
    else
        setProperty(characterType..'Light.alpha', 0)
    end
    playAnim(characterType..'Light', getProperty(characterType..'.animation.name'), true, getProperty(characterType..'.animation.curAnim.reversed'), getProperty(characterType..'.animation.curAnim.curFrame'))
end

function getCharacterType(characterName)
    if boyfriendName == characterName then
        return 'boyfriend'
    elseif dadName == characterName then
        return 'dad'
    elseif gfName == characterName then
        return 'gf'
    end
end