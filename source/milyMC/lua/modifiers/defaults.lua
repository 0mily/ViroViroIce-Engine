-- =========================================================================
-- Default Modifier Math
-- =========================================================================

function sortPseudo3DLayers()
    if not runHaxeCode then
        return
    end

    runHaxeCode([[
        var sortPseudoDepth = function(a:Dynamic, b:Dynamic) {
            if (a == null || b == null) return 0;

            var az:Float = (a.scale != null ? a.scale.x : 1);
            var bz:Float = (b.scale != null ? b.scale.x : 1);
            if (az < bz) return -1;
            if (az > bz) return 1;
            if (a.y < b.y) return -1;
            if (a.y > b.y) return 1;
            return 0;
        };

        if (game.notes != null && game.notes.members != null) {
            game.notes.members.sort(sortPseudoDepth);
        }
    ]])
end -- bnightmare visineroi

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end
    if x > 0 then
        return math.atan(y / x)
    end
    if x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    end
    if x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    end
    if y > 0 then
        return math.pi * 0.5
    end
    if y < 0 then
        return -math.pi * 0.5
    end
    return 0
end

local function normalizeAngle(angle)
    angle = (angle + 180) % 360
    if angle < 0 then
        angle = angle + 360
    end
    return angle - 180
end

local function lerpAngle(from, to, ratio)
    return from + (normalizeAngle(to - from) * ratio)
end

local function projectPseudo3DEnhanced(x, y, z)
    local depth = math.max(80, PERSPECTIVE_FL - z)
    local depthScale = PERSPECTIVE_FL / depth
    local outX = VP_X + ((x - VP_X) * depthScale)
    local outY = VP_Y + ((y - VP_Y) * depthScale)

    return outX, outY, depthScale
end

local function getNoteTravelDistance(distance, isPlayer, strumID, col, beat)
    local sign = distance < 0 and -1 or 1
    local magnitude = math.abs(distance)

    local dashVal = getMod('noteDash', isPlayer, strumID)
    if dashVal ~= 0 then
        local farFactor = math.sqrt(clamp(magnitude / 700, 0, 1))
        local beatPush = 1 + (math.max(0, math.sin((beat * math.pi) + (col * 0.35))) * 0.2)
        magnitude = magnitude * (1 + (farFactor * dashVal * 0.5 * beatPush))
    end

    local slowVal = getMod('noteSlow', isPlayer, strumID)
    if slowVal ~= 0 then
        local range = 500
        local halfFactor = clamp((range - magnitude) / range, 0, 1)
        magnitude = magnitude * (1 + (halfFactor * slowVal * 0.6))
    end

    local boostVal = getMod('boost', isPlayer, strumID)
    if boostVal ~= 0 then
        local near = 1 - clamp(magnitude / 650, 0, 1)
        magnitude = magnitude + (math.sin(near * math.pi) * 120 * boostVal)
    end

    local waveVal = getMod('wave', isPlayer, strumID)
    if waveVal ~= 0 then
        magnitude = magnitude + (math.sin(magnitude * 0.018) * 80 * waveVal)
    end

    local brakeVal = getMod('brake', isPlayer, strumID)
    if brakeVal ~= 0 then
        local near = 1 - clamp(magnitude / 700, 0, 1)
        magnitude = magnitude * (1 + (near * near * brakeVal * 1.4))
    end

    return sign * magnitude
end

local function getBeatPulse(beat)
    local accelTime = 0.3
    local totalTime = 0.7
    local beatPos = beat + accelTime
    local evenBeat = math.floor(beatPos) % 2 ~= 0
    local phase = beatPos - math.floor(beatPos)

    if phase >= totalTime then
        return 0
    end

    local amount = 0
    if phase < accelTime then
        amount = phase / accelTime
        amount = amount * amount
    else
        amount = (totalTime - phase) / (totalTime - accelTime)
        amount = 1 - ((1 - amount) * (1 - amount))
    end

    if evenBeat then
        amount = -amount
    end
    return amount
end

