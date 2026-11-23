-- Group ordering + caching for the grid layout.
local EvsHL = EvsHL
local orderCacheDirty = true
local orderCacheKey
local cachedOrder, cachedPositions, cachedRowCount, cachedColumns
function EvsHL.MarkOrderDirty() orderCacheDirty = true end

local DEFAULT_ORDER = { "TANK", "PLAYER", "HEALER", "BREAK", "DPS", "PETS", "TARGET" }
local KNOWN = {}
for _, key in ipairs(DEFAULT_ORDER) do KNOWN[key] = true end
local PRIORITY_KEYS = { "TANK", "PLAYER", "HEALER", "DPS" }

EvsHL.SORT_WITHIN_OPTIONS = {
    { "none", "Default order" }, { "name", "Name (A-Z)" }, { "nameDesc", "Name (Z-A)" },
    { "class", "Class" }, { "group", "Raid group" },
}
EvsHL.SORT_FILL_OPTIONS = {
    { "down", "Down, then across" }, { "across", "Across, then down" },
}
local WITHIN_VALID, FILL_VALID = {}, {}
for _, o in ipairs(EvsHL.SORT_WITHIN_OPTIONS) do WITHIN_VALID[o[1]] = true end
for _, o in ipairs(EvsHL.SORT_FILL_OPTIONS) do FILL_VALID[o[1]] = true end

