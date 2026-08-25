local noteMathErrorShown = false
local noteMathWasActive = false
local laneMathWasActive = {}
local noteStateBatch = {}
local laneBitValues = {[0] = 1, [1] = 2, [2] = 4, [3] = 8, [4] = 16, [5] = 32, [6] = 64, [7] = 128}

local function queueNoteState(objID, strumID, x, y, angle, scaleX, scaleY, alpha, brightness, isSustain, flipX, segmentAngle, drawLength)
    local index = #noteStateBatch
    noteStateBatch[index + 1] = objID
    noteStateBatch[index + 2] = strumID
    noteStateBatch[index + 3] = x
    noteStateBatch[index + 4] = y
    noteStateBatch[index + 5] = angle
    noteStateBatch[index + 6] = scaleX
    noteStateBatch[index + 7] = scaleY
    noteStateBatch[index + 8] = alpha
    noteStateBatch[index + 9] = brightness
    noteStateBatch[index + 10] = isSustain
    noteStateBatch[index + 11] = flipX
    noteStateBatch[index + 12] = segmentAngle
    noteStateBatch[index + 13] = drawLength
end

local function anyLaneWasActive()
    for lane = 0, 7 do
        if laneMathWasActive[lane] then return true end
    end
    return false
end

local function laneNeedsNoteMath(mask, lane)
    return mask == nil or mask[lane] or laneMathWasActive[lane]
end

local function getLaneMaskBits(mask)
    if mask == nil then return 255 end
    local bits = 0
    for lane = 0, 7 do
        if laneNeedsNoteMath(mask, lane) then bits = bits + laneBitValues[lane] end
    end
    return bits
end

local function safeUpdateNoteMath(objID, isStrum, strumID, songPosition, beat, noteInfo)
    if not _milyMCProtectedNoteMath then
        updateNoteMath(objID, isStrum, strumID, songPosition, beat, noteInfo)
        return
    end

    local ok, err = pcall(updateNoteMath, objID, isStrum, strumID, songPosition, beat, noteInfo)
    if not ok and not noteMathErrorShown then
        noteMathErrorShown = true
        if debugPrint then debugPrint('[MilyMC] note math error: ' .. tostring(err)) end
    end
end

function _milyMCTweenFinished(tag)
    callMilyMCLuas('finished', {tag})
end

function onUpdate(elapsed)
    callMilyMCLuas('updatePre', {elapsed})
    updateTweens(elapsed)
    if updateCustomModifiers then updateCustomModifiers(elapsed) end
    callMilyMCLuas('update', {elapsed})
end

function onUpdatePost(elapsed)
    local songPosition = getSongPosition()
    local beat = (songPosition / 1000) * (curBpm / 60)
    local activeMask = _milyMCGetActiveLaneMask()
    local hasActiveMath = activeMask.any
    local shouldUpdate = hasActiveMath or anyLaneWasActive() or noteMathWasActive

    if shouldUpdate then
        depthSortDirty = false
        if _milyMCClearMathCache then _milyMCClearMathCache() end

        for lane = 0, 7 do
            if laneNeedsNoteMath(activeMask, lane) then
                safeUpdateNoteMath(lane, true, lane, songPosition, beat)
            end
        end

        for index = #noteStateBatch, 1, -1 do noteStateBatch[index] = nil end
        local notes = _milyMCGetNoteBatch and _milyMCGetNoteBatch(getLaneMaskBits(activeMask)) or {}
        for _, noteInfo in ipairs(notes) do
            local objID = tonumber(noteInfo[MILYMC_NOTE_INDEX])
            local noteData = tonumber(noteInfo[MILYMC_NOTE_DATA])
            if objID ~= nil and noteData ~= nil then
                local strumID = noteData + (noteInfo[MILYMC_NOTE_MUST_PRESS] and 4 or 0)
                if strumID >= 0 and strumID <= 7 then
                    safeUpdateNoteMath(objID, false, strumID, songPosition, beat, noteInfo)
                end
            end
        end
        if #noteStateBatch >= 13 and _milyMCApplyNoteBatch then
            _milyMCApplyNoteBatch(noteStateBatch)
        end

        if depthSortDirty then sortPseudo3DLayers() end
    end

    for lane = 0, 7 do laneMathWasActive[lane] = activeMask[lane] end
    noteMathWasActive = hasActiveMath

    callMilyMCLuas('updatePost', {elapsed})
end

function onStepHit()
    runScheduledEvents()
    callMilyMCLuas('step', {curStep})
end

function onBeatHit()
    callMilyMCLuas('beat', {curBeat})
end

function onSectionHit()
    callMilyMCLuas('section', {curSection})
end

function onDestroy()
    if destroyCustomModifiers then destroyCustomModifiers() end
end