local function getBeatWave(strumE, noteDistance)
    local visualDiff = strumE and 0 or math.abs(noteDistance)
    return math.sin((visualDiff / 30) + (math.pi * 0.5))
end

local function getNoteBeatWave(strumE, noteDistance, isPlayer, strumID)
    local beatWave = getBeatWave(strumE, noteDistance)
    if not strumE then
        beatWave = lerp(1, beatWave, getModDef('beatIntensity', isPlayer, 1, strumID))
    end
    return beatWave
end

local function getReceptorScrollY(vDiff)
    refreshScrollAnchors()

    local reversed = math.floor(vDiff) % 2 == 0
    local phase = vDiff - math.floor(vDiff)
    local revPerc = reversed and (1 - phase) or phase
    return lerp(UPSCROLL_Y, DOWNSCROLL_Y, clamp(revPerc, 0, 1))
end

local function getReceptorScrollSpeed()
    return math.max(1, (crochet or ((stepCrochet or 125) * 4)) * 3)
end

local function getNoteSpeed(group, objID, noteInfo)
    if noteInfo ~= nil and noteInfo[MILYMC_NOTE_SPEED] ~= nil then
        return tonumber(noteInfo[MILYMC_NOTE_SPEED]) or 1
    end

    local songSpeed = tonumber(getProperty('songSpeed')) or 1
    local multSpeed = tonumber(getPropertyFromGroup(group, objID, 'multSpeed')) or 1
    local playbackRate = tonumber(getProperty('playbackRate')) or 1
    return (songSpeed * multSpeed) / math.max(0.001, playbackRate)
end

local function getStrumTimeFromDistance(songPos, distance, noteSpeed)
    songPos = tonumber(songPos) or 0
    distance = tonumber(distance) or 0
    noteSpeed = tonumber(noteSpeed) or 1
    return songPos + (distance / math.max(0.001, 0.45 * math.abs(noteSpeed)))
end

local brightnessCache = {}

local function applyNoteBrightness(group, objID, brightness)
    brightness = clamp(brightness or 0, 0, 1)
    local offset = brightness * 255
    local groupCache = brightnessCache[group]

    if groupCache == nil then
        groupCache = {}
        brightnessCache[group] = groupCache
    end

    if offset <= 0.001 then
        if groupCache[objID] == 0 then
            return
        end

        groupCache[objID] = 0
    else
        groupCache[objID] = brightness
    end

    setPropertyFromGroup(group, objID, 'colorTransform.redMultiplier', 1)
    setPropertyFromGroup(group, objID, 'colorTransform.greenMultiplier', 1)
    setPropertyFromGroup(group, objID, 'colorTransform.blueMultiplier', 1)
    setPropertyFromGroup(group, objID, 'colorTransform.redOffset', offset)
    setPropertyFromGroup(group, objID, 'colorTransform.greenOffset', offset)
    setPropertyFromGroup(group, objID, 'colorTransform.blueOffset', offset)
end

local function rotatePoint3D(x, y, z, pivotX, pivotY, pivotZ, rotX, rotY, rotZ)
    pivotZ = pivotZ or 0

    local relX = x - pivotX
    local relY = y - pivotY
    local relZ = z - pivotZ

    local radX = rotX * math.pi * 2
    local radY = rotY * math.pi * 2
    local radZ = rotZ * math.pi * 2

    local cZ, sZ = math.cos(radZ), math.sin(radZ)
    local x1 = relX * cZ - relY * sZ
    local y1 = relX * sZ + relY * cZ
    local z1 = relZ

    local cX, sX = math.cos(radX), math.sin(radX)
    local x2 = x1
    local y2 = y1 * cX - z1 * sX
    local z2 = y1 * sX + z1 * cX

    local cY, sY = math.cos(radY), math.sin(radY)
    local x3 = x2 * cY + z2 * sY
    local y3 = y2
    local z3 = -x2 * sY + z2 * cY

    return x3 + pivotX, y3 + pivotY, z3 + pivotZ
end

