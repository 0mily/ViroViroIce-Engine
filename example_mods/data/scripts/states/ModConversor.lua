--luaDebugMode = true

local curMod = ''
local ignoreMods = false

local folderNames = {
    --'characters', ainda não
    'custom_events',
    'custom_notetypes',
    'data',
    'scripts',
    'songs'
}

local checkThisFolder = { -- não achei jeito melhor de fazer isso gulp
    --false, characters ainda não

    false, -- 1. custom_events
    false, -- 2. custom_notetypes
    false, -- 3. data
    false, -- 4. scripts
    false --  5. songs
}

local files = {{} --[[1. events]], {} --[[2. notetypes]], {} --[[3. data]], {} --[[4. scripts]], {} --[[5. songs]], {} --[[6. songEvents]], {} --[[7. songScripts]]}
local absolutePath = 'assets/shared/'

function onCreate()

    setSoundVolume(_, 0)

    setPropertyFromClass('flixel.FlxG', 'mouse.visible', true)

    makeLuaSprite('bg', 'menuDesat')
    setProperty('bg.color', 0x353639)
    screenCenter('bg')
    addLuaSprite('bg')

    runHaxeCode([[
        import backend.Mods;
        import sys.FileSystem;

        function folderExists(path:String){
            if (FileSystem.exists(path) && FileSystem.isDirectory(path)) return true;
            return false;
        }

        function createFolder(path:String){
            if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
        }

        function deleteFolder(path:String){
            if (FileSystem.exists(path) && FileSystem.isDirectory(path)) FileSystem.deleteDirectory(path);
        }

        function moveStuff(in:String, out:String){
            if (FileSystem.exists(in)) FileSystem.rename(in, out);
        }
        
        function curMod(){
            if (Mods.currentModDirectory != null || Mods.currentModDirectory != '') return Mods.currentModDirectory;
            return '';
        }
    ]])
    curMod = runHaxeFunction('curMod')
    ignoreMods = curMod == ''

    xereca()
    bolas()
end

function onUpdate(elapsed)
    
    if keyboardJustPressed('ESCAPE') then
        switchState('states.MainMenuState')
        soundFadeIn(_, 4, 0, 0.7)
    end

    setProperty('mouseHitbox.x', getMouseX())
    setProperty('mouseHitbox.y', getMouseY())

    if objectsOverlap('mouseHitbox', 'ie') and mouseClicked() then
        playSound('what')
    end
end

function onCheckBoxChecked(tag, check)
    
    if tag == 'ignMods' then
        ignoreMods = check
        if not check then
            absolutePath = 'addons/'..curMod..'/'
            setProperty('mod.alpha', 1)
        else
            absolutePath = 'assets/shared/'
            setProperty('mod.alpha', 0.5)
        end
    end
end

function onButtonPressed(tag)

    if tag == 'convert' then
        convertStuff()
    end
end

function convertStuff()

    checkThisFolder = { -- talvez isso deixe converter vários de uma vez? (não testei)
    --false, characters ainda não

        false, -- 1. custom_events
        false, -- 2. custom_notetypes
        false, -- 3. data
        false, -- 4. scripts
        false --  5. songs
    }

    if not ignoreMods then
        absolutePath = 'addons/'..curMod..'/'
        
        for i = 1, #folderNames do
            if runHaxeFunction('folderExists', {absolutePath..folderNames[i]}) then
                checkThisFolder[i] = true
            end

            if checkThisFolder[i] then
                files[i] = directoryFileList(absolutePath..folderNames[i])
            end
        end

        if checkThisFolder[1] then
            runHaxeFunction('moveStuff', {absolutePath..'custom_events', absolutePath..'data/events'})
        end
        if checkThisFolder[2] then
            runHaxeFunction('moveStuff', {absolutePath..'custom_notetypes', absolutePath..'data/notetypes'})
        end
        if checkThisFolder[3] then
            convertScripts()
            convertEvents()
            convertCharts() -- charts por último pra deletar as pastas da data certinho
        end
        if checkThisFolder[4] then
            runHaxeFunction('moveStuff', {absolutePath..'scripts', absolutePath..'data/scripts'})
        end
        if checkThisFolder[5] then
            convertSongs()
        end
    end
end

