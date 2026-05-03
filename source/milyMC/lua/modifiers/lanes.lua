-- =========================================================================
-- Math & Modifier Core
-- =========================================================================

local function getStrumPivot(strumID)
    local base = (strumID > 3) and 4 or 0

    local x = 0
    for i = base, base + 3 do
        x = x + defaultStrums[i].x
    end

    local pivotX = x / 4
    local pivotY = defaultStrums[base].y
    return pivotX, pivotY
end

local function getScrollBlend(isPlayer, strumID)
    return clamp(getModDef('scrollMode', isPlayer, downscroll and 0 or 1, strumID), 0, 1)
end

local function getOppositeBlend(isPlayer, strumID)
    return clamp(getMod('opposite', isPlayer, strumID), 0, 1)
end

local function clamp(v, minv, maxv) -- a lacração no mundo dos modcharts
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end

local invertColumns = {[0] = 1, [1] = 0, [2] = 3, [3] = 2}

local function getSwappedColumnX(strumID, isPlayer, col)
    local base = isPlayer and 4 or 0
    local x = defaultStrums[strumID].x

    local flipVal = clamp(getMod('flip', isPlayer, strumID), 0, 1)
    if flipVal ~= 0 then
        local target = defaultStrums[base + (3 - col)]
        if target then
            x = lerp(x, target.x, flipVal)
        end
    end

    local invertVal = clamp(getMod('invert', isPlayer, strumID), 0, 1)
    if invertVal ~= 0 then
        local target = defaultStrums[base + invertColumns[col]]
        if target then
            x = lerp(x, target.x, invertVal)
        end
    end

    return x
end

local function isOppSwapOn()
    return getMod('opponentSwap', false, 0) ~= 0 or getMod('oppSwap', false, 0) ~= 0
end

local function getVisualStrumID(strumID)
    if isOppSwapOn() then
        return (strumID > 3) and (strumID - 4) or (strumID + 4)
    end
    return strumID
end

local function getOppSwapBlend(isPlayer, strumID)
    local swapVal = getMod('oppSwap', isPlayer, strumID)
    local altSwapVal = getMod('opponentSwap', isPlayer, strumID)

    if math.abs(altSwapVal) > math.abs(swapVal) then
        swapVal = altSwapVal
    end

    return clamp(swapVal, 0, 1)
end

local function getEffectiveScrollBlend(isPlayer, strumID)
    local scrollBlend = getScrollBlend(isPlayer, strumID)
    local col = strumID % 4
    local reverseBlend = getOppositeBlend(isPlayer, strumID)

    if col == 1 or col == 2 then
        reverseBlend = clamp(reverseBlend + getMod('cross', isPlayer, strumID), 0, 1)
    end
    if col % 2 == 1 then
        reverseBlend = clamp(reverseBlend + getMod('alternate', isPlayer, strumID), 0, 1)
    end

    return lerp(scrollBlend, 1 - scrollBlend, reverseBlend)
end

local function getStrumYFromBlend(scrollBlend)
    refreshScrollAnchors()
    return lerp(DOWNSCROLL_Y, UPSCROLL_Y, clamp(scrollBlend, 0, 1))
end

local function getOtherSideStrumID(strumID)
    return (strumID > 3) and (strumID - 4) or (strumID + 4)
end

