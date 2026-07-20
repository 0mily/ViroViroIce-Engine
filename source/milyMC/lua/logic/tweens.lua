local function makeTag(prefix, requested)
    if requested ~= nil and tostring(requested) ~= '' then return tostring(requested) end
    tagCounter = tagCounter + 1
    return tostring(prefix or 'mc') .. '#' .. tostring(tagCounter)
end

local function actionKey(kind, name, lane)
    return kind .. '::' .. tostring(name) .. '::' .. tostring(lane)
end

local function actionDefault(kind, name)
    if kind == 'strum' then return getStrumDefault(name) end
    return getModDefaultValue(name)
end

local function getCurrentAction(kind, name, target)
    if kind == 'strum' then return getTargetCurrentStrum(name, target) end
    return getTargetCurrentMod(name, target)
end

local function applyAction(kind, name, value, target)
    if kind == 'strum' then
        applyStrumValue(name, value, target)
    else
        applyModValue(name, value, target)
    end
end

local function clearActionTweens(kind, name, target, exceptKey)
    for key, tween in pairs(modTweens) do
        if key ~= exceptKey and tween.kind == kind and tween.name == name and targetsOverlap(tween.target, target) then
            modTweens[key] = nil
        end
    end
end

local function unbindKey(tag, key)
    local bindings = tagBindings[tag]
    if bindings == nil then return end
    for index = #bindings, 1, -1 do
        if bindings[index].key == key then table.remove(bindings, index) end
    end
    if #bindings < 1 then tagBindings[tag] = nil end
end

