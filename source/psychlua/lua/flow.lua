local function scriptFlowRun(callback)
    if type(callback) ~= 'function' then return false end
    callback()
    return true
end

local sectionSpans = {}

function _scriptForSteps(steps, callback, position)
    local value = tonumber(position)
    if value == nil then value = tonumber(curStep) or 0 end
    local span = sectionSpans[#sectionSpans] or 16
    local localStep = value % span

    for _, step in ipairs(steps or {}) do
        if math.floor(tonumber(step) or -1) == localStep then
            return scriptFlowRun(callback)
        end
    end
    return false
end

function from(first, last, callback, position) -- from(0, 64, () -> {}, step);
    local value = tonumber(position)
    if value == nil then value = tonumber(curStep) or 0 end

    first = tonumber(first) or 0
    last = tonumber(last) or first
    if value < math.min(first, last) or value > math.max(first, last) then
        return false
    end
    return scriptFlowRun(callback)
end

function every(amount, timing, callback, position) -- every(4, 'steps', () -> , step);
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    timing = tostring(timing or 'steps'):lower()
    if timing ~= 'steps' and timing ~= 'beats' then return false end

    local value = tonumber(position)
    if value == nil then
        value = timing == 'beats' and (tonumber(curBeat) or 0) or (tonumber(curStep) or 0)
    end
    if value % amount ~= 0 then return false end
    return scriptFlowRun(callback)
end

function onSection(many, steps, callback, position) -- onSection(2, [0, 8, 12], () -> {}, step);
    if type(steps) == 'function' and callback == nil then
        callback = steps
        steps = 0
    end

    many = math.max(1, math.floor(tonumber(many) or 1))
    local value = tonumber(position)
    if value == nil then value = tonumber(curStep) or 0 end
    local localStep = value % (many * 16)

    local matches = false
    if type(steps) == 'table' then
        for _, step in ipairs(steps) do
            if math.floor(tonumber(step) or -1) == localStep then
                matches = true
                break
            end
        end
    else
        matches = math.floor(tonumber(steps) or 0) == localStep
    end

    if not matches or type(callback) ~= 'function' then return false end
    sectionSpans[#sectionSpans + 1] = many * 16
    local ok, result = pcall(callback)
    sectionSpans[#sectionSpans] = nil
    if not ok then error(result, 0) end
    return true
end