local function buildLaneState(strumID)
    local isPlayer = (strumID > 3)
    local col = strumID % 4
    local def = defaultStrums[strumID]
    local scrollBlend = getEffectiveScrollBlend(isPlayer, strumID)
    local baseX = getSwappedColumnX(strumID, isPlayer, col)

    local state = {
        strumID = strumID,
        isPlayer = isPlayer,
        col = col,
        x = baseX + getMod('transformX', isPlayer, strumID) + getModDef('strumX' .. strumID, isPlayer, 0, strumID) + getMod('bumpX', isPlayer, strumID),
        y = getStrumYFromBlend(scrollBlend) + getMod('transformY', isPlayer, strumID) + getModDef('strumY' .. strumID, isPlayer, 0, strumID),
        z = getMod('transformZ', isPlayer, strumID) + getModDef('strumZ' .. strumID, isPlayer, 0, strumID),
        angle = def.angle + getModDef('strumAngle' .. strumID, isPlayer, 0, strumID),
        scaleX = def.scaleX * getModDef('strumScale' .. strumID, isPlayer, 1, strumID),
        scaleY = def.scaleY * getModDef('strumScale' .. strumID, isPlayer, 1, strumID),
        alpha = getModDef('strumAlpha' .. strumID, isPlayer, 1, strumID),
        scrollBlend = scrollBlend
    }

    local middleVal = getMod('middle', isPlayer, strumID)
    if middleVal ~= 0 then
        local centerOffset = 412
        local sideX = centerOffset + (col * 112)
        state.x = lerp(state.x, sideX, middleVal)
    end

    local middle2Val = getMod('middle2', isPlayer, strumID)
    if middle2Val ~= 0 then
        local extremidadesX = {[0] = 90, [1] = 205, [2] = 955, [3] = 1065}
        local targetX = extremidadesX[col]
        
        state.x = lerp(state.x, targetX, middle2Val)
    end

    return state
end

local function blendLaneStates(fromState, toState, ratio)
    return {
        strumID = fromState.strumID,
        isPlayer = fromState.isPlayer,
        col = fromState.col,
        x = lerp(fromState.x, toState.x, ratio),
        y = lerp(fromState.y, toState.y, ratio),
        z = lerp(fromState.z or 0, toState.z or 0, ratio),
        angle = lerp(fromState.angle, toState.angle, ratio),
        scaleX = lerp(fromState.scaleX, toState.scaleX, ratio),
        scaleY = lerp(fromState.scaleY, toState.scaleY, ratio),
        alpha = lerp(fromState.alpha, toState.alpha, ratio),
        scrollBlend = lerp(fromState.scrollBlend, toState.scrollBlend, ratio)
    }
end

local function getCurrentLinePivot(strumID)
    local isPlayer = (strumID > 3)
    local base = isPlayer and 4 or 0
    local swapBlend = getOppSwapBlend(isPlayer, strumID)
    local sumX, sumY = 0, 0
    local otherSumX, otherSumY = 0, 0

    for i = base, base + 3 do
        local lane = buildLaneState(i)
        sumX = sumX + lane.x
        sumY = sumY + lane.y
    end

    local pivotX = sumX / 4
    local pivotY = sumY / 4

    if swapBlend ~= 0 then
        local otherBase = isPlayer and 0 or 4
        for i = otherBase, otherBase + 3 do
            local otherLane = buildLaneState(i)
            otherSumX = otherSumX + otherLane.x
            otherSumY = otherSumY + otherLane.y
        end

        pivotX = lerp(pivotX, otherSumX / 4, swapBlend)
        pivotY = lerp(pivotY, otherSumY / 4, swapBlend)
    end

    return pivotX, pivotY
end

local function projectPseudo3D(x, y, z)
    local halfX = VP_X
    local halfY = VP_Y

    local fov = math.pi / 2 -- e obgda pro schmoovin' q fez isso antes e eu to adaptando em lua leroleroleroooo
    local aspect = 1
    local near = 0
    local far = 2

    local depth = z / PERSPECTIVE_FL
    depth = clamp(depth, -1, 0.999)

    local shit = depth - 1
    if shit > 0 then shit = 0 end

    local ta = math.tan(fov / 2)
    if ta == 0 then ta = 0.0001 end

    local a = (near + far) / (near - far)
    local b = (2 * near * far) / (near - far)

    local zProj = (a * shit + b)

    if math.abs(zProj) < 0.0001 then
        zProj = 0.0001
    end

    local outX = halfX + (((x - halfX) * aspect / ta) / zProj)
    local outY = halfY + (((y - halfY) / ta) / zProj)

    return outX, outY, zProj
end