local function bindTag(tag, kind, name, target)
    local bindings = tagBindings[tag]
    if bindings == nil then
        bindings = {}
        tagBindings[tag] = bindings
    end

    eachTargetLane(target, function(lane)
        local key = actionKey(kind, name, lane)
        local previousTag = actionOwners[key]
        if previousTag ~= nil and previousTag ~= tag then unbindKey(previousTag, key) end
        actionOwners[key] = tag

        local found = false
        for _, binding in ipairs(bindings) do
            if binding.key == key then
                found = true
                break
            end
        end
        if not found then
            bindings[#bindings + 1] = {key = key, kind = kind, name = name, lane = lane}
        end
    end)
end

local function setAction(kind, name, value, target, requestedTag)
    target = normalizeTarget(target)
    name = kind == 'strum' and normalizeStrumOption(name) or normalizeModName(name)
    local tag = makeTag(name, requestedTag)
    clearActionTweens(kind, name, target)
    applyAction(kind, name, value, target)
    bindTag(tag, kind, name, target)
    return tag
end

local function stepsToSeconds(steps)
    return math.max(0, tonumber(steps) or 0) * math.max(0, tonumber(stepCrochet) or 0) / 1000
end

local function easeAction(kind, name, value, time, ease, target, requestedTag)
    target = normalizeTarget(target)
    name = kind == 'strum' and normalizeStrumOption(name) or normalizeModName(name)
    local tag = makeTag(name, requestedTag)
    local duration = stepsToSeconds(time)
    clearActionTweens(kind, name, target)
    bindTag(tag, kind, name, target)

    if duration <= 0 then
        applyAction(kind, name, value, target)
        return tag
    end

    eachTargetLane(target, function(lane)
        modTweens[actionKey(kind, name, lane)] = {
            tag = tag,
            kind = kind,
            name = name,
            target = lane,
            startValue = getCurrentAction(kind, name, lane),
            endValue = tonumber(value) or actionDefault(kind, name),
            duration = duration,
            elapsed = 0,
            ease = ease or 'linear'
        }
    end)
    return tag
end

local function removeTaggedAction(tag, target)
    tag = tostring(tag or '')
    local bindings = tagBindings[tag]
    local allowed = nil
    if target ~= nil then
        allowed = {}
        eachTargetLane(target, function(lane) allowed[lane] = true end)
    end

    for key, tween in pairs(modTweens) do
        if tween.tag == tag and (allowed == nil or targetsOverlap(tween.target, target)) then
            modTweens[key] = nil
        end
    end

    if bindings == nil then return false end
    local kept = {}
    for _, binding in ipairs(bindings) do
        if allowed == nil or allowed[binding.lane] then
            if actionOwners[binding.key] == tag then
                applyAction(binding.kind, binding.name, actionDefault(binding.kind, binding.name), binding.lane)
                actionOwners[binding.key] = nil
            end
        else
            kept[#kept + 1] = binding
        end
    end
    tagBindings[tag] = #kept > 0 and kept or nil
    return true
end

local function queueAction(event)
    event.order = tagCounter + #scheduledEvents + 1
    scheduledEvents[#scheduledEvents + 1] = event
    return event.tag
end

local function readStepRange(stepRange)
    if type(stepRange) ~= 'table' then
        local step = tonumber(stepRange) or 0
        return step, step
    end
    local first = tonumber(stepRange[1] or stepRange.start or stepRange.from) or 0
    local last = tonumber(stepRange[2] or stepRange.finish or stepRange.to) or first
    if last < first then first, last = last, first end
    return first, last
end

local function runScheduledEvents()
    local due = {}
    for index = #scheduledEvents, 1, -1 do
        local event = scheduledEvents[index]
        if curStep >= event.step then
            table.insert(due, 1, event)
            table.remove(scheduledEvents, index)
        end
    end

    for _, event in ipairs(due) do
        if event.operation == 'remove' then
            removeTaggedAction(event.tag, event.target)
        elseif event.operation == 'ease' then
            easeAction(event.kind, event.name, event.value, event.endStep - event.step, event.ease, event.target, event.tag)
        else
            setAction(event.kind, event.name, event.value, event.target, event.tag)
        end
    end
end

local function updateTweens(elapsed)
    local finished = {}
    local finishedTags = {}
    for key, tween in pairs(modTweens) do
        tween.elapsed = tween.elapsed + elapsed
        local ratio = math.min(tween.elapsed / tween.duration, 1)
        local value = lerp(tween.startValue, tween.endValue, getEaseValue(ratio, tween.ease))
        applyAction(tween.kind, tween.name, value, tween.target)
        if ratio >= 1 then
            finished[#finished + 1] = key
            finishedTags[tween.tag] = true
        end
    end
    for _, key in ipairs(finished) do modTweens[key] = nil end
    if _milyMCTweenFinished then
        for tag in pairs(finishedTags) do
            local stillRunning = false
            for _, tween in pairs(modTweens) do
                if tween.tag == tag then stillRunning = true break end
            end
            if not stillRunning then _milyMCTweenFinished(tag) end
        end
    end
end

-- the fuctionsz

function setMC(name, value, target, tag)
    return setAction('mod', name, value, target, tag)
end

function easeMC(name, value, time, ease, target, tag)
    return easeAction('mod', name, value, time, ease, target, tag)
end

function removeMC(tag, target)
    return removeTaggedAction(tag, target)
end

function setQueueMC(step, name, value, target, tag)
    tag = makeTag(name, tag)
    return queueAction({operation = 'set', kind = 'mod', step = tonumber(step) or 0, name = name, value = value, target = target, tag = tag})
end

function easeQueueMC(stepRange, name, value, ease, target, tag)
    local first, last = readStepRange(stepRange)
    tag = makeTag(name, tag)
    return queueAction({operation = 'ease', kind = 'mod', step = first, endStep = last, name = name, value = value, ease = ease, target = target, tag = tag})
end

function removeQueueMC(step, tag, target)
    return queueAction({operation = 'remove', step = tonumber(step) or 0, tag = tostring(tag), target = target})
end

function kickMC(name, value, endValue, time, ease, target, tag)
    tag = setAction('mod', name, value, target, tag)
    easeAction('mod', name, endValue, time, ease, target, tag)
    return tag
end

function setStrum(option, value, target, tag)
    return setAction('strum', option, value, target, tag)
end

function easeStrum(option, value, time, ease, target, tag)
    return easeAction('strum', option, value, time, ease, target, tag)
end

function setQueueStrum(step, option, value, target, tag)
    tag = makeTag(option, tag)
    return queueAction({operation = 'set', kind = 'strum', step = tonumber(step) or 0, name = option, value = value, target = target, tag = tag})
end

function easeQueueStrum(stepRange, option, value, ease, target, tag)
    local first, last = readStepRange(stepRange)
    tag = makeTag(option, tag)
    return queueAction({operation = 'ease', kind = 'strum', step = first, endStep = last, name = option, value = value, ease = ease, target = target, tag = tag})
end