function EvsHL.GetSortOrder()
    local S = EvsHL.S
    local out, seen = {}, {}
    if type(S.sortOrder) == "table" then
        for _, key in ipairs(S.sortOrder) do
            if KNOWN[key] and not seen[key] then
                seen[key] = true
                out[#out + 1] = key
            end
        end
    end
    for _, key in ipairs(DEFAULT_ORDER) do
        if not seen[key] then out[#out + 1] = key end
    end
    return out
end
function EvsHL.SetSortOrder(order)
    local copy = {}
    for i, key in ipairs(order) do copy[i] = key end
    EvsHL.S.sortOrder = copy
    orderCacheDirty = true
end
function EvsHL.GetSortWithin()
    local v = EvsHL.S.sortWithin
    return WITHIN_VALID[v] and v or "none"
end
function EvsHL.GetSortFill()
    local v = EvsHL.S.sortFill
    return FILL_VALID[v] and v or "down"
end
function EvsHL.ResetSorting()
    local S = EvsHL.S
    S.sortOrder, S.sortWithin, S.sortFill, S.sortReverse = nil, nil, nil, nil
    S.sortByRole = EvsHL.DEFAULTS.sortByRole
    orderCacheDirty = true
end

local function Classify(u, simIndex, simTotal)
    if u == "target" then return "TARGET" end
    if type(u) == "string" and u:find("pet") then return "PETS" end
    if u == "sim" then
        local role = EvsHL.SimRole(simIndex, simTotal)
        return role == "TANK" and "TANK" or role == "PLAYER" and "PLAYER" or role == "HEALER" and "HEALER" or "DPS"
    end
    return PRIORITY_KEYS[EvsHL.RolePriority(u)] or "DPS"
end
local function SortName(unit)
    local name = UnitName(unit)
    if EvsHL.IsSecretValue(name) or type(name) ~= "string" then return "" end
    return name:lower()
end
local function SortClass(unit)
    local _, class = UnitClass(unit)
    if EvsHL.IsSecretValue(class) or type(class) ~= "string" then return "" end
    return class
end
local function RaidGroup(u)
    local index = type(u) == "string" and tonumber(u:match("^raid(%d+)$"))
    if index and GetRaidRosterInfo then
        local ok, _, _, subgroup = pcall(GetRaidRosterInfo, index)
        if ok and not EvsHL.IsSecretValue(subgroup) and type(subgroup) == "number" then
            return subgroup
        end
    end
    return 99
end
local function SortGroup(items, mode, reverse)
    if mode ~= "none" and #items > 1 then
        for _, it in ipairs(items) do
            local u = it.unit
            it.name = SortName(u)
            if mode == "class" then
                it.class = SortClass(u)
            elseif mode == "group" then
                it.group = RaidGroup(u)
            end
        end
        table.sort(items, function(a, b)
            if mode == "name" then
                if a.name ~= b.name then return a.name < b.name end
            elseif mode == "nameDesc" then
                if a.name ~= b.name then return a.name > b.name end
            elseif mode == "class" then
                if a.class ~= b.class then return a.class < b.class end
                if a.name ~= b.name then return a.name < b.name end
            elseif mode == "group" then
                if a.group ~= b.group then return a.group < b.group end
            end
            return a.idx < b.idx
        end)
    end
    if reverse then
        local n = #items
        for i = 1, math.floor(n / 2) do items[i], items[n - i + 1] = items[n - i + 1], items[i] end
    end
end
local function Segments(order, byCat)
    local segments, current = {}, {}
    for _, key in ipairs(order) do
        if key == "BREAK" then
            segments[#segments + 1] = current
            current = {}
        else
            for _, u in ipairs(byCat[key] or {}) do current[#current + 1] = u end
        end
    end
    segments[#segments + 1] = current
    return segments
end
-- Every segment before the last stacks in its own column; the last one flows across the remaining columns.
local function Arrange(segments, cols, fill)
    local stacks, flow = {}, {}
    local last = #segments
    for i, seg in ipairs(segments) do
        if cols > 1 and i < last and #seg > 0 and #stacks < cols - 1 then
            stacks[#stacks + 1] = seg
        else
            for _, u in ipairs(seg) do flow[#flow + 1] = u end
        end
    end
    local sorted, positions = {}, {}
    local rowCount = 1
    for _, seg in ipairs(stacks) do rowCount = math.max(rowCount, #seg) end
    local flowCols = math.max(cols - #stacks, 1)
    local flowCount = #flow
    local across = fill == "across"
    local perRow = math.max(math.min(flowCols, flowCount), 1)
    if across then
        rowCount = math.max(rowCount, math.ceil(flowCount / perRow))
    else
        rowCount = math.max(rowCount, math.ceil(flowCount / flowCols))
    end
    local usedColumns = #stacks
    for c, seg in ipairs(stacks) do
        for r, u in ipairs(seg) do
            sorted[#sorted + 1] = u
            positions[#sorted] = { row = r - 1, col = c - 1 }
        end
    end
    local base = #stacks
    for i, u in ipairs(flow) do
        local row, col
        if across then
            row, col = math.floor((i - 1) / perRow), base + (i - 1) % perRow
        else
            row, col = (i - 1) % rowCount, base + math.floor((i - 1) / rowCount)
        end
        sorted[#sorted + 1] = u
        positions[#sorted] = { row = row, col = col }
        if col + 1 > usedColumns then usedColumns = col + 1 end
    end
    return sorted, positions, rowCount, math.max(usedColumns, 1)
end
local function BuildOrder(list, raid, cols)
    local S = EvsHL.S
    local simTotal = 0
    for _, u in ipairs(list) do
        if u == "sim" then simTotal = simTotal + 1 end
    end
    local simIndex = 0
    local groups = {}
    for key in pairs(KNOWN) do groups[key] = {} end
    for i, u in ipairs(list) do
        if u == "sim" then simIndex = simIndex + 1 end
        local g = groups[Classify(u, simIndex, simTotal)]
        g[#g + 1] = { unit = u, idx = i }
    end
    local mode, reverse = EvsHL.GetSortWithin(), S.sortReverse and true or false
    local byCat = {}
    for key, items in pairs(groups) do
        SortGroup(items, mode, reverse)
        local units = {}
        for i, it in ipairs(items) do units[i] = it.unit end
        byCat[key] = units
    end
    return Arrange(Segments(EvsHL.GetSortOrder(), byCat), cols, EvsHL.GetSortFill())
end
function EvsHL.SortPreview(counts, cols)
    local byCat = {}
    for key in pairs(KNOWN) do
        local items = {}
        for i = 1, counts[key] or 0 do items[i] = key end
        byCat[key] = items
    end
    return Arrange(Segments(EvsHL.GetSortOrder(), byCat), cols, EvsHL.GetSortFill())
end
local function ExtraKey(list, mode)
    local parts = {}
    for i, u in ipairs(list) do
        local value
        if mode == "group" then
            value = tostring(RaidGroup(u))
        elseif mode == "class" then
            local class, name = SortClass(u), SortName(u)
            value = #class .. ":" .. class .. name
        else
            value = SortName(u)
        end
        parts[i] = #value .. ":" .. value
    end
    return table.concat(parts)
end
-- Public helper used by Refresh. Returns sorted list, positions, rowCount, columns.
function EvsHL.GetOrderedList(list, raid, cols)
    local S = EvsHL.S
    if S.sortByRole and #list > 1 then
        local key = table.concat(list, ",") .. "|" .. tostring(cols)
        local mode = EvsHL.GetSortWithin()
        if mode ~= "none" then key = key .. "|" .. ExtraKey(list, mode) end
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