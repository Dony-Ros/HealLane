-- Group ordering + caching for the grid layout.
local EvsHL = EvsHL
local orderCacheDirty = true
local orderCacheKey
local cachedOrder, cachedPositions, cachedRowCount, cachedColumns
function EvsHL.MarkOrderDirty() orderCacheDirty = true end
local function BuildOrder(list, raid, cols)
    local simTotal = 0
    for _, u in ipairs(list) do
        if u == "sim" then simTotal = simTotal + 1 end
    end
    local simIndex = 0
    local groups = { {}, {}, {}, {} }
    local tempUnit
    local pets = {}
    for _, u in ipairs(list) do
        if u == "target" then
            tempUnit = u
        elseif type(u) == "string" and u:find("pet") then
            pets[#pets + 1] = u
        elseif u == "sim" then
            simIndex = simIndex + 1
            local role = EvsHL.SimRole(simIndex, simTotal)
            local g = role == "TANK" and 1 or role == "PLAYER" and 2 or role == "HEALER" and 3 or 4
            groups[g][#groups[g] + 1] = u
        else
            local p = EvsHL.RolePriority(u)
            groups[p][#groups[p] + 1] = u
        end
    end
    for _, u in ipairs(pets) do groups[4][#groups[4] + 1] = u end
    if tempUnit then groups[4][#groups[4] + 1] = tempUnit end
    local priority = {}
    for _, g in ipairs({ groups[1], groups[2], groups[3] }) do
        for _, u in ipairs(g) do priority[#priority + 1] = u end
    end
    local others = groups[4]
    local sorted = {}
    local positions = {}
    local rowCount
    local roleColumns = cols
    local priorityCount = #priority
    local othersCount = #others
    if priorityCount + othersCount <= 1 or cols <= 1 then
        for _, u in ipairs(priority) do sorted[#sorted + 1] = u end
        for _, u in ipairs(others) do sorted[#sorted + 1] = u end
        rowCount = math.max(priorityCount + othersCount, 1)
        for i = 1, #sorted do positions[i] = { row = i - 1, col = 0 } end
        return sorted, positions, rowCount, 1
    end
    local firstDpsCol = priorityCount > 0 and 1 or 0
    local dpsColumns = math.max(cols - firstDpsCol, 1)
    local dpsRows = math.max(math.ceil(othersCount / dpsColumns), 1)
    rowCount = math.max(priorityCount, dpsRows, 1)
    local usedColumns = priorityCount > 0 and 1 or 0
    for i = 1, priorityCount do
        sorted[#sorted + 1] = priority[i]
        positions[#sorted] = { row = i - 1, col = 0 }
    end
    for i = 1, othersCount do
        local col = firstDpsCol + math.floor((i - 1) / rowCount)
        if col > firstDpsCol + dpsColumns - 1 then col = firstDpsCol + dpsColumns - 1 end
        local row = (i - 1) % rowCount
        sorted[#sorted + 1] = others[i]
        positions[#sorted] = { row = row, col = col }
        if col + 1 > usedColumns then usedColumns = col + 1 end
    end
    return sorted, positions, rowCount, math.max(usedColumns, 1)
end
-- Public helper used by Refresh. Returns sorted list, positions, rowCount, columns.
function EvsHL.GetOrderedList(list, raid, cols)
    local S = EvsHL.S
    if (S.sortByRole or next(S.roleOverrides or {})) and #list > 1 then
        local key = table.concat(list, ",") .. "|" .. tostring(cols)
        if orderCacheDirty or key ~= orderCacheKey then
            cachedOrder, cachedPositions, cachedRowCount, cachedColumns = BuildOrder(list, raid, cols)
            orderCacheKey = key
            orderCacheDirty = false
        end
        return cachedOrder, cachedPositions, cachedRowCount, cachedColumns
    end
    return nil
end
function EvsHL.BuildOrder(list, raid, cols)
    return BuildOrder(list, raid, cols)
end