local function applyRotateSet(curX, curY, curZ, curAngle, pivotX, pivotY, pivotZ, rotX, rotY, rotZ)
    if rotX == 0 and rotY == 0 and rotZ == 0 then
        return curX, curY, curZ, curAngle
    end

    local outX, outY, outZ = rotatePoint3D(curX, curY, curZ, pivotX, pivotY, pivotZ, rotX, rotY, rotZ)
    outZ = clamp(outZ, -PERSPECTIVE_FL * 0.7, PERSPECTIVE_FL * 0.7)

    return outX, outY, outZ, curAngle + (rotZ * 360)
end

local function getRotateValue(prefix, axis, isPlayer, strumID, col)
    return getMod(prefix .. axis, isPlayer, strumID) + getMod(prefix .. tostring(col) .. axis, isPlayer, strumID)
end

local function calculateNoteState(objID, strumE, strumID, songPos, beat, distanceOverride, includeCustom, includeProjection, noteInfo, beatWaveAnchor)
    local isPlayer = (strumID > 3)
    local col = strumID % 4
    local def = defaultStrums[strumID]
    if not def then return nil end

    local laneState = buildLaneState(strumID)
    local swapBlend = getOppSwapBlend(isPlayer, strumID)
    if swapBlend ~= 0 then
        laneState = blendLaneStates(laneState, buildLaneState(getOtherSideStrumID(strumID)), swapBlend)
    end

    local scrollBlend = laneState.scrollBlend
    local scrollSign = lerp(-1, 1, scrollBlend)

    local curX, curY, curAngle = laneState.x, laneState.y, laneState.angle
    local curScaleX, curScaleY = laneState.scaleX, laneState.scaleY
    local curAlpha = 1
    local curZ = laneState.z or 0
    local curBrightness = 0
    local eLonga = (not strumE) and (noteInfo and noteInfo[MILYMC_NOTE_IS_SUSTAIN] or getPropertyFromGroup('notes', objID, 'isSustainNote'))
    local noteDistance = 0

    if not strumE then
        local offsetX = (noteInfo and noteInfo[MILYMC_NOTE_OFFSET_X]) or getPropertyFromGroup('notes', objID, 'offsetX') or 0
        local offsetY = (noteInfo and noteInfo[MILYMC_NOTE_OFFSET_Y]) or getPropertyFromGroup('notes', objID, 'offsetY') or 0
        noteDistance = distanceOverride

        if noteDistance == nil then
            noteDistance = noteInfo and noteInfo[MILYMC_NOTE_DISTANCE] or getPropertyFromGroup('notes', objID, 'distance')
        end

        if noteDistance == nil then
            local noteY = getPropertyFromGroup('notes', objID, 'y') or def.y
            noteDistance = (noteY - def.y) * (downscroll and -1 or 1)
        end

        local travelDistance = getNoteTravelDistance(noteDistance, isPlayer, strumID, col, beat)

        local receptorScrollVal = clamp(getMod('receptorScroll', isPlayer, strumID), 0, 1)

        curX = curX + offsetX
        curY = curY + offsetY + (travelDistance * scrollSign)

        if receptorScrollVal ~= 0 then
            local noteSpeed = getNoteSpeed('notes', objID, noteInfo)
            local strumTime = getStrumTimeFromDistance(songPos, noteDistance, noteSpeed)
            local targetY = getReceptorScrollY(strumTime / getReceptorScrollSpeed()) + offsetY
            curY = lerp(curY, targetY, receptorScrollVal)
        end

        local zigzagVal = getMod('zigzag', isPlayer, strumID)
        if zigzagVal ~= 0 then
            local alignBlend = clamp(math.abs(travelDistance) / 240, 0, 1)
            local zigzagWave = math.sin((math.abs(travelDistance) * 0.03) + ((songPos / 1000) * 5) + (col * 0.7))
            curX = curX + (zigzagWave * 48 * zigzagVal * alignBlend)
        end
    end

    if strumE then
        local receptorScrollVal = clamp(getMod('receptorScroll', isPlayer, strumID), 0, 1)
        if receptorScrollVal ~= 0 then
            local targetY = getReceptorScrollY(songPos / getReceptorScrollSpeed())
            curY = lerp(curY, targetY, receptorScrollVal)
        end
    end

    local globalScale = math.max(0.05, 1 + getMod('globalScale', isPlayer, strumID))
    curScaleX = curScaleX * globalScale
    curScaleY = curScaleY * globalScale
    curAlpha = curAlpha * laneState.alpha

    local miniVal = getMod('mini', isPlayer, strumID)
    local miniXVal = getMod('miniX', isPlayer, strumID)
    local miniYVal = getMod('miniY', isPlayer, strumID)
    local scaleXMod = math.max(0.05, 1 - miniVal - miniXVal + getMod('squish', isPlayer, strumID))
    local scaleYMod = math.max(0.05, 1 - miniVal - miniYVal + getMod('stretch', isPlayer, strumID))

    if strumE then
        scaleXMod = scaleXMod * getModDef('receptorScaleX', isPlayer, 1, strumID)
        scaleYMod = scaleYMod * getModDef('receptorScaleY', isPlayer, 1, strumID)
    else
        scaleXMod = scaleXMod * getModDef('noteScaleX', isPlayer, 1, strumID)
        scaleYMod = scaleYMod * getModDef('noteScaleY', isPlayer, 1, strumID)
    end

    curScaleX = curScaleX * scaleXMod
    curScaleY = curScaleY * scaleYMod

    local drunkVal = getMod('drunk', isPlayer, strumID)
    if drunkVal ~= 0 then
        local noteOffset = strumE and 0 or (noteDistance * 0.01)
        local drunkSpeed = getModDef('drunkSpeed', isPlayer, 1, strumID)
        local drunkPeriod = getModDef('drunkPeriod', isPlayer, 1, strumID)
        local drunkOffset = getMod('drunkOffset', isPlayer, strumID)
        local drunkTime = ((songPos / 1000) * 2 * drunkSpeed) + (col * 0.5) + (noteOffset * drunkPeriod) + drunkOffset
        curX = curX + (drunkVal * math.cos(drunkTime) * 40)

        if eLonga then
            curAngle = curAngle + (-math.sin(drunkTime) * drunkVal * 15)
        end
    end

    local tipsyVal = getMod('tipsy', isPlayer, strumID)
    if tipsyVal ~= 0 then
        local noteOffset = strumE and 0 or (noteDistance * 0.01)
        local tipsySpeed = getModDef('tipsySpeed', isPlayer, 1, strumID)
        local tipsyPeriod = getModDef('tipsyPeriod', isPlayer, 1, strumID)
        local tipsyOffset = getMod('tipsyOffset', isPlayer, strumID)
        local tipsyTime = ((songPos / 1000) * 2 * tipsySpeed) + (col * 0.6) + (noteOffset * tipsyPeriod) + tipsyOffset
        curY = curY + (tipsyVal * math.cos(tipsyTime) * 35)
    end

    local tipZVal = getMod('tipZ', isPlayer, strumID)
    if tipZVal ~= 0 then
        local noteOffset = strumE and 0 or (noteDistance * 0.01)
        local tipZSpeed = getModDef('tipZSpeed', isPlayer, 1, strumID)
        local tipZPeriod = getModDef('tipZPeriod', isPlayer, 1, strumID)
        local tipZOffset = getMod('tipZOffset', isPlayer, strumID)
        local tipZTime = ((songPos / 1000) * 2 * tipZSpeed) + (col * 0.6) + (noteOffset * tipZPeriod) + tipZOffset
        curZ = curZ + (tipZVal * math.cos(tipZTime) * 120)
    end

    local floatVal = getMod('float', isPlayer, strumID)
    if floatVal ~= 0 then
        local noteOffset = strumE and 0 or (noteDistance * 0.01)
        local floatTime = ((songPos / 1000) * 2) + (col * 0.6) + noteOffset
        curX = curX + (floatVal * math.cos(floatTime) * 30)
        curY = curY + (floatVal * math.cos(floatTime) * 30)
        curZ = curZ + (floatVal * math.sin(floatTime * 1.3) * 100) + 30

        if eLonga then
            curAngle = curAngle + (-math.sin(floatTime) * floatVal * 6)
        end
    end

    local beatVal = getMod('beat', isPlayer, strumID)
    local beatKickVal = getMod('beatKick', isPlayer, strumID)
    local beatYVal = getMod('beatY', isPlayer, strumID)
    local beatYKickVal = getMod('beatYKick', isPlayer, strumID)
    if beatVal ~= 0 or beatKickVal ~= 0 or beatYVal ~= 0 or beatYKickVal ~= 0 then
        local beatWave = getNoteBeatWave(strumE, noteDistance, isPlayer, strumID)
        if eLonga and beatWaveAnchor ~= nil then
            beatWave = lerp(beatWaveAnchor, beatWave, getModDef('beatSusIntensity', isPlayer, 1, strumID))
        end
        local beatPulse = getBeatPulse(beat)
        local beatShift = (beatVal * beatPulse * 40 * beatWave) + (beatKickVal * 150 * beatWave)
        local beatYShift = (beatYVal * beatPulse * 40 * beatWave) + (beatYKickVal * 150 * beatWave)
        curX = curX + beatShift
        curY = curY + beatYShift
    end

    local beatZVal = getMod('beatZ', isPlayer, strumID)
    if beatZVal ~= 0 then
        local beatZMath = beat + (col * 0.2) + (strumE and 0 or (math.abs(noteDistance) * 0.003))
        local beatPulse = math.sin(beatZMath)
        curX = curX + (beatPulse * 90 * beatZVal)
        curY = curY + (beatPulse * 30 * beatZVal)
        curZ = curZ + (math.max(0, beatPulse) * 140 * beatZVal)
    end

    local temnaVal = getMod('temna', isPlayer, strumID)
    if temnaVal ~= 0 then
        local temnaMath = beat + (col * 0.2)
        curX = curX + (math.sin(temnaMath) * 150 * temnaVal)

        if eLonga then
            local waveDeriv = math.cos(temnaMath)
            curAngle = curAngle + (waveDeriv * temnaVal * 36)
            curX = curX + (waveDeriv * temnaVal * 10)
        end
    end

    local earthquakeVal = getMod('earthquake', isPlayer, strumID)
    local earthquakeValX = getMod('earthquakeX', isPlayer, strumID)
    local earthquakeValY = getMod('earthquakeY', isPlayer, strumID)
    if earthquakeVal ~= 0 or earthquakeValX ~= 0 or earthquakeValY ~= 0 then
        local quakeTime = (songPos / 1000) * 40
        curX = curX + (math.sin(quakeTime + objID + (col * 3)) * 8 * (earthquakeVal + earthquakeValX))
        curY = curY + (math.cos((quakeTime * 1.27) + objID + (col * 2)) * 6 * (earthquakeVal + earthquakeValY))
    end

    local susPulseVal = getMod('susPulse', isPlayer, strumID)
    if susPulseVal ~= 0 and eLonga then
        local susPulseTime = (beat * 2) + (math.abs(noteDistance) * 0.015) + (col * 0.4)
        curX = curX + (math.sin(susPulseTime) * 24 * susPulseVal)
        curAngle = curAngle + (math.cos(susPulseTime) * 10 * susPulseVal)
    end

    local spinVal = getMod('spin', isPlayer, strumID)
    if spinVal ~= 0 and not eLonga then
        curAngle = curAngle + (spinVal * 360)
    end

    local confusionVal = getMod('confusion', isPlayer, strumID)
    if confusionVal ~= 0 then
        curAngle = curAngle + confusionVal
    end

    if strumE then
        curAngle = curAngle + getMod('receptorAngle', isPlayer, strumID)
    else
        curAngle = curAngle + getMod('noteAngle', isPlayer, strumID)
    end

    local rotX = getRotateValue('r', 'X', isPlayer, strumID, col)
    local rotY = getRotateValue('r', 'Y', isPlayer, strumID, col)
    local rotZ = getRotateValue('r', 'Z', isPlayer, strumID, col)
    if rotX ~= 0 or rotY ~= 0 or rotZ ~= 0 then
        local pivotX, pivotY = getCurrentLinePivot(strumID)
        pivotY = lerp(pivotY, VP_Y, 0.35)

        local rotationBaseX = curX
        local preservedXOffset = 0
        if not strumE then
            rotationBaseX = laneState.x
            preservedXOffset = curX - laneState.x
        end

        curX, curY, curZ, curAngle = applyRotateSet(rotationBaseX, curY, curZ, curAngle, pivotX, pivotY, 0, rotX, rotY, rotZ)

        if not strumE then
            local yawDampen = math.max(0.2, math.abs(math.cos(rotY * math.pi * 2)))
            curX = curX + (preservedXOffset * yawDampen)
        end
    end

    local centerRotX = getRotateValue('centerR', 'X', isPlayer, strumID, col)
    local centerRotY = getRotateValue('centerR', 'Y', isPlayer, strumID, col)
    local centerRotZ = getRotateValue('centerR', 'Z', isPlayer, strumID, col)
    if centerRotX ~= 0 or centerRotY ~= 0 or centerRotZ ~= 0 then
        curX, curY, curZ, curAngle = applyRotateSet(curX, curY, curZ, curAngle, VP_X, VP_Y, 0, centerRotX, centerRotY, centerRotZ)
    end

    local zVal = getMod('z', isPlayer, strumID)
    if zVal ~= 0 then
        curZ = curZ + zVal
    end

    if strumE then
        local darkVal = clamp(getMod('dark', isPlayer, strumID), 0, 1)
        if darkVal ~= 0 then
            curAlpha = curAlpha * (1 - darkVal)
        end
    else
        local absDistance = math.abs(noteDistance)
        local visibility = 1

        local stealthVal = clamp(getMod('stealth', isPlayer, strumID), 0, 1)
        if stealthVal ~= 0 then
            if stealthVal <= 0.5 then
                curBrightness = math.max(curBrightness, stealthVal * 2)
            else
                visibility = visibility * (1 - ((stealthVal - 0.5) * 2))
                curBrightness = math.max(curBrightness, 1)
            end
        end

        local hiddenVal = clamp(getMod('hidden', isPlayer, strumID), 0, 1)
        if hiddenVal ~= 0 then
            local hiddenOffset = getMod('hiddenOffset', isPlayer, strumID) * 360
            local hiddenNear = 1 - clamp((absDistance - hiddenOffset) / 240, 0, 1)
            visibility = visibility * (1 - (hiddenVal * hiddenNear))
        end

        local suddenVal = clamp(getMod('sudden', isPlayer, strumID), 0, 1)
        if suddenVal ~= 0 then
            local suddenOffset = getMod('suddenOffset', isPlayer, strumID) * 360
            local suddenNear = 1 - clamp((absDistance - suddenOffset) / 240, 0, 1)
            visibility = visibility * lerp(1, suddenNear, suddenVal)
        end

        local blinkVal = clamp(getMod('blink', isPlayer, strumID), 0, 1)
        if blinkVal ~= 0 then
            local blinkAlpha = (math.sin((songPos / 1000) * 12) + 1) * 0.5
            visibility = visibility * lerp(1, blinkAlpha, blinkVal)
        end

        visibility = clamp(visibility, 0, 1)
        curAlpha = curAlpha * visibility
        curBrightness = math.max(curBrightness, clamp((1 - visibility) * 2, 0, 1))
    end

    if includeCustom ~= false then
        local ctx = {
            objID = objID,
            strumE = strumE,
            strumID = strumID,
            isPlayer = isPlayer,
            col = col,
            songPos = songPos,
            beat = beat,
            x = curX,
            y = curY,
            angle = curAngle,
            scaleX = curScaleX,
            scaleY = curScaleY,
            alpha = curAlpha,
            brightness = curBrightness,
            z = curZ,
            distance = noteDistance,
            isSustainNote = eLonga,
            scrollBlend = scrollBlend
        }

        applyCustomModifiers(ctx)

        curX = ctx.x or curX
        curY = ctx.y or curY
        curAngle = ctx.angle or curAngle
        curScaleX = ctx.scaleX or curScaleX
        curScaleY = ctx.scaleY or curScaleY
        curAlpha = ctx.alpha or curAlpha
        curBrightness = ctx.brightness or curBrightness
        curZ = ctx.z or curZ
    end

    if includeProjection ~= false and curZ ~= 0 then
        local px, py, depthScale = projectPseudo3DEnhanced(curX, curY, curZ)
        curX = px
        curY = py
        curScaleX = curScaleX * depthScale
        curScaleY = curScaleY * depthScale
        depthSortDirty = true
    end

    return {
        x = curX,
        y = curY,
        angle = curAngle,
        scaleX = curScaleX,
        scaleY = curScaleY,
        alpha = curAlpha,
        brightness = curBrightness,
        z = curZ,
        distance = noteDistance,
        scrollBlend = scrollBlend,
        isSustainNote = eLonga
    }
