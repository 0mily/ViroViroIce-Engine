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
local noteMathWasActive = false
local laneMathWasActive = {}
local laneBitValues = {
    [0] = 1,
    [1] = 2,
    [2] = 4,
    [3] = 8,
    [4] = 16,
    [5] = 32,
    [6] = 64,
    [7] = 128
}

local function anyLaneWasActive()
    for i = 0, 7 do
        if laneMathWasActive[i] then
            return true
        end
    end
    return false
end

local function laneNeedsNoteMath(activeLaneMask, strumID)
    if activeLaneMask == nil then
        return true
    end
    return activeLaneMask[strumID] or laneMathWasActive[strumID]
end

local function getLaneMaskBits(activeLaneMask)
    if activeLaneMask == nil then
        return 255
    end

    local bits = 0
    for i = 0, 7 do
        if laneNeedsNoteMath(activeLaneMask, i) then
            bits = bits + laneBitValues[i]
        end
    end
    return bits
end

local function safeUpdateNoteMath(objID, strumE, strumID, songPos, beat, noteInfo)
    if not _milyMCProtectedNoteMath then
        updateNoteMath(objID, strumE, strumID, songPos, beat, noteInfo)
        return
    end

    local ok, err = pcall(updateNoteMath, objID, strumE, strumID, songPos, beat, noteInfo)
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
    local activeLaneMask = _milyMCGetActiveLaneMask and _milyMCGetActiveLaneMask() or nil
    local hasActiveNoteMath = false
    if activeLaneMask ~= nil then
        hasActiveNoteMath = activeLaneMask.any
    else
        hasActiveNoteMath = (_milyMCHasActiveNoteMath == nil) or _milyMCHasActiveNoteMath()
    end
    local shouldUpdateNoteMath = hasActiveNoteMath or anyLaneWasActive() or noteMathWasActive

    if shouldUpdateNoteMath then
        if _milyMCClearMathCache then
            _milyMCClearMathCache()
        end

        for i = 0, 7 do
            if laneNeedsNoteMath(activeLaneMask, i) then
                safeUpdateNoteMath(i, true, i, currentSongPos, currentBeat)
            end
        end

        local noteCount = _milyMCGetNoteCount and _milyMCGetNoteCount() or getProperty('notes.length')
        local laneMaskBits = getLaneMaskBits(activeLaneMask)
        for i = 0, noteCount - 1 do
            if _milyMCGetNoteInfo then
                local noteInfo = _milyMCGetNoteInfo(i, laneMaskBits)
                if noteInfo ~= nil then
                    local noteData = tonumber(noteInfo[MILYMC_NOTE_DATA])
                    if noteData ~= nil then
                        local isDad = not noteInfo[MILYMC_NOTE_MUST_PRESS]
                        local strumID = noteData + (isDad and 0 or 4)
                        if strumID >= 0 and strumID <= 7 then
                            safeUpdateNoteMath(i, false, strumID, currentSongPos, currentBeat, noteInfo)
                        end
                    end
                end
            else
                local noteData = tonumber(getPropertyFromGroup('notes', i, 'noteData'))
                if noteData ~= nil then
                    local mustPress = getPropertyFromGroup('notes', i, 'mustPress')
                    local isDad = not mustPress
                    local strumID = noteData + (isDad and 0 or 4)

                    if strumID >= 0 and strumID <= 7 and laneNeedsNoteMath(activeLaneMask, strumID) then
                        safeUpdateNoteMath(i, false, strumID, currentSongPos, currentBeat)
                    end
                end
            end
        end

        if depthSortDirty then
            sortPseudo3DLayers()
        end
    end

    for i = 0, 7 do
        if activeLaneMask ~= nil then
            laneMathWasActive[i] = activeLaneMask[i]
        else
            laneMathWasActive[i] = hasActiveNoteMath
        end
    end
    noteMathWasActive = hasActiveNoteMath

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

