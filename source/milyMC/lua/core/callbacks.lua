-- =========================================================================
-- Callbacks extras
-- =========================================================================

function callExternalModchart(funcName, args)
    if callOnScripts then
        callOnScripts(funcName, args or {}, true, true)
    end
end

function onUpdate(elapsed)
    local toRemove = {}

    for key, data in pairs(modTweens) do
        data.time = data.time + elapsed
        local ratio = math.min(data.time / data.duration, 1)
        local easedRatio = getEaseValue(ratio, data.easeName)
        local val = lerp(data.startVal, data.targetVal, easedRatio)

        if mods[data.modName] then
            applyModValue(data.modName, val, data.target)
        end

        if ratio >= 1 then
            table.insert(toRemove, key)
            if modChartTweenFinished then
                modChartTweenFinished(data.tag)
            end
        end
    end

    for _, key in ipairs(toRemove) do
        modTweens[key] = nil
    end

    if modChartUpdate then modChartUpdate(elapsed) end
    callExternalModchart('modChartUpdate', {elapsed})
end

local noteMathErrorShown = false
local function safeUpdateNoteMath(objID, strumE, strumID, songPos, beat)
    local ok, err = pcall(updateNoteMath, objID, strumE, strumID, songPos, beat)
    if not ok and not noteMathErrorShown then
        noteMathErrorShown = true
        if debugPrint then
            debugPrint('[MilyMC] updateNoteMath error: ' .. tostring(err))
        end
    end
end

function onUpdatePost(elapsed)
    local currentSongPos = getSongPosition()
    local currentBeat = (currentSongPos / 1000) * (curBpm / 60)
    depthSortDirty = false

    for i = 0, 7 do
        safeUpdateNoteMath(i, true, i, currentSongPos, currentBeat)
    end

    for i = 0, getProperty('notes.length') - 1 do
        local noteData = tonumber(getPropertyFromGroup('notes', i, 'noteData'))
        if noteData ~= nil then
            local isDad = not getPropertyFromGroup('notes', i, 'mustPress')
            local strumID = noteData + (isDad and 0 or 4)

            if strumID >= 0 and strumID <= 7 then
                safeUpdateNoteMath(i, false, strumID, currentSongPos, currentBeat)
            end
        end
    end

    if depthSortDirty then
        sortPseudo3DLayers()
    end

    if modChartUpdatePost then modChartUpdatePost(elapsed) end
    callExternalModchart('modChartUpdatePost', {elapsed})
end

function onBeatHit()
    if modChartBeatHit then modChartBeatHit() end
    callExternalModchart('modChartBeatHit')
end

function onStepHit()
    runScheduledEvents()
    if modChartStepHit then modChartStepHit() end
    callExternalModchart('modChartStepHit')
end

function onSectionHit()
    if modChartSectionHit then modChartSectionHit() end
    callExternalModchart('modChartSectionHit')
end

function onMoveCamera(focus)
    if modChartFocus then modChartFocus(focus) end
    callExternalModchart('modChartFocus', {focus})
end

function goodNoteHit(id, nd, nt, sus)
    if modChartBFNote then modChartBFNote(id, nd, nt, sus) end
    callExternalModchart('modChartBFNote', {id, nd, nt, sus})
end

function opponentNoteHit(id, nd, nt, sus)
    if modChartDADNote then modChartDADNote(id, nd, nt, sus) end
    callExternalModchart('modChartDADNote', {id, nd, nt, sus})
end

function goodNoteHitPre(id, nd, nt, sus)
    if modChartBFNotePre then modChartBFNotePre(id, nd, nt, sus) end
    callExternalModchart('modChartBFNotePre', {id, nd, nt, sus})
end

function opponentNoteHitPre(id, nd, nt, sus)
    if modChartDADNotePre then modChartDADNotePre(id, nd, nt, sus) end
    callExternalModchart('modChartDADNotePre', {id, nd, nt, sus})
end

function noteMiss(id, nd, nt, sus)
    if modChartMiss then modChartMiss(id, nd, nt, sus) end
    callExternalModchart('modChartMiss', {id, nd, nt, sus})
end

function noteMissPress(id, nd, nt, sus)
    if modChartMissPress then modChartMissPress(id, nd, nt, sus) end
    callExternalModchart('modChartMissPress', {id, nd, nt, sus})
end

function onSongStart()
    if modChartSongStart then modChartSongStart() end
    callExternalModchart('modChartSongStart')
end