end

function updateNoteMath(objID, strumE, strumID, songPos, beat, noteInfo)
    local state = calculateNoteState(objID, strumE, strumID, songPos, beat, nil, true, true, noteInfo)
    if not state then return end

    local group = strumE and 'strumLineNotes' or 'notes'
    if strumE and _milyMCApplyStrumState then
        _milyMCApplyStrumState(objID, state.x, state.y, state.angle, state.scaleX, state.scaleY, state.alpha, state.brightness or 0)
        return
    end

    local finalAlpha = state.alpha
    if not strumE and state.isSustainNote then
        finalAlpha = finalAlpha * ((noteInfo and noteInfo[MILYMC_NOTE_MULT_ALPHA]) or getPropertyFromGroup(group, objID, 'multAlpha') or 0.6)
    end

    if not state.isSustainNote then
        if _milyMCApplyNoteState then
            _milyMCApplyNoteState(objID, strumID, state.x, state.y, state.angle, state.scaleX, state.scaleY, finalAlpha, state.brightness or 0, false, false, state.angle, 1)
            return
        end

        setPropertyFromGroup(group, objID, 'x', state.x)
        setPropertyFromGroup(group, objID, 'y', state.y)
        setPropertyFromGroup(group, objID, 'angle', state.angle)
        setPropertyFromGroup(group, objID, 'scale.x', state.scaleX)
        setPropertyFromGroup(group, objID, 'alpha', finalAlpha)
        applyNoteBrightness(group, objID, state.brightness or 0)
        setPropertyFromGroup(group, objID, 'scale.y', state.scaleY)
        return
    end

    local isUpscroll = state.scrollBlend >= 0.5
    local strumWidth = getPropertyFromGroup('strumLineNotes', strumID, 'width') or 112
    local strumHeight = getPropertyFromGroup('strumLineNotes', strumID, 'height') or 112
    local frameWidth = getPropertyFromGroup(group, objID, 'frameWidth') or getPropertyFromGroup(group, objID, 'width') or strumWidth
    local frameHeight = getPropertyFromGroup(group, objID, 'frameHeight') or getPropertyFromGroup(group, objID, 'height') or 44
    local sustainPixels = (noteInfo and noteInfo[MILYMC_NOTE_SUSTAIN_PIXELS])
    if sustainPixels == nil then
        local sustainLength = getPropertyFromGroup(group, objID, 'sustainLength') or (stepCrochet or 0)
        local noteSpeed = getNoteSpeed(group, objID, noteInfo)
        sustainPixels = math.abs(0.45 * sustainLength * noteSpeed)
    end
    local isPlayer = (strumID > 3)
    local receptorScrollVal = clamp(getMod('receptorScroll', isPlayer, strumID), 0, 1)
    local tangentAngle = state.angle
    local tangentLength = sustainPixels
    local lengthDistance = math.max(1, sustainPixels)
    local tangentCenterDistance = state.distance + (lengthDistance * 0.5)
    local tangentSample = math.max(4, math.min(36, sustainPixels * 0.35))
    local beatWaveAnchor = getNoteBeatWave(false, state.distance, isPlayer, strumID)
    local nextState = calculateNoteState(objID, strumE, strumID, songPos, beat, state.distance + lengthDistance, false, true, noteInfo, beatWaveAnchor)
    local tangentNextState = calculateNoteState(objID, strumE, strumID, songPos, beat, tangentCenterDistance + tangentSample, false, true, noteInfo, beatWaveAnchor)
    local tangentPrevState = calculateNoteState(objID, strumE, strumID, songPos, beat, tangentCenterDistance - tangentSample, false, true, noteInfo, beatWaveAnchor)
    local chordAngle = tangentAngle
    if nextState then
        local dx = nextState.x - state.x
        local dy = nextState.y - state.y
        local distSq = (dx * dx) + (dy * dy)

        if distSq > 0.0001 then
            tangentLength = math.sqrt(distSq)
            chordAngle = math.deg(atan2(dy, dx)) - 90
            tangentAngle = chordAngle
        end

        if tangentNextState and tangentPrevState then
            dx = tangentNextState.x - tangentPrevState.x
            dy = tangentNextState.y - tangentPrevState.y
            distSq = (dx * dx) + (dy * dy)
        end

        if distSq > 0.0001 then
            tangentAngle = math.deg(atan2(dy, dx)) - 90
        end
    end

    local drunkPressure = math.abs(getMod('drunk', isPlayer, strumID))
    local overlap = lerp(2, 5, receptorScrollVal)
    if drunkPressure > 0 and receptorScrollVal > 0 then
        overlap = overlap + clamp(drunkPressure * 1.5, 0, 4)
    end

    local drawLength = math.max(1, tangentLength + overlap)
    local angleDelta = math.abs(((tangentAngle - chordAngle + 180) % 360) - 180)
    if angleDelta > 1 then
        drawLength = drawLength + (clamp(angleDelta / 60, 0, 1) * 3)
    end
    local receptorAlpha = drunkPressure > 0 and 0.28 or 0.4
    if receptorScrollVal ~= 0 then
        finalAlpha = finalAlpha * lerp(1, receptorAlpha, receptorScrollVal)
    end

    if _milyMCApplyNoteState then
        _milyMCApplyNoteState(objID, strumID, state.x, state.y, state.angle, state.scaleX, state.scaleY, finalAlpha, state.brightness or 0, true, not isUpscroll, tangentAngle, drawLength)
        return
    end

    setPropertyFromGroup(group, objID, 'x', state.x)
    setPropertyFromGroup(group, objID, 'y', state.y)
    setPropertyFromGroup(group, objID, 'angle', state.angle)
    setPropertyFromGroup(group, objID, 'scale.x', state.scaleX)
    setPropertyFromGroup(group, objID, 'alpha', finalAlpha)
    applyNoteBrightness(group, objID, state.brightness or 0)
    setPropertyFromGroup(group, objID, 'origin.x', frameWidth * 0.5)
    setPropertyFromGroup(group, objID, 'origin.y', 0)
    setPropertyFromGroup(group, objID, 'offset.x', 0)
    setPropertyFromGroup(group, objID, 'offset.y', 0)
    setPropertyFromGroup(group, objID, 'flipX', not isUpscroll)
    setPropertyFromGroup(group, objID, 'flipY', false)
    setPropertyFromGroup(group, objID, 'angle', tangentAngle)
    setPropertyFromGroup(group, objID, 'x', state.x + ((strumWidth - frameWidth) * 0.5))
    setPropertyFromGroup(group, objID, 'y', state.y + (strumHeight * 0.5))

    local isSustainEnd = (noteInfo and noteInfo[MILYMC_NOTE_IS_SUSTAIN_END]) or getPropertyFromGroup(group, objID, 'isSustainEnd')
    if not isSustainEnd and drawLength > 1 and frameHeight > 0 then
        local scaleY = drawLength / math.max(1, frameHeight - 1)
        setPropertyFromGroup(group, objID, 'scale.y', math.max(0.001, scaleY))
    end
end