function convertSongs()

    for i = 1, #files[5] do
        runHaxeFunction('createFolder', {absolutePath..'songs/'..files[5][i]..'/song'})

        local songs = directoryFileList(absolutePath..'songs/'..files[5][i])
        for j = 1, #songs do
            if stringEndsWith(absolutePath..'songs/'..files[5][i]..'/'..songs[j], '.ogg') then
                runHaxeFunction('moveStuff', {absolutePath..'songs/'..files[5][i]..'/'..songs[j], absolutePath..'songs/'..files[5][i]..'/song/'..songs[j]})
            end
        end
    end
end

function convertScripts()

    for i = 1, #files[3] do
        local data = directoryFileList(absolutePath..'data/'..files[3][i])
        for j = 1, #data do
            if stringEndsWith(absolutePath..'data/'..files[3][i]..'/'..data[j], '.lua') or stringEndsWith(absolutePath..'data/'..files[3][i]..'/'..data[j], '.hx') then
                runHaxeFunction('moveStuff', {absolutePath..'data/'..files[3][i]..'/'..data[j], absolutePath..'songs/'..files[3][i]..'/'..data[j]})
            end
        end
    end
end

function convertEvents()

    for i = 1, #files[3] do
        runHaxeFunction('createFolder', {absolutePath..'songs/'..files[3][i]..'/events'})

        local data = directoryFileList(absolutePath..'data/'..files[3][i])
        for j = 1, #data do
            if stringEndsWith(absolutePath..'data/'..files[3][i]..'/'..data[j], 'events.json') then
                runHaxeFunction('moveStuff', {absolutePath..'data/'..files[3][i]..'/'..data[j], absolutePath..'songs/'..files[3][i]..'/events/'..data[j]})
            end
        end
    end
end

function convertCharts()

    for i = 1, #files[3] do
        runHaxeFunction('createFolder', {absolutePath..'songs/'..files[3][i]..'/chart'})

        local data = directoryFileList(absolutePath..'data/'..files[3][i])
        for j = 1, #data do
            if not stringEndsWith(absolutePath..'data/'..files[3][i]..'/'..data[j], 'events.json') and not stringEndsWith(absolutePath..'data/'..files[3][i]..'/'..data[j], '.lua') and not stringEndsWith(absolutePath..'data/'..files[3][i]..'/'..data[j], '.hx') then -- esse aqui me deu nojo credo
                runHaxeFunction('moveStuff', {absolutePath..'data/'..files[3][i]..'/'..data[j], absolutePath..'songs/'..files[3][i]..'/chart/'..data[j]})
                runHaxeFunction('deleteFolder', {absolutePath..'data/'..files[3][i]})
            end
        end
    end
    debugPrint('Mod was converted successfully!')
    playSound('scrollMenu')
end

function bolas()

    makeLuaBox('box', {'Conversor'}, 'Conversor', 300, 130)
    screenCenter('box')
    addLuaSprite('box', true)

    makeLuaInputText('mod', curMod, 8, 150, 20, 30)
    addToBox('mod', 'box', 'Conversor')
    createLabel('mod', 'Current Mod Directory:', 'box', 'Conversor')

    makeLuaButton('convert', 'CONVERT', 100, 30, 95, getProperty('mod.y') + 30)
    addToBox('convert', 'box', 'Conversor')

    makeLuaCheckBox('ignMods', 'Ignore Mods', ignoreMods, 100, getProperty('mod.width') + 40, 30)
    addToBox('ignMods', 'box', 'Conversor')

    makeLuaSprite('mouseHitbox')
    makeGraphic('mouseHitbox', 5, 5, 'FF0000')
    setProperty('mouseHitbox.visible', false)
    addLuaSprite('mouseHitbox', true)
end

function xereca()

    makeLuaSprite('vv', 'viroviroice/viroviro')
    scaleObject('vv', 0.3, 0.3)
    setProperty('vv.antialiasing', false)
    addLuaSprite('vv', true)

    makeLuaSprite('ie', 'viroviroice/ice')
    screenCenter('ie')
    setProperty('ie.antialiasing', false)
    addLuaSprite('ie', true)

    local pos = {minX = 0, minY = 0, maxX = screenWidth - getProperty('vv.width'), maxY = screenHeight - getProperty('vv.height')}
    setProperty('vv.x', getRandomFloat(pos.minX, pos.maxX))
    setProperty('vv.y', getRandomFloat(pos.minY, pos.maxY))

    scaleObject('ie', getProperty('vv.scale.x') * 2, getProperty('vv.scale.y') * 2)
    setProperty('ie.x', getProperty('vv.x') - 34)
    setProperty('ie.y', getProperty('vv.y') - 24)
end
